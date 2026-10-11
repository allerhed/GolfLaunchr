// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Analytics",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Analytics", targets: ["Analytics"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Analytics", dependencies: ["Domain"]),
        .testTarget(name: "AnalyticsTests", dependencies: ["Analytics"]),
    ]
)
