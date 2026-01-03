// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickNotes",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuickNotes", targets: ["QuickNotes"])
    ],
    targets: [
        .executableTarget(
            name: "QuickNotes",
            path: "Sources"
        )
    ]
)
