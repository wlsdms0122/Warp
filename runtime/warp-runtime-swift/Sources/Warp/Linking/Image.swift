//
//  Image.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure together with every procedure it can reach, resolved. Only `Linker`
// makes one, so holding a value of this type is the evidence that linking
// happened — the executor takes an image rather than a procedure so that "ran
// without linking" has no spelling.
public struct Image: Sendable {
    // MARK: - Property
    public let entry: Procedure

    // Keyed by the name the call site used, which is what the executor looks a
    // callee up by. Transitive: a procedure reached only through another procedure
    // is in here too.
    public let procedures: [String: Procedure]

    // Every shape the linked modules declared. A named type survives into the
    // run rather than being expanded at link, so the run needs the table that
    // answers it.
    public let types: TypeTable

    // Which of them answer without running. Computed here rather than declared,
    // because for a body it is a fact about what it calls — and a fact the
    // whole call graph has to be walked to know.
    public let pure: Set<String>

    // What a path segment may reach, by the bare name a path writes. `x.count`
    // names no module, so this is resolved by the run rather than by the link —
    // and the link is where an ambiguity between two such names is refused.
    public let derivations: [String: Procedure]

    // MARK: - Initializer
    init(
        entry: Procedure,
        procedures: [String: Procedure],
        types: TypeTable,
        pure: Set<String>,
        derivations: [String: Procedure]
    ) {
        self.entry = entry
        self.procedures = procedures
        self.types = types
        self.pure = pure
        self.derivations = derivations
    }

    // MARK: - Public
    // MARK: - Private
}
