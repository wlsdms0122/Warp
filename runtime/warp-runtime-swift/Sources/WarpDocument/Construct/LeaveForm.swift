//
//  LeaveForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// `return:`, `break:` and `continue:`.
//
// Three forms rather than one under three words, because the table maps a word
// to a form and reads back the same way. One form answering to three words could
// be written down but not written out — asked which word means it, the table
// would have three answers and no way to say which. Three forms also make each
// word droppable on its own, which one would not.
//
//     { id: done,   return: { ref: answer } }
//     { id: enough, break: }
//     { id: skip,   continue: outer }
public struct ReturnForm: ConstructForm {
    // MARK: - Property
    public static let key = "return"

    private let value: Expression?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let written = try ValueReader(from: decoder).value

        // Nothing written answers with nothing. A procedure always answers
        // something, so this is `null` rather than a procedure that does not.
        self.value = written == .null ? nil : try ExpressionReader.read(written, in: decoder)
    }

    // MARK: - Public
    // Nothing is bound: a statement names what its expression answered, and this
    // one does not answer.
    public func expression(boundTo id: String?) -> Expression {
        .leave(Leave(reach: .procedure, value: value))
    }

    // MARK: - Private
}

public struct BreakForm: ConstructForm {
    // MARK: - Property
    public static let key = "break"

    private let target: String?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.target = try Self.target(from: decoder, called: Self.key)
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .leave(Leave(reach: .construct, target: target))
    }

    // MARK: - Private
}

public struct ContinueForm: ConstructForm {
    // MARK: - Property
    public static let key = "continue"

    private let target: String?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.target = try BreakForm.target(from: decoder, called: Self.key)
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .leave(Leave(reach: .round, target: target))
    }

    // MARK: - Private
}

extension BreakForm {
    // Which loop, or nothing for the nearest. A loop answers what it was going
    // to answer, so there is nothing to carry and what stands here is a name.
    static func target(from decoder: Decoder, called word: String) throws -> String? {
        switch try ValueReader(from: decoder).value {
        case .null:
            return nil

        case let .string(name):
            return name

        case let other:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "\(word) takes the name of a loop, or nothing for the"
                        + " nearest one — got \(other.type)"
                )
            )
        }
    }
}
