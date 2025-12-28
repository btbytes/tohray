// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TohrayClient",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TohrayClient",
            targets: ["TohrayClient"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TohrayClient",
            dependencies: []
        )
    ]
)
