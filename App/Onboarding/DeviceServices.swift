import AVFoundation
import Capture
import CaptureAV
import Foundation
import UIKit

enum CameraPermission: Equatable {
    case notDetermined, authorized, denied
}

/// Camera permission, behind a protocol so tests never show the system prompt.
protocol CameraAccess: Sendable {
    func status() -> CameraPermission
    func request() async -> CameraPermission
}

/// Reads what this device reports. No permission is needed to list formats.
protocol DeviceInspecting: Sendable {
    func facts() -> DeviceFacts
}

struct LiveCameraAccess: CameraAccess {
    func status() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied // denied or restricted: both are "not allowed", and both route to Settings
        }
    }

    func request() async -> CameraPermission {
        if status() == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return status()
    }
}

struct LiveDeviceInspector: DeviceInspecting {
    func facts() -> DeviceFacts {
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        let free = (try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let formats = AVFormatCatalog.backCameras().flatMap { AVFormatCatalog.formats(of: $0).map(\.descriptor) }
        return DeviceFacts(
            modelIdentifier: model, osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            freeStorageBytes: free, formats: formats
        )
    }
}

#if DEBUG
    /// UI-test doubles, Debug builds only (selected by `-uiTestFakeCamera`).
    struct FakeCameraAccess: CameraAccess {
        let result: CameraPermission
        func status() -> CameraPermission {
            .notDetermined
        }

        func request() async -> CameraPermission {
            result
        }
    }

    struct FakeDeviceInspector: DeviceInspecting {
        let hasCamera: Bool
        func facts() -> DeviceFacts {
            let format = CaptureFormatDescriptor(
                id: "fake#0", lens: .wide, width: 1920, height: 1080, maxFrameRate: 240, fieldOfViewDegrees: 70
            )
            return DeviceFacts(
                modelIdentifier: "FakePhone1,1", osMajorVersion: 26, freeStorageBytes: 50_000_000_000, formats: hasCamera ? [format] : []
            )
        }
    }
#endif
