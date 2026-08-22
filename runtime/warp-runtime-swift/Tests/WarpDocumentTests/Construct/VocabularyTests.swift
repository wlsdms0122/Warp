//
//  VocabularyTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// Vocabulary is modules — not a second container beside them with its own
// registration, namespace and lookup order. These are the facts that follow.
@Suite("Vocabulary is modules")
struct VocabularyTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a word is a declaration, so a module can add one")
    func moduleAddsWords() async throws {
        // Given — `count` and `contains` are declarations, not language
        // structure; anyone adds their own the same way
        let extra = Module(
            name: "extra",
            procedures: [
                "head": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .array(.any))],
                        returns: .any
                    ),
                    implementation: .query(FirstQuery())
                ),
                "longerThan": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string),
                            "value": Parameter(type: .int)
                        ],
                        returns: .bool
                    ),
                    implementation: .query(LongerThanQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                [
                    "id": "verdict",
                    "branch": [
                        "when": ["of": ["ref": "names.first"], "longerThan": 3],
                        "then": [
                            "body": [["id": "long", "value": "long"]],
                            "result": ["ref": "long"]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "verdict"], "head": ["ref": "names.first"]]
        ])

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("spectacle"), .string("ok")])],
            vocabulary: Module.standard + [.testing, extra]
        )

        // Then
        #expect(outputs["result"] == .string("long"))
        #expect(outputs["head"] == .string("spectacle"))
    }

    @Test("a word left out of the link is a word that does not exist")
    func omittedVocabularyDoesNotResolve() throws {
        // Given — nothing is privileged, so the standard module is a file like
        // any other and leaving it out means leaving out what it declares
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                ["id": "how_many", "value": ["ref": "names.count"]],
                ["id": "said", "call": ["procedure": "count"]]
            ]
        ])

        // When / Then
        #expect(throws: LinkError.self) {
            try loader.language.link([sut], entry: entryName)
        }
    }

    @Test("two modules declaring one path word is refused, because a path names no module")
    func ambiguousDerivationRefused() throws {
        // Given — `${x.count}` writes no module, so there is no spelling that
        // would tell two of them apart
        let rival = Module(
            name: "rival",
            procedures: [
                "count": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .any)],
                        returns: .int
                    ),
                    implementation: .query(FirstQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure(["body": [["id": "done", "value": "end"]]])

        // When / Then
        #expect(throws: LinkError.self) {
            try loader.language.link([sut] + Module.standard + [rival], entry: entryName)
        }
    }

    @Test("a claimed construct key is never silently replaced")
    func claimedConstructKeyRejected() {
        // Given / When / Then — nobody may silently replace `loop`
        #expect(throws: ValidationError.self) {
            try ConstructRegistry.standard.registering(LoopForm.self)
        }
    }

    @Test("what the shipped notation says with words, the shipped bundles declare")
    func standardNotationIsCoveredByStandardBundles() {
        // Given — a spelling that lowers to a word is a debt the notation owes,
        // and this is the pair it is shipped beside
        let sut = Loader().vocabulary

        // When — a qualified name is what a spelling lowers to, so that is what
        // the bundles have to be read as. How one is spelt is `Symbol`'s rule,
        // repeated here because a test target cannot reach it.
        let declared = Set(
            Module.standard.flatMap { module in
                module.procedures.keys.map { name in
                    module.name.map { prefix in "\(prefix).\(name)" } ?? name
                }
            }
        )

        // Then
        #expect(sut.subtracting(declared).isEmpty)
    }

    @Test("a notation that drops a form stops owing what that form sent")
    func droppingAFormDropsItsDebt() throws {
        // Given — the debt belongs to the table rather than to the package, so
        // giving up the forms that read conditions gives up the operator words
        // only they reached
        let sut = Loader(
            registry: ConstructRegistry.standard.removing("branch").removing("loop"),
            spellings: .standard
        )
        let word = try #require(SpellingRegistry.standard.word(for: "is"))

        // When / Then
        #expect(Loader(spellings: .standard).vocabulary.contains(word))
        #expect(!sut.vocabulary.contains(word))
    }

    @Test("a notation with no conditions owes nothing the conditions would have")
    func operatorDebtBelongsToTheFormsThatReadIt() throws {
        // Given — the operator words are reached through `when` and `where`, so
        // a registry offering neither has no document that could reach them
        let sut = Loader(registry: try ConstructRegistry(forms: []), spellings: .standard)

        // When
        let owed = sut.vocabulary

        // Then — interpolation is written in a value slot, so it stays owed
        #expect(owed.isDisjoint(with: Set(Spelling.operators.values)))
        #expect(owed == Spelling.interpolation)
    }

    @Test("a document declaring a word by the same name does not capture a spelling")
    func aLocalDeclarationDoesNotCaptureASpelling() async throws {
        // Given — `is` reaches `equal`, and the author never wrote that name. A
        // declaration they did write must not be able to answer it.
        let sut = try loader.load([
            "name": "app",
            "procedures": [
                "equal": [
                    "receiver": "of",
                    "parameters": ["of": ["type": "any"], "value": ["type": "any"]],
                    "returns": "bool",
                    "result": ["value": false]
                ],
                "entry": [
                    "body": [[
                        "id": "same",
                        "branch": [
                            "when": ["of": ["value": 1], "is": ["value": 1]],
                            "then": ["body": [], "result": ["value": "same"]],
                            "else": ["body": [], "result": ["value": "different"]]
                        ]
                    ]],
                    "result": ["same": ["ref": "same"]]
                ]
            ]
        ])

        // When
        let answered = try await run(sut)

        // Then
        #expect(answered["same"] == .string("same"))
    }
}

// MARK: - Words a test brings

private struct FirstQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        return elements.first
    }

    // MARK: - Private
}

private struct LongerThanQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard
            case let .string(text) = question.receiver,
            case let .int(limit) = question["value"]
        else {
            return nil
        }

        return .bool(text.count > limit)
    }

    // MARK: - Private

}
