// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Modes",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Modes", targets: ["Modes"])],
    dependencies: [.package(path: "../Domain"), .package(path: "../Persistence")],
    targets: [
        .target(name: "Modes", dependencies: ["Domain", "Persistence"]),
        .testTarget(name: "ModesTests", dependencies: ["Modes", .product(name: "PersistenceTestSupport", package: "Persistence")]),
    ]
)
