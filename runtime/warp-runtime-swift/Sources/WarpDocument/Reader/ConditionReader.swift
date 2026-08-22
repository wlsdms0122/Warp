//
//  ConditionReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The condition spellings. A predicate is `{ of: <expression>, <operator>:
// <expression> }` — exactly two keys, both sides full expressions, so a
// condition can compare a reference against another reference and not only
// against a literal. The unary `present` takes its subject directly:
// `present: <expression>`.
//
// None of that is a fact about the expression it builds — which is either one of
// the five operators, or a message sent to the subject. `of`, the two-key shape
// and the unary exception are this notation's, and they live here so the IR does
// not have to carry them.
//
// Nothing here is required to write a condition. What a construct asks for in
// this slot is an expression, and a spelling is one way of arriving at one: a
// slot holding anything but an operator record is read as the expression it is.
// The layering is the point — a document that writes its conditions plainly owes
// none of these words, and a notation that drops the spellings still has every
// condition the language can hold.
//
// A word is spelled as an operator here and reached as a selector there:
// `{ of: x, startsWith: "a" }` is `x` being sent `startsWith`. The grammar has
// one slot for an operand and does not name it, so this notation fixes the name
// it lands under: `value`. A word wanting to be spellable as an operator writes
// its operand parameter that way, and one that does not is still reachable as a
// statement, where arguments are written by name.
//
// Which words exist is not asked here. A reader holding a table of them would
// know the vocabulary before anything was linked. Vocabulary is declared by
// modules, so an unknown word is a name the linker cannot resolve, and that is
// where it is refused.
public struct ConditionReader: Decodable {
    // MARK: - Property
    static let subjectKey = "of"

    // Where an operator's operand lands. The grammar writes one and does not
    // name it, so the name is this notation's rather than the word's.
    static let operandKey = "value"

    // The grammar's own spellings — a library atom may not claim these. Derived
    // from `Spelling` so the gate and the lowering cannot drift apart.
    public static let reservedOperatorKeys = Set(Spelling.operators.keys)
        .union([subjectKey])

    public let condition: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // A spelling is recognised by the word it is spelled with. Anything else
        // in this slot never was a condition shape — it is an expression, and
        // reading it as one is what keeps these words optional.
        let written = try ValueReader(from: decoder).value

        guard
            case let .object(object) = written,
            !Set(object.keys).isDisjoint(with: Self.reservedOperatorKeys)
        else {
            // Through the ordinary entry point rather than the reading behind
            // it, so that a bad expression here says where it is the way one in
            // any other slot does.
            self.condition = try ExpressionReader(from: decoder).expression

            return
        }

        let spellings = decoder.userInfo[.spellingRegistry] as? SpellingRegistry ?? .canonical
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = container.allKeys
            .map(\.stringValue)
            .filter { key in key != Self.subjectKey }
            .sorted()

        // A key reserved for a spelling this notation does not offer is refused
        // rather than read as data. Dropping a spelling says a document may not
        // write it; it does not free the word to mean something else, which would
        // make the same document mean two things in two notations.
        //
        // Only the reserved ones — a key this notation never named is already a
        // word's own name and reaches it untouched, which is what lets a caller's
        // word be written as an operator without anything here knowing about it.
        let unoffered = Set(found)
            .intersection(Spelling.operators.keys)
            .subtracting(spellings.operators.keys)

        guard unoffered.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "this notation does not spell"
                        + " \(unoffered.sorted().joined(separator: ", "))"
                        + " — write the message it would have stood for"
                )
            )
        }

        guard found.count == 1, let key = found.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "a condition is one operator and its subject —"
                        + " { of: <expression>, <operator>: <expression> };"
                        + " found: \(found)"
                )
            )
        }

        let hasSubject = container.contains(AnyCodingKey(stringValue: Self.subjectKey))

        switch key {
        case "all_of", "any_of", "not":
            guard !hasSubject else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "`of` does not accompany \(key) —"
                            + " combinators take conditions, not a subject"
                    )
                )
            }

        case "present":
            // Unary — the subject rides directly under the operator key.
            guard !hasSubject else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "present takes its expression directly —"
                            + " `present: <expression>`, without `of`"
                    )
                )
            }

        default:
            guard hasSubject else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "\(key) needs a subject —"
                            + " { of: <expression>, \(key): <expression> }"
                    )
                )
            }
        }

        switch key {
        // A connective must be able to leave a side unasked, and a word receives
        // what it is given already computed — so each side is wrapped in a
        // procedure here and the word calls the ones it needs. The wrapping is
        // this notation's, the same as `of` is.
        case "all_of", "any_of":
            self.condition = .dispatch(
                Dispatch(
                    receiver: .array(
                        try container.decode(
                            [ConditionReader].self,
                            forKey: AnyCodingKey(stringValue: key)
                        )
                        .map { read in Self.deferring(read.condition) }
                    ),
                    selector: Self.word(for: key, in: spellings)
                )
            )

            return

        case "not":
            self.condition = .dispatch(
                Dispatch(
                    receiver: try container.decode(
                        ConditionReader.self,
                        forKey: AnyCodingKey(stringValue: key)
                    )
                    .condition,
                    selector: Self.word(for: key, in: spellings)
                )
            )

            return

        // `present: x` is `x != null`. The notation keeps the word because it
        // reads better in a document.
        case "present":
            self.condition = try Self.send(
                Self.word(for: key, in: spellings),
                to: try container.decode(
                    ExpressionReader.self,
                    forKey: AnyCodingKey(stringValue: key)
                )
                .expression,
                with: .literal(.null),
                at: container.codingPath
            )

            return

        default:
            break
        }

        let subject = try container.decode(
            ExpressionReader.self,
            forKey: AnyCodingKey(stringValue: Self.subjectKey)
        )
        .expression
        let operand = try container.decode(
            ExpressionReader.self,
            forKey: AnyCodingKey(stringValue: key)
        )
        .expression

        switch key {
        case "is":
            self.condition = try Self.send(
                Self.word(for: key, in: spellings),
                to: subject,
                with: operand,
                at: container.codingPath
            )

            return

        case "is_not":
            self.condition = try Self.send(
                Self.word(for: key, in: spellings),
                to: subject,
                with: operand,
                at: container.codingPath
            )

            return

        // `one_of` is `contains` sent the other way round — the document says
        // "the subject is one of these", the library word says "these contain
        // the subject".
        case "one_of":
            self.condition = try Self.send(
                Self.word(for: key, in: spellings),
                to: operand,
                with: subject,
                at: container.codingPath
            )

            return

        default:
            break
        }

        self.condition = try Self.send(
            key,
            to: subject,
            with: operand,
            at: container.codingPath
        )
    }

    // MARK: - Public
    // MARK: - Private
    // An operator this notation named itself reaches the word it was named for;
    // anything else is already a word's name.
    private static func word(for key: String, in spellings: SpellingRegistry) -> String {
        spellings.word(for: key) ?? key
    }

    // A condition as something that has not been asked yet. It declares nothing
    // and reads its names from where it was written, so wrapping changes when it
    // is answered and nothing else about it.
    private static func deferring(_ condition: Expression) -> Expression {
        .closure(Procedure(body: [], result: condition))
    }

    private static func send(
        _ selector: String,
        to receiver: Expression,
        with operand: Expression,
        at codingPath: [any CodingKey]
    ) throws -> Expression {
        .dispatch(
            Dispatch(
                receiver: receiver,
                selector: selector,
                arguments: [Self.operandKey: operand]
            )
        )
    }
}
