//
//  Writer+Expression.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// Where the two positions a document writes an expression in stop being the
// same. A statement is a name and one construct, so every shape the language has
// can be written there; inside another expression there is no name to give, so
// only the shapes that need none can.
public extension Writer {
    // MARK: - Public
    func value(of statement: Statement) throws -> Value {
        var written: [String: Value] = [:]

        if let id = statement.id {
            written[binding(of: statement.binding)] = .string(id)
        }

        let (key, body) = try construct(of: statement.expression, named: statement.id)

        written[key] = body

        return .object(written)
    }

    // Where the expression is going decides what may be written bare there. Most
    // slots reserve the form keys alone; a condition slot also reserves the
    // words a spelling is recognised by, since anything written plainly there
    // would be read as one.
    func value(of expression: Expression, reserving reserved: Set<String> = []) throws -> Value {
        let reserved = reserved.union(ExpressionReader.formKeys)

        switch expression {
        // Data that happens to look like a form has to say it is data, and data
        // that could not be mistaken for one says nothing.
        case let .literal(value):
            switch try Self.spelling(of: value, reserving: reserved) {
            case .plainly: return value
            case .quoted: return .object(["value": value])
            }

        case let .reference(path):
            return .object(["ref": .string(path.rendered)])

        case let .array(elements):
            return .array(try elements.map { element in try value(of: element) })

        // A record of expressions is not data, so `{ value: }` cannot rescue it
        // — quoting one would say the fields are literals rather than things to
        // evaluate. A record whose own field names are read as a form here has
        // no document, and saying so beats writing one that means something else.
        case let .record(fields):
            guard Set(fields.keys).isDisjoint(with: reserved) else {
                throw WritingError(
                    "a record with the field(s) "
                        + "\(Set(fields.keys).intersection(reserved).sorted()) is read as a form"
                        + " where it is written, and a record of expressions cannot be quoted"
                )
            }

            return .object(try fields.mapValues { field in try value(of: field) })

        case let .closure(procedure):
            return .object(["closure": try value(of: procedure)])

        case let .dispatch(dispatch):
            return .object(["call": try message(of: dispatch)])

        // Everything left is a construct, and this notation spells constructs in
        // statement position only. Some of them need to be there — a loop, an
        // iteration, a fan-out over a collection and an attempt each bind a name
        // inside themselves and take it from the statement they are written as —
        // and the rest are there because the expression grammar is a fixed set
        // and they are not in it.
        default:
            throw WritingError(
                "\(Self.shape(of: expression)) has no spelling where a value is wanted"
                    + " — this notation writes it as a statement"
            )
        }
    }

    // MARK: - Private
    // A construct key and what goes under it. The key comes from the registry
    // rather than from the form, because a notation may have respelled it or
    // given it up.
    private func construct(
        of expression: Expression,
        named id: String?
    ) throws -> (String, Value) {
        switch expression {
        case let .dispatch(dispatch):
            return (try spelling(CallForm.self), try message(of: dispatch))

        case let .invoke(callee, arguments):
            var written: [String: Value] = ["procedure": try value(of: callee)]

            if !arguments.isEmpty {
                written["arguments"] = .object(
                    try arguments.mapValues { argument in try value(of: argument) }
                )
            }

            return (try spelling(InvokeForm.self), .object(written))

        case let .block(block):
            return (try spelling(GroupForm.self), .object(try fields(of: block)))

        case let .conditional(condition, then, otherwise):
            var written: [String: Value] = [
                "when": try value(of: condition, reserving: ConditionReader.reservedOperatorKeys),
                "then": .object(try fields(of: then))
            ]

            if let otherwise {
                written["else"] = .object(try fields(of: otherwise))
            }

            return (try spelling(BranchForm.self), .object(written))

        case let .loop(condition, body, round):
            try named(round, matches: id, in: "loop", binding: "round")

            var written: [String: Value] = [
                "where": try value(of: condition, reserving: ConditionReader.reservedOperatorKeys)
            ]

            written.merge(try fields(of: body)) { one, _ in one }

            return (try spelling(LoopForm.self), .object(written))

        case let .iteration(material, body, element):
            try named(element, matches: id, in: "each", binding: "element")

            // `body` is written even when empty, because the reader requires
            // the key — a writer that drops what its reader demands writes
            // documents nobody can read back.
            let written: [String: Value] = [
                "in": try value(of: material),
                "body": .array(try body.map(value(of:)))
            ]

            return (try spelling(EachForm.self), .object(written))

        case let .leave(leave):
            switch leave.reach {
            case .procedure:
                var carried = Value.null

                if let written = leave.value {
                    carried = try value(of: written)
                }

                return (try spelling(ReturnForm.self), carried)

            case .construct:
                return (try spelling(BreakForm.self), leave.target.map(Value.string) ?? .null)

            case .round:
                return (try spelling(ContinueForm.self), leave.target.map(Value.string) ?? .null)
            }

        case let .attempt(attempted, rescue, failure):
            try named(failure, matches: id, in: "attempt", binding: "failure")

            var written = try fields(of: attempted)

            written["rescue"] = .object(try fields(of: rescue))

            return (try spelling(AttemptForm.self), .object(written))

        // Whatever is left needs no name, so it is written as the expression it
        // is under the word that says "this statement is just a value".
        default:
            return (try spelling(ValueForm.self), try value(of: expression))
        }
    }

