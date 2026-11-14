// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SnowPlay", platforms: [.macOS(.v13)], products: [
    .library(name: "SnowCore", targets: ["SnowCore"]),
    .executable(name: "SnowPlay", targets: ["SnowPlay"])
], targets: [
    .target(name: "SnowCore"),
    .executableTarget(name: "SnowPlay", dependencies: ["SnowCore"], resources: [.copy("Resources")]),
    .testTarget(name: "SnowCoreTests", dependencies: ["SnowCore"])
], swiftLanguageModes: [.v5])
