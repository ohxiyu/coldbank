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
            name: "ColdSignerCore",
            dependencies: [
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
            ]
        ),
        .executableTarget(
            name: "ColdSignerCoreTestRunner",
            dependencies: ["ColdSignerCore"],
            path: "Tests/ColdSignerCoreTestRunner"
        ),
    ]
)
