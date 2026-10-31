// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NashiMini",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NashiMini", targets: ["NashiMini"])
    ],
    targets: [
        .target(name: "NashiCore", resources: [.copy("Resources")]),
        .executableTarget(name: "NashiMini", dependencies: ["NashiCore"]),
        .testTarget(name: "NashiCoreTests", dependencies: ["NashiCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
