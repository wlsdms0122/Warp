// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Warp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Warp", targets: ["Warp"]),
        .library(name: "WarpDocument", targets: ["WarpDocument"]),
        .library(name: "WarpBinary", targets: ["WarpBinary"]),
        .library(name: "WarpText", targets: ["WarpText"]),
    ],
    targets: [
        // The language as Swift holds it: the shapes a program is made of, and
        // everything done to them — checking, linking, running, and the standard
        // vocabulary. No dependencies and no `Decodable`, because a language
        // that can decode itself has confused itself with one of its notations.
        //
        // A caller that builds these shapes directly needs this and nothing
        // else. That is not a trick — it is how a front end with a syntax of its
        // own works, and how a program that never travels is run.
        .target(
            name: "Warp"
        ),
        // The shapes written down, and read back: which key names which shape,
        // the spellings a document may write instead, and the way back out.
        //
        // Optional, and the dependency graph is where that is said rather than
        // claimed. A program only travels as text, so this is what a program has
        // to come through to leave one machine and arrive at another — and a
        // program that stays where it was built never comes through here at all.
        .target(
            name: "WarpDocument",
            dependencies: [
                "Warp"
            ]
        ),
        // The wire. Warp's own bytes for a document — the encoding a program
        // travels in when nobody needs to read it on the way. It depends on
        // `Warp` and not on `WarpDocument`: an encoding carries a tree of data
        // and never learns what the tree means.
        .target(
            name: "WarpBinary",
            dependencies: [
                "Warp"
            ]
        ),
        // The same document laid out for eyes — `.wat` beside `.wasm`. One
        // encoding, one target, and the same reason it sees only `Warp`.
        .target(
            name: "WarpText",
            dependencies: [
                "Warp"
            ]
        ),
        // One test target per target, and the dependencies are the point: a test
        // that cannot import the notation can only be saying something about the
        // language. Where a behaviour is tested is then a fact anyone can read
        // off the imports, rather than a claim.
        //
        // It was a claim for a while. Writing a `Value` in Swift was awkward
        // enough that the notation tests reached for the YAML front end to build
        // fixtures, and the language tests reached for the notation — so a parser
        // change could fail a reader's test, and the linker had no test in its own
        // target at all. Each layer writes its own fixtures now, in the shape that
        // layer actually takes.
        .testTarget(
            name: "WarpTests",
            dependencies: [
                "Warp"
            ]
        ),
        .testTarget(
            name: "WarpDocumentTests",
            dependencies: [
                "WarpDocument"
            ]
        ),
        // The specification's cases, run against this implementation. It imports
        // what any caller imports and nothing more — a runner that could see
        // inside could pass by agreeing with the implementation rather than with
        // the specification, which is the one thing it must not do.
        .testTarget(
            name: "WarpConformanceTests",
            dependencies: [
                "Warp",
                "WarpDocument",
                "WarpText"
            ]
        ),
        // The front page's examples, run. It imports exactly what the page
        // tells a reader to import — a page whose examples do not compile is
        // worse than no page, and the way to know is to compile them.
        .testTarget(
            name: "WarpReadmeTests",
            dependencies: [
                "Warp",
                "WarpDocument",
                "WarpBinary"
            ]
        ),
        .testTarget(
            name: "WarpBinaryTests",
            dependencies: [
                "WarpBinary"
            ]
        ),
        .testTarget(
            name: "WarpTextTests",
            dependencies: [
                "WarpText"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
