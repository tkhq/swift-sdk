// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TurnkeyCodegen",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "typegen", targets: ["Typegen"]),
        .executable(name: "clientgen", targets: ["Clientgen"]),
    ],
    targets: [
        .target(
            name: "Internal",
            path: "Sources/Internal"
        ),
        .executableTarget(
            name: "Typegen",
            dependencies: ["Internal"],
            path: "Sources/Typegen"
        ),
        .executableTarget(
            name: "Clientgen",
            dependencies: ["Internal"],
            path: "Sources/Clientgen"
        ),
    ]
)
