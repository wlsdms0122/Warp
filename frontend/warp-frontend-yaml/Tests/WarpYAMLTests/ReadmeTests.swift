//
//  ReadmeTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
import WarpYAML
@testable import Warp
@testable import WarpDocument

// The README's examples, run. A front page that does not compile is worse than
// no front page, and the way to know it compiles is to compile it.
@Suite("What the README shows")
struct ReadmeTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("the opening example, written in Swift")
    func swiftOpeningExample() async throws {
        // Given
        let language = Language()

        let greet = Procedure(
            signature: Signature(
                parameters: ["name": Parameter(type: .string)],
                returns: .string
            ),
            body: [
                Statement(
                    id: "greeting",
                    expression: .dispatch(
                        Dispatch(
                            receiver: .array([
                                .literal(.string("hello, ")),
                                .dispatch(
                                    Dispatch(
                                        receiver: .reference([.key("name")]),
                                        selector: "text"
                                    )
                                )
                            ]),
                            selector: "joined"
                        )
                    )
                )
            ],
            result: .reference([.key("greeting")])
        )

        // When
        let image = try language.link(
            [Module(name: "hello", procedures: ["greet": greet])] + Module.standard,
            entry: "greet"
        )
        let answer = try await language.makeExecutor().run(
            image,
            arguments: ["name": .string("warp")]
        )

        // Then
        #expect(answer == .string("hello, warp"))
    }

    @Test("a written procedure reachable from a path, as the concepts section shows")
    func receiverExample() async throws {
        // Given
        let sut = try loaded("""
        procedures:
          entry:
            parameters:
              tasks: array<string>
            result: { ref: tasks.summarize }
          summarize:
            receiver: of
            parameters: { of: array<string> }
            returns: string
            body:
              - id: many
                value: { ref: of.count }
              - id: line
                value: { format: "${n} tasks", with: { n: { ref: many } } }
            result: { ref: line }
        """)

        // When
        let image = try Loader().language.link([sut] + Module.standard, entry: "entry")
        let answer = try await Language().makeExecutor().run(
            image,
            arguments: ["tasks": .array([.string("a"), .string("b"), .string("c")])]
        )

        // Then
        #expect(answer == .string("3 tasks"))
    }

    @Test("the document the notation section shows")
    func notationExample() async throws {
        // Given
        let sut = try loaded("""
        name: greeter

        const:
          greeting: hello

        types:
          Task:
            id: string
            done: bool

        procedures:
          greet:
            parameters:
              names: array<string>
            returns: string
            body:
              - id: many
                value: { ref: names.count }
              - id: gate
                branch:
                  when: { of: { ref: many }, greaterThan: 0 }
                  then:
                    body:
                      - id: line
                        value: { format: "${g}, ${who}", with: { g: { ref: greeting }, who: { ref: names.first } } }
                    result: { ref: line }
                  else:
                    body:
                      - id: empty
                        value: nobody
                    result: { ref: empty }
            result: { ref: gate }
        """)

        // When
        let image = try Loader().language.link([sut] + Module.standard, entry: "greet")
        let executor = Language().makeExecutor()

        // Then
        #expect(
            try await executor.run(image, arguments: ["names": .array([.string("warp")])])
                == .string("hello, warp")
        )
        #expect(
            try await executor.run(image, arguments: ["names": .array([])])
                == .string("nobody")
        )
    }

    @Test("a word a caller declares, as the usage section shows")
    func vocabularyExample() async throws {
        // Given
        let vocabulary = Module(
            name: "app",
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .string)],
                        returns: .string
                    ),
                    implementation: .query(ShoutQuery())
                )
            ]
        )
        let sut = try loaded("""
        procedures:
          entry:
            parameters:
              name: string
            returns: string
            result: { ref: name.shout }
        """)

        // When
        let image = try Loader().language.link([sut] + Module.standard + [vocabulary], entry: "entry")
        let answer = try await Language().makeExecutor().run(
            image,
            arguments: ["name": .string("warp")]
        )

        // Then
        #expect(answer == .string("WARP"))
    }

    @Test("a construct word a caller spells, as the front end section shows")
    func constructExample() async throws {
        // Given
        let loader = Loader(
            registry: try ConstructRegistry.standard.registering(UnlessForm.self),
            spellings: .standard
        )
        let sut = try loader.load(try YAMLParser().parse("""
        procedures:
          entry:
            parameters:
              flag: bool
            body:
              - id: gate
                unless:
                  when: { of: { ref: flag }, is: true }
                  body:
                    - id: taken
                      value: skipped
                  result: { ref: taken }
            result: { ref: gate }
        """))

        // When
        let image = try loader.language.link([sut] + Module.standard, entry: "entry")
        let executor = Language().makeExecutor()

        // Then
        #expect(
            try await executor.run(image, arguments: ["flag": .bool(false)])
                == .string("skipped")
        )
        #expect(
            try await executor.run(image, arguments: ["flag": .bool(true)]) == .null
        )
    }
}

// MARK: - What the README declares

private struct ShoutQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .string(text) = question.receiver else { return nil }

        return .string(text.uppercased())
    }

    // MARK: - Private
}

private struct UnlessForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case when
        case body
        case result
    }

    // MARK: - Property
    static let key = "unless"

    private let condition: Warp.Expression
    private let block: Block

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.condition = try container.decode(ConditionReader.self, forKey: .when).condition
        self.block = Block(
            body: try container.decodeIfPresent([StatementReader].self, forKey: .body)?
                .map(\.statement) ?? [],
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
    }

    // MARK: - Public
    func expression(boundTo id: String?) -> Warp.Expression {
        .conditional(
            .dispatch(Dispatch(receiver: condition, selector: "not")),
            then: block,
            else: nil
        )
    }

    // MARK: - Private
}

// MARK: - The pipeline the examples run through

// Author's text to canonical document to the runtime's one door — the same
// two calls an application makes, so every example above exercises the same
// boundary a program crosses when it arrives from somewhere else.
private func loaded(_ yaml: String) throws -> Module {
    try Loader().load(try YAMLFrontend().document(from: yaml))
}
