// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitMarket",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GitMarket", targets: ["GitMarket"]),
    ],
    targets: [
        .target(name: "GitMarketCore"),
        .executableTarget(name: "GitMarket", dependencies: ["GitMarketCore"]),
        .testTarget(name: "GitMarketCoreTests", dependencies: ["GitMarketCore"]),
    ]
)
