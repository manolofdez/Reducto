// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import SwiftUI
import Reducto

@MainActor
struct StoreBindingTests {

    @Test func binding_getReturnsCurrentStateValue() {
        let store = Store<CounterReducer>(state: .init(count: 13))
        let binding = store.binding(\.count) { feature, state, value -> CounterReducer.Event? in
            feature.set(count: value, in: &state)
            return nil
        }

        #expect(binding.wrappedValue == 13)
    }

    @Test func binding_setMutatesStateViaFeature() {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let binding = store.binding(\.count) { feature, state, value -> CounterReducer.Event? in
            feature.set(count: value, in: &state)
            return nil
        }

        binding.wrappedValue = 99

        #expect(store.count == 99)
    }

    @Test func binding_setWithNilEventReturn_stillMutatesState() {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let binding = store.binding(\.count) { feature, state, value -> CounterReducer.Event? in
            feature.set(count: value, in: &state)
            return nil
        }

        binding.wrappedValue = 77

        #expect(store.count == 77)
    }

    @Test func bindingVoid_getReturnsCurrentStateValue() {
        let store = Store<CounterReducer>(state: .init(count: 13))
        let binding = store.binding(\.count) { feature, state, value in
            feature.set(count: value, in: &state)
        }

        #expect(binding.wrappedValue == 13)
    }

    @Test func bindingVoid_setMutatesState() {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let binding = store.binding(\.count) { feature, state, value in
            feature.set(count: value, in: &state)
        }

        binding.wrappedValue = 42

        #expect(store.count == 42)
    }

    @Test func binding_getReflectsLatestState() {
        let store = Store<CounterReducer>(state: .init(count: 1))
        let binding = store.binding(\.count) { feature, state, value -> CounterReducer.Event? in
            feature.set(count: value, in: &state)
            return nil
        }

        store.apply { feature, state in feature.set(count: 50, in: &state) }

        #expect(binding.wrappedValue == 50)
    }
}
