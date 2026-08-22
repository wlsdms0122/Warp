//
//  ModuleReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A document, which is a module and not a procedure: metadata, and the procedures
// it declares.
//
// There is no top level to run. A body written at the root would make every
// document an entry point and leave no way to write one that only declares.
// Procedures are named here and which one runs is said at link time, so a
// document that declares three of them is ordinary rather than a special case.
public struct ModuleReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case warp
        case needs
        case name
        case description
        case types
        case const
        case procedures
    }

    // MARK: - Property
    public let module: Module

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The version first, and through its own container, because everything
        // after it is read by rules a newer document may not be written to —
        // including which keys exist. A later version adding a key would
        // otherwise be turned away as malformed, and a reader has to tell "I am
        // too old for this" (upgrade me) from "this is wrong" (fix the sender).
        try Self.check(
            version: try decoder
                .container(keyedBy: AnyCodingKey.self)
                .decodeIfPresent(Int.self, forKey: AnyCodingKey(stringValue: Envelope.versionKey)),
            at: decoder.codingPath
        )

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "module"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)

        let procedures = try container.decode([String: ProcedureReader].self, forKey: .procedures)

        guard !procedures.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "a module that declares nothing can never be"
                        + " linked into anything — write at least one procedure"
                )
            )
        }

        let module = Module(
            name: try container.decodeIfPresent(String.self, forKey: .name),
            description: try container.decodeIfPresent(String.self, forKey: .description),
            types: try container
                .decodeIfPresent([String: TypeReader].self, forKey: .types)?
                .mapValues(\.type) ?? [:],
            constants: try container
                .decodeIfPresent([String: ExpressionReader].self, forKey: .const)?
                .mapValues(\.expression) ?? [:],
            procedures: procedures.mapValues(\.procedure)
        )

        // A document that lists what it needs is held to the list. A caller
        // reads it to decide whether to run the program at all, so a list that
        // was allowed to drift would be worse than none — it would be trusted
        // and wrong.
        if let claimed = try container.decodeIfPresent([String].self, forKey: .needs) {
            let sent = Envelope.needs(of: module)

            guard Set(claimed) == sent else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "this document says it needs"
                            + " \(claimed.sorted()) and sends \(sent.sorted())"
                    )
                )
            }
        }

        self.module = module
    }

    // MARK: - Public
    // MARK: - Private
    // A document says nothing and is read as the earliest, which is what lets one
    // written before the field existed still be read. Anything outside the range
    // this reader knows is refused rather than guessed at — below it, the
    // document is claiming a language that never existed.
    private static func check(version: Int?, at codingPath: [any CodingKey]) throws {
        let version = version ?? Envelope.earliest

        guard (Envelope.earliest ... Envelope.version).contains(version) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "this document is written for warp \(version),"
                        + " and this reads \(Envelope.earliest) through \(Envelope.version)"
                )
            )
        }
    }
}
