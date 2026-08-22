//
//  Linker.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Takes every module this run was given and one name to start from, and answers
// with an image — or refuses.
//
// A link is handed its whole world at once, and no module says anything about
// the others: what to link is the caller's statement, and joining the names up
// is this. So a module declares no imports, and the entry is an argument rather
// than a name written into a document.
//
// Unreached code is checked too. A misspelled procedure in a branch today's
// arguments never take is a defect whether or not this run walks that way, so
// linking follows the whole call graph and refuses on the first name it cannot
// resolve rather than on the first one a run happens to reach.
//
// Every send goes through the same gate: a library word and a procedure are
// checked against a signature by the same code, and the only difference is where
// the signature came from — the installed table, or another module in the same
// link.
//
// Names resolve, and resolving is a rewrite. A call site says `helper`, and what
// it means depends on where it was written; the image the executor runs is
// spelled in resolved names, so a run never has to ask again. That is also why
// constants disappear here — a name bound to a value at load has nothing left to
// do at run time, so linking folds it into the literal it always was.
//
// What it can promise is narrower than "nothing unresolved remains": arguments
// are mostly references that settle at run time, so this checks names, arity and
// the types of *constant* arguments. Calling a value is outside the promise
// entirely, because a closure's callee is a run-time fact.
public struct Linker: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func link(_ modules: [Module], entry: String) throws -> Image {
        let types = try types(of: modules)
        let symbols = try symbols(of: modules)

        guard let start = resolve(entry, from: nil, in: symbols) else {
            throw LinkError(
                "entry '\(entry)' is not declared by any module in this link"
                    + " — declared: \(symbols.map(\.qualified).sorted().joined(separator: ", "))"
            )
        }

        // What every declaration returns, by the name a resolved call site
        // uses. Built before the walk so a call can be judged against a callee
        // the walk has not reached yet.
        var signatures = symbols.reduce(into: [String: Signature]()) { table, symbol in
            table[symbol.qualified] = symbol.procedure.signature
        }

        // Purity is worked out over every declaration rather than the reached
        // ones: a path names a word the call graph never mentions.
        let settled = pure(among: symbols)
        let reachable = try derivable(among: symbols, pure: settled)

        // Folded after the words are known, because a constant may send one:
        // interpolation is `joined` now, and a constant that spells a URL out of
        // other constants is spelling it with words like any other expression.
        let constants = try constants(of: modules, reaching: reachable, in: types)

        // A path writes a bare name, so what it returns has to be findable under
        // one. Inference asks both spellings of the same question.
        for (bare, procedure) in reachable {
            signatures[bare] = procedure.signature
        }

        let frame = TypeFrame(signatures: signatures, types: types, pure: settled)

        var procedures: [String: Procedure] = [:]
        var frontier: [Symbol] = [start]
        var index = 0
        var linked: Procedure?

        // Breadth over the frontier, so the first refusal an author sees is the
        // first mistake they wrote. Memoising by qualified name is what makes a
        // recursive procedure link once instead of forever.
        while index < frontier.count {
            let symbol = frontier[index]
            index += 1

            if procedures[symbol.qualified] != nil { continue }

            let resolved = try bind(
                symbol.procedure,
                within: symbol.origin,
                folding: Resolver(
                    scope: Scope(bindings: constants[symbol.origin] ?? [:]),
                    derivations: reachable,
                    types: types
                ),
                symbols: symbols,
                at: symbol.qualified
            )

            procedures[symbol.qualified] = resolved

            if symbol.qualified == start.qualified { linked = resolved }

            // A constant answer is knowable from the text, so it is held to the
            // declaration here, the way a constant argument is. An answer only
            // a run can produce is settled at the boundary instead.
            if let returns = resolved.signature.returns,
               let answer = resolved.block?.result?.constantValue {
                do {
                    _ = try returns.settling(answer, at: "\(symbol.qualified).result", in: types)
                } catch {
                    throw LinkError(
                        "\(symbol.qualified): answers \(answer.type), and its"
                            + " declaration promises \(returns) — \(error)"
                    )
                }
            }

            guard let block = resolved.block else { continue }

            for site in try sites(
                in: block,
                at: "\(symbol.qualified).body",
                in: environment(of: resolved.signature),
                with: frame
            ) {
                switch site {
                case let .call(call):
                    let selector = call.dispatch.selector

                    // Resolution already happened in `bind`, so a name that
                    // reaches here is one the rewrite settled on and this only
                    // has to find it.
                    guard let callee = symbols.first(where: { $0.qualified == selector }) else {
                        throw LinkError(
                            "\(call.location): sends '\(selector)', which no module in"
                                + " this link declares"
                        )
                    }

                    try check(call, against: callee.procedure, with: frame)

                    frontier.append(callee)

                case let .reach(reach):
                    try check(reach, with: frame)
                }
            }
        }

