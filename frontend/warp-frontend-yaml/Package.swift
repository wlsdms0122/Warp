// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WarpYAML",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WarpYAML", targets: ["WarpYAML"]),
    ],
    dependencies: [
        // A front end ends where the document begins: it depends on the layer
        // that says what a document means, and through it on the language —
        // never on the runtime's checking, linking or running. What it produces
        // is a document, and anything a runtime does with one is not its
        // business.
        .package(path: "../../runtime/warp-runtime-swift"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        // One notation. Text in, `Value` out, and nothing else — what a
        // document *means* is settled a layer down, so a second notation is a
        // second package this size rather than a second language.
        .target(
            name: "WarpYAML",
            dependencies: [
                .product(name: "WarpDocument", package: "warp-runtime-swift"),
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "WarpYAMLTests",
            dependencies: [
                "WarpYAML"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
