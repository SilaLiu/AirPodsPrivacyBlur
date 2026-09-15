// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AirPodsPrivacyBlur",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AirPodsPrivacyBlur", targets: ["AirPodsPrivacyBlur"])
    ],
    targets: [
        .executableTarget(
            name: "AirPodsPrivacyBlur",
            path: "Sources/AirPodsPrivacyBlur"
        )
    ]
)
