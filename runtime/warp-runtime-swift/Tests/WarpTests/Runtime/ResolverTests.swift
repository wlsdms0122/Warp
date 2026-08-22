//
//  ResolverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp

@Suite
struct ResolverTests {
    // MARK: - Property
    private let sut = Resolver(
        scope: Scope(
            bindings: [
                "count": .int(3),
                "maybe": .null,
                "record": .object(["a": .int(1)])
            ]
        ),
        derivations: Module.standard.procedures
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("ref resolution preserves the type")
    func refResolutionPreservesType() throws {
        // Given
        let reference = Expression.reference([.key("count")])

        // When
        let value = try sut.resolve(reference)

        // Then
        #expect(value == .int(3))
    }

    @Test("a null value flows through a ref untouched")
    func nullPassesThroughRef() throws {
        // Given
        let reference = Expression.reference([.key("maybe")])

        // When
        let value = try sut.resolve(reference)

        // Then
        #expect(value == .null)
    }

    @Test("a null binding inside format is unfit")
    func nullBindingInFormatThrowsUnfit() {
        // Given — interpolating a name means the author assumed a value exists
        let reference = interpolated(literal("amount="), spelling(reference("maybe")))

        // When / Then
        #expect(throws: ReferenceUnfit.self) {
            try sut.resolve(reference)
        }
    }

    @Test("a name the scope does not hold reads as null")
    func absentPathReadsAsNull() throws {
        // Given — the head of every reference is checked at load, so what is
        // left to be absent at run time is a field nobody set
        let reference = Expression.reference([.key("gone")])

        // When / Then
        #expect(try sut.resolve(reference) == .null)
    }

    @Test("a shape-misusing path throws ReferenceUnfit")
    func shapeMisuseThrowsUnfit() {
        // Given
        let reference = Expression.reference([.key("count"), .key("field")])

        // When / Then
        #expect(throws: ReferenceUnfit.self) {
            try sut.resolve(reference)
        }
    }

    @Test("nested structure resolves element by element")
    func nestedStructureResolves() throws {
        // Given
        let reference = Expression.record([
            "n": .reference([.key("count")]),
            "list": .array([.literal(.string("x"))])
        ])

        // When
        let value = try sut.resolve(reference)

        // Then
        #expect(value == .object(["n": .int(3), "list": .array([.string("x")])]))
    }

    @Test("format renders over its declared with bindings")
    func declaredBindingsRenderFormat() throws {
        // Given
        let reference = interpolated(literal("n="), spelling(reference("count")))

        // When
        let value = try sut.resolve(reference)

        // Then
        #expect(value == .string("n=3"))
    }

    @Test("in a closed scope a binding named after an ambient head is just a binding")
    func closedScopeServesBindingNamedAfterAmbientHead() throws {
        // Given — a closed surface has no reserved heads: a binding named `run`
        // is just a binding, not the ambient namespace of that name
        let reference = interpolated(literal("who="), spelling(reference("count")))

        // When
        let value = try sut.resolve(reference)

        // Then
        #expect(value == .string("who=3"))
    }

    @Test("a quoted payload passes verbatim, unevaluated")
    func quotedPayloadPassesVerbatim() throws {
        // Given — the payload is data: a ref-shaped object inside stays an object
        let reference = Expression.literal(.object([
            "ref": .string("count"),
            "note": .string("${count}")
        ]))

        // When
        let value = try sut.resolve(reference)

        // Then — nothing evaluated, nothing rendered
        #expect(value == .object([
            "ref": .string("count"),
            "note": .string("${count}")
        ]))
    }
}
