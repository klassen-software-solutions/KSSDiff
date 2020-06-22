// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KSSDiff",
    products: [
        .library(name: "KSSDiff", targets: ["KSSDiff"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(name: "KSSDiff", dependencies: []),
        .testTarget(name: "KSSDiffTests", dependencies: ["KSSDiff"]),
    ]
)
