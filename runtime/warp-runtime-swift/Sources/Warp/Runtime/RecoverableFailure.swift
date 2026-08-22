//
//  RecoverableFailure.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A failure of the work itself — the data wasn't there, the world didn't
// cooperate. `attempt` absorbs these; author mistakes (shape misuse, contract
// violations) deliberately do not carry the marker, so they surface instead.
//
// It lives beside the runtime because it is `attempt`'s half of a contract, not
// a taxonomy of errors: the executor is the only thing that reads it, and what
// declares it is whatever can fail while a body runs — three constructs here,
// and a caller's own words out beyond the package.
//
// While a rescue runs, the failure exists as a value: the executor binds
// `payload` under the failed statement's id, so a rescue body can read what went
// wrong through `<id>.message` and whatever else that failure carries. Every
// payload holds at least `type` and `message`; each error adds its own fields on
// top — the runtime owns the mechanism, the error owns the vocabulary.
public protocol RecoverableFailure: WarpError {
    var payload: Value { get }
}
