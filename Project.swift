import ProjectDescription

let project = Project(
    name: "Lyra",
    packages: [
        .remote(
            url: "https://github.com/swiftlang/swift-foundation-icu",
            requirement: .branch("main")
        )
    ],
    targets: [
        .target(
            name: "CTagLib",
            destinations: .macOS,
            product: .staticLibrary,
            bundleId: "dev.tuist.Lyra.CTagLib",
            sources: [
                "Lyra/Sources/CTagLib/taglib/taglib/**/*.cpp"
            ],
            headers: .headers(
                public: ["Lyra/Sources/CTagLib/include/**/*.h", "Lyra/Sources/CTagLib/include/**/*.hpp"],
                private: ["Lyra/Sources/CTagLib/taglib/taglib/**/*.h", "Lyra/Sources/CTagLib/taglib/taglib/**/*.hpp"]
            ),
            dependencies: [],
            settings: .settings(
                base: [
                    "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
                    "GCC_PREPROCESSOR_DEFINITIONS": ["$(inherited)", "TAGLIB_STATIC", "HAVE_ZLIB=1"],
                    "HEADER_SEARCH_PATHS": [
                        "$(SRCROOT)/Lyra/Sources/CTagLib/taglib/taglib",
                        "$(SRCROOT)/Lyra/Sources/CTagLib/taglib/taglib/toolkit",
                        "$(SRCROOT)/Lyra/Sources/CTagLib/taglib/3rdparty/utfcpp/source"
                    ],
                    "OTHER_LDFLAGS": ["$(inherited)", "-lz"]
                ]
            )
        ),
        .target(
            name: "LyraBridge",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.tuist.Lyra.Bridge",
            sources: [
                "Lyra/Sources/LyraBridge/include/*.mm",
                "Lyra/Sources/Xiph/ogg/src/*.c"
            ],
            headers: .headers(
                public: ["Lyra/Sources/LyraBridge/include/LyraBridge.h"],
                private: []
            ),
            dependencies: [
                .target(name: "CTagLib"),
                .package(product: "_FoundationICU"),
                .sdk(name: "z", type: .library),
                .sdk(name: "AVFoundation", type: .framework),
                .sdk(name: "CoreMedia", type: .framework),
                .sdk(name: "AudioToolbox", type: .framework)
            ],
            settings: .settings(
                base: [
                    "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
                    "HEADER_SEARCH_PATHS": [
                        "$(SRCROOT)/Lyra/Sources/LyraBridge/include",
                        "$(SRCROOT)/Lyra/Sources/LyraBridge",
                        "$(SRCROOT)/Lyra/Sources/Xiph/ogg/include",
                        "$(SRCROOT)/Lyra/Sources/Xiph/vorbis/include",
                        "$(SRCROOT)/Lyra/Sources/Xiph/opusfile/include",
                        "$(SRCROOT)/Lyra/Sources/CTagLib/taglib/taglib",
                        "$(SRCROOT)/Lyra/Sources/CTagLib/taglib/taglib/toolkit"
                    ]
                ]
            )
        ),
        .target(
            name: "Lyra",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.tuist.Lyra",
            sources: [
                "Lyra/Sources/Lyra/**/*.swift"
            ],
            dependencies: [
                .target(name: "LyraBridge")
            ]
        ),
        .target(
            name: "LyraTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tuist.LyraTests",
            sources: [
                "Lyra/Tests/**/*.swift"
            ],
            resources: [
                "Lyra/Tests/TestAudio/**"
            ],
            dependencies: [.target(name: "Lyra")]
        ),
    ],
    schemes: [
        .scheme(
            name: "Lyra",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    .target("Lyra")
                ]
            ),
            testAction: .targets(
                ["LyraTests"],
                configuration: .debug
            )
        ),
        .scheme(
            name: "LyraTests",
            shared: true,
            buildAction: .buildAction(
                targets: [
                    .target("LyraTests")
                ]
            ),
            testAction: .targets(
                ["LyraTests"],
                configuration: .debug
            )
        ),
    ]
)
