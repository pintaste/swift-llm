// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftLLM",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "SwiftLLM", targets: ["SwiftLLM"]),
    ],
    targets: [
        .target(name: "SwiftLLM"),
        .testTarget(name: "SwiftLLMTests", dependencies: ["SwiftLLM"]),
    ]
)
