//
//  NeverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
@testable import Warp

// A statement typed `never` does not finish, so it binds nothing and nothing
// after it runs. The syntactic leaves are refused where they are read; a call
// is the link's to refuse, because only the link knows what the word declares.
// One rule, two places, each catching what only it can see.
@Suite("What never finishes binds nothing")
struct NeverTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a statement after a call that never finishes is refused at link")
    func nothingRunsAfterANeverCall() {
        // Given — `std.control.abort` declares never, so the statement after
        // it would never run, and a name written there would never bind
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(expression: refusing(literal("done"))),
                        Statement(id: "after", expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("after")])
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("nothing written after")
        }
    }

    @Test("a name on the last statement is still refused when it never finishes")
    func aNamedNeverLastStatementIsRefused() {
        // Given — last in the body, so the "nothing after" rule has nothing to
        // say; only the name itself is wrong
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(id: "gone", expression: refusing(literal("done")))
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("binds nothing and takes no name")
        }
    }

    @Test("a result after a statement that never finishes is refused at link")
    func aResultAfterNeverIsRefused() {
        // Given — the result runs after the body, so it is "after" the same
        // way a trailing statement is; the type reading already knows it (a
        // block ending in never types never), and the refusal must know it too
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(expression: refusing(literal("done")))
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("never finishes before it")
        }
    }

    @Test("a statement after a branch both of whose arms leave is refused")
    func nothingRunsAfterABranchThatAlwaysLeaves() {
        // Given — neither arm finishes, so the branch never does, and the
        // statement after it is unreachable whichever way the condition answers
        let branch = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: Block(body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ]),
            else: Block(body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
            ])
        )

        // When / Then
        #expect(!validates(body: [
            Statement(expression: branch),
            Statement(id: "after", expression: .literal(.int(3)))
        ]))
    }

    @Test("a name on a branch both of whose arms leave is refused")
    func aNamedBranchThatAlwaysLeavesIsRefused() {
        // Given — the name could only ever bind what an arm answers, and both
        // arms answer by leaving instead
        let branch = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: Block(body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ]),
            else: Block(body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
            ])
        )

        // When / Then
        #expect(!validates(body: [Statement(id: "gone", expression: branch)]))
    }

    @Test("an arm that leaves through its result is still a leaving arm")
    func anArmLeavingThroughItsResultCounts() {
        // Given — a block answers through its result, so a leave written there
        // ends every way through the arm exactly as one written in the body
        let branch = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: Block(body: [], result: .leave(Leave(reach: .procedure, value: .literal(.int(1))))),
            else: Block(body: [], result: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
        )

        // When / Then
        #expect(!validates(body: [
            Statement(expression: branch),
            Statement(id: "after", expression: .literal(.int(3)))
        ]))
    }

    @Test("a branch that can decline still lets what follows run")
    func aDecliningBranchIsNotALeave() {
        // Given — with no else, the branch finishes whenever the condition
        // declines, so the statement after it is reachable
        let branch = Warp.Expression.conditional(
            .literal(.bool(false)),
            then: Block(body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ]),
            else: nil
        )

        // When / Then
        #expect(validates(body: [
            Statement(expression: branch),
            Statement(id: "after", expression: .literal(.int(3)))
        ]))
    }

    @Test("a result after a leaving statement is refused at the check")
    func aResultAfterLeavingIsRefused() {
        // Given — the syntactic half of the same rule, held where leaves are
        let sut = Procedure(
            body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ],
            result: .literal(.int(2))
        )

        // When / Then
        #expect {
            try Validator().validate(sut)
        } throws: { error in
            "\(error)".contains("never be reached")
        }
    }
}
