// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Daylight",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Daylight", targets: ["Daylight"])],
    targets: [
        .target(name: "DaylightCore"),
        .executableTarget(name: "Daylight", dependencies: ["DaylightCore"]),
        .testTarget(name: "DaylightCoreTests", dependencies: ["DaylightCore"])
    ]
)
