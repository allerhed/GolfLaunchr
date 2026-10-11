// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Formatting",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Formatting", targets: ["Formatting"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Formatting", dependencies: ["Domain"]),
        .testTarget(name: "FormattingTests", dependencies: ["Formatting", "Domain"]),
    ]
)
