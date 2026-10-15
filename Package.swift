// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TodoFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TodoFloat", path: "Sources/TodoFloat")
    ]
)
