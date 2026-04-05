// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CleanShotClone",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CleanShotClone",
            dependencies: [],
            path: "CleanShotClone",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
