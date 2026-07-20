// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS("7.4"),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "VLCKit", targets: ["VLCKit"])
    ],
    targets: [
        .binaryTarget(
            name: "VLCKit",
            url: "https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260720-1538.zip",
            checksum: "d9de86d0c755cbcf46c49513ff57fffcd98258f0c7dd29f3e2d23bff3860da2a"
        )
    ]
)
