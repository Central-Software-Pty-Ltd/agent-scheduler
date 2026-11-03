// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentScheduler",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "AgentScheduler"),
        .testTarget(name: "AgentSchedulerTests", dependencies: ["AgentScheduler"]),
    ]
)
