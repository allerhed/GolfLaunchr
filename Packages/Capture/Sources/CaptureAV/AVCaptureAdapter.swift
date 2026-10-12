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

    /// Live camera frames with presentation timestamps (via `onFrame`), plus dropped-frame reasons.
    /// BEHAVIOUR NOT RUN: compile-checked only. Needs a physical iPhone (G1, plan items 1.3/1.4).
    public final class AVCaptureFrameSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
        public let session = AVCaptureSession()
        public let drops: AsyncStream<DroppedFrameReason>
        private let dropContinuation: AsyncStream<DroppedFrameReason>.Continuation
        private let queue = DispatchQueue(label: "golflaunchr.capture.frames", qos: .userInitiated)
        private let device: AVCaptureDevice
        private var nextIndex = 0
        /// Called on the capture queue for every delivered frame. The pixel buffer is only valid for the call unless retained:
        /// hand it to an encoder at once, because holding raw buffers starves the camera's buffer pool.
        public var onFrame: (@Sendable (CVPixelBuffer, Double, Int) -> Void)?

        public init(device: AVCaptureDevice) {
            self.device = device
            (drops, dropContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
            super.init()
        }

        /// Selects `format` at `frameRate` (locked min = max duration) and starts delivery. Returns what was actually applied.
        /// - Parameter discardLateFrames: true (default) drops a frame when the previous callback is still running; false queues frames
        ///   so a brief callback spike delays frames instead of losing them, until the camera's buffer pool is exhausted.
        public func start(
            format: AVCaptureDevice.Format,
            frameRate: Double,
            discardLateFrames: Bool = true
        ) throws -> AppliedCaptureSettings {
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { throw CaptureAVError.permissionDenied }
            session.beginConfiguration()
            session.sessionPreset = .inputPriority
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CaptureAVError.cannotAddInput }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = discardLateFrames
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
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

        /// Waits for auto exposure to settle, then fixes the exposure duration and raises ISO to keep the same brightness,
        /// as far as the camera allows. Returns the plan with any light shortfall in stops (nil if exposure cannot be read).
        public func applyFixedExposure(durationSeconds: Double) async throws -> ExposurePlan? {
            try await Task.sleep(for: .seconds(1))
            let format = device.activeFormat
            guard let plan = ExposurePlanner.plan(
                autoDuration: CMTimeGetSeconds(device.exposureDuration),
                autoISO: Double(device.iso),
                targetDuration: durationSeconds,
                isoRange: Double(format.minISO) ... Double(format.maxISO),
                durationRange: CMTimeGetSeconds(format.minExposureDuration) ... CMTimeGetSeconds(format.maxExposureDuration)
            ) else { return nil }
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.setExposureModeCustom(
                duration: CMTime(seconds: plan.durationSeconds, preferredTimescale: 1_000_000), iso: Float(plan.iso), completionHandler: nil
            )
            return plan
        }

        public func stop() {
            if device.isExposureModeSupported(.continuousAutoExposure), (try? device.lockForConfiguration()) != nil {
                device.exposureMode = .continuousAutoExposure
                device.unlockForConfiguration()
            }
            session.stopRunning()
            dropContinuation.finish()
        }

        public func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
            guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let index = nextIndex
            nextIndex += 1
            onFrame?(pixels, pts, index)
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
