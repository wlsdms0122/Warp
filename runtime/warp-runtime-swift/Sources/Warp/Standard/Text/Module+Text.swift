//
//  Module+Text.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let text = Module(
        name: "std.text",
        description: "Words about strings.",
        procedures: [
            "text": Procedure(
                description: "How a value reads as text.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .string
                ),
                implementation: .query(SpellingQuery())
            ),
            "startsWith": Procedure(
                description: "Whether a string begins with another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string),
                        "value": Parameter(type: .string)
                    ],
                    returns: .bool
                ),
                implementation: .query(StartsWithQuery())
            ),
            "regex": Procedure(
                description: "Whether a string matches a pattern.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string),
                        "value": Parameter(type: .string)
                    ],
                    returns: .bool
                ),
                implementation: .query(RegexQuery())
            ),
            "uppercased": Procedure(
                description: "The text in upper case.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string)
                    ],
                    returns: .string
                ),
                implementation: .query(TextQuery(.uppercased))
            ),
            "lowercased": Procedure(
                description: "The text in lower case.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string)
                    ],
                    returns: .string
                ),
                implementation: .query(TextQuery(.lowercased))
            ),
            "trimmed": Procedure(
                description: "The text without surrounding whitespace.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string)
                    ],
                    returns: .string
                ),
                implementation: .query(TextQuery(.trimmed))
            ),
            "split": Procedure(
                description: "The text cut on a separator.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string),
                        "value": Parameter(type: .string)
                    ],
                    returns: .array(.string)
                ),
                implementation: .query(SplitQuery())
            ),
            "joined": Procedure(
                description: "The strings written one after another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.string)),
                        "value": Parameter(type: .string, default: .string(""))
                    ],
                    returns: .string
                ),
                implementation: .query(JoinedQuery())
            ),
            "replacing": Procedure(
                description: "Every occurrence of a piece swapped for another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .string),
                        "value": Parameter(type: .string),
                        "with": Parameter(type: .string)
                    ],
                    returns: .string
                ),
                implementation: .query(ReplacingQuery())
            )
        ]
    )
}
