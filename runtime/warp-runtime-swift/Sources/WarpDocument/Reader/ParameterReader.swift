//
//  ParameterReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A parameter, written either as a bare type name or as a record. The shorthand
// is the notation's convenience — the IR has one shape.
public struct ParameterReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case oneOf
        case `default`
        case hint
    }

    // MARK: - Property
    public let parameter: Parameter

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // The shorthand: a bare type where a parameter is wanted. Anything a
        // type can be spelled as works here, so `array<string>` is as short as
        // `string` is.
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            do {
                self.parameter = Parameter(type: try TypeReader.parse(single))
            } catch let error as TypeFormError {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: error.message)
                )
            }

            return
        }

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            context: "input param"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Omitting `type:` declares nothing, which is not the same as declaring
        // `any`. Both take whatever arrives; only one of them says so.
        let type = try container.decodeIfPresent(TypeReader.self, forKey: .type)?.type

        // The default is stored as written. Whether the parameter itself admits
        // it is a declaration fact judged at the link — the one place a default
        // written against a declared type name could be judged at all — and a
        // default-supplied slot reads the declared representation because taking
        // one settles it, the same gate a caller's value walks.
        self.parameter = Parameter(
            type: type,
            oneOf: try container.decodeIfPresent([String].self, forKey: .oneOf),
            default: container.contains(.default)
                ? try container.decode(ValueReader.self, forKey: .default).value
                : nil,
            hint: try container.decodeIfPresent(String.self, forKey: .hint)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
