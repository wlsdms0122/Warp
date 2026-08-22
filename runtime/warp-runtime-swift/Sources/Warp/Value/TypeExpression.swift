//
//  TypeExpression.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a declaration says it takes. Distinct from `ValueType`, which is what a
// value *is*: `any` is only ever something a declaration says, and `array` alone
// was the most a declaration could say about a list — no element, no fields, no
// name for a shape two procedures share.
//
// A type is an expression for the same reason an expression is: it composes.
// `array<string>` is `array` applied to `string`, and a name is a name for one
// of these rather than a separate kind of thing — which is why a module declares
// a type the same way it declares anything, by binding a name to something.
//
// Checking is structural, and it is width-tolerant on records: a value with more
// fields than the declaration names passes. What arrives here is data from
// outside — a payload gains fields, and a declaration saying which ones it needs
// should not be a declaration that it needs nothing else to exist.
public indirect enum TypeExpression: Sendable, Equatable {
    // Nothing ever *is* `any` — it is what a declaration says when it accepts
    // whatever it is handed. `contains` compares elements of any shape, and
    // declaring `string` there would be a lie the linker would then enforce.
    case any

    // The other end of `any`. No value is ever of this type, which is how a
    // place control does not come back from is written down: a refusal answers
    // `never` because it does not answer at all. Saying so is what keeps the
    // arm that leaves from having an opinion about what the arm that stays
    // holds — without it, one branch failing would cost the other its type.
    case never

    case null
    case bool
    case int
    case double
    case string
    case bytes

    // Whole or fraction, without saying which.
    //
    // It exists because arithmetic is the one place a declaration genuinely
    // means both. Writing `any` there instead said nothing at all, so a sum of a
    // number and a piece of text was found by running it — in a language whose
    // whole claim is that what can be decided before running is.
    //
    // It is not a fourth number. Nothing is ever *of* this type: a value is
    // whole or it is a fraction, and this is what a slot says when either will
    // do. That makes it the numeric `any`, narrowed to the two shapes that
    // arithmetic can actually work with.
    case number

    // A list of one shape. The element is always written, so `array<any>` says
    // out loud that anything is accepted — a declaration that accepts anything
    // reads differently from one that has not been written yet.
    case array(TypeExpression)

    // A map of string keys to one shape — a record whose field names are data
    // rather than declaration. Keys are always strings because that is what
    // `Value.object` holds.
    case object(TypeExpression)

    // Named fields with types. The value may carry more.
    case record([String: TypeExpression])

    // A value that can be called: what it may be called with, and what it must
    // be. Nil is a declaration that has not been written — "some procedure" —
    // the way `any` is for a value, and it is accepted by anything for the same
    // reason.
    //
    // Purity is a requirement rather than a claim. A declaration never states
    // its own — the linker derives that from what a body calls — so what is
    // written here is what a slot asks of whatever fills it.
    case procedure(Signature?, Purity = .unstated)

    // A type a module declared. Kept rather than expanded so that a type may
    // name itself — `Tree` with children of `array<Tree>` is a shape, not a
    // regress — which means resolving one needs the table it was declared in.
    case named(String)

    // A hole in a declaration, filled by whatever the call site puts there. The
    // name is what ties the holes in one signature together: `first` takes
    // `array<some T>` and answers `some T`, so an array of strings answers a
    // string and the declaration never had to say which.
    //
    // It stands for a type rather than naming one, which is why it is not
    // `named` — a name is looked up in a table and this is worked out from the
    // call.
    case variable(String)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // What this type accepts, settled to the declared representation, or a
    // refusal saying which part disagreed. `at` is the path into the value so
    // the message names the field rather than the whole argument.
    public func settling(
        _ value: Value,
        at path: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        switch self {
        case .any:
            return value

        // A value arrived where nothing was supposed to, so the arrival is the
        // refusal — there is no shape to compare it against.
        case .never:
            throw ArgumentError("\(path): declares never, and nothing is ever that")

        // Either shape arrives as itself. Settling to one of them would be the
        // declaration picking, and it declined to.
        case .number:
            switch value {
            case .int, .double:
                return value

            default:
                throw mismatch(value, at: path)
            }

        case let .named(name):
            guard let declared = types.resolve(name) else {
                throw ArgumentError("\(path): declares type '\(name)', which nothing declares")
            }

            return try declared.settling(value, at: path, in: types)

        // A hole the call site filled, and the link is where it was filled. What
        // arrives here has already been checked against what filled it, so there
        // is nothing left for this to compare against.
        case .variable:
            return value

        case let .array(element):
            guard case let .array(elements) = value else { throw mismatch(value, at: path) }

            return .array(
                try elements.enumerated().map { index, item in
                    try element.settling(item, at: "\(path)[\(index)]", in: types)
                }
            )

        case let .object(entry):
            guard case let .object(object) = value else { throw mismatch(value, at: path) }

            return .object(
                try object.mapValues { item in
                    try entry.settling(item, at: path, in: types)
                }
            )

        case let .record(fields):
            guard case let .object(object) = value else { throw mismatch(value, at: path) }

            var settled = object

            for (name, field) in fields.sorted(by: { left, right in left.key < right.key }) {
                guard let written = object[name] else {
                    throw ArgumentError("\(path).\(name): required by \(rendered), and nothing was given")
                }

                settled[name] = try field.settling(written, at: "\(path).\(name)", in: types)
            }

            return settled.isEmpty ? .object([:]) : .object(settled)

        // Purity is not checked here. What a closure calls is a fact about the
        // text it was written in, which the link read and this cannot — a value
        // in hand carries a body, not the judgement made about it.
        case let .procedure(required, _):
            guard case let .procedure(closure) = value else { throw mismatch(value, at: path) }
            guard let required else { return value }

            guard required.accepts(closure.procedure.signature, in: types) else {
                throw ArgumentError(
                    "\(path): expected \(rendered), got"
                        + " \(TypeExpression.procedure(closure.procedure.signature).rendered)"
                )
            }

            return value

        // The scalars, plus the one coercion the language has always had: a
        // whole double where an int is declared, and an int where a double is.
        case .null, .bool, .int, .double, .string, .bytes:
            guard let settled = scalar(value) else { throw mismatch(value, at: path) }

            return settled
        }
    }

    // How the type reads in a message. A declaration an author wrote should come
    // back to them in the spelling they wrote it in.
    public var rendered: String {
        switch self {
        case .any:
            return "any"

        case .never:
            return "never"

        case .number:
            return "number"

        case .null:
            return "null"

        case .bool:
            return "bool"

        case .int:
            return "int"

        case .double:
            return "double"

        case .string:
            return "string"

        case .bytes:
            return "bytes"

        case let .variable(name):
            return "some \(name)"

        case let .procedure(signature, purity):
            let word = purity == .pure ? "pure procedure" : "procedure"

            guard let signature else { return word }

            let written = signature.parameters
                .sorted { left, right in left.key < right.key }
                .map { name, parameter in "\(name): \(parameter.declared.rendered)" }

            // Rendered as what it accepts, because a message is about what would
            // have fit. Which half was written is a fact about the source rather
            // than about the value being refused.
            return "\(word)<(\(written.joined(separator: ", "))) -> \((signature.returns ?? .any).rendered)>"

        case let .array(element):
            return "array<\(element.rendered)>"

        case let .object(entry):
            return "object<\(entry.rendered)>"

        case let .record(fields):
            let written = fields
                .sorted { left, right in left.key < right.key }
                .map { name, field in "\(name): \(field.rendered)" }

            return "{ \(written.joined(separator: ", ")) }"

        case let .named(name):
            return name
        }
    }

    // MARK: - Private
    // The one conversion the language performs, and it goes one way.
    //
    // Every whole number is a fraction, so a slot asking for a fraction can take
    // a whole one and lose nothing. The reverse is not true, and taking it when
    // the fraction happened to be whole would make the answer to "does this fit"
    // depend on the value rather than the type — `2.0` accepted where `2.5` is
    // refused, by a declaration that names neither.
    private func scalar(_ value: Value) -> Value? {
        switch (self, value) {
        case (.null, .null), (.bool, .bool), (.int, .int), (.double, .double),
            (.string, .string), (.bytes, .bytes):
            return value

        case (.double, .int(let integer)):
            return .double(Double(integer))

        default:
            return nil
        }
    }

    private func mismatch(_ value: Value, at path: String) -> ArgumentError {
        ArgumentError("\(path): expected \(rendered), got \(value.type)")
    }
}

