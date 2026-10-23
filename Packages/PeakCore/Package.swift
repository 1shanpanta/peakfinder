// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeakCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PeakCore", targets: ["PeakCore"])],
    targets: [
        .target(name: "PeakCore"),
        .testTarget(name: "PeakCoreTests", dependencies: ["PeakCore"]),
    ]
)
