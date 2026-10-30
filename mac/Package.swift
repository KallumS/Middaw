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
        .target(name: "MiddawEngines", dependencies: ["MiddawCore"]),
        .target(name: "MiddawAudio", dependencies: ["MiddawCore"]),
        .executableTarget(name: "Middaw", dependencies: ["MiddawCore", "MiddawEngines", "MiddawAudio"]),
        .testTarget(name: "MiddawCoreTests", dependencies: ["MiddawCore"], exclude: ["Fixtures"]),
        .testTarget(name: "MiddawEnginesTests", dependencies: ["MiddawEngines", "MiddawCore"]),
        .testTarget(name: "MiddawAudioTests", dependencies: ["MiddawAudio", "MiddawCore"]),
    ]
)
