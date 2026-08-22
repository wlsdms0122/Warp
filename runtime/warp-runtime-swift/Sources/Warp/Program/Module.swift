//
//  Module.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What one document declares, and nothing about running.
//
// A module is not a procedure and cannot be run. It becomes runnable only when a
// linker is handed it together with the others and told which name to start
// from. Which declaration that is stays an argument to linking rather than a
// property one of them carries, so there is no marking to put on a declaration
// and no reserved name.
public struct Module: Sendable {
    // MARK: - Property
    // Metadata only. A module's identity is whatever the caller resolved it by —
    // usually a file — and the language never derives meaning from this.
    public let name: String?
    public let description: String?

    // Shapes this module declares. A type is a name bound to a
    // `TypeExpression`, which is the same thing a procedure is with a body in
    // place of a type — a module declares, and what it declares differs only in
    // what kind of thing the name stands for.
    public let types: [String: TypeExpression]

    // Names bound to values, settled at link and gone by run time. Private to
    // the module: a constant is read by writing its name, and a name is a scope
    // question, so exporting one would need a second namespace in path position
    // — where a qualified spelling cannot be told from drilling into a record.
    public let constants: [String: Expression]

    public let procedures: [String: Procedure]

    // MARK: - Initializer
    public init(
        name: String? = nil,
        description: String? = nil,
        types: [String: TypeExpression] = [:],
        constants: [String: Expression] = [:],
        procedures: [String: Procedure]
    ) {
        self.name = name
        self.description = description
        self.types = types
        self.constants = constants
        self.procedures = procedures
    }

    // MARK: - Public
    // MARK: - Private
}
