//
//  ReferenceLookupTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp

@Suite
struct ReferenceLookupTests {
    // MARK: - Property
    private let sut = Resolver(
        scope: Scope(
            bindings: [
                "name": .string("spec"),
                "run": .object(["id": .string("r-1")]),
                "items": .array([.int(1), .int(2), .int(3)]),
                "step": .object(["out": .string("done"), "list": .array([.string("a")])]),
                "index": .int(1)
            ]
        ),
        derivations: Module.standard.procedures
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("an existing path returns its value")
    func existingPathReturnsValue() {
        #expect(sut.lookup([.key("name")]) == .found(.string("spec")))
        #expect(sut.lookup([.key("run"), .key("id")]) == .found(.string("r-1")))
        #expect(sut.lookup([.key("step"), .key("out")]) == .found(.string("done")))
        #expect(sut.lookup([.key("items"), .index(1)]) == .found(.int(2)))
    }

    @Test("a missing key answers absent")
    func missingKeyReturnsAbsent() {
        #expect(sut.lookup([.key("missing")]) == .absent)
        #expect(sut.lookup([.key("nowhere")]) == .absent)
        #expect(sut.lookup([.key("items"), .index(9)]) == .absent)
    }

    @Test("shape misuse is unfit, not absent")
    func shapeMisuseReturnsUnfit() {
        // Then — drilling a field into a string is an author error, not missing data
        guard case .unfit = sut.lookup([.key("name"), .key("foo")]) else {
            Issue.record("expected unfit")

            return
        }

        guard case .unfit = sut.lookup([.key("name"), .index(0)]) else {
            Issue.record("expected unfit for indexing into a string")

            return
        }
    }

    @Test("count derives from countable values")
    func countDerivesFromCountable() {
        #expect(sut.lookup([.key("items"), .key("count")]) == .found(.int(3)))
        #expect(sut.lookup([.key("name"), .key("count")]) == .found(.int(4)))
        #expect(sut.lookup([.key("step"), .key("count")]) == .found(.int(2)))
    }

    @Test("an index-reference segment resolves from a binding")
    func indexReferenceResolvesFromBinding() {
        #expect(sut.lookup([.key("items"), .indexRef([.key("index")])]) == .found(.int(2)))
    }

    // A scope is an environment and nothing more — which is what lets the
    // vocabulary that derives `count` be the caller's rather than the scope's.
    @Test("a scope answers about a head and not about a path")
    func scopeAnswersHeadsOnly() {
        #expect(sut.scope.value(of: "step") != nil)
        #expect(sut.scope.value(of: "nowhere") == nil)
    }
}
