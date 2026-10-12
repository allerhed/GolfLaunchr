// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "PersistenceTestSupport", targets: ["PersistenceTestSupport"]),
    ],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Persistence", dependencies: ["Domain"]),
        // Test helper executable: SIGKILLs itself mid-commit so tests can prove crash atomicity. Never linked into the app.
        .executableTarget(name: "PersistenceCrashHelper", dependencies: ["Persistence", "Domain"]),
        // In-memory fake. Test/preview only: the app target must not depend on it.
        .target(name: "PersistenceTestSupport", dependencies: ["Persistence", "Domain"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "PersistenceTestSupport", "Domain"]),
    ]
)
