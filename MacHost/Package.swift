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
        .executableTarget(
            name: "VeqralHost",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Network"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "VeqralHostSmoke"
        )
    ]
)
