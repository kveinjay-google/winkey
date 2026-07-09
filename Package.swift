// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WinKey",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WinKey", targets: ["WinKey"])
    ],
    targets: [
        .target(
            name: "WinKeyHIDShim",
            path: "Sources/WinKeyHIDShim"
        ),
        .target(
            name: "WinKeyScrollReverser",
            dependencies: ["WinKeyHIDShim"],
            path: "Sources/WinKeyScrollReverser",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "WinKey",
            dependencies: ["WinKeyHIDShim", "WinKeyScrollReverser"],
            path: "Sources/WinKey"
        )
    ]
)
