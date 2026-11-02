// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipShelf",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipShelfCore"),
        .executableTarget(name: "ClipShelf", dependencies: ["ClipShelfCore"]),
        // A plain executable rather than an XCTest target, so tests also run with just the
        // Command Line Tools (which don't ship XCTest): `swift run ClipShelfTests` or `./build.sh test`.
        .executableTarget(name: "ClipShelfTests", dependencies: ["ClipShelfCore"], path: "Tests/ClipShelfTests"),
    ]
)
