// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "FLAnimatedImage",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FLAnimatedImage",
            type: .dynamic,
            targets: ["FLAnimatedImage"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FLAnimatedImage",
            path: "FLAnimatedImage",
            exclude: [ "FLAnimatedImage/FLAnimatedImage/Info.plist" ],
            publicHeadersPath: "FLAnimatedImage"
        )
    ]
)
