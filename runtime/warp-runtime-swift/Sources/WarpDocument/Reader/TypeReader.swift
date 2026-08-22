//
//  TypeReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// How a document spells a type. Two shapes, because a type has two:
//
//   string / any / procedure   — a built-in, by its own name
//   array<string>              — a built-in applied to another type
//   object<Task>               — the same, for a map of string keys
//   Task                       — a name some module declares
//   { id: string, done: bool } — a record, written as the record it describes
//   { procedure: { parameters:, returns: } }
//                              — a procedure, written as the signature it takes.
//                                Bare `procedure` says only that it is one
//
// A record is a mapping and a parameter is also written as a mapping, which
// would be ambiguous if both could appear in the same slot. They cannot: a
// parameter's record always carries `type`, and a record type is only ever the
// value of that key.
public struct TypeReader: Decodable {
    // MARK: - Property
    public let type: TypeExpression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        if let written = try? decoder.singleValueContainer().decode(String.self) {
            do {
                self.type = try Self.parse(written)
            } catch let error as TypeFormError {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: error.message)
                )
            }

            return
        }

        // A record and a procedure are both mappings, so one of them has to be
        // told apart by its key. A single `procedure` key whose value is itself
        // a mapping is the procedure form; anything else is a record, including
        // a record that happens to have a field called `procedure`.
        if
            let written = try? decoder
                .singleValueContainer()
                .decode([String: SignatureFormReader].self),
            written.count == 1,
            let key = written.keys.first,
            let signature = written[key],
            let purity = Self.purities[key]
        {
            self.type = .procedure(signature.signature, purity)

            return
        }

        guard
            let fields = try? decoder
                .singleValueContainer()
                .decode([String: TypeReader].self)
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "a type is a name like `string`, `array<string>` or"
                        + " `Task`, or a record like { id: string }"
                )
            )
        }

        self.type = .record(fields.mapValues(\.type))
    }

    // MARK: - Public
    public static func parse(_ written: String) throws -> TypeExpression {
        let text = written.trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            throw TypeFormError("a type name must not be empty")
        }

        // Purity is a word in front rather than an argument, because it says
        // what a slot requires of the whole procedure rather than of a part of
        // it — the same place a reader expects an adjective.
        // A hole rather than a name: `some T` is worked out from the call, where
        // `T` alone would be looked up in the table of declared types.
        if text == "some" || text.hasPrefix("some ") {
            let bare = text.dropFirst("some".count).trimmingCharacters(in: .whitespaces)

            guard !bare.isEmpty, !bare.contains("<"), !bare.contains(" ") else {
                throw TypeFormError("type '\(text)' names no hole — write `some` and one name")
            }

            return .variable(bare)
        }

        if let bare = text.dropPrefixed("pure ") {
            guard case let .procedure(signature, _) = try parse(String(bare)) else {
                throw TypeFormError("only a procedure is written pure")
            }

            return .procedure(signature, .pure)
        }

        guard let open = text.firstIndex(of: "<") else {
            guard !text.contains(">") else {
                throw TypeFormError("type '\(text)' closes an argument it never opened")
            }

            return Self.builtins[text] ?? .named(text)
        }

        let head = String(text[text.startIndex ..< open])

        guard text.hasSuffix(">") else {
            throw TypeFormError("type '\(text)' opens an argument it never closes")
        }

        let inner = String(text[text.index(after: open) ..< text.index(before: text.endIndex)])

        switch head {
        case "array":
            return .array(try parse(inner))

        case "object":
            return .object(try parse(inner))

        default:
            throw TypeFormError(
                "type '\(head)' takes no argument — only `array<…>` and `object<…>` do"
            )
        }
    }

    // The names this notation answers with a type of its own, and the keys that
    // make a mapping a procedure rather than a record. Both are read here and
    // both decide what a document *cannot* say, so writing one asks for them.
    public static var builtinNames: Set<String> { Set(builtins.keys) }
    public static var procedureKeys: Set<String> { Set(purities.keys) }

    // MARK: - Private
    private static let builtins: [String: TypeExpression] = [
        "any": .any,
        // A declaration a call never comes back from. Written out loud because
        // a word that always refuses is a word an author may declare.
        "never": .never,
        "null": .null,
        "bool": .bool,
        "int": .int,
        "double": .double,
        "string": .string,
        "bytes": .bytes,
        // Whole or fraction, for a slot that means both.
        "number": .number,
        // Bare, these mean "a list of anything" and "a map of anything" — the
        // most a declaration could say before it could say more.
        "array": .array(.any),
        "object": .object(.any),
        "procedure": .procedure(nil)
    ]

    // The two spellings of the procedure form, and what each asks for.
    private static let purities: [String: Purity] = [
        "procedure": .unstated,
        "pure procedure": .pure
    ]
}

private extension String {
    // The rest of the text where it begins with this, and nothing where it does
    // not.
    func dropPrefixed(_ prefix: String) -> Substring? {
        hasPrefix(prefix) ? dropFirst(prefix.count) : nil
    }
}

// The signature inside a procedure type: what a call may pass and what it gets
// back, written the way a procedure writes them.
private struct SignatureFormReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case parameters
        case receiver
        case returns
    }

    // MARK: - Property
    let signature: Signature

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "procedure type"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.signature = Signature(
            receiver: try container.decodeIfPresent(String.self, forKey: .receiver),
            parameters: try container
                .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                .signature.parameters ?? [:],
            returns: try container
                .decodeIfPresent(TypeReader.self, forKey: .returns)?
                .type
        )
    }

    // MARK: - Public
    // MARK: - Private
}
