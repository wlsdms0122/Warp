//
//  ObservationTests.swift
//  WarpTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
@testable import Warp

// What a caller is told while a run happens.
//
// This is the language's only outward-facing account of a run in progress, and
// the reason nothing here counts iterations or bounds recursion: runaway work is
// meant to be seen from outside and cancelled, not guessed at from inside. An
// account nobody checked would have made that answer hollow.
@Suite("What a run reports while it runs")
struct ObservationTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("every statement is announced before it runs and again with its value")
    func statementsAreAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(id: "first", expression: .literal(.int(1))),
                        Statement(id: "second", expression: .literal(.int(2)))
                    ],
                    result: reference("second")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        _ = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(await observer.events == [
            .started("first"),
            .completed("first", .int(1)),
            .started("second"),
            .completed("second", .int(2))
        ])
    }

    @Test("a statement inside a body is announced under the place it ran in")
    func nestedStatementsAreAnnounced() async throws {
        // Given — observation follows the run, not the top level of the text
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "outer",
                            expression: .block(
                                Block(
                                    body: [
                                        Statement(id: "inner", expression: .literal(.int(7)))
                                    ],
                                    result: reference("inner")
                                )
                            )
                        )
                    ],
                    result: reference("outer")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        _ = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.started("outer.inner")))
        #expect(await observer.events.contains(.completed("outer.inner", .int(7))))
    }

    @Test("the same statement run twice is announced as two different places")
    func roundsAreToldApart() async throws {
        // Given — the text says `step` once, and the run reaches it once a round
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "walk",
                            expression: .iteration(
                                over: .literal(.array([.int(1), .int(2)])),
                                body: [
                                    Statement(
                                        id: "step",
                                        expression: reference("each", "item")
                                    )
                                ],
                                element: "each"
                            )
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        _ = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.completed("walk[0].step", .int(1))))
        #expect(await observer.events.contains(.completed("walk[1].step", .int(2))))
    }

    @Test("a piece of a fan-out is announced under which piece it is")
    func piecesAreToldApart() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "both",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .literal(.array([.int(1), .int(2)])),
                                    selector: "std.concurrent.map",
                                    arguments: [
                                        "by": .closure(
                                            Procedure(
                                                signature: Signature(
                                                    parameters: ["item": Parameter(type: .any)]
                                                ),
                                                body: [
                                                    Statement(
                                                        id: "step",
                                                        expression: reference("item")
                                                    )
                                                ],
                                                result: reference("step")
                                            )
                                        )
                                    ]
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        _ = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.completed("both[0].step", .int(1))))
        #expect(await observer.events.contains(.completed("both[1].step", .int(2))))
    }

    @Test("a call into a body keeps the statement that called it")
    func aCallPushesRatherThanReplaces() async throws {
        // Given — a place is how the run got here, not where it ended up
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "helper"))
                        )
                    ]
                ),
                "helper": Procedure(
                    body: [
                        Statement(id: "inner", expression: .literal(.int(7)))
                    ],
                    result: reference("inner")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        _ = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(await observer.events.contains(.completed("said.helper.inner", .int(7))))
    }

    @Test("a refusal carries the place it happened, not the one it passed through")
    func aRefusalCarriesItsInnermostPlace() async throws {
        // Given — the mistake is inside the body, two statements deep
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "helper"))
                        )
                    ]
                ),
                "helper": Procedure(
                    body: [
                        // Nameless — a statement that never finishes takes no
                        // name, so the place is its position.
                        Statement(
                            expression: refusing(literal("no"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        // Then
        await #expect(throws: Aborted.self) {
            try await language.makeExecutor().run(image)
        }

        do {
            _ = try await language.makeExecutor().run(image)
        } catch let error as Aborted {
            #expect(error.trace?.rendered == "said.helper.[0]")
            #expect("\(error)" == "said.helper.[0]: no")
        }
    }

    @Test("a statement that fails is announced as failed and not as completed")
    func failureIsAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "doomed",
                            expression: .dispatch(Dispatch(selector: "fail"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard + [.failing], entry: entryName)

        _ = try? await language.makeExecutor(observer: observer).run(image)

        // Then
        let events = await observer.events

        #expect(events.contains(.failed("doomed")))
        #expect(!events.contains { event in
            if case let .completed(id, _) = event { return id == "doomed" }

            return false
        })
    }

    @Test("a rescued failure is announced under the name it was bound as")
    func rescueIsAnnounced() async throws {
        // Given
        let observer = RecordingObserver()
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .attempt(
                                Block(
                                    body: [
                                        Statement(
                                            id: "doomed",
                                            expression: .dispatch(
                                                Dispatch(
                                                    selector: "fail",
                                                    arguments: [
                                                        "recoverable": .literal(.bool(true))
                                                    ]
                                                )
                                            )
                                        )
                                    ]
                                ),
                                rescue: Block(body: [], result: .literal(.string("caught"))),
                                failure: "fragile"
                            )
                        )
                    ],
                    result: reference("fragile")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard + [.failing], entry: entryName)
        let answer = try await language.makeExecutor(observer: observer).run(image)

        // Then
        #expect(answer == .string("caught"))
        #expect(await observer.events.contains(.rescued("fragile")))
    }

    @Test("a run with no observer is the same run")
    func observationIsOptional() async throws {
        // Given
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [Statement(id: "only", expression: .literal(.int(1)))],
                    result: reference("only")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)
        let answer = try await language.makeExecutor().run(image)

        // Then
        #expect(answer == .int(1))
    }
}

// MARK: - What a test hears

private enum ObservedEvent: Equatable {
    case started(String)
    case completed(String, Value)
    case failed(String)
    case rescued(String)
}

private actor RecordingObserver: ExecutionObserver {
    // MARK: - Property
    private(set) var events: [ObservedEvent] = []

    // MARK: - Initializer
    // MARK: - Public
    func statementStarted(at trace: Trace, expression: Warp.Expression) async {
        events.append(.started(trace.rendered))
    }

    func statementCompleted(at trace: Trace, result: Value) async {
        events.append(.completed(trace.rendered, result))
    }

    func statementFailed(at trace: Trace, error: any Error) async {
        events.append(.failed(trace.rendered))
    }

    func failureRescued(name: String, error: any Error) async {
        events.append(.rescued(name))
    }

    // MARK: - Private
}
