@testable import Capture
import Foundation

/// Fake frame source: paced frames with optional missing frames and per-frame jitter. Test-only.
enum FakeFrames {
    static func make(
        count: Int,
        fps: Double = 240,
        start: Double = 100,
        skipping: Set<Int> = [],
        bytes: Int = 1000,
        firstIndex: Int = 0
    ) -> [Frame<Int>] {
        (0 ..< count).filter { !skipping.contains($0) }.map { i in
            Frame(index: firstIndex + i, pts: start + Double(i) / fps, byteCost: bytes, payload: i)
        }
    }
}

func format(
    _ id: String,
    fps: Double,
    fov: Double? = 63,
    w: Int = 1920,
    h: Int = 1080,
    lens: LensKind = .wide
) -> CaptureFormatDescriptor {
    CaptureFormatDescriptor(id: id, lens: lens, width: w, height: h, maxFrameRate: fps, fieldOfViewDegrees: fov)
}
