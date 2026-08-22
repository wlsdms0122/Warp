//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every shape the modules in a link declared, and what each name
// stands for. The counterpart of `Library` on the other axis — that one holds
// the words a caller installed, this one the shapes a document declared.
//
// It exists because a named type is kept rather than expanded. Expanding at link
// would make a self-naming shape a regress, so the name survives into the run and
// something has to be able to answer it.
public struct TypeTable: Sendable {
    // MARK: - Property
    public private(set) var types: [String: TypeExpression]

    // MARK: - Initializer
    public init(types: [String: TypeExpression] = [:]) {
        self.types = types
    }

    // MARK: - Public
    public func resolve(_ name: String) -> TypeExpression? {
        types[name]
    }

    // MARK: - Private
}
