//
//  StatementReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A statement, written as at most one name plus exactly one construct key.
//
// The envelope carries no modifiers — not `when:` to say whether the statement
// runs, not `rescue:` to say what happens if it fails, because no language
// spells them that way. `some() when x > 0` is not a form anyone writes;
// `if x > 0 { some() }` is, and that is `branch`. Recovery is `attempt` for the
// same reason, plus one of its own: what do-catch guards is a body, and an
// envelope key could only ever guard one statement.
//
// So the envelope is a name, and what a statement binds is one expression.
//
// The name is written three ways, and the spelling is what the statement does
// to it rather than a modifier hung beside it: `id:` fixes a name, `var:`
// introduces one that may be written again, and `set:` writes one declared
// earlier. At most one of the three — none is a statement run for its effect,
// with the answer dropped — and exactly one construct key; the envelope never
// grew back. A leaving construct takes no name at all: it never finishes, so
// the name could never bind.
public struct StatementReader: Decodable {
    private enum EnvelopeKeys: String, CodingKey, CaseIterable {
        case id
        case variable = "var"
        case assignment = "set"

        var binding: Statement.Binding {
            switch self {
            case .id: .constant
            case .variable: .variable
            case .assignment: .assignment
            }
        }
    }

    // MARK: - Property
    public let statement: Statement

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        guard let registry = decoder.userInfo[.constructRegistry] as? ConstructRegistry else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "statement decoding requires a ConstructRegistry"
                        + " — decode through Loader"
                )
            )
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: EnvelopeKeys.allCases.map(\.stringValue) + registry.keys,
            context: "statement"
        )

        let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = registry.keys.filter { key in
            container.contains(AnyCodingKey(stringValue: key))
        }

        guard found.count == 1, let key = found.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "a statement must declare exactly one construct key"
                        + " (\(registry.keys.joined(separator: "/")));"
                        + " found: \(found)"
                )
            )
        }

        guard let form = registry.form(for: key) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "no construct registered for key '\(key)'"
                )
            )
        }

        // Presence first, decoding second — `id: null` is a key written with
        // no name in it, and reading it as "no naming key" would make a failed
        // name and an omitted one the same document.
        let names = EnvelopeKeys.allCases.filter { name in envelope.contains(name) }

        guard names.count <= 1 else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: envelope.codingPath,
                    debugDescription: "a statement names itself at most once with"
                        + " \(EnvelopeKeys.allCases.map { key in "'\(key.stringValue)'" }.joined(separator: ", "));"
                        + " found: \(names.map { name in "'\(name.stringValue)'" })"
                )
            )
        }

        let name = names.first
        let id = try name.map { name in try envelope.decode(String.self, forKey: name) }
        let expression = try form.init(
            from: container.superDecoder(forKey: AnyCodingKey(stringValue: key))
        )
        .expression(boundTo: id)

        // A statement that leaves never finishes, so a name on one promises a
        // binding that cannot happen. Only the syntactic leaves are caught here
        // — a call whose word never answers is a fact about the link, and the
        // linker refuses it where the signature is known.
        if id != nil, Self.isLeaving(expression) {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: envelope.codingPath,
                    debugDescription: "a leaving statement binds nothing, and it takes no name"
                )
            )
        }

        self.statement = Statement(
            id: id,
            binding: name?.binding ?? .constant,
            expression: expression
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func isLeaving(_ expression: Expression) -> Bool {
        if case .leave = expression { return true }

        return false
    }
}
