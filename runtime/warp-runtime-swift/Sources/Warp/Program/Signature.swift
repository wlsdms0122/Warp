//
//  Signature.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a call is checked against, in both directions — what it takes and what
// comes back. Declaring only the inward half would stop the judgement this
// language makes before running at the boundary it is easiest to make it at.
public struct Signature: Sendable, Equatable {
    // MARK: - Property
    // Which declared parameter is the receiver — the thing this is sent *to* —
    // or nil for a plain call, which most procedures are.
    //
    // A name rather than a type, so the body reads its receiver by the name it
    // declared, the same as every other parameter — a reserved spelling would be
    // the alternative. Declaring a receiver is the whole of what makes a word
    // reachable through a path: it is what lets `x.name` find it.
    public let receiver: String?

    public let parameters: [String: Parameter]

    // What a call returns, or nil where nothing was declared. Absence is spelled
    // by being absent rather than by a type meaning "no claim" — `any` is a
    // claim, so a declaration nobody wrote stays distinguishable from one
    // somebody wrote. Nothing is checked either way; they differ in what they
    // say.
    public let returns: TypeExpression?

    // MARK: - Initializer
    public init(
        receiver: String? = nil,
        parameters: [String: Parameter] = [:],
        returns: TypeExpression? = nil
    ) {
        self.receiver = receiver
        self.parameters = parameters
        self.returns = returns
    }

    // MARK: - Public
    // The returned value, checked against what was declared. Run time rather
    // than link time because what a body computes is not a thing the linker can
    // read off the text — but a declaration that only ever describes is a declaration
    // nothing keeps, so it is checked where the fact exists.
    public func settling(returned value: Value, in types: TypeTable = TypeTable()) throws -> Value {
        guard let returns else { return value }

        return try returns.settling(value, at: "returns", in: types)
    }

    // The receiver, checked against what the parameter naming it declares —
    // except that nothing passes through. A word decides for itself what being
    // sent to nothing means: `contains` says false rather than failing, and a
    // path that reached null is absence rather than misuse.
    public func settling(receiver value: Value, in types: TypeTable = TypeTable()) throws -> Value {
        guard let receiver, let parameter = parameters[receiver], value != .null else {
            return value
        }

        return try parameter.checking(value, called: receiver, in: types)
    }

    // Whether something declared this way may stand where this is required.
    //
    // The directions are opposite on purpose: what is given must accept
    // everything that will be passed to it, and what is required must accept
    // everything it will get back. A body promising less than the slot asks and
    // returning more than the slot allows is the one that fits.
    public func accepts(_ given: Signature, in types: TypeTable = TypeTable()) -> Bool {
        // An undeclared half claims nothing, so it neither demands nor promises —
        // it reads as `any` here, which is the one type that fits both roles.
        //
        // A parameter the body leaves out is not a disagreement. What is given
        // must accept everything that will be passed to it, and a body that
        // never reads a name accepts anything under it — so the check is on the
        // ones it did declare.
        for (name, parameter) in parameters {
            guard let taken = given.parameters[name] else { continue }
            guard taken.declared.accepts(parameter.declared, in: types) else { return false }
        }

        return (returns ?? .any).accepts(given.returns ?? .any, in: types)
    }

    // Whether a path segment may reach this — it takes a receiver, so there is
    // something for the walk to send it to, and it needs nothing else, so
    // `x.count` supplies everything it asks for.
    //
    // A declaration that answers `never` is reachable by neither: a path reads a
    // value, and this one leaves instead of producing one. Letting it in would
    // put the word that must not be missable where a walk decides on its own
    // whether to send it.
    public var isDerivable: Bool {
        guard let receiver else { return false }
        guard returns != .never else { return false }

        return parameters
            .filter { name, _ in name != receiver }
            .values
            .allSatisfy { parameter in !parameter.isRequired }
    }

    // Inputs settle once at the scope boundary — inside the scope, references read
    // the settled values instead of re-evaluating.
    public func settle(
        _ given: [String: Value],
        in types: TypeTable = TypeTable()
    ) throws -> [String: Value] {
        try settle(given, offered: false, in: types)
    }

    // The same, for a caller that hands over more than the body asked for. A
    // word walking an array offers the element and whatever else it has, and
    // which of those the author wanted is the author's business — declaring a
    // name only to leave it unread is a declaration nobody meant.
    public func settle(
        offered given: [String: Value],
        in types: TypeTable = TypeTable()
    ) throws -> [String: Value] {
        try settle(given, offered: true, in: types)
    }

    // MARK: - Private
    private func settle(
        _ given: [String: Value],
        offered: Bool,
        in types: TypeTable
    ) throws -> [String: Value] {
        let undeclared = given.keys
            .filter { name in parameters[name] == nil }
            .sorted()

        guard offered || undeclared.isEmpty else {
            throw ArgumentError(
                "parameters: not declared in the signature:"
                    + " \(undeclared.joined(separator: ", "))"
            )
        }

        // What "nothing was given" means differs by who is giving. An author's
        // argument space folds null and unwritten into one instruction — a
        // reference that names nothing reads as null, and requiring the author
        // to know which is which would make absence observable. A word that
        // *offers* is the other way: it hands over values it actually holds,
        // and a null it offered is a value — an element of the walked
        // collection, not a blank — so only a key it never offered is missing.
        let missing = parameters
            .filter { name, parameter in
                parameter.isRequired
                    && (offered ? given[name] == nil : (given[name] ?? .null) == .null)
            }
            .keys
            .sorted()

        guard missing.isEmpty else {
            throw ArgumentError(
                "parameters: required, and nothing was given for \(missing.joined(separator: ", "))"
            )
        }

        // The settled scope is built from the declaration, never copied from the
        // caller — only declared names exist inside the boundary.
        var settled: [String: Value] = [:]

        for (name, parameter) in parameters.sorted(by: { left, right in left.key < right.key }) {
            // An offered null passes through as the value it is, for the same
            // reason it counted as given above.
            if offered, given[name] == .null {
                settled[name] = .null

                continue
            }

            settled[name] = try parameter.taking(
                given[name] ?? .null,
                called: name,
                in: types
            )
        }

        return settled
    }
}
