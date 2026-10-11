#if os(iOS)
    import Capture
    import CoreVideo

    /// Samples a coarse luma grid from a bi-planar 4:2:0 pixel buffer for the motion trigger. Reads the Y plane only.
    public enum LumaSampler {
        public static func grid(from pixels: CVPixelBuffer, columns: Int = 32, rows: Int = 18) -> LumaGrid? {
            guard CVPixelBufferGetPlaneCount(pixels) >= 1 else { return nil }
            CVPixelBufferLockBaseAddress(pixels, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
            guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0) else { return nil }
            let width = CVPixelBufferGetWidthOfPlane(pixels, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixels, 0)
            let stride = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
            guard width >= columns, height >= rows else { return nil }
            let luma = base.assumingMemoryBound(to: UInt8.self)
            var values = [UInt8](repeating: 0, count: columns * rows)
            for r in 0 ..< rows {
                let y = (2 * r + 1) * height / (2 * rows)
                for c in 0 ..< columns {
                    let x = (2 * c + 1) * width / (2 * columns)
                    values[r * columns + c] = luma[y * stride + x]
                }
            }
            return LumaGrid(columns: columns, rows: rows, values: values)
        }
    }
#endif
