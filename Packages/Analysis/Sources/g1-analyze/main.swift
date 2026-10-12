#if os(macOS)
    import Analysis
    import AVFoundation
    import Capture
    import Foundation

    // g1-analyze: runs the offline analyses on a clip recorded by the G1 capture harness.
    //   g1-analyze <clip.mov> [--manifest clip.json] [--fps 240] [--json report.json] [--annotation-template out.json --annotator id]
    // Prints a readable report; exits 1 if the manifest disagrees with the decoded file, 2 on usage or decode errors.

    func fail(_ message: String, code: Int32) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(code)
    }

    func option(_ name: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: name), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    func lumaFrame(from buffer: CVPixelBuffer) -> LumaFrame? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0), height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        var pixels = [UInt8](repeating: 0, count: width * height)
        let source = base.assumingMemoryBound(to: UInt8.self)
        for y in 0 ..< height {
            for x in 0 ..< width {
                pixels[y * width + x] = source[y * stride + x]
            }
        }
        return LumaFrame(width: width, height: height, pixels: pixels)
    }

    func format(_ value: Double?, _ digits: Int = 3) -> String {
        value.map { String(format: "%.\(digits)f", $0) } ?? "n/a"
    }

    let args = Array(CommandLine.arguments.dropFirst())
    guard let path = args.first, !path.hasPrefix("--") else {
        fail(
            "usage: g1-analyze <clip.mov> [--manifest clip.json] [--fps 240] [--json report.json] "
                + "[--annotation-template out.json --annotator id]",
            code: 2
        )
    }

    let manifestURL = option("--manifest", in: args).map { URL(fileURLWithPath: $0) }
    var manifest: CaptureManifest?
    if let manifestURL {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do { manifest = try decoder.decode(CaptureManifest.self, from: Data(contentsOf: manifestURL)) } catch {
            fail("cannot read manifest \(manifestURL.path): \(error)", code: 2)
        }
    }

    let fps = option("--fps", in: args).flatMap(Double.init) ?? manifest?.requestedFrameRate ?? 240

    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { fail("no video track in \(path)", code: 2) }
    let size = try await track.load(.naturalSize)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
        track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
    )
    reader.add(output)
    guard reader.startReading() else { fail("cannot start reading: \(String(describing: reader.error))", code: 2) }

    var analyzer = ClipAnalyzer(nominalFrameRate: fps)
    var frames = 0
    while let sample = output.copyNextSampleBuffer() {
        guard let buffer = CMSampleBufferGetImageBuffer(sample), let frame = lumaFrame(from: buffer) else { continue }
        analyzer.ingest(pts: CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)), frame: frame)
        frames += 1
    }

    if reader.status == .failed {
        fail("decode failed: \(String(describing: reader.error))", code: 2)
    }

    let report = analyzer.report()

    print(
        "clip      \(URL(fileURLWithPath: path).lastPathComponent)  \(Int(size.width))x\(Int(size.height))  "
            + "frames=\(frames)  nominal \(Int(fps)) fps"
    )
    let t = report.timing
    print(
        "timing    measured \(format(t.measuredFrameRate, 2)) fps, "
            + "gaps \(t.gapEvents) (missing \(t.missingFrames)), jitter \(t.jitterEvents), " +
            "non-monotonic \(t.nonMonotonicEvents), within tolerance \(format(t.fractionWithinTolerance.map { $0 * 100 }, 2))%"
    )
    if let scale = t.quantizedTimescale {
        print("          NOTE: file timestamps are quantised to 1/\(scale) s, so the jitter above is the container, not the camera;")
        print("          intervals within one tick of nominal: \(format(t.fractionWithinOneTick.map { $0 * 100 }, 2))%")
    }

    for gap in t.gaps.prefix(10) {
        print("          gap after frame \(gap.afterFrameIndex): \(gap.missingFrames) missing")
    }

    if let l = report.luma {
        print("luma      mean \(format(l.mean)) min \(format(l.minimum)) max \(format(l.maximum))")
    }

    if let f = report.flicker {
        print(
            "flicker   peak \(format(f.peakFrequencyHz, 1)) Hz, modulation \(format(f.relativeAmplitude * 100, 2))% "
                + "(resolution \(format(f.resolutionHz, 2)) Hz)"
        )
    }

    if let s = report
        .sharpness {
        print("sharpness median \(format(s.median, 1)) p10 \(format(s.p10, 1)) min \(format(s.minimum, 1)) (relative, higher = sharper)")
    }

    print("motion    triggers at frames \(report.motionTriggerFrames.prefix(10).map(String.init).joined(separator: ", "))" +
        "; peak score \(format(report.peakMotionScore, 2)) at frame \(report.peakMotionFrame.map(String.init) ?? "n/a")")

    var exitCode: Int32 = 0
    if let manifest {
        let problems = ManifestConsistency.compare(report: report, manifest: manifest)
        print(problems.isEmpty ? "manifest  consistent with the file (frames, gaps, missing)" : "manifest  MISMATCH:")
        for problem in problems {
            print("          \(problem)")
        }
        if !problems.isEmpty {
            exitCode = 1
        }
    }

    if let out = option("--json", in: args) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: URL(fileURLWithPath: out))
        print("wrote     \(out)")
    }

    if let out = option("--annotation-template", in: args) {
        let info = ClipInfo(
            clipID: manifest?.clipID ?? UUID(), annotator: option("--annotator", in: args) ?? "unknown",
            width: Int(size.width), height: Int(size.height), frameCount: frames
        )
        let template = try AnnotationTemplate.make(for: info, center: report.peakMotionFrame ?? frames / 2, span: 24)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(template).write(to: URL(fileURLWithPath: out))
        print("wrote     \(out) (\(template.frames.count) frames to annotate)")
    }

    exit(exitCode)
#endif
