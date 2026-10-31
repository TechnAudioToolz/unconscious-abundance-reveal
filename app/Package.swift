// swift-tools-version:5.9
// The Mac app. Build the .app with ./build.sh (no Xcode project needed).
import PackageDescription

let package = Package(
    name: "UnconsciousReveal",
    platforms: [.macOS(.v14)],  // Sonoma and newer
    targets: [
        // No dependencies: recording, reversing and speech recognition all come with macOS.
        .executableTarget(name: "UnconsciousReveal", path: "Sources/UnconsciousReveal"),
    ]
)
