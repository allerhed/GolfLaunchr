import Capture
import Foundation

/// An 8-bit luma image (Y plane of a decoded frame).
public struct LumaFrame: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init?(width: Int, height: Int, pixels: [UInt8]) {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        pixels[y * width + x]
    }

    /// Mean luma 0...1, sampled on a regular stride (cheap on 1080p).
    public func meanLuma(stride: Int = 4) -> Double {
        var total = 0, count = 0
        for y in Swift.stride(from: 0, to: height, by: stride) {
            for x in Swift.stride(from: 0, to: width, by: stride) {
                total += Int(self[x, y])
                count += 1
            }
        }
        return count == 0 ? 0 : Double(total) / Double(count) / 255
    }

    /// Coarse grid of cell-centre samples for the motion detector, the same shape the harness uses on the phone.
    public func grid(columns: Int = 32, rows: Int = 18) -> LumaGrid? {
        guard width >= columns, height >= rows else { return nil }
        var values = [UInt8](repeating: 0, count: columns * rows)
        for r in 0 ..< rows {
            let y = (2 * r + 1) * height / (2 * rows)
            for c in 0 ..< columns {
                values[r * columns + c] = self[(2 * c + 1) * width / (2 * columns), y]
            }
        }
        return LumaGrid(columns: columns, rows: rows, values: values)
    }
}

public enum Sharpness {
    /// Variance of the 4-neighbour Laplacian on a sampled grid. Higher = sharper. Flat images give 0.
    /// A relative measure for comparing exposures/frames of the same scene, not an absolute blur size.
    public static func laplacianVariance(_ f: LumaFrame, step: Int = 2) -> Double {
        guard f.width > 2, f.height > 2 else { return 0 }
        var sum = 0.0, sumSquares = 0.0, n = 0.0
        for y in Swift.stride(from: 1, to: f.height - 1, by: step) {
            for x in Swift.stride(from: 1, to: f.width - 1, by: step) {
                let lap = 4 * Double(f[x, y]) - Double(f[x - 1, y]) - Double(f[x + 1, y]) - Double(f[x, y - 1]) - Double(f[x, y + 1])
                sum += lap
                sumSquares += lap * lap
                n += 1
            }
        }
        guard n > 0 else { return 0 }
        let mean = sum / n
        return max(0, sumSquares / n - mean * mean)
    }
}
