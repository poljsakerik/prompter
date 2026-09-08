// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prompter",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Prompter", targets: ["Prompter"])],
    targets: [
        .executableTarget(name: "Prompter"),
        .testTarget(name: "PrompterTests", dependencies: ["Prompter"])
    ],
    swiftLanguageModes: [.v5]
)
