//
//  LinkError.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Deliberately not a `RecoverableFailure`. A call that names nothing, or calls
// with arguments the callee never declared, is an author mistake — absorbing it
// into a rescue path would hide the one class of defect linking exists to find.
public struct LinkError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
