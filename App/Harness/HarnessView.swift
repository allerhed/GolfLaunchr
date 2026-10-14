#if CAPTURE_HARNESS
    import AVFoundation
    import SwiftUI

    /// Debug-only G1 capture harness screen. Verbatim English text on purpose: developer tooling, never shipped.
    struct HarnessView: View {
        @State private var model = HarnessModel()
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                GeometryReader { proxy in
                    let wide = proxy.size.width > proxy.size.height
                    Group {
                        if wide {
                            HStack(spacing: 0) {
                                preview.frame(width: proxy.size.width * 0.45)
                                controls
                            }
                        } else {
                            VStack(spacing: 0) {
                                preview.frame(height: proxy.size.height * 0.28)
                                controls
                            }
                        }
                    }
                }
                .navigationTitle(Text(verbatim: "DEBUG HARNESS"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { Task { await model.stop(); dismiss() } } label: { Text(verbatim: "Close") }
                            .accessibilityIdentifier("harness.close")
                    }
                }
            }
            .task {
                if let config = HarnessAutorunConfig.current {
                    await model.runAutorun(config)
                } else {
                    model.loadFormats()
                }
            }
            .accessibilityIdentifier("harness.root")
        }

        private var preview: some View {
            ZStack {
                Color.black
                if model.previewSession != nil {
                    CameraPreview(session: model.previewSession)
                    sessionOverlay
                } else {
                    Text(verbatim: model.phase == .noCamera ? "No camera available" : "Preview starts with Start")
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("harness.previewState")
                }
            }
        }

        /// Big enough to read from the hitting position: which block and shot the next clip will be, and what was last saved.
        private var sessionOverlay: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(model.block) \(model.recordingKind.rawValue) next #\(model.upcomingSequence)")
                    .font(.title2.bold().monospacedDigit())
                Text(verbatim: "\(model.club) · \(model.exposurePreset.rawValue) · \(model.ball)").font(.headline)
                if let last = model.lastSavedLabel {
                    Text(verbatim: "Saved \(last)").font(.headline).foregroundStyle(.green)
                }
            }
            .padding(8)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("harness.sessionOverlay")
        }

        private var controls: some View {
            @Bindable var model = model
            return Form {
                Section {
                    Text(
                        verbatim: "DEBUG HARNESS: records raw clips for offline analysis. Not shipped. "
                            + "Creates no shots, credits or measurements."
                    )
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("harness.banner")
                    if let message = model.message {
                        Text(verbatim: message).font(.footnote).accessibilityIdentifier("harness.message")
                    }
                    statusRow
                }
                Section(header: Text(verbatim: "Camera")) {
                    Picker(selection: $model.selectedFormatID) {
                        ForEach(model.formats) { Text(verbatim: $0.label).tag(Optional($0.id)) }
                    } label: { Text(verbatim: "Format") }
                        .disabled(model.phase == .running)
                        .accessibilityIdentifier("harness.format")
                    Picker(selection: $model.trigger) {
                        ForEach(TriggerMode.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Trigger") }
                        .pickerStyle(.segmented)
                        .disabled(model.phase == .running)
                    Picker(selection: $model.exposurePreset) {
                        ForEach(ExposurePreset.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Exposure") }
                        .pickerStyle(.segmented)
                        .disabled(model.phase == .running)
                        .accessibilityIdentifier("harness.exposure")
                    Stepper(value: $model.motionThreshold, in: 1 ... 40, step: 1) {
                        Text(verbatim: "Motion threshold \(Int(model.motionThreshold))")
                    }
                    .disabled(model.phase == .running)
                }
                Section(header: Text(verbatim: "Session (garage / bay with a reference monitor)")) {
                    field("Block", $model.block)
                    Button { model.block = Self.nextBlock(after: model.block) } label: { Text(verbatim: "Next block") }
                        .accessibilityIdentifier("harness.nextBlock")
                    Picker(selection: $model.recordingKind) {
                        ForEach(RecordingKind.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Recording") }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("harness.kind")
                    Picker(selection: $model.ball) {
                        Text(verbatim: "white").tag("white")
                        Text(verbatim: "marked").tag("marked")
                        Text(verbatim: "yellow").tag("yellow")
                    } label: { Text(verbatim: "Ball") }
                        .pickerStyle(.segmented)
                    field("Reference monitor", $model.referenceInstrument)
                    if !model.clips.isEmpty {
                        Button { model.markLast("void: false trigger") } label: { Text(verbatim: "Last clip: false trigger (void)") }
                            .accessibilityIdentifier("harness.voidLast")
                        Button { model.markLast("reference missed") } label: { Text(verbatim: "Last clip: reference monitor missed it") }
                        Button { model.markLast("mis-hit") } label: { Text(verbatim: "Last clip: mis-hit") }
                    }
                }
                Section(header: Text(verbatim: "Setup (recorded in the manifest)")) {
                    Picker(selection: $model.handedness) {
                        Text(verbatim: "right").tag("right")
                        Text(verbatim: "left").tag("left")
                    } label: { Text(verbatim: "Handedness") }
                        .pickerStyle(.segmented)
                    field("Club", $model.club)
                    field("Lighting", $model.lighting)
                    field("Location", $model.location)
                    field("Distance to ball (m)", $model.distanceText)
                    field("Camera height (m)", $model.heightText)
                    field("Golfer id", $model.golferID)
                }
                Section {
                    if model.phase == .running {
                        Button { Task { await model.saveNow() } } label: { Text(verbatim: "Save last 2 s now") }
                            .accessibilityIdentifier("harness.save")
                        Button(role: .destructive) { Task { await model.stop() } } label: { Text(verbatim: "Stop") }
                            .accessibilityIdentifier("harness.stop")
                    } else {
                        Button { Task { await model.start() } } label: { Text(verbatim: "Start") }
                            .disabled(model.formats.isEmpty)
                            .accessibilityIdentifier("harness.start")
                    }
                }
                Section(header: Text(verbatim: "Live")) {
                    liveRow("FPS (capture clock)", model.measuredFPS.map { String(format: "%.1f", $0) } ?? "-")
                    liveRow("Dropped / gaps / missing", "\(model.droppedTotal) / \(model.gapEvents) / \(model.missingFrames)")
                    liveRow("Exposure", model.exposureText)
                    if let plan = model.exposurePlanText {
                        liveRow("Exposure plan", plan)
                    }
                    liveRow("Orientation", model.orientationText)
                    liveRow("Callback", model.callbackText)
                    liveRow("Thermal", model.thermalText)
                    liveRow("Buffer", model.bufferText)
                    liveRow("Storage", model.freeSpaceText)
                }
                Section(header: Text(verbatim: "Saved clips (\(model.clips.count))")) {
                    ForEach(model.clips) { clip in
                        VStack(alignment: .leading) {
                            Text(verbatim: clip.movie.lastPathComponent).font(.footnote.monospaced())
                            Text(
                                verbatim: "\(clip.frames) frames, \(clip.missingFrames) missing, "
                                    + (clip.isComplete ? "complete" : "INCOMPLETE")
                            )
                            .font(.caption)
                            ShareLink(items: [clip.movie, clip.manifest]) { Text(verbatim: "Share clip + manifest") }
                        }
                    }
                }
            }
        }

        /// "B3" -> "B4"; anything without a trailing number gets "-2".
        static func nextBlock(after block: String) -> String {
            let digits = block.reversed().prefix { $0.isNumber }
            guard !digits.isEmpty, let n = Int(String(digits.reversed())) else { return block + "-2" }
            return String(block.dropLast(digits.count)) + String(n + 1)
        }

        @ViewBuilder private var statusRow: some View {
            switch model.phase {
            case .idle: Text(verbatim: "Idle").accessibilityIdentifier("harness.phase")
            case .running: Text(verbatim: "Recording").accessibilityIdentifier("harness.phase")
            case .noCamera: Text(verbatim: "No camera available on this device (simulator?)").accessibilityIdentifier("harness.phase")
            case .denied: Text(verbatim: "Camera permission denied: enable it in Settings").accessibilityIdentifier("harness.phase")
            case let .failed(reason): Text(verbatim: reason).accessibilityIdentifier("harness.phase")
            }
        }

        private func field(_ title: String, _ text: Binding<String>) -> some View {
            LabeledContent { TextField("", text: text).multilineTextAlignment(.trailing).textInputAutocapitalization(.never) } label: {
                Text(verbatim: title)
            }
        }

        private func liveRow(_ title: String, _ value: String) -> some View {
            LabeledContent { Text(verbatim: value).monospacedDigit() } label: { Text(verbatim: title) }
        }
    }

    struct CameraPreview: UIViewRepresentable {
        let session: AVCaptureSession?

        final class PreviewView: UIView {
            // swiftlint:disable:next static_over_final_class
            override class var layerClass: AnyClass {
                AVCaptureVideoPreviewLayer.self
            }

            var previewLayer: AVCaptureVideoPreviewLayer? {
                layer as? AVCaptureVideoPreviewLayer
            }
        }

        func makeUIView(context _: Context) -> PreviewView {
            let view = PreviewView()
            view.previewLayer?.videoGravity = .resizeAspect
            view.previewLayer?.session = session
            return view
        }

        func updateUIView(_ view: PreviewView, context _: Context) {
            view.previewLayer?.session = session
        }
    }
#endif
