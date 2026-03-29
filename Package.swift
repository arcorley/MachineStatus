// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MachineStatus",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MachineStatus",
            path: "MachineStatus",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
            ]
        )
    ]
)
