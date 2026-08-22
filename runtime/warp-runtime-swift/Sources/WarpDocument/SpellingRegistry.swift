//
//  SpellingRegistry.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// Which spellings a notation offers, the way `ConstructRegistry` says which
// construct words it offers.
//
// A spelling stands in for something the language already has: `{ of: a, is: b }`
// is a message, and so is a template. So a document has two layers, and this is
// the switch between them — the standard table offers every spelling, and the
// canonical one offers none and leaves a document writing the shapes themselves.
//
// It is worth being able to turn off because the lower layer is what travels. A
// program read somewhere else needs that reader to agree about what it says, and
// each spelling is one more rule the far side has to implement identically. A
// notation that offers none owes no words for spellings it never spends.
//
// **Dropping a spelling does not free the word to mean something else.** The keys
// stay reserved either way, and a document that writes one this notation does not
// offer is refused rather than read as a record that happens to have those
// fields. What varies is whether a shape is understood, never what it means — the
// same reason the set of expression form keys is fixed rather than composed.
public struct SpellingRegistry: Sendable {
    // MARK: - Property
    public static let standard = SpellingRegistry(
        operators: Spelling.operators,
        interpolation: true
    )

    // Nothing stood in for. Every condition is the expression it is written as,
    // and text is put together by sending the words that put text together.
    public static let canonical = SpellingRegistry(operators: [:], interpolation: false)

    // Which operator keys reach a word here, and what each reaches.
    public let operators: [String: String]

    // Whether `{ format:, with: }` is offered.
    public let interpolation: Bool

    // What the operator spellings reach, for the forms that read them. It is not
    // owed by offering them — a condition is read through `when` and `where`, so
    // a notation with neither spends nothing here however many it offers.
    public var operatorWords: Set<String> {
        Set(operators.values)
    }

    // What these spellings spend no matter which constructs exist. A template is
    // written in a value slot and every construct has one, so offering it owes
    // these wherever the table is used.
    public var vocabulary: Set<String> {
        interpolation ? Spelling.interpolation : []
    }

    // MARK: - Initializer
    public init(operators: [String: String], interpolation: Bool) {
        self.operators = operators
        self.interpolation = interpolation
    }

    // MARK: - Public
    // The word an operator key reaches here, and nothing where this notation does
    // not offer that spelling. Nothing is not "read it as a record" — the caller
    // refuses, because the key is reserved whether it is offered or not.
    public func word(for key: String) -> String? {
        operators[key]
    }

    // Giving up a spelling. The word it stood for is still reachable by writing
    // the message it stood for, which is the whole reason a spelling can be given
    // up at all.
    public func removing(_ key: String) -> SpellingRegistry {
        var operators = operators

        operators[key] = nil

        return SpellingRegistry(operators: operators, interpolation: interpolation)
    }

    public func removingInterpolation() -> SpellingRegistry {
        SpellingRegistry(operators: operators, interpolation: false)
    }

    // MARK: - Private
}
