// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Voice",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Voice", targets: ["Voice"])],
    dependencies: [.package(path: "../Domain"), .package(path: "../Formatting")],
    targets: [
        .target(name: "Voice", dependencies: ["Domain", "Formatting"]),
        .testTarget(name: "VoiceTests", dependencies: ["Voice", "Domain", "Formatting"]),
    ]
)
