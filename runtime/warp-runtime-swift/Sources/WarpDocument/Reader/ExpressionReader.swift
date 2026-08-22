//
//  ExpressionReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The expression grammar. `Expression` has shapes and no spelling; this is the
// spelling — no front end may hide an expression inside a string, so any
// notation that can write an object can write every expression:
//
//   scalar             — a literal, and strings are always literal text
//   { ref: a.b[0] }    — a name to resolve in the consuming scope
//   { value: <data> }  — the escape for data that looks like a form. It builds
//                        a plain literal: quotation is a fact about this
//                        notation, not about the expression it writes
//   { format:, with: } — closed interpolation: the template sees only its
//                        declared bindings, nothing from the ambient scope
//   { closure: <procedure> }
//                      — a procedure written where a value is wanted. An
//                        expression rather than a construct because that is
//                        where one is needed: a closure is written as an
//                        argument far more often than as a statement
//   { call: <message> } — a message where a value is wanted. The same form a
//                        statement writes, and here because the language puts
//                        no such limit on it: every spelling that stands in for
//                        a word builds one of these somewhere inside an
//                        expression, so a document that could only write one as
//                        a statement could not say plainly what its own
//                        spellings mean
//   record / array     — elements are expressions
//
// A string is never re-parsed into anything live — the injection surface the
// old `${}` grammar carried does not exist here.
public struct ExpressionReader: Decodable {
    // MARK: - Property
    // The object keys that make a record an expression form. A record that
    // carries one of these as plain data must be quoted — `{ value: ... }`.
    //
    // Fixed, where construct words are a `ConstructRegistry` a caller composes. The
    // asymmetry is deliberate, and this set is why: it is the quoting boundary.
    // A construct word is read in statement position, where a document is already
    // writing code; these are read wherever data appears, so widening the set
    // turns records that were data into forms. Under a movable boundary the same
    // document means different things in different notations, and the way an author
    // finds out is a payload silently becoming a reference.
    static let formKeys: Set<String> = ["ref", "value", "format", "with", "closure", "call"]

    public let expression: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let value = try ValueReader(from: decoder).value

