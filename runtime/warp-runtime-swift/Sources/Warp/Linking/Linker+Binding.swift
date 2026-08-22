//
//  Linker+Binding.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Resolving is a rewrite. Two things a document writes are not yet what they
// mean — a selector, which means whichever declaration the writing module can
// see, and a reference to a constant, which means the value it was bound to.
// Both are settled here, so the image the executor runs holds no name whose
// meaning depends on where it was written.
//
// The walk is total over `Expression` on purpose. A case added to the language
// and forgotten here would be a case whose names silently stay unresolved, and
// silence is exactly the failure a linker exists to prevent.
extension Linker {
    // MARK: - Internal
    // A native procedure has no names to resolve — its body is Swift, which the
    // linker cannot read and does not need to.
    func bind(
        _ procedure: Procedure,
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at name: String
    ) throws -> Procedure {
        guard let block = procedure.block else { return procedure }

        return Procedure(
            description: procedure.description,
            signature: procedure.signature,
            implementation: .body(
                try bind(
                    block,
                    within: origin,
                    folding: folding,
                    symbols: symbols,
                    at: "\(name).body"
                )
            )
        )
    }

    func bind(
        _ block: Block,
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at location: String
    ) throws -> Block {
        Block(
            body: try bind(
                block.body,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            ),
            result: try block.result.map { result in
                try bind(
                    result,
                    within: origin,
                    folding: folding,
                    symbols: symbols,
                    at: location
                )
            }
        )
    }

    // A body with no result slot — the walk's, and any future one whose
    // answer is nothing by grammar.
    func bind(
        _ body: [Statement],
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at location: String
    ) throws -> [Statement] {
        try body.enumerated().map { position, statement in
            try bind(
                statement,
                at: position,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            )
        }
    }

    // MARK: - Private
    private func bind(
        _ statement: Statement,
        at position: Int,
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at location: String
    ) throws -> Statement {
        Statement(
            id: statement.id,
            binding: statement.binding,
            expression: try bind(
                statement.expression,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: "\(location).\(statement.id ?? "[\(position)]")"
            )
        )
    }

    private func bind(
        _ expression: Expression,
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at location: String
    ) throws -> Expression {
        func inner(_ expression: Expression) throws -> Expression {
            try bind(
                expression,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            )
        }

        func inner(_ block: Block) throws -> Block {
            try bind(
                block,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            )
        }

        func inner(_ body: [Statement]) throws -> [Statement] {
            try bind(
                body,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            )
        }

        switch expression {
        case .literal:
            return expression

        case let .leave(leave):
            guard let value = leave.value else { return expression }

            return .leave(Leave(reach: leave.reach, target: leave.target, value: try inner(value)))

        // A path whose head names a constant is data the moment it is read, so
        // it becomes that data. Drilling is done here too — a constant record's
        // field is as settled as the record.
        case let .reference(path):
            guard case let .key(head)? = path.first, folding.scope.value(of: head) != nil else {
                return expression
            }

            do {
                return .literal(try folding.resolve(expression))
            } catch {
                throw LinkError("\(location): reading constant '\(head)' — \(error)")
            }

        case let .array(array):
            return .array(try array.map(inner))

        case let .record(record):
            return .record(try record.mapValues(inner))

        case let .closure(procedure):
            guard let block = procedure.block else { return expression }

            return .closure(
                Procedure(
                    description: procedure.description,
                    signature: procedure.signature,
                    implementation: .body(try inner(block))
                )
            )

        case let .invoke(callee, arguments):
            return .invoke(try inner(callee), arguments: try arguments.mapValues(inner))

        case let .block(block):
            return .block(try inner(block))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try inner(condition),
                then: try inner(then),
                else: try otherwise.map(inner)
            )

        case let .loop(condition, body, round):
            return .loop(
                while: try inner(condition),
                body: try inner(body),
                round: round
            )

        case let .iteration(material, body, element):
            return .iteration(
                over: try inner(material),
                body: try inner(body),
                element: element
            )

        case let .attempt(block, rescue, failure):
            return .attempt(try inner(block), rescue: try inner(rescue), failure: failure)

        case let .dispatch(dispatch):
            return .dispatch(
                try bind(
                    dispatch,
                    within: origin,
                    folding: folding,
                    symbols: symbols,
                    at: location
                )
            )
        }
    }

    // The selector is the one thing here whose meaning is a fact about where it
    // was written. An installed word answers first and is not a symbol; anything
    // else is resolved against the writing module, and an ambiguity is refused
    // rather than decided by link order.
    private func bind(
        _ dispatch: Dispatch,
        within origin: Int,
        folding: Resolver,
        symbols: [Symbol],
        at location: String
    ) throws -> Dispatch {
        func inner(_ expression: Expression) throws -> Expression {
            try bind(
                expression,
                within: origin,
                folding: folding,
                symbols: symbols,
                at: location
            )
        }

        let selector: String

        if let symbol = resolve(dispatch.selector, from: origin, in: symbols) {
            selector = symbol.qualified
        } else {
            let candidates = symbols
                .filter { symbol in symbol.declares(dispatch.selector) }
                .map(\.qualified)
                .sorted()

            guard candidates.isEmpty else {
                throw LinkError(
                    "\(location): sends '\(dispatch.selector)', which"
                        + " \(candidates.joined(separator: " and ")) both declare"
                        + " — name the one you meant"
                )
            }

            throw LinkError(
                "\(location): sends '\(dispatch.selector)', which no module in this"
                    + " link declares"
            )
        }

        return Dispatch(
            receiver: try dispatch.receiver.map(inner),
            selector: selector,
            arguments: try dispatch.arguments.mapValues(inner)
        )
    }
}
