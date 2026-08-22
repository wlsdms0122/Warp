//
//  SignatureReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

public struct SignatureReader: Decodable {
    // MARK: - Property
    public let signature: Signature

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.signature = Signature(
            parameters: try decoder.singleValueContainer()
                .decode([String: ParameterReader].self)
                .mapValues(\.parameter)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
