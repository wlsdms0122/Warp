//
//  ConformanceTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
import Warp
import WarpDocument
import WarpText

// The specification's cases, run against this implementation.
//
// Every other test here reaches inside — `@testable`, private types, internal
// helpers — which is right for a test about how something is built. These are
// about something else: whether this is the language `spec/` describes. So this
// file imports what any caller imports and nothing more. A runner that could see
// inside could pass by agreeing with the implementation rather than with the
// specification, which is the one thing it must not be able to do.
//
// The cases are data, and the point of that is that this file is replaceable.
// An implementation in another language writes its own runner — this much code —
// and asks the same questions.
@Suite("The specification's cases")
struct ConformanceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every case in the specification", arguments: try Case.all())
    func specificationCase(_ sut: Case) async throws {
        switch sut.expectation {
        case let .answers(expected):
            let answered = try await run(sut)

            #expect(answered == expected, "\(sut.name): \(sut.note)")

        case let .refuses(stage):
            let reached = await reached(sut)

            #expect(reached == stage, "\(sut.name): \(sut.note)")
        }
    }

    @Test("the cases are the specification's, and it has some")
    func thereAreCases() throws {
        // Given — a suite that silently found nothing would pass, and passing by
        // asking nothing is the failure mode a conformance suite has
        let sut = try Case.all()

        #expect(sut.count >= 10)
        #expect(Set(sut.map(\.name)).count == sut.count)
    }

    // MARK: - Public
    // MARK: - Private
    private func run(_ sut: Case) async throws -> Value {
        let language = Language()
        let module = try Loader().load(sut.program)
        let image = try language.link([module] + Module.standard, entry: "entry")

        return try await language.makeExecutor().run(image, arguments: sut.arguments)
    }

    // How far a case got before it was refused. The stage is part of the answer:
    // stopping at a run what another implementation stops at a link means
    // something already happened, and what already happened cannot be taken back.
    private func reached(_ sut: Case) async -> Case.Stage? {
        let language = Language()
        let module: Module

        do {
            module = try Loader().load(sut.program)
        } catch {
            return .load
        }

        let image: Image

        do {
            image = try language.link([module] + Module.standard, entry: "entry")
        } catch {
            return .link
        }

        do {
            _ = try await language.makeExecutor().run(image, arguments: sut.arguments)
        } catch {
            return .run
        }

        return nil
    }
}

// One question, read from the specification rather than written here.
struct Case: Sendable, CustomStringConvertible {
    enum Stage: String, Sendable {
        case load
        case link
        case run
    }

    enum Expectation: Sendable {
        case answers(Value)
        case refuses(Stage)
    }

    // MARK: - Property
    let name: String
    let note: String
    let program: Value
    let arguments: [String: Value]
    let expectation: Expectation

    var description: String { name }

    // MARK: - Initializer
    init(from written: Value) throws {
        guard
            case let .string(name)? = written["name"],
            case let .string(note)? = written["note"],
            let program = written["program"],
            let expect = written["expect"]
        else {
            throw ConformanceError("a case is a name, a note, a program and what to expect")
        }

        self.name = name
        self.note = note
        self.program = program

        if case let .object(arguments)? = written["arguments"] {
            self.arguments = arguments
        } else {
            self.arguments = [:]
        }

        if case let .string(stage)? = expect["refuses"] {
            guard let stage = Stage(rawValue: stage) else {
                throw ConformanceError("'\(stage)' is not a stage a program is refused at")
            }

            self.expectation = .refuses(stage)
        } else if let answer = expect["answers"] {
            self.expectation = .answers(answer)
        } else {
            throw ConformanceError("a case expects an answer or a refusal")
        }
    }

    // MARK: - Public
    // The cases live beside the specification they belong to rather than inside
    // this package, because they are not this implementation's — the day there
    // is a second implementation they move with `spec/` and this file stays.
    static func all() throws -> [Case] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WarpConformanceTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // warp-runtime-swift
            .deletingLastPathComponent()   // runtime
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("spec")
            .appendingPathComponent("conformance")

        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "warpt" }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }

        return try files.map { file in
            try Case(from: try TextEncoding.value(from: try Data(contentsOf: file)))
        }
    }

    // MARK: - Private
}

struct ConformanceError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
