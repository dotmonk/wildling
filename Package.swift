// swift-tools-version:5.9
import PackageDescription

// Root Package.swift so GitHub tags work with SwiftPM:
//   .package(url: "https://github.com/dotmonk/wildling.git", from: "1.0.0")
let package = Package(
    name: "wildling",
    products: [
        .library(name: "Wildling", targets: ["Wildling"]),
        .executable(name: "wildling", targets: ["wildlingCLI"]),
    ],
    targets: [
        .target(
            name: "Wildling",
            path: "swift/Sources",
            exclude: ["main.swift"]
        ),
        .executableTarget(
            name: "wildlingCLI",
            dependencies: ["Wildling"],
            path: "swift/Executable"
        ),
    ]
)
