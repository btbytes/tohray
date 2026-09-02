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
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "TohrayClient",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        )
    ]
)
