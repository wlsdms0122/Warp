//
//  Module+Standard.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

public extension Module {
    // A list rather than one module: these are separate bundles, and a caller
    // takes the ones its programs have use for.
    static let standard: [Module] = [.logic, .math, .text, .collection, .control, .concurrent]
}