        return Image(
            entry: linked ?? start.procedure,
            procedures: procedures,
            types: types,
            pure: settled,
            derivations: reachable
        )
    }

    // MARK: - Private
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls.
    //
    // Optimistic and iterated: everything with a body starts as a candidate and
    // is struck out when something it reaches is not pure. Starting from "impure
    // until proven" would make two procedures that call each other permanently
    // impure, which is a fact about the algorithm rather than about the code.
    private func pure(among symbols: [Symbol]) -> Set<String> {
        let bodies = symbols.reduce(into: [String: (Block?, Int)]()) { table, symbol in
            table[symbol.qualified] = (symbol.procedure.block, symbol.origin)
        }

        var pure = Set(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyPure != false }
                .map(\.qualified)
        )

        while true {
            let struck = pure.filter { name in
                guard let (block, origin) = bodies[name], let block else { return false }

                return !isPure(written: block, given: pure, within: origin, in: symbols)
            }

            guard !struck.isEmpty else { return pure }

            pure.subtract(struck)
        }
    }

    // A block answers without running when every part of it is something the
    // pure evaluator can answer, and every name it sends to is pure. Control
    // flow is not in that set — not because running a branch is impure, but
    // because the surface that answers purely does not run bodies at all.
    // A body whose selectors are still the spellings an author wrote. What one
    // means depends on where it was written, so this needs the module it came
    // from and everything the link declares.
    func isPure(
        written block: Block,
        given pure: Set<String>,
        within origin: Int,
        in symbols: [Symbol]
    ) -> Bool {
        isPure(block, given: pure, within: origin, in: symbols)
    }

    // A body binding already rewrote, so every selector in it is the name it
    // resolved to. Nothing is left to look up.
    func isPure(resolved block: Block, given pure: Set<String>) -> Bool {
        isPure(block, given: pure, within: nil, in: [])
    }

    private func isPure(
        _ block: Block,
        given pure: Set<String>,
        within origin: Int?,
        in symbols: [Symbol]
    ) -> Bool {
        block.body.allSatisfy { statement in
            statement.binding == .constant
                && isPure(statement.expression, given: pure, within: origin, in: symbols)
        }
            && (block.result.map { result in
                isPure(result, given: pure, within: origin, in: symbols)
            } ?? true)
    }

    private func isPure(
        _ expression: Expression,
        given pure: Set<String>,
        within origin: Int?,
        in symbols: [Symbol]
    ) -> Bool {
        func isPure(_ inner: Expression) -> Bool {
            self.isPure(inner, given: pure, within: origin, in: symbols)
        }

        switch expression {
        case .literal, .reference, .closure:
            return true

        // Leaving is not a computation, and what it does is not something the
        // pure evaluator can do: purity here means "can be answered without
        // running", and this one answers by not answering. Asking only what it
        // carries would let it through to a slot the resolver then refuses.
        case .leave:
            return false

        case let .array(array):
            return array.allSatisfy(isPure)

        case let .record(record):
            return record.values.allSatisfy(isPure)

        // The selector is what the author wrote, and what it means depends on
        // where it was written — the same question binding answers. Asking the
        // unresolved spelling would call every call impure, because the table is
        // keyed by what a name resolves to.
        case let .dispatch(dispatch):
            let callee = resolve(dispatch.selector, from: origin, in: symbols)?.qualified

            return pure.contains(callee ?? dispatch.selector)
                && (dispatch.receiver.map(isPure) ?? true)
                && dispatch.arguments.values.allSatisfy(isPure)

        // Calling a value is settled at run time, so nothing here can say what
        // it reaches. A body that does it is not answerable purely.
        case .invoke:
            return false

        case .block, .conditional, .loop, .iteration, .attempt:
            return false
        }
    }

    // What can be answered without running, under every name something may look
    // it up by. Two names, because there are two ways to reach one:
    //
    //   `std.count`  — a selector, resolved at link like any other
    //   `count`      — a path segment. `x.count` names no module, because the
    //                  front end cannot know whether a trailing segment is a
    //                  field or a word, so this is the one name still answered
    //                  at run time — and the one place an ambiguity has to be
    //                  refused before the run rather than during it.
    //
    // Built from every declaration rather than the reached ones: a path names a
    // word the call graph never mentions, so reachability is the wrong question.
    private func derivable(
        among symbols: [Symbol],
        pure: Set<String>
    ) throws -> [String: Procedure] {
        var table: [String: Procedure] = [:]
        var reachable: Set<String> = []
        var ambiguous: Set<String> = []

        for symbol in symbols.sorted(by: { $0.qualified < $1.qualified }) {
            let procedure = symbol.procedure

            guard pure.contains(symbol.qualified) else { continue }

            table[symbol.qualified] = procedure

            guard procedure.signature.isDerivable else { continue }

            let bare = symbol.qualified.split(separator: ".").last.map(String.init)
                ?? symbol.qualified

            // Only two words a path could both reach are ambiguous. A
            // declaration a path cannot reach shares the table but not the
            // question, so it is not competing for the name.
            if !reachable.insert(bare).inserted { ambiguous.insert(bare) }

            table[bare] = procedure
        }

        guard ambiguous.isEmpty else {
            throw LinkError(
                "\(ambiguous.sorted().joined(separator: ", ")) is declared by more than"
                    + " one module as something a path may reach — a path segment names"
                    + " no module, so there is no spelling that would tell them apart"
            )
        }

        return table
    }

    // Every declaration, qualified. A module with a name declares into that
    // name; a module without one declares into the shared space, and two of
    // those cannot both declare a name for the same reason two `.c` files
    // cannot both define a symbol.
    private func symbols(of modules: [Module]) throws -> [Symbol] {
        var symbols: [Symbol] = []
        var claimed: Set<String> = []

        for (origin, module) in modules.enumerated() {
            for name in module.procedures.keys.sorted() {
                guard let procedure = module.procedures[name] else { continue }

                let qualified = module.name.map { module in "\(module).\(name)" } ?? name

                guard claimed.insert(qualified).inserted else {
                    throw LinkError(
                        "'\(qualified)' is declared more than once in this link"
                            + " — two declarations of a name have no way to be told apart"
                    )
                }

                symbols.append(
                    Symbol(qualified: qualified, origin: origin, procedure: procedure)
                )
            }
        }

        return symbols
    }

    // What a name written inside `origin` means. A module's own declaration wins,
    // which is what keeps a name from changing meaning because some other module
    // in the link grew a declaration of its own — and past that, a name that only
    // one module declares needs no qualifying.
    func resolve(_ name: String, from origin: Int?, in symbols: [Symbol]) -> Symbol? {
        if let exact = symbols.first(where: { symbol in symbol.qualified == name }) {
            return exact
        }

        if
            let origin,
            let own = symbols.first(where: { symbol in
                symbol.origin == origin && symbol.declares(name)
            })
        {
            return own
        }

        let candidates = symbols.filter { symbol in symbol.declares(name) }

        return candidates.count == 1 ? candidates.first : nil
    }

    // Every shape the modules declared, and the check that each name a
    // declaration mentions is one of them. A type name is resolved here for the
    // same reason a procedure name is: unreached code still has to compile, and
    // a signature naming a shape nobody declared is a defect whether or not this
    // run walks that way.
    private func types(of modules: [Module]) throws -> TypeTable {
        var declared: [String: TypeExpression] = [:]

        for module in modules {
            for name in module.types.keys.sorted() {
                guard declared[name] == nil else {
                    throw LinkError("type '\(name)' is declared more than once in this link")
                }

                declared[name] = module.types[name]
            }
        }

        let table = TypeTable(types: declared)

        for module in modules {
            for (name, type) in module.types.sorted(by: { $0.key < $1.key }) {
                try mentioned(in: type, at: "type '\(name)'", resolve: table)
            }

            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                for (input, parameter) in procedure.signature.parameters.sorted(
                    by: { $0.key < $1.key }
                ) {
                    try mentioned(
                        in: parameter.declared,
                        at: "\(name).inputs.\(input)",
                        resolve: table
                    )
                    try judge(parameter, called: input, at: "\(name).inputs.\(input)", in: table)
                }

                try mentioned(
                    in: procedure.signature.returns ?? .any,
                    at: "\(name).returns",
                    resolve: table
                )
            }
        }

        return table
    }

    // A named type may name itself, so this checks that a name resolves rather
    // than walking into what it resolves to.
    private func mentioned(
        in type: TypeExpression,
        at location: String,
        resolve table: TypeTable
    ) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .variable:
            return

        case let .procedure(signature, _):
            guard let signature else { return }

            for (name, parameter) in signature.parameters.sorted(by: { $0.key < $1.key }) {
                try mentioned(in: parameter.declared, at: "\(location).\(name)", resolve: table)
                try judge(parameter, called: name, at: "\(location).\(name)", in: table)
            }

            try mentioned(in: signature.returns ?? .any, at: location, resolve: table)

        case let .named(name):
            guard table.resolve(name) != nil else {
                throw LinkError(
                    "\(location): names type '\(name)', which no module in this"
                        + " link declares"
                )
            }

        case let .array(element):
            try mentioned(in: element, at: location, resolve: table)

        case let .object(entry):
            try mentioned(in: entry, at: location, resolve: table)

        case let .record(fields):
            for (name, field) in fields.sorted(by: { $0.key < $1.key }) {
                try mentioned(in: field, at: "\(location).\(name)", resolve: table)
            }
        }
    }

    // Whether a parameter's own declaration can be satisfied at all — facts it
    // states about itself, judged wherever a parameter is written: a `oneOf`
    // none of whose candidates the declared type admits is a parameter no call
    // could ever fit, and a default the parameter itself would refuse is a
    // refusal waiting for the one call that leans on it.
    private func judge(
        _ parameter: Parameter,
        called name: String,
        at location: String,
        in table: TypeTable
    ) throws {
        if let allowed = parameter.oneOf {
            guard allowed.contains(where: { candidate in
                admits(parameter.declared, candidate, resolve: table)
            }) else {
                throw LinkError(
                    "\(location): oneOf admits nothing, so no call could ever fit"
                )
            }
        }

        guard let fallback = parameter.default else { return }

        // An explicitly-null default is the value the body receives when the
        // argument is left out, so the declaration must admit null like any
        // other value — and a `oneOf` never lists it, since null has no scalar
        // spelling.
        if fallback == .null {
            guard parameter.oneOf == nil, admitsNull(parameter.declared, resolve: table) else {
                throw LinkError(
                    "\(location): its default is not a value it takes — null"
                )
            }

            return
        }

        do {
            _ = try parameter.checking(fallback, called: name, in: table)
        } catch {
            throw LinkError(
                "\(location): its default is not a value it takes — \(error)"
            )
        }
    }

    // Whether a `oneOf` candidate could ever be a value of the declared type.
    // Candidates are written as the scalar spellings arguments are compared
    // under, so a type with no scalar spelling admits none of them.
    private func admits(
        _ type: TypeExpression,
        _ candidate: String,
        resolve table: TypeTable
    ) -> Bool {
        switch type {
        case .any, .string:
            return true

        case .int:
            return Int64(candidate) != nil

        case .double, .number:
            return Double(candidate) != nil

        case .bool:
            return candidate == "true" || candidate == "false"

        // A hole is filled by the call, so nothing about the candidates is
        // knowable here.
        case .variable:
            return true

        case let .named(name):
            guard let resolved = table.resolve(name) else { return false }

            return admits(resolved, candidate, resolve: table)

        case .null, .never, .bytes, .array, .object, .record, .procedure:
            return false
        }
    }

    private func admitsNull(
        _ type: TypeExpression,
        resolve table: TypeTable
    ) -> Bool {
        switch type {
        case .any, .null:
            return true

        case let .named(name):
            guard let resolved = table.resolve(name) else { return false }

            return admitsNull(resolved, resolve: table)

        default:
            return false
        }
    }

    // Each module's constants, settled. They are evaluated here because there is
    // nothing about them left for a run to do: a constant sees no scope, so what
    // it will be is knowable the moment the document is read.
    //
    // One may name another declared beside it, which is why this repeats until it
    // stops learning — and why a name that never settles is a cycle rather than a
    // typo, and says so.
    private func constants(
        of modules: [Module],
        reaching derivations: [String: Procedure],
        in types: TypeTable
    ) throws -> [Int: [String: Value]] {
        var settled: [Int: [String: Value]] = [:]

        for (origin, module) in modules.enumerated() where !module.constants.isEmpty {
            var known: [String: Value] = [:]
            var pending = module.constants

            while !pending.isEmpty {
                var progressed = false

                for (name, expression) in pending.sorted(by: { $0.key < $1.key }) {
                    // Every constant this one reads must already be settled.
                    // Without the check a name that is not settled yet would
                    // resolve to null — the reading a scope gives an absent
                    // name — and a cycle would quietly become two nulls.
                    guard heads(of: expression).isSubset(of: Set(known.keys)) else { continue }

                    let resolver = Resolver(
                        scope: Scope(bindings: known),
                        derivations: derivations,
                        types: types
                    )

                    // Everything this constant reads is settled, so a refusal
                    // here is the expression's own and not a dependency waiting
                    // its turn. Swallowing it would report the one thing it is
                    // not — a cycle — and leave the author nothing to act on.
                    do {
                        known[name] = try resolver.resolve(expression)
                    } catch {
                        throw LinkError("constant '\(name)': \(error)")
                    }

                    pending[name] = nil
                    progressed = true
                }

                guard progressed else {
                    throw LinkError(
                        "constants \(pending.keys.sorted().joined(separator: ", ")) cannot"
                            + " be settled — a constant may name another declared beside it,"
                            + " but not one that names it back"
                    )
                }
            }

            settled[origin] = known
        }

        return settled
    }

    // The names an expression reads from the scope around it. A closure's body
    // is skipped: what it reads is answered where it is called, from the scope
    // it captured, so requiring those names to be settled first would be asking
    // the wrong question.
    private func heads(of expression: Expression) -> Set<String> {
        switch expression {
        case .literal, .closure:
            return []

        case let .leave(leave):
            return leave.value.map(heads(of:)) ?? []

        case let .reference(path):
            return Set(path.expandingIndexReferences.compactMap(\.head))

        case let .array(array):
            return array.reduce(into: Set()) { names, element in
                names.formUnion(heads(of: element))
            }

        case let .record(record):
            return record.values.reduce(into: Set()) { names, field in
                names.formUnion(heads(of: field))
            }

        case let .invoke(callee, arguments):
            return arguments.values.reduce(into: heads(of: callee)) { names, argument in
                names.formUnion(heads(of: argument))
            }

        case let .dispatch(dispatch):
            return dispatch.arguments.values.reduce(
                into: dispatch.receiver.map(heads(of:)) ?? []
            ) { names, argument in
                names.formUnion(heads(of: argument))
            }

        // A constant sees no scope, so nothing that runs a body can be one —
        // the validator refuses these before linking ever asks.
        case .block, .conditional, .loop, .iteration, .attempt:
            return []
        }
    }

    // A path names what it drills into, and a name has to be one the link can
    // find for the same reason a selector does.
    private func check(_ site: ReachSite, with frame: TypeFrame) throws {
        guard case let .refused(reason) = reach(
            of: site.path,
            in: site.environment,
            with: frame
        ) else {
            return
        }

        throw LinkError("\(site.location): \(reason)")
    }

    private func check(
        _ site: CallSite,
        against callee: Procedure,
        with frame: TypeFrame
    ) throws {
        let dispatch = site.dispatch
        let types = frame.types

        // A declaration with a hole in it is checked with the hole filled, or a
        // slot standing for whatever arrives would refuse whatever arrived.
        let declared = callee.signature
        let filled = declared.isGeneric
            ? bound(of: declared, at: dispatch, in: site.environment, with: frame)
            : nil

        // A hole read two ways has no answer, and going on with one of them
        // would check the call against a declaration nobody wrote. This is what
        // one signature says in place of the several a language with overloading
        // would need — `some N` on both sides and on the way out is a whole
        // number and a whole number answering a whole number, and a whole number
        // and a fraction refused, without a way to declare a name twice.
        if let disagreeing = filled?.disagreeing, !disagreeing.isEmpty {
            let named = disagreeing.keys.sorted().map { hole in
                "'\(hole)' is read as \(filled?.holes[hole]?.rendered ?? "?")"
                    + " and as \(disagreeing[hole]?.rendered ?? "?")"
            }

            throw LinkError(
                "\(site.location): sending '\(dispatch.selector)' —"
                    + " \(named.joined(separator: ", "))"
            )
        }

        let signature = filled.map { filled in declared.filling(filled.holes) } ?? declared
        let undeclared = dispatch.arguments.keys
            .filter { name in signature.parameters[name] == nil }
            .sorted()

        guard undeclared.isEmpty else {
            throw LinkError(
                "\(site.location): sending '\(dispatch.selector)' with"
                    + " \(undeclared.joined(separator: ", ")), which it does not declare"
            )
        }

        // A receiver is written on the other side of the dot rather than by
        // name, so a site that sends one has supplied that parameter.
        let supplied = Set(dispatch.arguments.keys)
            .union(dispatch.receiver == nil ? [] : [signature.receiver].compactMap { $0 })

        let missing = signature.parameters
            .filter { name, parameter in parameter.isRequired && !supplied.contains(name) }
            .keys
            .sorted()

        guard missing.isEmpty else {
            throw LinkError(
                "\(site.location): sending '\(dispatch.selector)' without"
                    + " \(missing.joined(separator: ", ")), which it requires"
            )
        }

        // An argument that needs a scope cannot be judged here — only the ones
        // that already are what they will be. `taking` rather than `checking`,
        // so a constant passes exactly the gate the run would apply to it.
        for (name, argument) in dispatch.arguments.sorted(by: { left, right in left.key < right.key }) {
            guard
                let parameter = signature.parameters[name],
                let constant = argument.constantValue
            else {
                continue
            }

            do {
                _ = try parameter.taking(constant, called: name, in: types)
            } catch {
                throw LinkError("\(site.location): sending '\(dispatch.selector)' — \(error)")
            }
        }

        // A word may judge its own constant arguments before any run — a type
        // cannot say that a regex pattern compiles, and the word can. It happens
        // here rather than while decoding, because a notation judging arguments
        // would have to know the vocabulary; judging belongs where names resolve.
        if case let .query(query) = callee.implementation {
            let constants = dispatch.arguments.compactMapValues(\.constantValue)

            do {
                try query.validate(constants)
            } catch {
                throw LinkError("\(site.location): sending '\(dispatch.selector)' — \(error)")
            }
        }

        // What an argument holds is read from the body it was written in, so a
        // name bound to a call carries that call's declared answer. This is what
        // makes declaring an answer worth anything before a run: both sides are
        // declarations, and a declaration is text.
        for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
            guard let parameter = signature.parameters[name] else { continue }

            let written = type(of: argument, in: site.environment, with: frame)

            guard !parameter.declared.accepts(written, in: types) else { continue }

            throw LinkError(
                "\(site.location): sending '\(dispatch.selector)' with \(name),"
                    + " which holds \(written) where \(parameter.declared) is declared"
            )
        }

        // The receiver is written on the other side of the dot and checked the
        // same way.
        if
            let receiver = dispatch.receiver,
            let name = signature.receiver,
            let parameter = signature.parameters[name]
        {
            let written = type(of: receiver, in: site.environment, with: frame)

            guard parameter.declared.accepts(written, in: types) else {
                throw LinkError(
                    "\(site.location): sending '\(dispatch.selector)' to \(written),"
                        + " where \(parameter.declared) is declared"
                )
            }
        }
    }

}
