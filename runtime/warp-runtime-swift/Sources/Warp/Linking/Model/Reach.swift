//
//  Reach.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// What walking a path through types found. Reading it answers a shape; the walk
// refuses only where it read one and the shape had no room for the segment —
// what it could not read is `any`, and `any` is not a mistake anyone can act on.
enum Reach: Sendable {
    case reads(TypeExpression)
    case refused(String)
}
