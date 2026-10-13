// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Allowance",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Allowance", targets: ["Allowance"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Allowance", dependencies: ["Domain"]),
        .testTarget(name: "AllowanceTests", dependencies: ["Allowance"]),
    ]
)
