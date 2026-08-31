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
            url: "https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260831-1526.zip",
            checksum: "c61a42052ec4c1315325fba81f8893f4ccf639d92bf61dd1b3c37c3a2f26b8e3"
        )
    ]
)
