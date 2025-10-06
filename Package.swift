// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-sdk",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "TurnkeyEncoding", targets: ["TurnkeyEncoding"]),
        .library(name: "TurnkeyHttp", targets: ["TurnkeyHttp"]),
        .library(name: "TurnkeyCrypto", targets: ["TurnkeyCrypto"]),
        .library(name: "TurnkeyPasskeys", targets: ["TurnkeyPasskeys"]),
        .library(name: "TurnkeyStamper", targets: ["TurnkeyStamper"]),
        .library(name: "TurnkeySwift", targets: ["TurnkeySwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/anquii/Base58Check.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.2"),
    ],
    targets: [
        .target(name: "TurnkeyEncoding", dependencies: []),
        .target(name: "TurnkeyPublicAPI",  dependencies: [  
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        ], path: "Sources/TurnkeyHttp/Generated/Public"),
         .target(name: "TurnkeyAuthProxyAPI",  dependencies: [  
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        ], path: "Sources/TurnkeyHttp/Generated/AuthProxy"),
        .target(
            name: "TurnkeyHttp",
            dependencies: [
                "TurnkeyStamper",
                "TurnkeyPublicAPI",
                "TurnkeyAuthProxyAPI",
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            exclude: ["Generated"]),
        .target(
            name: "TurnkeyCrypto",
            dependencies: [
                .product(name: "Base58Check", package: "Base58Check")
            ]
        ),
        .target(name: "TurnkeyPasskeys", dependencies: ["TurnkeyEncoding", "TurnkeyCrypto"]),
        .target(name: "TurnkeyStamper", dependencies: ["TurnkeyPasskeys"]),
        .target(
            name: "TurnkeySwift",
            dependencies: [
                "TurnkeyHttp",
                "TurnkeyStamper",
                "TurnkeyCrypto",
                "TurnkeyPasskeys",
                "TurnkeyEncoding",
            ]),

    ]
)
