//
//  Writer.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// The other direction: a program written back out as data. `Loader` reads a
// document and answers with a module; this takes a module and answers with the
// document that would load into it.
//
// It exists because a program has to be able to leave the machine that built it.
// Building the language's shapes directly is what a front end with a syntax of
// its own does, and a caller assembling procedures in native code does the same
// — but neither can hand what it built to anything running elsewhere unless the
// result can be written down. Reading was half a door.
//
// Only the shapes that stand one to one with the language are written. Nothing
// here reaches for a spelling — no `is`, no template, no `abort` — because a
// spelling is a claim about what the reading side implements, and the point of
// writing plainly is to make that claim as small as it can be. A program that
// arrived spelled is written back unspelled, and it means the same thing.
public struct Writer: Sendable {
    // MARK: - Property
    public let registry: ConstructRegistry

    // MARK: - Initializer
    public init(registry: ConstructRegistry = .standard) {
        self.registry = registry
    }

    // MARK: - Public
    public func value(of module: Module) throws -> Value {
        // Written every time, because a document that travels is the only kind
        // worth writing and neither question can be asked of it later. What it
        // costs is two keys; what it buys is that a reader too old for it, or
        // without the words it calls, says so instead of finding out part of the
        // way through.
        var written: [String: Value] = [
            Envelope.versionKey: .int(Envelope.version),
            Envelope.needsKey: .array(Envelope.needs(of: module).sorted().map(Value.string)),
            "procedures": .object(try module.procedures.mapValues(value(of:)))
        ]

        if let name = module.name {
            written["name"] = .string(name)
        }

        if let description = module.description {
            written["description"] = .string(description)
        }

        if !module.types.isEmpty {
            written["types"] = .object(try module.types.mapValues(value(of:)))
        }

        if !module.constants.isEmpty {
            written["const"] = .object(
                try module.constants.mapValues { constant in try value(of: constant) }
            )
        }

        return .object(written)
    }

    public func value(of procedure: Procedure) throws -> Value {
        // A body is what a document declares. A word backed by native code has
        // nothing a document could carry, and writing its name alone would make
        // a document that loads into something else.
        guard case let .body(block) = procedure.implementation else {
            throw WritingError(
                "a procedure implemented in native code has no document —"
                    + " what a caller brings is declared where the run is assembled"
            )
        }

        var written: [String: Value] = [:]

        if let description = procedure.description {
            written["description"] = .string(description)
        }

        written.merge(try fields(of: procedure.signature)) { one, _ in one }
        written.merge(try fields(of: block)) { one, _ in one }

        return .object(written)
    }

    public func value(of type: TypeExpression) throws -> Value {
        switch type {
        case .any: return .string("any")
        case .never: return .string("never")
        case .null: return .string("null")
        case .bool: return .string("bool")
        case .int: return .string("int")
        case .double: return .string("double")
        case .string: return .string("string")
        case .bytes: return .string("bytes")
        case .number: return .string("number")

        // A declared name is written as itself, and a document reads a name it
        // knows as the type it knows. Nothing stops a module declaring a type
        // called `int`; a document just has no way to say which one it meant.
        case let .named(name):
            guard TypeReader.builtinNames.contains(name) else { return .string(name) }

            throw WritingError(
                "a type declared as '\(name)' is written the same way the built-in one is,"
                    + " and a document has no way to tell them apart"
            )

        case let .variable(name): return .string("some \(name)")

        case let .array(element): return .string("array<\(try spelt(element))>")
        case let .object(element): return .string("object<\(try spelt(element))>")

        // A record and a procedure are both written as a mapping, and the one
        // key that tells them apart belongs to the procedure. A record whose
        // only field is that key would come back as the other one.
        case let .record(fields):
            guard fields.count != 1 || !TypeReader.procedureKeys.contains(fields.keys.first!) else {
                throw WritingError(
                    "a record whose only field is '\(fields.keys.first!)' is written the same"
                        + " way a procedure type is, and a document has no way to tell"
                        + " them apart"
                )
            }

            return .object(try fields.mapValues(value(of:)))

        case let .procedure(signature, purity):
            let word = purity == .pure ? "pure procedure" : "procedure"

            guard let signature else { return .string(word) }

            return .object([word: .object(try fields(of: signature))])
        }
    }

    public func value(of parameter: Parameter) throws -> Value {
        var written: [String: Value] = [:]

        if let type = parameter.type {
            written["type"] = try value(of: type)
        }

        if let oneOf = parameter.oneOf {
            written["oneOf"] = .array(oneOf.map(Value.string))
        }

        if let fallback = parameter.default {
            written["default"] = fallback
        }

        if let hint = parameter.hint {
            written["hint"] = .string(hint)
        }

        // The shorthand where nothing but the type was said. Written because the
        // pair has to round-trip through the shorthand as well as around it.
        if written.count == 1, case let .string(only)? = written["type"] {
            return .string(only)
        }

        return .object(written)
    }

    // MARK: - Private
    // A signature is written flat into whatever declares it — a procedure and a
    // procedure type both spell it as their own keys rather than nesting it.
    func fields(of signature: Signature) throws -> [String: Value] {
        var written: [String: Value] = [:]

        if let receiver = signature.receiver {
            written["receiver"] = .string(receiver)
        }

        if !signature.parameters.isEmpty {
            written["parameters"] = .object(try signature.parameters.mapValues(value(of:)))
        }

        if let returns = signature.returns {
            written["returns"] = try value(of: returns)
        }

        return written
    }

    private func spelt(_ type: TypeExpression) throws -> String {
        guard case let .string(name) = try value(of: type) else {
            throw WritingError(
                "only a type with a name goes inside array<…> or object<…>"
            )
        }

        return name
    }
}
