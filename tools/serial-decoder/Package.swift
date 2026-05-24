// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SerialDecoder",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SerialDecoderLib",
            path: "Sources/SerialDecoderLib"
        ),
        .executableTarget(
            name: "SerialDecoderCLI",
            dependencies: ["SerialDecoderLib"],
            path: "Sources/SerialDecoderCLI"
        ),
        .testTarget(
            name: "SerialDecoderTests",
            dependencies: ["SerialDecoderLib"],
            path: "Tests/SerialDecoderTests"
        ),
    ]
)
