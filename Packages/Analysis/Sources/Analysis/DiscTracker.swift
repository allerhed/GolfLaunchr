import Foundation

public struct DiscDetection: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let area: Int
    /// Radius of a disc with the same area, in pixels.
    public var radius: Double {
        (Double(area) / .pi).squareRoot()
    }
}

/// Self-check tool: finds a bright blob on a darker background. It is NOT the product's ball detector; it exists to
/// validate the analysis plumbing against synthetic clips with known motion.
public enum DiscTracker {
    public static func detect(_ f: LumaFrame, threshold: UInt8, minimumArea: Int = 4) -> DiscDetection? {
        var sumX = 0.0, sumY = 0.0, area = 0
        for y in 0 ..< f.height {
            for x in 0 ..< f.width where f[x, y] >= threshold {
                sumX += Double(x)
                sumY += Double(y)
                area += 1
            }
        }
        guard area >= minimumArea else { return nil }
        return DiscDetection(x: sumX / Double(area), y: sumY / Double(area), area: area)
    }

    /// Median speed in metres per second from consecutive detections; nil with fewer than two usable segments.
    /// A rough speed from pixel motion at one scale (metres per pixel at the ball plane): not a measurement of ball speed.
    public static func medianSpeed(detections: [DiscDetection?], pts: [Double], metresPerPixel: Double) -> Double? {
        guard detections.count == pts.count, metresPerPixel > 0 else { return nil }
        var speeds: [Double] = []
        for i in 1 ..< max(detections.count, 1) {
            guard let a = detections[i - 1], let b = detections[i], pts[i] > pts[i - 1] else { continue }
            let pixels = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
            speeds.append(pixels * metresPerPixel / (pts[i] - pts[i - 1]))
        }
        guard speeds.count >= 2 else { return nil }
        let sorted = speeds.sorted()
        return sorted.count.isMultiple(of: 2) ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
    }
}
