// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PasteStack",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "PasteStack", path: "Sources/PasteStack")
    ]
)
