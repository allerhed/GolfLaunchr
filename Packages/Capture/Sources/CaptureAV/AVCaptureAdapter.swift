#if os(iOS)
    import AVFoundation
    import Capture

    /// CMSampleBuffer is not Sendable; the adapter hands it across exactly once, from the capture queue.
    public struct SampleBufferBox: @unchecked Sendable {
        public let buffer: CMSampleBuffer
    }

    /// Maps AVFoundation formats to platform-neutral descriptors. Field of view comes from the platform, never guessed.
    public enum AVFormatCatalog {
        public static func backCameras() -> [AVCaptureDevice] {
            AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
                mediaType: .video,
                position: .back
            ).devices
        }

        static func lens(for device: AVCaptureDevice) -> LensKind {
            switch device.deviceType {
            case .builtInWideAngleCamera: .wide
            case .builtInUltraWideCamera: .ultraWide
            case .builtInTelephotoCamera: .telephoto
            default: .other
            }
        }

        /// Every format of the device paired with its descriptor, in the device's own order (the id encodes the index).
        public static func formats(of device: AVCaptureDevice) -> [(format: AVCaptureDevice.Format, descriptor: CaptureFormatDescriptor)] {
            device.formats.enumerated().map { index, format in
                let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let rate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
                let descriptor = CaptureFormatDescriptor(
                    id: "\(device.deviceType.rawValue)#\(index)-\(size.width)x\(size.height)",
                    lens: lens(for: device),
                    width: Int(size.width),
                    height: Int(size.height),
                    maxFrameRate: rate,
                    fieldOfViewDegrees: Double(format.videoFieldOfView),
                    isVideoBinned: format.isVideoBinned
                )
                return (format, descriptor)
            }
        }

        public static func exposureSample(of device: AVCaptureDevice, at time: Double) -> ExposureSample {
            ExposureSample(
                time: time,
                durationSeconds: CMTimeGetSeconds(device.exposureDuration),
                iso: Double(device.iso),
                lensPosition: Double(device.lensPosition)
            )
        }
    }

    public struct AppliedCaptureSettings: Sendable, Equatable {
        public let stabilization: String
        public let requestedFrameRate: Double
        /// Frame duration the device accepted; compare with the request to detect silent changes.
        public let activeFrameRate: Double
    }

    public enum CaptureAVError: Error {
        case cannotAddInput
        case cannotAddOutput
        case permissionDenied
    }

    /// Live camera frames as `Frame` values with presentation timestamps, plus dropped-frame reasons.
    /// BEHAVIOUR NOT RUN: compile-checked only. Needs a physical iPhone (G1, plan items 1.3/1.4).
    public final class AVCaptureFrameSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
        public let session = AVCaptureSession()
        public let frames: AsyncStream<Frame<SampleBufferBox>>
        public let drops: AsyncStream<DroppedFrameReason>
        private let frameContinuation: AsyncStream<Frame<SampleBufferBox>>.Continuation
        private let dropContinuation: AsyncStream<DroppedFrameReason>.Continuation
        private let queue = DispatchQueue(label: "golflaunchr.capture.frames", qos: .userInitiated)
        private let device: AVCaptureDevice
        private var nextIndex = 0

        public init(device: AVCaptureDevice) {
            self.device = device
            (frames, frameContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
            (drops, dropContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
            super.init()
        }

        /// Selects `format` at `frameRate` (locked min = max duration) and starts delivery. Returns what was actually applied.
        public func start(format: AVCaptureDevice.Format, frameRate: Double) throws -> AppliedCaptureSettings {
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { throw CaptureAVError.permissionDenied }
            session.beginConfiguration()
            session.sessionPreset = .inputPriority
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CaptureAVError.cannotAddInput }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw CaptureAVError.cannotAddOutput }
            session.addOutput(output)
            try device.lockForConfiguration()
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
            var stabilization = "unavailable"
            if let connection = output.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .off
                }
                stabilization = String(describing: connection.activeVideoStabilizationMode)
                if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                } // landscape-right sensor orientation
            }
            session.commitConfiguration()
            session.startRunning()
            let active = CMTimeGetSeconds(device.activeVideoMinFrameDuration)
            return AppliedCaptureSettings(
                stabilization: stabilization, requestedFrameRate: frameRate, activeFrameRate: active > 0 ? 1 / active : 0
            )
        }

        public func stop() {
            session.stopRunning()
            frameContinuation.finish()
            dropContinuation.finish()
        }

        public func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let frame = Frame(
                index: nextIndex, pts: pts, byteCost: CMSampleBufferGetTotalSampleSize(sampleBuffer),
                payload: SampleBufferBox(buffer: sampleBuffer)
            )
            nextIndex += 1
            frameContinuation.yield(frame)
        }

        public func captureOutput(_: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
            let raw = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReason, attachmentModeOut: nil)
            let text = raw.map { String(describing: $0) } ?? ""
            let reason: DroppedFrameReason = switch text {
            case String(kCMSampleBufferDroppedFrameReason_FrameWasLate): .frameWasLate
            case String(kCMSampleBufferDroppedFrameReason_OutOfBuffers): .outOfBuffers
            case String(kCMSampleBufferDroppedFrameReason_Discontinuity): .discontinuity
            default: .unknown
            }
            dropContinuation.yield(reason)
        }
    }
#endif
