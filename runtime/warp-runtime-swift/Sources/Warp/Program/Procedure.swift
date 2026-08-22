//
//  Procedure.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A declaration: what it is sent, what it answers with, and how it does that.
//
// It has no name of its own — a procedure's name is the key it is declared under
// in its `Module`, the same way a symbol's name is not stored inside the function
// it names. Which of them a run starts from is decided at link time, so every
// declaration is equally a procedure and none of them is the procedure.
//
// A signature and an implementation, and nothing else. The implementation is a
// body of statements or native code, and that axis is the only thing that used
// to separate this from a "library word" — which is why there is no library any
// more, and no second namespace, and no second lookup order.
public struct Procedure: Sendable {
    // MARK: - Property
    public let description: String?
    public let signature: Signature
    public let implementation: Implementation

    public var block: Block? { implementation.block }
    public var body: [Statement] { block?.body ?? [] }
    public var result: Expression? { block?.result }

    // MARK: - Initializer
    public init(
        description: String? = nil,
        signature: Signature = Signature(),
        implementation: Implementation
    ) {
        self.description = description
        self.signature = signature
        self.implementation = implementation
    }

    // A procedure written in the language. The common case, and the one a
    // document can spell.
    public init(
        description: String? = nil,
        signature: Signature = Signature(),
        body: [Statement],
        result: Expression? = nil
    ) {
        self.init(
            description: description,
            signature: signature,
            implementation: .body(Block(body: body, result: result))
        )
    }

    // MARK: - Public
    // MARK: - Private
}
