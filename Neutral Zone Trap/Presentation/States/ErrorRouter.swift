//
//  ErrorRouter.swift
//  Neutral Zone Trap
//

import Foundation

@Observable
final class ErrorRouter {
    var error: (any Error)?

    func report(_ error: any Error) {
        self.error = error
    }

    func dismiss() {
        error = nil
    }
}
