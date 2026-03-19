// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RemindersMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "RemindersMac",
            targets: ["RemindersMac"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "RemindersMac",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ]),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
