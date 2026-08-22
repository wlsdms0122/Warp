//
//  Module+Concurrent.swift
//  Warp
//
//  Created by JSilver on 8/22/26.
//

import Foundation

public extension Module {
    // Words that run closures at once. Vocabulary rather than grammar, so
    // running things concurrently is something a caller grants by linking this
    // bundle — a program whose caller left it out cannot fan out at all.
    static let concurrent = Module(
        name: "std.concurrent",
        description: "Running closures at once.",
        procedures: [
            // Plain words — `all`, `first`, `map` — with the module carrying
            // the context, the way `Array.map` and `TaskGroup.next` lean on
            // their types. A bare name resolves only while exactly one linked
            // module declares it, so a link that carries this bundle beside
            // `std.collection` pays for `first` and `map` on *both* sides:
            // every call site qualifies, the sequential ones included. That
            // cost is taken knowingly — the qualified spelling is the meaning,
            // and concurrency shows at the call site.
            //
            // `of` and what comes back are declared `any` because both take two
            // shapes — a record of closures or an array of them — and a union
            // is not a thing a type here can say. The precision is not lost so
            // much as unsayable; `map`, whose shapes are single, says it all.
            "all": Procedure(
                description: "Runs every closure, and answers every answer —"
                    + " a record's under its keys, an array's in its order."
                    + " A failure fails the whole word, with every piece's"
                    + " failure reported.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .any
                ),
                implementation: .effect(ConcurrentEffect(.all, receiving: "of"))
            ),
            "first": Procedure(
                description: "Runs every closure, answers the first success and"
                    + " asks the rest to stop. Which one wins is timing's — the"
                    + " one fact here that is.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .any
                ),
                implementation: .effect(ConcurrentEffect(.first, receiving: "of"))
            ),
            "map": Procedure(
                description: "Runs one closure once per element, offering each"
                    + " call `item` and `index`, and answers in the"
                    + " collection's order.",
                signature: Signature(
                    receiver: "over",
                    parameters: [
                        "over": Parameter(type: .array(.variable("Element"))),
                        "by": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: [
                                        "item": Parameter(type: .variable("Element")),
                                        "index": Parameter(type: .int)
                                    ],
                                    returns: .variable("Answer")
                                )
                            )
                        )
                    ],
                    returns: .array(.variable("Answer"))
                ),
                implementation: .effect(ConcurrentEffect(.map, receiving: "over"))
            )
        ]
    )
}
