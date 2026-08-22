//
//  ReadmeTests.swift
//  WarpReadmeTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
import WarpBinary
import WarpDocument

// The README's examples, run — the page claims its examples are executed by
// test suites rather than transcribed into them, and this target is where that
// claim is true for the pages of this package.
@Suite("What the runtime README shows")
struct ReadmeTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("an arriving program, exactly as the front page walks it")
    func anArrivingProgram() async throws {
        // Given — bytes, made the way a sender makes them: a document written
        // out and encoded
        let sent = try BinaryEncoding.data(
            from: try Writer().value(
                of: try Loader().load([
                    "procedures": [
                        "entry": [
                            "body": [
                                [
                                    "id": "sum",
                                    "call": [
                                        "procedure": "plus",
                                        "of": 1,
                                        "arguments": ["value": 2]
                                    ]
                                ]
                            ],
                            "result": ["ref": "sum"]
                        ]
                    ]
                ])
            )
        )

        // When — the README's pipeline, verbatim
        let document = try BinaryEncoding.value(from: sent)
        let module = try Loader().load(document)
        let image = try Language().link([module] + Module.standard, entry: "entry")
        let answer = try await Language().makeExecutor().run(image)

        // Then
        #expect(answer == .int(3))
    }

    // MARK: - Public
    // MARK: - Private
}
