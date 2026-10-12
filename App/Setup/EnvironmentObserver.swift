import AVFoundation
import Capture
import CaptureAV
import Foundation

/// Source of live scene observations for the setup screen.
protocol EnvironmentObserving: Sendable {
    func start() -> AsyncStream<SetupObservation>
    func stop()
}

/// Frame callbacks arrive on one capture queue; the box makes that single-writer state explicit for the compiler.
private final class MonitorBox: @unchecked Sendable {
    private var monitor = SetupMonitor()
    private var lastReport = 0.0
    private let device: AVCaptureDevice

    init(device: AVCaptureDevice) {
        self.device = device
    }

    /// Adds a frame; returns an observation about four times a second.
    func add(_ grid: LumaGrid, at time: Double) -> SetupObservation? {
        monitor.add(grid, at: time)
        guard time - lastReport >= 0.25 else { return nil }
        lastReport = time
        return monitor.observation(exposureSeconds: CMTimeGetSeconds(device.exposureDuration))
    }
}

/// Real camera on the device: frames -> coarse luma grids -> `SetupMonitor`, reported about four times a second.
/// BEHAVIOUR NOT RUN: compile-checked only (the simulator has no camera). Needs the physical iPhone.
final class LiveEnvironmentObserver: EnvironmentObserving, @unchecked Sendable {
    private var source: AVCaptureFrameSource?
    private let lock = NSLock()

    func start() -> AsyncStream<SetupObservation> {
        AsyncStream { continuation in
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  let device = AVFormatCatalog.backCameras().first(where: { $0.deviceType == .builtInWideAngleCamera })
                  ?? AVFormatCatalog.backCameras().first,
                  let chosen = AVFormatCatalog.formats(of: device)
                  .filter({ FormatCatalog.rejection($0.descriptor) == nil })
                  .max(by: { $0.descriptor.maxFrameRate < $1.descriptor.maxFrameRate })
            else {
                continuation.yield(SetupObservation()) // nothing measured: the screen shows "camera not running"
                continuation.finish()
                return
            }
            let frames = AVCaptureFrameSource(device: device)
            let state = MonitorBox(device: device)
            frames.onFrame = { pixels, pts, _ in
                guard let grid = LumaSampler.grid(from: pixels) else { return }
                if let observation = state.add(grid, at: pts) {
                    continuation.yield(observation)
                }
            }
            do {
                _ = try frames.start(format: chosen.format, frameRate: min(240, chosen.descriptor.maxFrameRate))
                lock.lock(); source = frames; lock.unlock()
            } catch {
                continuation.yield(SetupObservation())
                continuation.finish()
            }
            continuation.onTermination = { [weak self] _ in self?.stop() }
        }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        source?.stop()
        source = nil
    }
}

#if DEBUG
    /// UI-test scenes (`-uiTestSetupScene good|dark|moving|flicker|none`), Debug builds only.
    struct FakeEnvironmentObserver: EnvironmentObserving {
        let scene: String

        func start() -> AsyncStream<SetupObservation> {
            AsyncStream { continuation in
                var o = SetupObservation(
                    meanLuma: 0.45,
                    clippedFraction: 0.01,
                    motionScore: 0.4,
                    flickerIndex: 0.004,
                    exposureSeconds: 1.0 / 2000
                )
                switch scene {
                case "dark": o.meanLuma = 0.04
                case "moving": o.motionScore = 12
                case "flicker": o.flickerIndex = 0.12
                case "none": o = SetupObservation()
                default: break
                }
                continuation.yield(o)
                continuation.finish()
            }
        }

        func stop() {}
    }
#endif
