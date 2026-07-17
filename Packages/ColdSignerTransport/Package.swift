// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ColdSignerTransportPackage",
    platforms: [
        .iOS(.v16),
        .macOS("15.5"),
    ],
    products: [
        .library(name: "ColdSignerTransport", targets: ["ColdSignerTransport"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/BlockchainCommons/URKit", exact: "9.0.0"),
    ],
    targets: [
        .target(
            name: "ColdSignerTransport",
            dependencies: [
                .product(name: "ColdSignerCore", package: "ColdSignerCorePackage"),
                .product(name: "URKit", package: "URKit"),
            ]
        ),
    ]
)
