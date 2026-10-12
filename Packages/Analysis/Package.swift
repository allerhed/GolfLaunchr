// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Analysis",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Analysis", targets: ["Analysis"]),
        .executable(name: "g1-analyze", targets: ["g1-analyze"]),
    ],
    dependencies: [.package(path: "../Capture")],
    targets: [
        // Pure analysis of recorded clips: timing, flicker, sharpness, motion, annotations. No AVFoundation.
        .target(name: "Analysis", dependencies: [.product(name: "Capture", package: "Capture")]),
        // macOS command line tool: decodes a clip with AVFoundation and runs the analysis.
        .executableTarget(name: "g1-analyze", dependencies: ["Analysis", .product(name: "Capture", package: "Capture")]),
        .testTarget(name: "AnalysisTests", dependencies: ["Analysis", .product(name: "Capture", package: "Capture")]),
    ]
)
