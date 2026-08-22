//
//  BranchTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct BranchTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("branch selects the then/else arm by its condition")
    func branchSelectsArm() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "parameters": ["kind": "string"],
            "body": [
                [
                    "id": "pick",
                    "branch": [
                        "when": ["of": ["ref": "kind"], "is": "a"],
                        "then": [
                            "body": [["id": "chosen", "value": "took-then"]],
                            "result": ["ref": "chosen"]
                        ],
                        "else": [
                            "body": [["id": "chosen", "value": "took-else"]],
                            "result": ["ref": "chosen"]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "pick"]]
        ])

        // When
        let thenOutputs = try await run(spec, arguments: ["kind": .string("a")])
        let elseOutputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(thenOutputs["result"] == .string("took-then"))
        #expect(elseOutputs["result"] == .string("took-else"))
    }
}