        do {
            self.expression = try Self.read(value, in: decoder)
        } catch let error as ExpressionFormError {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message)
            )
        }
    }

    // MARK: - Public
    // The decoder comes along because one form needs more than the value: a
    // closure carries statements, and which words a statement may write is the
    // registry's answer, which travels in the decoder rather than in the data.
    public static func read(_ value: Value, in decoder: Decoder? = nil) throws -> Expression {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes:
            return .literal(value)

        case let .array(array):
            return .array(try array.map { element in try read(element, in: decoder) })

        case let .object(object):
            return try read(object: object, in: decoder)

        // A document is text. Nothing it parses to is ever a procedure, so this
        // arm is unreachable rather than unwritten — a closure reaches the
        // language by being spelled, and spelling it is a form.
        case .procedure:
            throw ExpressionFormError("a document cannot contain a procedure value")
        }
    }

    // MARK: - Private
    private static func read(object: [String: Value], in decoder: Decoder?) throws -> Expression {
        let formKeys = Set(object.keys).intersection(Self.formKeys)

        // No form key — an ordinary record of expressions.
        guard !formKeys.isEmpty else {
            return .record(try object.mapValues { field in try read(field, in: decoder) })
        }

        if object.keys.contains("ref") {
            guard object.count == 1 else {
                throw ExpressionFormError(
                    "a record with `ref` must be exactly { ref: <path> } —"
                        + " wrap it in { value: ... } if the keys are plain data"
                        + " (found keys: \(object.keys.sorted()))"
                )
            }

            guard case let .string(rendered)? = object["ref"] else {
                throw ExpressionFormError(
                    "{ ref: } takes a path string like a.b[0]"
                )
            }

            do {
                return .reference(try TemplateParser().parseRefPath(rendered))
            } catch {
                throw ExpressionFormError("{ ref: \(rendered) } — \(error)")
            }
        }

        if object.keys.contains("closure") {
            guard object.count == 1, let written = object["closure"] else {
                throw ExpressionFormError(
                    "a record with `closure` must be exactly { closure: <procedure> }"
                        + " (found keys: \(object.keys.sorted()))"
                )
            }

            guard let decoder else {
                throw ExpressionFormError(
                    "{ closure: } cannot be read here — a closure carries statements,"
                        + " and this surface reads expressions alone"
                )
            }

            do {
                return .closure(
                    try ProcedureReader(from: ValueDecoder(
                        value: written,
                        codingPath: decoder.codingPath,
                        userInfo: decoder.userInfo
                    ))
                    .procedure
                )
            } catch {
                throw ExpressionFormError("{ closure: } — \(error)")
            }
        }

        if object.keys.contains("call") {
            guard object.count == 1, let written = object["call"] else {
                throw ExpressionFormError(
                    "a record with `call` must be exactly { call: <message> }"
                        + " (found keys: \(object.keys.sorted()))"
                )
            }

            guard let decoder else {
                throw ExpressionFormError(
                    "{ call: } cannot be read here — a message may carry bodies,"
                        + " and this surface reads expressions alone"
                )
            }

            do {
                // A message written where a value is wanted has no statement to
                // take a name from, and nothing in a message wants one.
                return try CallForm(from: ValueDecoder(
                    value: written,
                    codingPath: decoder.codingPath,
                    userInfo: decoder.userInfo
                ))
                .expression(boundTo: "")
            } catch {
                throw ExpressionFormError("{ call: } — \(error)")
            }
        }

        if object.keys.contains("value") {
            guard object.count == 1, let payload = object["value"] else {
                throw ExpressionFormError(
                    "a record with `value` must be exactly { value: <data> } —"
                        + " wrap the whole record in { value: ... } if the keys are"
                        + " plain data (found keys: \(object.keys.sorted()))"
                )
            }

            return .literal(payload)
        }

        // A notation may decline to offer a template, and then these keys are
        // refused rather than read as an ordinary record. Giving up a spelling
        // says a document may not write it — it does not hand the words back to
        // mean something else, which is why the set of form keys is the same in
        // every notation whether or not each one is offered.
        let spellings = decoder?.userInfo[.spellingRegistry] as? SpellingRegistry ?? .canonical

        guard spellings.interpolation else {
            throw ExpressionFormError(
                "this notation does not spell a template — put the text together"
                    + " by sending the words that put text together"
            )
        }

        guard object.keys.contains("format") else {
            // Only `with` remains — with is format's companion, meaningless alone.
            throw ExpressionFormError(
                "`with` only accompanies `format` — wrap the record in"
                    + " { value: ... } if the keys are plain data"
                    + " (found keys: \(object.keys.sorted()))"
            )
        }

        guard Set(object.keys).subtracting(["format", "with"]).isEmpty else {
            throw ExpressionFormError(
                "a record with `format` must be exactly { format: <template>,"
                    + " with: <bindings> } — wrap it in { value: ... } if the keys"
                    + " are plain data (found keys: \(object.keys.sorted()))"
            )
        }

        guard case let .string(template)? = object["format"] else {
            throw ExpressionFormError("{ format: } takes a template string")
        }

        let bindings: [String: Expression]

        switch object["with"] {
        case nil:
            bindings = [:]

        case let .object(withObject)?:
            bindings = try withObject.mapValues { binding in try read(binding, in: decoder) }

        case let other?:
            throw ExpressionFormError(
                "{ format: } `with` takes a record of bindings,"
                    + " got \(other.type)"
            )
        }

        let segments: [TemplateSegment]

        do {
            segments = try TemplateParser().parse(template)
        } catch {
            throw ExpressionFormError("{ format: } template — \(error)")
        }

        // The format surface is closed: every placeholder must name a declared
        // binding. An undeclared name is an author mistake caught at load, never
        // an ambient lookup at run time.
        try validateClosed(segments, over: Set(bindings.keys))

        return try lowered(segments, over: bindings)
    }

    // A template as the words that build it. Interpolation is a spelling rather
    // than a thing the language has: each piece becomes a literal or a value
    // asked how it reads, and the pieces are written one after another.
    //
    // Lowering here is what makes a placeholder an ordinary reference. It is
    // checked, linked and refused the way every other reference is, instead of
    // being a shape only the template walk knew how to read.
    private static func lowered(
        _ segments: [TemplateSegment],
        over bindings: [String: Expression]
    ) throws -> Expression {
        let pieces: [Expression] = try segments.map { segment in
            switch segment {
            case let .text(literal):
                return .literal(.string(literal))

            case let .ref(path):
                return .dispatch(
                    Dispatch(
                        receiver: try substituted(path, over: bindings),
                        selector: Spelling.read
                    )
                )
            }
        }

        // One piece that is already text is that text. Nothing is written one
        // after another when there is nothing to write it after.
        if pieces.count == 1, case let .literal(.string(only)) = pieces[0] {
            return .literal(.string(only))
        }

        return .dispatch(Dispatch(receiver: .array(pieces), selector: Spelling.joined))
    }

    // A placeholder names a binding and then drills into it, so what it reads is
    // the binding's expression with the rest of the path walked from there. A
    // binding that is itself a reference keeps one path rather than growing a
    // dispatch around itself.
    //
    // Every name in the path is substituted, not only the head. An index
    // reference is a path of its own inside this one, and leaving it as written
    // would have it read from whatever scope the statement runs in — which is
    // the one thing a closed template must never do, and which `validateClosed`
    // has already made the author declare a binding for.
    private static func substituted(
        _ path: [PathSegment],
        over bindings: [String: Expression]
    ) throws -> Expression {
        guard let head = path.head, let bound = bindings[head] else {
            throw ExpressionFormError(
                "{ format: } placeholder ${\(path.rendered)} names"
                    + " no binding this template was given"
            )
        }

        let rest = try Array(path.dropFirst()).map { segment in
            try closing(segment, over: bindings)
        }

        guard !rest.isEmpty else { return bound }

        // Drilling continues a path, and only a path can be continued. Reading
        // the placeholder as written would reach the ambient scope, so it is
        // refused instead.
        guard case let .reference(prefix) = bound else {
            throw ExpressionFormError(
                "{ format: } placeholder ${\(path.rendered)} drills into"
                    + " '\(head)', which is bound to something other than a name"
            )
        }

        return .reference(prefix + rest)
    }

    // A segment with any path inside it closed over the same bindings. Only an
    // index reference holds one; the rest name nothing.
    private static func closing(
        _ segment: PathSegment,
        over bindings: [String: Expression]
    ) throws -> PathSegment {
        guard case let .indexRef(inner) = segment else { return segment }

        guard case let .reference(closed) = try substituted(inner, over: bindings) else {
            throw ExpressionFormError(
                "{ format: } index ${\(inner.rendered)} is bound to something"
                    + " other than a name, and an index reads a name"
            )
        }

        return .indexRef(closed)
    }

    private static func validateClosed(
        _ segments: [TemplateSegment],
        over declared: Set<String>
    ) throws {
        for segment in segments {
            guard case let .ref(path) = segment else { continue }

            for referenced in path.expandingIndexReferences {
                guard let head = referenced.head, declared.contains(head) else {
                    throw ExpressionFormError(
                        "{ format: } placeholder ${\(referenced.rendered)} names"
                            + " '\(referenced.head ?? referenced.rendered)', which is"
                            + " not declared in `with` — a format template sees only"
                            + " its own bindings"
                    )
                }
            }
        }
    }
}