    private func message(of dispatch: Dispatch) throws -> Value {
        var written: [String: Value] = ["procedure": .string(dispatch.selector)]

        if let receiver = dispatch.receiver {
            written["of"] = try value(of: receiver)
        }

        if !dispatch.arguments.isEmpty {
            written["arguments"] = .object(
                try dispatch.arguments.mapValues { argument in try value(of: argument) }
            )
        }

        return .object(written)
    }

    internal func fields(of block: Block) throws -> [String: Value] {
        var written: [String: Value] = [:]

        if !block.body.isEmpty {
            written["body"] = .array(try block.body.map(value(of:)))
        }

        if let result = block.result {
            written["result"] = try value(of: result)
        }

        return written
    }

    private func spelling(_ form: any ConstructForm.Type) throws -> String {
        guard let key = registry.key(for: form) else {
            throw WritingError(
                "this notation registers no word for \(form) — a shape it gave up"
                    + " the word for is one it can no longer write"
            )
        }

        return key
    }

    // A construct takes the name it binds from the statement it is written as,
    // so one built with any other name has no document. It is reachable: a
    // caller assembling the language's shapes directly is under no obligation to
    // make the two agree, and finds out here rather than at a run that reads a
    // name nothing bound.
    private func named(
        _ bound: String,
        matches id: String?,
        in construct: String,
        binding: String
    ) throws {
        guard bound != id else { return }

        throw WritingError(
            "a \(construct) binds its \(binding) under the name of the statement it is"
                + " written as, and this one binds '\(bound)' inside '\(id ?? "a nameless statement")'"
        )
    }

    private func binding(of binding: Statement.Binding) -> String {
        switch binding {
        case .constant: "id"
        case .variable: "var"
        case .assignment: "set"
        }
    }

    // How data has to be written to come back as itself: as it stands, or
    // quoted because something in it would otherwise be read as a form.
    //
    // The third answer is a refusal rather than a case. A procedure is code that
    // has already closed over a scope, and a document holds neither — quoting
    // one would put something in the text that reading it back could not answer
    // with, which is the same reason a natively implemented word has no document.
    private enum Spelling {
        case plainly
        case quoted
    }

    private static func spelling(
        of value: Value,
        reserving reserved: Set<String>
    ) throws -> Spelling {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes:
            return .plainly

        case let .array(elements):
            return try elements.reduce(.plainly) { carried, element in
                try spelling(of: element, reserving: reserved) == .plainly ? carried : .quoted
            }

        case let .object(fields):
            guard Set(fields.keys).isDisjoint(with: reserved) else { return .quoted }

            return try fields.values.reduce(.plainly) { carried, field in
                try spelling(of: field, reserving: reserved) == .plainly ? carried : .quoted
            }

        case .procedure:
            throw WritingError(
                "a procedure closed over a scope is not data, and a document holds data"
            )
        }
    }

    private static func shape(of expression: Expression) -> String {
        switch expression {
        case .leave: "leaving"
        case .literal: "a literal"
        case .reference: "a reference"
        case .array: "an array"
        case .record: "a record"
        case .closure: "a closure"
        case .invoke: "an invocation"
        case .block: "a group"
        case .conditional: "a branch"
        case .loop: "a loop"
        case .iteration: "an iteration"
        case .attempt: "an attempt"
        case .dispatch: "a message"
        }
    }
}
