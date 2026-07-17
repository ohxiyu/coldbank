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
        .package(name: "ColdSignerCorePackage", path: "../.."),
        .package(url: "https://github.com/BlockchainCommons/URKit", exact: "9.0.0"),
    ],
    targets: [
        .systemLibrary(name: "CZlib"),
        .target(
            name: "ColdSignerTransport",
            dependencies: [
                "CZlib",
                .product(name: "ColdSignerCore", package: "ColdSignerCorePackage"),
                .product(name: "URKit", package: "URKit"),
            ]
        ),
        .testTarget(
            name: "ColdSignerTransportTests",
            dependencies: [
                "ColdSignerTransport",
                .product(name: "URKit", package: "URKit"),
            ]
        ),
    ]
)
