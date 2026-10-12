import Foundation

public struct FlickerResult: Codable, Sendable, Equatable {
    /// Frequency of the strongest non-DC component, in Hz.
    public let peakFrequencyHz: Double
    /// Sinusoid amplitude of that component relative to the mean level (0.1 = +/-10% brightness modulation).
    public let relativeAmplitude: Double
    /// Frequency resolution of the analysis (sample rate / sample count).
    public let resolutionHz: Double
}

/// Finds periodic brightness modulation (mains-driven lights) in a per-frame mean-luma series.
/// A modulation above the Nyquist rate would alias to a lower frequency; the result reports what is observed.
public enum FlickerAnalyzer {
    /// - Parameters:
    ///   - series: mean luma per frame.
    ///   - sampleRate: frames per second on the capture clock.
    ///   - minimumFrequencyHz: components below this are ignored: slow brightness changes (people moving, auto exposure) are not
    ///     flicker. Mains lighting modulates at 100 or 120 Hz (or 50/60 Hz).
    /// - Returns: nil if the series is too short or has no signal.
    public static func analyze(_ series: [Double], sampleRate: Double, minimumFrequencyHz: Double = 20) -> FlickerResult? {
        let n = series.count
        guard n >= 16, sampleRate > 0 else { return nil }
        let mean = series.reduce(0, +) / Double(n)
        guard mean > 1e-9 else { return nil }
        let centred = series.map { $0 - mean }
        var bestBin = 0
        var bestMagnitude = 0.0
        for k in 1 ... n / 2 where Double(k) * sampleRate / Double(n) >= minimumFrequencyHz {
            let w = 2 * Double.pi * Double(k) / Double(n)
            var re = 0.0, im = 0.0
            for (i, v) in centred.enumerated() {
                re += v * cos(w * Double(i))
                im -= v * sin(w * Double(i))
            }
            let magnitude = (re * re + im * im).squareRoot() * 2 / Double(n)
            if magnitude > bestMagnitude {
                bestMagnitude = magnitude
                bestBin = k
            }
        }
        guard bestBin > 0 else { return nil }
        let resolution = sampleRate / Double(n)
        return FlickerResult(
            peakFrequencyHz: Double(bestBin) * resolution,
            relativeAmplitude: bestMagnitude / mean,
            resolutionHz: resolution
        )
    }
}
