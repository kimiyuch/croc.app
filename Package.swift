// swift-tools-version:5.9
import PackageDescription

// Sparkle (updates) is fetched into vendor/ by scripts/fetch-sparkle.sh; build.sh copies it into Contents/Frameworks.
let sparkle = "\(Context.packageDirectory)/vendor/sparkle-2.10.0"

let package = Package(
    name: "Croc",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Croc",
            path: "Sources/Croc",
            swiftSettings: [.unsafeFlags(["-F\(sparkle)"])],
            linkerSettings: [
                .unsafeFlags(["-F\(sparkle)", "-framework", "Sparkle",
                              "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
