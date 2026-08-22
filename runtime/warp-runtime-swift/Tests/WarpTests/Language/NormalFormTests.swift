//
//  NormalFormTests.swift
//  WarpTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
@testable import Warp

// One name, one spelling. Unicode writes `é` two ways — one scalar, or `e` plus
// a combining mark — and the two look identical while comparing as different
// bytes. Record keys settled this at the encodings; every name a program writes
// as a value settles here: a name is normal form C or it is refused, so a
// declaration and a reference can only meet by being the same bytes.
@Suite("A name is written in normal form C")
struct NormalFormTests {
    // MARK: - Property
    // `é` as `e` plus a combining acute — canonically equivalent to the one-
    // scalar spelling, and different bytes.
    private let denormal = "cafe\u{301}"
    private let normal = "caf\u{E9}"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a statement id outside normal form C is refused")
    func aDenormalIdIsRefused() {
        #expect(!validates(body: [
            Statement(id: denormal, expression: .literal(.int(1)))
        ]))
        #expect(validates(body: [
            Statement(id: normal, expression: .literal(.int(1)))
        ]))
    }

    @Test("a parameter outside normal form C is refused")
    func aDenormalParameterIsRefused() {
        // Given — a parameter is a name the body reads, so it is held to the
        // same spelling the body's own names are
        let sut = Procedure(
            signature: Signature(parameters: [denormal: Parameter(type: .int)]),
            body: [],
            result: .literal(.int(1))
        )

        // When / Then
        #expect {
            try Validator().validate(sut)
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a reference outside normal form C is refused before visibility")
    func aDenormalReferenceIsRefused() {
        // Given — the declaration is the one-scalar spelling and the reference
        // is the decomposed one. Bytes differ, so without this rule the reading
        // would say "not visible" about a name the author can see on screen —
        // refused as a spelling problem, which is what it is.
        #expect {
            try Validator().validate(
                body: [Statement(id: normal, expression: .literal(.int(1)))]
                    + [Statement(id: "read", expression: .reference([.key(denormal)]))],
                visible: []
            )
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a binding name outside normal form C is refused, whichever construct binds it", arguments: [
        Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(body: []),
            round: "cafe\u{301}"
        ),
        .iteration(
            over: .literal(.array([.int(1)])),
            body: [],
            element: "cafe\u{301}"
        ),
        .attempt(
            Block(body: [], result: .literal(.int(1))),
            rescue: Block(body: [], result: .literal(.int(0))),
            failure: "cafe\u{301}"
        )
    ])
    func aDenormalBindingNameIsRefused(_ expression: Warp.Expression) {
        #expect {
            try Validator().validate(expression, visible: [])
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a closure's parameter outside normal form C is refused")
    func aDenormalClosureParameterIsRefused() {
        // Given — a closure's signature is a signature; the rule does not care
        // where one sits
        let sut = Warp.Expression.closure(
            Procedure(
                signature: Signature(parameters: [denormal: Parameter(type: .int)]),
                body: [],
                result: .literal(.int(1))
            )
        )

        // When / Then
        #expect {
            try Validator().validate(sut, visible: [])
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a module's own names outside normal form C are refused", arguments: [
        Module(
            constants: ["cafe\u{301}": .literal(.int(1))],
            procedures: ["entry": Procedure(body: [], result: .literal(.int(1)))]
        ),
        Module(
            procedures: ["cafe\u{301}": Procedure(body: [], result: .literal(.int(1)))]
        )
    ])
    func aDenormalModuleNameIsRefused(_ module: Module) {
        // Given — a constant's and a procedure's name are read by references
        // and calls, so they meet the same bytes rule their readers do
        #expect {
            try Validator().validate(module)
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("an argument name outside normal form C is refused")
    func aDenormalArgumentNameIsRefused() {
        // Given — an argument's name has to meet a parameter's, and parameters
        // are held to normal form C, so a denormal argument could never match
        let sut = Warp.Expression.dispatch(
            Dispatch(
                selector: "somebody",
                arguments: [denormal: .literal(.int(1))]
            )
        )

        // When / Then
        #expect {
            try Validator().validate(sut, visible: [])
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a leave target outside normal form C is refused")
    func aDenormalLeaveTargetIsRefused() {
        // Given — a loop named in one spelling and left in the other
        let sut = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(body: [
                Statement(expression: .leave(Leave(reach: .construct, target: denormal)))
            ]),
            round: normal
        )

        // When / Then
        #expect {
            try Validator().validate(sut, visible: [])
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }
}
