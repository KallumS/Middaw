// swift-tools-version:5.9
// Middaw for Apple silicon Macs. `swift build` builds it, `swift test` tests
// it, `scripts/bundle.sh` turns the build into Middaw.app.
import PackageDescription

let package = Package(
    name: "Middaw",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Middaw", targets: ["Middaw"]),
    ],
    targets: [
        .target(name: "MiddawCore"),
        .executableTarget(name: "Middaw", dependencies: ["MiddawCore"]),
        .testTarget(name: "MiddawCoreTests", dependencies: ["MiddawCore"]),
    ]
)
