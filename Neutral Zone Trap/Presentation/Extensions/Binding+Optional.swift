//
//  Binding+Optional.swift
//  Neutral Zone Trap
//

import SwiftUI

extension Binding where Value == Bool {
    /// Binding je true když optional obsahuje hodnotu.
    /// Při nastavení na false se optional vymaže.
    static func presence<T>(of optional: Binding<T?>) -> Binding<Bool> {
        Binding<Bool>(
            get: { optional.wrappedValue != nil },
            set: { isPresent in
                if !isPresent {
                    optional.wrappedValue = nil
                }
            }
        )
    }
}
