@testable import Analysis
import Foundation

/// Synthetic clips with known truth. Test-only: not real footage and not evidence of anything about the camera.
struct Disc {
    let x: Double
    let y: Double
    let r: Double
}

enum Synthetic {
    static let width = 160
    static let height = 90

    static func frame(
        background: UInt8 = 20,
        disc: Disc? = nil,
        level: UInt8 = 220,
        gain: Double = 1
    ) -> LumaFrame {
        var pixels = [UInt8](repeating: UInt8(min(255, Double(background) * gain)), count: width * height)
        if let d = disc {
            for y in 0 ..< height {
                for x in 0 ..< width where (Double(x) - d.x) * (Double(x) - d.x) + (Double(y) - d.y) * (Double(y) - d.y) <= d.r * d.r {
                    pixels[y * width + x] = UInt8(min(255, Double(level) * gain))
                }
            }
        }
        guard let f = LumaFrame(width: width, height: height, pixels: pixels) else { preconditionFailure("valid synthetic frame") }
        return f
    }

    /// Disc stationary for `still` frames, then moving `dx` px/frame; PTS at `fps` with the listed frame numbers skipped.
    static func clip(
        count: Int, fps: Double = 240, still: Int = 20, dx: Double = 6, skipping: Set<Int> = [], flickerHz: Double = 0,
        flickerDepth: Double = 0
    ) -> [(pts: Double, frame: LumaFrame)] {
        (0 ..< count).filter { !skipping.contains($0) }.map { i in
            let t = Double(i) / fps
            let x = 20 + Double(max(0, i - still)) * dx
            let gain = 1 + flickerDepth * sin(2 * .pi * flickerHz * t)
            return (100 + t, frame(disc: Disc(x: x, y: 45, r: 5), gain: gain))
        }
    }
}
