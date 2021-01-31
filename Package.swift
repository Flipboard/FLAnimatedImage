// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "FLAnimatedImage",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(name: "FLAnimatedImage", targets: ["FLAnimatedImage"]),
    ],
    targets: [
        .target(name: "FLAnimatedImage", path: "FLAnimatedImage")
    ]
)
