//
//  ValueNotationTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// Reading and writing data are one mapping seen from two sides, and the whole of
// what they promise is that they are the same one.
@Suite("What a document spells data as")
struct ValueNotationTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test(
        "what is written reads back as what it was",
        arguments: [
            Value.null,
            .bool(true),
            .int(42),
            .double(3.5),
            .string("warp"),
            .array([.int(1), .string("two"), .null]),
            .object(["id": .string("a"), "done": .bool(false)]),
            .object(["nested": .array([.object(["deep": .int(1)])])])
        ]
    )
    func writingRoundTrips(_ sut: Value) throws {
        // When
        let written = try JSONEncoder().encode(ValueWriter(sut))
        let read = try JSONDecoder().decode(ValueReader.self, from: written)

        // Then
        #expect(read.value == sut)
    }

    @Test("a procedure has no spelling, so writing one refuses")
    func writingAProcedureRefuses() throws {
        // Given
        let sut = Value.procedure(
            Closure(procedure: Procedure(body: []), captured: Scope())
        )

        // When / Then
        #expect(throws: EncodingError.self) {
            try JSONEncoder().encode(ValueWriter(sut))
        }
    }
}
