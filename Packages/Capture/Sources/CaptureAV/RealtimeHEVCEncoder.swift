#if os(iOS)
    import Capture
    import CoreMedia
    import VideoToolbox

    /// Compressed HEVC sample, handed across once from the encoder callback.
    public struct CompressedBox: @unchecked Sendable {
        public let sample: CMSampleBuffer
    }

    public enum EncoderError: Error {
        case sessionCreateFailed(OSStatus)
        case propertyFailed(OSStatus)
        case encodeFailed(OSStatus)
    }

    /// Real-time all-intra HEVC encoder. Every frame is a key frame, so a clip can start at any frame and no inter-frame
    /// prediction smears the ball. Compressed frames are small, so the ring buffer can hold seconds of video without
    /// holding the camera's raw buffers. BEHAVIOUR NOT RUN: compile-checked only (needs a physical iPhone).
    public final class RealtimeHEVCEncoder: @unchecked Sendable {
        private var session: VTCompressionSession?
        public var onSample: (@Sendable (CompressedBox, Int, Double) -> Void)?
        private let frameRate: Double

        /// - Parameter maxBitRate: hard cap over a one-second window (bits/s). Noisy dark scenes make all-intra frames huge; without a cap
        ///   the encoder can burst to ~10x the average bit rate and fall behind the camera.
        public init(width: Int, height: Int, frameRate: Double, bitRate: Int, maxBitRate: Int? = nil) throws {
            self.frameRate = frameRate
            var created: VTCompressionSession?
            let spec: [CFString: Any] = [kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: true]
            let status = VTCompressionSessionCreate(
                allocator: nil, width: Int32(width), height: Int32(height), codecType: kCMVideoCodecType_HEVC,
                encoderSpecification: spec as CFDictionary, imageBufferAttributes: nil, compressedDataAllocator: nil,
                outputCallback: nil, refcon: nil, compressionSessionOut: &created
            )
            guard status == noErr, let created else { throw EncoderError.sessionCreateFailed(status) }
            session = created
            var properties: [(CFString, CFTypeRef)] = [
                (kVTCompressionPropertyKey_RealTime, kCFBooleanTrue),
                (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse),
                (kVTCompressionPropertyKey_MaxKeyFrameInterval, 1 as CFNumber),
                (kVTCompressionPropertyKey_ExpectedFrameRate, frameRate as CFNumber),
                (kVTCompressionPropertyKey_AverageBitRate, bitRate as CFNumber),
                (kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel),
            ]
            if let maxBitRate {
                // [bytes, seconds]
                properties.append((kVTCompressionPropertyKey_DataRateLimits, [maxBitRate / 8, 1] as CFArray))
            }
            for (key, value) in properties {
                let result = VTSessionSetProperty(created, key: key, value: value)
                guard result == noErr else { throw EncoderError.propertyFailed(result) }
            }
            VTCompressionSessionPrepareToEncodeFrames(created)
        }

        /// Submits a frame. The compressed sample arrives on the encoder's thread via `onSample` with the original PTS.
        public func encode(_ pixels: CVPixelBuffer, pts: Double, index: Int) throws {
            guard let session else { return }
            let time = CMTime(seconds: pts, preferredTimescale: 1_000_000)
            let duration = CMTime(seconds: 1 / frameRate, preferredTimescale: 1_000_000)
            let handler = onSample
            let status = VTCompressionSessionEncodeFrame(
                session, imageBuffer: pixels, presentationTimeStamp: time, duration: duration, frameProperties: nil,
                infoFlagsOut: nil
            ) { status, _, sample in
                guard status == noErr, let sample else { return }
                handler?(CompressedBox(sample: sample), index, pts)
            }
            guard status == noErr else { throw EncoderError.encodeFailed(status) }
        }

        public func finish() {
            guard let session else { return }
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
    }
#endif
