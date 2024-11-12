// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-sdk",
  platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "TurnkeySDK",
      targets: ["TurnkeySDK"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types", from: "1.0.2"),
    .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.0.0"),
    .package(url: "https://github.com/mkrd/Swift-BigInt.git", from: "2.0.0"),
    .package(url: "https://github.com/anquii/Base58Check.git", from: "1.0.0"),
    .package(url: "https://github.com/Square/Valet", from: "4.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.6.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "Shared",
      dependencies: [
        .product(name: "BigNumber", package: "Swift-BigInt"),
        .product(name: "Base58Check", package: "Base58Check"),
        .product(name: "Valet", package: "Valet")
      ]
    ),
    .target(
      name: "Middleware",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "HTTPTypes", package: "swift-http-types"),
        "Shared"
      ],
      path: "Sources/Middleware"
    ),
    .target(
      name: "TurnkeySDK",
      dependencies: [
        "Middleware", .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        .product(name: "BigNumber", package: "Swift-BigInt"),
        "Shared"
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .testTarget(
      name: "TurnkeySDKTests",
      dependencies: ["TurnkeySDK",
         .product(name: "SwiftDotenv", package: "swift-dotenv"),
         .product(name: "Web3", package: "Web3.swift"),
         .product(name: "Web3PromiseKit", package: "Web3.swift"),
      ]
    ),
  ]
)
