// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreTests {

    @Test func initWithStateAndFeature_setsInitialState() {
        let store = Store(state: CounterReducer.State(count: 5), feature: { CounterReducer() })

        #expect(store.count == 5)
    }

    @Test func initWithEmptyInitializingFeature_setsInitialState() {
        let store = Store<CounterReducer>(state: .init(count: 7))

        #expect(store.count == 7)
    }

    @Test func dynamicMemberLookup_readsCorrectField() {
        let store = Store(state: AppState(extra: "hello"), feature: { AppReducer() })

        #expect(store.extra == "hello")
    }

    @Test func applyVoidEvent_mutatesState() {
        let store = Store<CounterReducer>(state: .init(count: 0))

        store.apply { feature, state in
            feature.set(count: 42, in: &state)
        }

        #expect(store.count == 42)
    }

    @Test func apply_writesComputedValueToState() {
        let store = Store<CounterReducer>(state: .init(count: 5))

        store.apply { feature, state in
            feature.add(10, to: &state)
        }

        #expect(store.count == 15)
    }

    @Test func apply_passesFeatureAndState() {
        var receivedCount = -1
        let store = Store<CounterReducer>(state: .init(count: 7))

        store.apply { _, state in
            receivedCount = state.count
        }

        #expect(receivedCount == 7)
    }

    @Test func multipleApplies_accumulateCorrectly() {
        let store = Store<CounterReducer>(state: .init(count: 0))

        store.apply { feature, state in feature.increment(&state) }
        store.apply { feature, state in feature.increment(&state) }
        store.apply { feature, state in feature.increment(&state) }

        #expect(store.count == 3)
    }

    @Test func applyReturningNilEvent_stillMutatesState() {
        let store = Store<CounterReducer>(state: .init(count: 0))

        store.apply { feature, state -> CounterReducer.Event? in
            feature.set(count: 42, in: &state)
            return nil
        }

        #expect(store.count == 42)
    }
}
