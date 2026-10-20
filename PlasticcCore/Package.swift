// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlasticcCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "PlasticcCore", targets: ["PlasticcCore"])],
    targets: [
        .target(name: "PlasticcCore"),
        .testTarget(name: "PlasticcCoreTests", dependencies: ["PlasticcCore"]),
    ],
    swiftLanguageModes: [.v5]
)
