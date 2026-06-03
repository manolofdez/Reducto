// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import SwiftUI

extension Store {
    /// Creates a SwiftUI `Binding` that reads from state and routes writes through the feature.
    public func binding<Value>(
        _ keyPath: KeyPath<StoreFeature.State, Value>,
        reducing reduce: @escaping (StoreFeature, inout StoreFeature.State, Value) -> StoreFeature.Event?
    ) -> Binding<Value> {
        .init(
            get: {
                self[dynamicMember: keyPath]
            },
            set: { value in
                self.apply {
                    return reduce($0, &$1, value)
                }
            }
        )
    }

    /// Creates a SwiftUI `Binding` that reads from state and routes writes through the feature, without returning an event.
    public func binding<Value>(
        _ keyPath: KeyPath<StoreFeature.State, Value>,
        reducing reduce: @escaping (StoreFeature, inout StoreFeature.State, Value) -> Void
    ) -> Binding<Value> {
        binding(keyPath) { feature, state, value in
            reduce(feature, &state, value)
            return nil
        }
    }
}
