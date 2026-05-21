// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ToughScan",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ToughScanCore", targets: ["ToughScanCore"]),
        .executable(name: "ToughScanCoreChecks", targets: ["ToughScanCoreChecks"])
    ],
    targets: [
        .target(name: "ToughScanCore"),
        .executableTarget(
            name: "ToughScanCoreChecks",
            dependencies: ["ToughScanCore"]
        )
    ]
)

