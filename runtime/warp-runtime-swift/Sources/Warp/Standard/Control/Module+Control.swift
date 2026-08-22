//
//  Module+Control.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

public extension Module {
    // Words about whether a body goes on, rather than about what it computes.
    // The other bundles are named for what they read — truths, numbers, text,
    // containers — and this one reads nothing.
    static let control = Module(
        name: "std.control",
        description: "Leaving instead of answering.",
        procedures: [
            "abort": Procedure(
                description: "Refuses with a message, which an attempt around it catches.",
                signature: Signature(
                    receiver: "of",
                    // Anything spells, so a refusal can name what it was holding
                    // rather than only a sentence written ahead of time. It is
                    // required: a refusal with nothing to say is the one shape
                    // this word exists to prevent.
                    parameters: ["of": Parameter(type: .any)],
                    returns: .never
                ),
                implementation: .query(AbortQuery())
            )
        ]
    )
}
