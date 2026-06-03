// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreScopeTests {

    @Test func scope_childStoreReflectsChildSliceOfParentState() {
        let store = Store<AppReducer>(state: .init(counter: .init(count: 10)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)

        #expect(childStore.count == 10)
    }

    @Test func scopedApply_mutatesCorrespondingSliceInParent() {
        let store = Store<AppReducer>(state: .init())
        let childStore: Store<CounterReducer> = store.scope(\.counter)

        childStore.apply { feature, state in feature.set(count: 55, in: &state) }

        #expect(store.counter.count == 55)
    }

    @Test func scopedApply_withEventReturningNil_updatesStateButDoesNotCallOnEvent() {
        let store = Store<AppReducer>(state: .init())
        var onEventCallCount = 0

        let childStore: Store<LabelReducer> = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { _, _, _ in onEventCallCount += 1; return nil }
        )

        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "no event", in: &state)
            return nil
        }

        #expect(store.label.label == "no event")
        #expect(onEventCallCount == 0)
    }

    @Test func scopedApply_withEventReturningValue_callsOnEventWithCorrectEvent() {
        let store = Store<AppReducer>(state: .init())
        var receivedEvent: LabelReducer.Event?

        let childStore: Store<LabelReducer> = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { event, _, _ in receivedEvent = event; return nil }
        )

        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "with event", in: &state)
            return .labelChanged("with event")
        }

        #expect(store.label.label == "with event")
        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "with event")
    }

    @Test func scopedApply_onEventCanMutateParentState() {
        let store = Store<AppReducer>(state: .init())

        let childStore: Store<LabelReducer> = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { event, feature, parentState in
                if case .labelChanged(let value) = event {
                    feature.set(extra: "received: \(value)", in: &parentState)
                }
                return nil
            }
        )

        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "ping", in: &state)
            return .labelChanged("ping")
        }

        #expect(store.extra == "received: ping")
    }

    @Test func scopedApplyMixed_onEventFiresOnlyForNonNilReturns() {
        let store = Store<AppReducer>(state: .init())
        var onEventCallCount = 0

        let childStore: Store<LabelReducer> = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { _, _, _ in onEventCallCount += 1; return nil }
        )

        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "first", in: &state)
            return nil
        }
        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "second", in: &state)
            return .labelChanged("second")
        }

        #expect(onEventCallCount == 1)
    }

    @Test func scope_cachingReturnsSameInstanceForSameKeyPath() {
        let store = Store<AppReducer>(state: .init())
        let childStore1: Store<CounterReducer> = store.scope(\.counter)
        let childStore2: Store<CounterReducer> = store.scope(\.counter)

        #expect(childStore1 === childStore2)
    }

    @Test func scope_neverEventVariant_worksWithoutEventHandling() {
        let store = Store<AppReducer>(state: .init())
        let childStore: Store<CounterReducer> = store.scope(\.counter, feature: { CounterReducer() })

        childStore.apply { feature, state in feature.set(count: 20, in: &state) }

        #expect(store.counter.count == 20)
    }

    @Test func scope_emptyInitializingVariant_createsChildWithDefaultFeature() {
        let store = Store<AppReducer>(state: .init(counter: .init(count: 3)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)

        #expect(childStore.count == 3)
    }

    @Test func parentStateChange_outsideChildSlice_doesNotAffectChildCount() {
        let store = Store<AppReducer>(state: .init(counter: .init(count: 5)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)

        store.apply { feature, state in feature.set(extra: "irrelevant", in: &state) }

        #expect(childStore.count == 5)
    }

    @Test func parentDirectMutation_isImmediatelyReflectedInChildStore() {
        let store = Store<AppReducer>(state: .init(counter: .init(count: 0)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)

        store.apply { _, state in state.counter.count = 42; return nil }

        #expect(childStore.count == 42)
    }
}
