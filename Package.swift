// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CanaryLinux",
    platforms: [.macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "CanaryLinux",
            targets: ["CanaryLinux"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Canary.git",
                 branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Chord.git",
                 from: "0.0.15"),
        .package(url: "https://github.com/OperatorFoundation/Datable",
                 from: "3.1.5"),
        .package(url: "https://github.com/OperatorFoundation/Gardener",
                 from: "0.0.48"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 from: "0.4.1"),
        .package(url: "https://github.com/apple/swift-log.git",
                 from: "1.4.2"),
        .package(url: "https://github.com/weichsel/ZIPFoundation",
                 from: "0.9.11"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from: "1.2.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "CanaryLinux",
            dependencies: ["Canary",
                           "Chord",
                           "Datable",
                           "Gardener",
                           "SwiftHexTools",
                           "ZIPFoundation",
                           .product(name: "ArgumentParser", package: "swift-argument-parser"),
                           .product(name: "Logging", package: "swift-log")
            ],
            linkerSettings: [
                         .linkedLibrary("icui18n"),
                         .linkedLibrary("icuuc"),
                         .linkedLibrary("icudata"),
                         .linkedLibrary("z"),
                         .linkedLibrary("lzma")
                       ]),
        .testTarget(
            name: "CanaryLinuxTests",
            dependencies: ["CanaryLinux"]),
    ],
    swiftLanguageVersions: [.v5]
)
