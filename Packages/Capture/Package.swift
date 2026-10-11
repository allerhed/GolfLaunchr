// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Capture",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Capture", targets: ["Capture"]),
        .library(name: "CaptureAV", targets: ["CaptureAV"]),
    ],
    targets: [
        // Pure logic: no AVFoundation, fully testable without a camera.
        .target(name: "Capture"),
        // AVFoundation adapter (iOS only). Compile-checked in the app build; behaviour needs a physical iPhone.
        .target(name: "CaptureAV", dependencies: ["Capture"]),
        .testTarget(name: "CaptureTests", dependencies: ["Capture"]),
    ]
)
