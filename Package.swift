// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Croc",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Croc", path: "Sources/Croc")
    ]
)
