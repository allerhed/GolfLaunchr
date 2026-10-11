#if os(iOS)
    import AVFoundation
    import Capture

    public enum ClipWriterError: Error {
        case noFrames
        case cannotStart
        case failed(String)
    }

    /// Writes already-compressed HEVC samples to a .mov without re-encoding (passthrough), preserving every PTS.
    /// BEHAVIOUR NOT RUN: compile-checked only.
    public enum ClipWriter {
        public static func write(_ frames: [Frame<CompressedBox>], to url: URL) async throws {
            guard let first = frames.first else { throw ClipWriterError.noFrames }
            let hint = CMSampleBufferGetFormatDescription(first.payload.sample)
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: hint)
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else { throw ClipWriterError.cannotStart }
            writer.add(input)
            guard writer.startWriting() else { throw ClipWriterError.failed(writer.error?.localizedDescription ?? "startWriting") }
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(first.payload.sample))
            for frame in frames {
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(for: .milliseconds(2))
                }
                guard input.append(frame.payload.sample) else {
                    throw ClipWriterError.failed(writer.error?.localizedDescription ?? "append failed at frame \(frame.index)")
                }
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw ClipWriterError.failed(writer.error?.localizedDescription ?? "finishWriting") }
        }
    }
#endif
