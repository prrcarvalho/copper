// swift-tools-version: 5.9

import PackageDescription

let developerLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "Copper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Copper", targets: ["Copper"])
    ],
    dependencies: [
        // The selected Command Line Tools image contains a Testing.framework
        // whose discovery runtime enumerates zero cases. Pin the matching
        // upstream Swift 6.3.3 implementation for deterministic `swift test`.
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            revision: "48d727cc1cf4eda667c858c501495f1018f69d21"
        )
    ],
    targets: [
        .target(
            name: "CopperCore",
            path: "Sources/CopperCore"
        ),
        .executableTarget(
            name: "Copper",
            dependencies: ["CopperCore"],
            path: "Sources/Copper"
        ),
        .testTarget(
            name: "CopperTests",
            dependencies: [
                "CopperCore",
                "Copper",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/CopperTests",
            linkerSettings: [
                .unsafeFlags([
                    "-L", developerLibraries,
                    "-Xlinker", "-rpath",
                    "-Xlinker", developerLibraries
                ])
            ]
        )
    ]
)
