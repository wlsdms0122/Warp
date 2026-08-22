//
//  Module+Math.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let math = Module(
        name: "std.math",
        description: "Arithmetic, and the ordering of numbers and strings.",
        procedures: [
            "plus": Procedure(
                description: "The sum, whole where both sides are.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.plus))
            ),
            "minus": Procedure(
                description: "The difference.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.minus))
            ),
            "times": Procedure(
                description: "The product.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.times))
            ),
            "dividedBy": Procedure(
                description: "The quotient, which is not generally whole.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .double
                ),
                implementation: .query(ArithmeticQuery(.dividedBy))
            ),
            "remainder": Procedure(
                description: "What is left of a whole division.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.remainder))
            ),
            "min": Procedure(
                description: "The smaller of two numbers.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.min))
            ),
            "max": Procedure(
                description: "The larger of two numbers.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("N")),
                        "value": Parameter(type: .variable("N"))
                    ],
                    returns: .variable("N")
                ),
                implementation: .query(ArithmeticQuery(.max))
            ),
            "absolute": Procedure(
                description: "The number without its sign.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .variable("N"))],
                    returns: .variable("N")
                ),
                implementation: .query(NumberQuery(.absolute))
            ),
            "floored": Procedure(
                description: "The whole number at or below this one.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .number)],
                    returns: .int
                ),
                implementation: .query(NumberQuery(.floored))
            ),
            "rounded": Procedure(
                description: "The nearest whole number.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .number)],
                    returns: .int
                ),
                implementation: .query(NumberQuery(.rounded))
            ),
            "lessThan": Procedure(
                description: "Whether this orders before another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("Ordered")),
                        "value": Parameter(type: .variable("Ordered"))
                    ],
                    returns: .bool
                ),
                implementation: .query(ComparisonQuery(.lessThan))
            ),
            "greaterThan": Procedure(
                description: "Whether this orders after another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .variable("Ordered")),
                        "value": Parameter(type: .variable("Ordered"))
                    ],
                    returns: .bool
                ),
                implementation: .query(ComparisonQuery(.greaterThan))
            )
        ]
    )
}
