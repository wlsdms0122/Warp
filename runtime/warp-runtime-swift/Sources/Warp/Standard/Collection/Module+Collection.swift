//
//  Module+Collection.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let collection = Module(
        name: "std.collection",
        description: "Words about arrays and objects. A string counts and contains too.",
        procedures: [
            "count": Procedure(
                description: "How many, for a shape that has a count.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .int
                ),
                implementation: .query(CountQuery())
            ),
            "contains": Procedure(
                description: "Whether a string or an array holds a value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .any),
                        "value": Parameter(type: .any)
                    ],
                    returns: .bool
                ),
                implementation: .query(ContainsQuery())
            ),
            "first": Procedure(
                description: "The first element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .variable("Element")
                ),
                implementation: .query(SequenceQuery(.first))
            ),
            "last": Procedure(
                description: "The last element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .variable("Element")
                ),
                implementation: .query(SequenceQuery(.last))
            ),
            "reversed": Procedure(
                description: "The elements back to front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(SequenceQuery(.reversed))
            ),
            "appending": Procedure(
                description: "The elements with one more at the end.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element"))),
                        "value": Parameter(type: .variable("Element"))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(BuildingQuery(.appending))
            ),
            "prepending": Procedure(
                description: "The elements with one more at the front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element"))),
                        "value": Parameter(type: .variable("Element"))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(BuildingQuery(.prepending))
            ),
            "dropFirst": Procedure(
                description: "The elements after the first.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(BuildingQuery(.dropFirst))
            ),
            "dropLast": Procedure(
                description: "The elements before the last.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(BuildingQuery(.dropLast))
            ),
            "sorted": Procedure(
                description: "The elements in order, for numbers or for strings.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element")))
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(BuildingQuery(.sorted))
            ),
            "map": Procedure(
                description: "Each element answered by a procedure, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .variable("Element"))],
                                    returns: .variable("Answer")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.variable("Answer"))
                ),
                implementation: .query(WalkingQuery(.map))
            ),
            "filter": Procedure(
                description: "The elements a procedure answers true for.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .variable("Element"))],
                                    returns: .bool
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.variable("Element"))
                ),
                implementation: .query(WalkingQuery(.filter))
            ),
            "reduce": Procedure(
                description: "The elements folded into one, starting from a value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable("Element"))),
                        "from": Parameter(type: .variable("Carried")),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: [
                                        "carried": Parameter(type: .variable("Carried")),
                                        "item": Parameter(type: .variable("Element"))
                                    ],
                                    returns: .variable("Carried")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .variable("Carried")
                ),
                implementation: .query(WalkingQuery(.reduce))
            ),
            "keys": Procedure(
                description: "The names an object holds, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.any))
                    ],
                    returns: .array(.string)
                ),
                implementation: .query(MappingQuery(.keys))
            ),
            "values": Procedure(
                description: "What an object holds, by its names in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.variable("Entry")))
                    ],
                    returns: .array(.variable("Entry"))
                ),
                implementation: .query(MappingQuery(.values))
            ),
            "setting": Procedure(
                description: "The object with one name bound to another value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.any)),
                        "key": Parameter(type: .string),
                        "value": Parameter(type: .any)
                    ],
                    returns: .object(.any)
                ),
                implementation: .query(MappingQuery(.setting))
            )
        ]
    )
}
