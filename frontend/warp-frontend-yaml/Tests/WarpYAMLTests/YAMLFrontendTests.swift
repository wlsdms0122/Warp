//
//  YAMLFrontendTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
import WarpDocument
import WarpYAML

// The front end's one promise: what a person wrote becomes a canonical
// document, and nothing else comes out. Everything downstream of that document
// is a runtime's business, which these tests prove by handing it to a reader
// that offers no spellings at all.
@Suite("The YAML front end")
struct YAMLFrontendTests {
    // MARK: - Property
    private let sut = YAMLFrontend()

    // The far side of the boundary: a reader with every spelling turned off,
    // which is what any runtime is entitled to be
    private let arrival = Loader()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("what a person wrote becomes a document, from text or from bytes")
    func textBecomesADocument() throws {
        // Given
        let written = """
        name: greeter
        procedures:
          greet:
            body:
              - id: said
                value: hello
            result: { ref: said }
        """

        // When
        let fromText = try sut.document(from: written)
        let fromData = try sut.document(from: Data(written.utf8))

        // Then — the same text is the same document
        #expect(fromText == fromData)

        // And it is a document a spelling-free reader accepts
        #expect(try arrival.load(fromText).name == "greeter")
    }

    @Test("every spelling is spent before the document leaves")
    func spellingsAreLoweredToShapes() throws {
        // Given — `is` and a template: the two kinds of sugar this notation
        // offers, both of which a wire reader refuses
        let document = try sut.document(from: """
        procedures:
          entry:
            parameters:
              word: string
            body:
              - id: pick
                branch:
                  when: { of: { ref: word }, is: hey }
                  then: { result: yes }
                  else: { result: no }
              - id: line
                value: { format: "${word}!", with: { word: { ref: word } } }
            result: { ref: line }
        """)

        // Then — the canonical reader reads it, which it could not if one
        // spelling survived
        #expect(throws: Never.self) {
            try arrival.load(document)
        }

        // And the spelled keys are nowhere in the document — judged on the
        // tree itself, not on how some dump happens to print it
        #expect(keys(of: document).isDisjoint(with: ["is", "format", "with"]))
    }

    @Test("the document says what it needs, because the front end computed it")
    func theDocumentCarriesItsManifest() throws {
        // Given — an author does not write a manifest; a front end owes one
        let document = try sut.document(from: """
        procedures:
          entry:
            body:
              - id: sum
                call: { procedure: plus, of: 1, arguments: { value: 2 } }
            result: { ref: sum }
        """)

        // Then
        #expect(document["needs"] == .array([.string("plus")]))
        #expect(document["warp"] != nil)
    }

    @Test("a program the language refuses does not become a document")
    func aRefusedProgramShipsNothing() {
        // Given — well-formed YAML that is not a module worth shipping. The
        // refusal belongs at the author's desk, not at the arrival.
        #expect(throws: (any Error).self) {
            try sut.document(from: """
            name: empty
            procedures: {}
            """)
        }
    }

    @Test("text that is not YAML fails as text, before it is anything else")
    func malformedTextFailsEarly() {
        #expect(throws: DecodingError.self) {
            try sut.document(from: "procedures: [unclosed")
        }
    }

    @Test("the composition a host makes itself is still open")
    func fragmentsComposeByHand() throws {
        // Given — a host that lowers fragments mid-run does not go through a
        // document; it parses and reads, which are the two pieces this package
        // and the runtime already are
        let reader = Loader(spellings: .standard)

        let statements = try reader.statements(from: try YAMLParser().parse("""
        - id: first
          value: hello
        - id: second
          value: { ref: first }
        """))

        // Then
        #expect(statements.map(\.id) == ["first", "second"])
    }

    // MARK: - Public
    // MARK: - Private
    // Every record key anywhere in a document
    private func keys(of value: Value) -> Set<String> {
        switch value {
        case let .object(object):
            object.values.reduce(into: Set(object.keys)) { held, field in
                held.formUnion(keys(of: field))
            }

        case let .array(array):
            array.reduce(into: []) { held, element in held.formUnion(keys(of: element)) }

        default:
            []
        }
    }
}