extension TypeExpression: CustomStringConvertible {
    public var description: String { rendered }
}

extension TypeExpression {
    // Whether a value of `other` may stand where this is declared. Structural,
    // and one-directional: `any` on the left accepts anything because nothing
    // was declared, and `any` on the right is accepted by anything because
    // nothing is known — an undeclared answer cannot be proven wrong.
    //
    // This is the half of checking the linker can do. What a body computes is
    // not readable from the text, but what a *call* answers is: it is the
    // callee's declaration, and a declaration is text.
    public func accepts(_ other: TypeExpression, in types: TypeTable = TypeTable()) -> Bool {
        switch (self, other) {
        // What answers `never` never arrives, so it cannot be the value that
        // disagrees with a declaration — it fits everywhere. The other way round
        // it fits nowhere, because a slot declaring `never` is a slot nothing
        // can reach.
        case (_, .never):
            return true

        // A hole accepts whatever fills it, and what fills it is worked out at
        // the call rather than here. In the other direction a hole stands for
        // some type and this one is that type, so it fits.
        case (.variable, _), (_, .variable):
            return true

        case (.any, _), (_, .any):
            return true

        case (.never, _):
            return false

        case (.named(let name), _):
            guard let declared = types.resolve(name) else { return false }

            return declared.accepts(other, in: types)

        case (_, .named(let name)):
            guard let declared = types.resolve(name) else { return false }

            return accepts(declared, in: types)

        case (.array(let mine), .array(let theirs)):
            return mine.accepts(theirs, in: types)

        case (.object(let mine), .object(let theirs)):
            return mine.accepts(theirs, in: types)

        // A record is an object whose fields happen to be known. What is asked
        // for is a mapping with values of one shape, and a record whose every
        // field is that shape is one — the extra knowledge does not disqualify
        // it. Not the other way round: an `object` promises nothing about which
        // fields exist, and a record names fields it requires.
        case let (.object(mine), .record(theirs)):
            return theirs.values.allSatisfy { field in mine.accepts(field, in: types) }

        // Width again: what stands here must declare at least the fields this
        // one names, and may declare more.
        case let (.record(mine), .record(theirs)):
            return mine.allSatisfy { name, field in
                theirs[name].map { given in field.accepts(given, in: types) } ?? false
            }

        case let (.procedure(required, wanted), .procedure(given, offered)):
            // A slot asking for purity takes only what says it is pure. The
            // other way round is free: a pure procedure stands anywhere one is
            // wanted, because answering without running is a promise nothing
            // needs relieving of.
            guard wanted != .pure || offered == .pure else { return false }

            // Nothing was said on one side or the other, so nothing is refused.
            guard let required, let given else { return true }

            return required.accepts(given, in: types)

        // The one conversion the language has, and it goes the way that cannot
        // lose anything. A slot asking for a whole number does not take a
        // fraction, whatever that fraction happens to be worth.
        case (.double, .int):
            return true

        // A slot that means either takes either.
        case (.number, .int), (.number, .double):
            return true

        // And the other way round, because arithmetic answers one of these and
        // the answer has to fit where a whole number or a fraction was asked
        // for. It reads the same way `any` does one case above: a value known
        // only this loosely fits a slot that takes everything the looseness
        // covers, and no slot that takes less.
        case (_, .number):
            return accepts(.int, in: types) && accepts(.double, in: types)

        default:
            return self == other
        }
    }
}
