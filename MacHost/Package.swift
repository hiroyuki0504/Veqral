// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VeqralMacHost",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VeqralHost", targets: ["VeqralHost"]),
        .executable(name: "VeqralHostSmoke", targets: ["VeqralHostSmoke"])
    ],
    targets: [
        .target(
            name: "VeqralShared"
        ),
        .executableTarget(
            name: "VeqralHost",
            dependencies: ["VeqralShared"],
            swiftSettings: [
                // Two source files mean SwiftPM no longer compiles main.swift in
                // single-file mode; @main requires library parsing.
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Network"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "VeqralHostSmoke"
        ),
        .testTarget(
            name: "VeqralSharedTests",
            dependencies: ["VeqralShared"]
        )
    ]
)
