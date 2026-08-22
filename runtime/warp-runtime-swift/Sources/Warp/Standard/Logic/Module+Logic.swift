//
//  Module+Logic.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

public extension Module {
    static let logic = Module(
        name: "std.logic",
        description: "Equality, negation and the connectives.",
        procedures: [
            "equal": Procedure(
                description: "Whether two values are the same.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        // Nothing is required on either side: comparing against
                        // null is what asking whether a name holds anything is,
                        // and a required parameter cannot be given null.
                        "of": Parameter(type: .any, default: .null),
                        "value": Parameter(type: .any, default: .null)
                    ],
                    returns: .bool
                ),
                implementation: .query(EqualityQuery(.same))
            ),
            "notEqual": Procedure(
                description: "Whether two values differ.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        // Nothing is required on either side: comparing against
                        // null is what asking whether a name holds anything is,
                        // and a required parameter cannot be given null.
                        "of": Parameter(type: .any, default: .null),
                        "value": Parameter(type: .any, default: .null)
                    ],
                    returns: .bool
                ),
                implementation: .query(EqualityQuery(.different))
            ),
            "not": Procedure(
                description: "The opposite of a truth.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .bool)],
                    returns: .bool
                ),
                implementation: .query(NegationQuery())
            ),
            // `and`/`or` rather than `all`/`any`: the connectives' universal
            // names, and they leave `all` free for `std.concurrent`, whose
            // meaning is the one everybody else calls `all`.
            "and": Procedure(
                description: "Whether every one answers true, asked until one does not.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .array(.procedure(nil, .pure)))],
                    returns: .bool
                ),
                implementation: .query(ChainQuery(.and))
            ),
            "or": Procedure(
                description: "Whether one answers true, asked until one does.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .array(.procedure(nil, .pure)))],
                    returns: .bool
                ),
                implementation: .query(ChainQuery(.or))
            )
        ]
    )
}
