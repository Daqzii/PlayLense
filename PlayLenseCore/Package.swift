// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlayLenseCore",
    defaultLocalization: "de",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlayLenseCore", targets: ["PlayLenseCore"]),
        .library(name: "PlayLenseData", targets: ["PlayLenseData"]),
        .library(name: "PlayLenseUI", targets: ["PlayLenseUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "PlayLenseCore",
            resources: [.copy("Resources/exercises.seed.json")]
        ),
        .target(
            name: "PlayLenseData",
            dependencies: [
                "PlayLenseCore",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .target(
            name: "PlayLenseUI",
            dependencies: ["PlayLenseCore", "PlayLenseData"]
        ),
    ]
)
