//
//  ProcedureReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

public struct ProcedureReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case description
        case parameters
        case receiver
        case returns
        case body
        case result
    }

    // MARK: - Property
    public let procedure: Procedure

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "procedure"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // A procedure has no name of its own — it is named by the key its module
        // declares it under.
        self.procedure = Procedure(
            description: try container.decodeIfPresent(String.self, forKey: .description),
            // Absent `parameters:` means an empty signature, not an absent
            // contract. `parameters:`, `receiver:` and `returns:` are one
            // signature — what a call may pass, which of those it is sent to,
            // and what comes back.
            signature: Signature(
                receiver: try container.decodeIfPresent(String.self, forKey: .receiver),
                parameters: try container
                    .decodeIfPresent(SignatureReader.self, forKey: .parameters)?
                    .signature.parameters ?? [:],
                returns: try container
                    .decodeIfPresent(TypeReader.self, forKey: .returns)?
                    .type
            ),
            // A procedure that only returns a value has nothing to do first, so
            // `body:` is what a procedure writes when it has statements rather
            // than something every procedure must write.
            body: try container
                .decodeIfPresent([StatementReader].self, forKey: .body)?
                .map(\.statement) ?? [],
            // One expression, because a procedure answers one value. Several
            // named answers are one record, which is a thing an author writes
            // rather than a shape this reader assembles. A document that
            // declares none answers with nothing, as a block does.
            result: try container
                .decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
    }

    // MARK: - Public
    // MARK: - Private
}
