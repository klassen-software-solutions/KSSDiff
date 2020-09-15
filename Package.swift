// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KSSDiff",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(name: "KSSDiff", targets: ["KSSDiff"]),
    ],
    dependencies: [
        .package(url: "https://github.com/klassen-software-solutions/KSSCore.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "KSSDiff", dependencies: [.product(name: "KSSFoundation", package: "KSSCore")]),
        .testTarget(name: "KSSDiffTests", dependencies: ["KSSDiff",
                                                         .product(name: "KSSTest", package: "KSSCore")]),
    ]
)
