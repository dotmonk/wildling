// swift-tools-version:5.9
import PackageDescription

// Generated in dotmonk/wildling-swift by scripts/mirror-swift-spm.sh — do not edit in monorepo.
let package = Package(
    name: "wildling",
    products: [
        .library(name: "Wildling", targets: ["Wildling"]),
        .executable(name: "wildling", targets: ["wildlingCLI"]),
    ],
    targets: [
        .target(
            name: "Wildling",
            path: "Sources",
            exclude: ["main.swift"]
        ),
        .executableTarget(
            name: "wildlingCLI",
            dependencies: ["Wildling"],
            path: "Executable"
        ),
    ]
)
