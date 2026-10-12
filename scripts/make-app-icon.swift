// Builds the 1024x1024 opaque app icon from docs/branding/app-icon-source.webp (rounded-square concept art).
// Usage (run in an empty scratch folder):
//   sips -s format png <repo>/docs/branding/app-icon-source.webp --out src.png
//   swiftc -o compose make-app-icon.swift && ./compose      # writes icon-1024.png
// Then copy icon-1024.png to App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
// It detects the artwork bounds, snaps compression noise to the background colour and centres the mark on a flat canvas;
// iOS applies the rounded mask itself, so the source's rounded corners are not carried over.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: "src.png") as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = image.width, h = image.height
let space = CGColorSpace(name: CGColorSpace.sRGB)!
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(
    data: &pixels,
    width: w,
    height: h,
    bitsPerComponent: 8,
    bytesPerRow: w * 4,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
    let i = (y * w + x) * 4; return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
}

/// background colour: sampled well inside the rounded square, away from the artwork
let bg = px(w / 2, Int(Double(h) * 0.82))
print("bg sample", bg, "size", w, h)
for i in stride(from: 0, to: w * h * 4, by: 4) {
    let d = abs(Int(pixels[i]) - bg.0) + abs(Int(pixels[i + 1]) - bg.1) + abs(Int(pixels[i + 2]) - bg.2)
    if d < 30 {
        pixels[i] = UInt8(bg.0); pixels[i + 1] = UInt8(bg.1); pixels[i + 2] = UInt8(bg.2)
    }
}

// artwork bounds inside the safe inner region (excludes the rounded-square edge and its shadow)
let x0 = Int(Double(w) * 0.12), x1 = Int(Double(w) * 0.88), y0 = Int(Double(h) * 0.20), y1 = Int(Double(h) * 0.80)
var minX = w, minY = h, maxX = 0, maxY = 0
for y in y0 ..< y1 {
    for x in x0 ..< x1 {
        let (r, g, b) = px(x, y)
        let d = abs(r - bg.0) + abs(g - bg.1) + abs(b - bg.2)
        if d > 40 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}

print("artwork bbox", minX, minY, maxX, maxY)
let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let cleaned = CGContext(
    data: &pixels,
    width: w,
    height: h,
    bitsPerComponent: 8,
    bytesPerRow: w * 4,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!.makeImage()!
let mark = cleaned.cropping(to: crop)!
// compose: 1024 opaque canvas, mark scaled to ~74% of the width, optically centred
let size = 1024
let out = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
out.setFillColor(CGColor(colorSpace: space, components: [CGFloat(bg.0) / 255, CGFloat(bg.1) / 255, CGFloat(bg.2) / 255, 1])!)
out.fill(CGRect(x: 0, y: 0, width: size, height: size))
let targetW = Double(size) * 0.86
let scale = targetW / Double(crop.width)
let drawW = Double(crop.width) * scale, drawH = Double(crop.height) * scale
out.interpolationQuality = .high
out.draw(mark, in: CGRect(x: (Double(size) - drawW) / 2, y: (Double(size) - drawH) / 2, width: drawW, height: drawH))
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "icon-1024.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote icon-1024.png", Int(drawW), "x", Int(drawH))
