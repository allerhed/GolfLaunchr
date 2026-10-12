// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Export",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Export", targets: ["Export"])],
    dependencies: [.package(path: "../Domain"), .package(path: "../Persistence")],
    targets: [
        .target(name: "Export", dependencies: ["Domain", "Persistence"]),
        .testTarget(
            name: "ExportTests",
            dependencies: ["Export", .product(name: "PersistenceTestSupport", package: "Persistence")]
        ),
    ]
)
