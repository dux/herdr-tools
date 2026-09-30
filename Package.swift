// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HerdrTools",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HerdrTools", targets: ["HerdrTools"])],
    targets: [
        .target(name: "HerdrToolsCore"),
        .executableTarget(name: "HerdrTools", dependencies: ["HerdrToolsCore"]),
        .testTarget(name: "HerdrToolsCoreTests", dependencies: ["HerdrToolsCore"])
    ]
)
