// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pastir",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pastir", targets: ["Pastir"])],
    targets: [
        .target(name: "PastirCore"),
        .executableTarget(name: "Pastir", dependencies: ["PastirCore"]),
        .testTarget(name: "PastirCoreTests", dependencies: ["PastirCore"])
    ]
)
