// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flight",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Flight", targets: ["Flight"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Flight", dependencies: ["Domain"]),
        .testTarget(name: "FlightTests", dependencies: ["Flight"]),
    ]
)
