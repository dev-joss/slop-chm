// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "slop-chm",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "CHMLib",
            path: "Sources/CHMLib",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "CHMKit",
            dependencies: ["CHMLib"],
            path: "Sources/CHMKit"
        ),
        .executableTarget(
            name: "slop-chm",
            dependencies: ["CHMKit"],
            path: "Sources/CHMReader",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "CHMKitTests",
            dependencies: ["CHMKit"],
            path: "Tests/CHMKitTests"
        )
    ]
)
