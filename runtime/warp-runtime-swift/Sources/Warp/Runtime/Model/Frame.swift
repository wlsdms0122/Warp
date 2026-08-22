//
//  Frame.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// One hop of how a run reached where it is.
//
// Four kinds, because there are four ways a run goes somewhere it can come back
// from. Two of them exist only at run time — which round a loop is on, and
// which piece of the work a concurrent word gave this closure call is — neither
// readable from the text, and they are the difference between naming a
// statement and naming an occurrence of one.
public enum Frame: Sendable, Equatable {
    case procedure(String)
    case statement(String)
    case round(Int)
    case piece(String)
}
