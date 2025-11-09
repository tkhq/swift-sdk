// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-sdk",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "TurnkeyEncoding", targets: ["TurnkeyEncoding"]),
        .library(name: "TurnkeyTypes", targets: ["TurnkeyTypes"]),
        .library(name: "TurnkeyHttp", targets: ["TurnkeyHttp"]),
        .library(name: "TurnkeyCrypto", targets: ["TurnkeyCrypto"]),
        .library(name: "TurnkeyPasskeys", targets: ["TurnkeyPasskeys"]),
        .library(name: "TurnkeyStamper", targets: ["TurnkeyStamper"]),
        .library(name: "TurnkeySwift", targets: ["TurnkeySwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/anquii/Base58Check.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.2"),
    ],
    targets: [
        .target(name: "TurnkeyEncoding", dependencies: []),
        .target(name: "TurnkeyTypes", dependencies: []),
        .target(
            name: "TurnkeyHttp",
            dependencies: [
                "TurnkeyTypes",
                "TurnkeyStamper",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]),
        .target(
            name: "TurnkeyCrypto",
            dependencies: [
                "TurnkeyEncoding",
                .product(name: "Base58Check", package: "Base58Check")
            ]
        ),
        .target(name: "TurnkeyPasskeys", dependencies: ["TurnkeyEncoding", "TurnkeyCrypto", "TurnkeyTypes"]),
        .target(name: "TurnkeyStamper", dependencies: ["TurnkeyPasskeys", "TurnkeyCrypto"]),
        .target(
            name: "TurnkeySwift",
            dependencies: [
                "TurnkeyHttp",
                "TurnkeyStamper",
                "TurnkeyCrypto",
                "TurnkeyPasskeys",
                "TurnkeyEncoding",
            ]),
        .testTarget(
            name: "TurnkeyStamperTests",
            dependencies: ["TurnkeyStamper", "TurnkeyCrypto"]
        ),

    ]
)
