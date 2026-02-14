import ProjectDescription

let project = Project(
    name: "Lyra",
    targets: [
        .target(
            name: "Lyra",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.tuist.Lyra",
            infoPlist: .default,
            buildableFolders: [
                "Lyra/Sources",
                "Lyra/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "LyraTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tuist.LyraTests",
            infoPlist: .default,
            buildableFolders: [
                "Lyra/Tests"
            ],
            dependencies: [.target(name: "Lyra")]
        ),
    ]
)
