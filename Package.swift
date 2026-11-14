// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PiPWindow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PiPWindow", targets: ["PiPWindow"])
    ],
    targets: [
        .executableTarget(
            name: "PiPWindow",
            path: "Sources/PiPWindow",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
