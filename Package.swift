// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ColdSignerCorePackage",
    platforms: [
        .iOS(.v16),
        .macOS("15.5"),
    ],
    products: [
        .library(name: "ColdSignerCore", targets: ["ColdSignerCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/bitcoindevkit/bdk-swift", exact: "3.0.0"),
    ],
    targets: [
        .target(
            name: "ColdSignerDomain"
        ),
        .target(
            name: "ColdSignerPSBT",
            dependencies: ["ColdSignerDomain"]
        ),
        .target(
            name: "ColdSignerCore",
            dependencies: [
                "ColdSignerDomain",
                "ColdSignerPSBT",
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
            ]
        ),
        .executableTarget(
            name: "ColdSignerCoreTestRunner",
            dependencies: [
                "ColdSignerCore",
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
            ],
            path: "Tests/ColdSignerCoreTestRunner"
        ),
        .executableTarget(
            name: "ColdSignerPSBTFuzzer",
            dependencies: ["ColdSignerPSBT"],
            path: "Tests/ColdSignerPSBTFuzzer"
        ),
        .executableTarget(
            name: "ColdSignerPSBTSanitizerRunner",
            dependencies: ["ColdSignerPSBT"],
            path: "Tests/ColdSignerPSBTSanitizerRunner"
        ),
    ]
)
