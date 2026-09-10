// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlayLenseCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlayLenseCore", targets: ["PlayLenseCore"]),
        .library(name: "PlayLenseUI", targets: ["PlayLenseUI"]),
    ],
    targets: [
        .target(
            name: "PlayLenseCore",
            resources: [.copy("Resources/exercises.seed.json")]
        ),
        .target(
            name: "PlayLenseUI",
            dependencies: ["PlayLenseCore"]
        ),
        .testTarget(
            name: "PlayLenseCoreTests",
            dependencies: ["PlayLenseCore"]
        ),
    ]
)
