// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreOptionalScopeTests {

    // MARK: - nil / non-nil return

    @Test func optionalScope_whenChildIsNil_returnsNil() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: nil))

        let childStore: Store<CounterReducer>? = store.scope(\.counter)

        #expect(childStore == nil)
    }

    @Test func optionalScope_whenChildIsNonNil_returnsStore() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 7)))

        let childStore: Store<CounterReducer>? = store.scope(\.counter)

        #expect(childStore != nil)
    }

    // MARK: - State reads

    @Test func optionalScope_childStoreReflectsChildSliceOfParentState() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 42)))

        let childStore: Store<CounterReducer> = store.scope(\.counter)!

        #expect(childStore.count == 42)
    }

    // MARK: - State writes

    @Test func optionalScope_mutatesCorrespondingSliceInParent() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 0)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)!

        childStore.apply { feature, state in feature.set(count: 99, in: &state) }

        #expect(store.counter?.count == 99)
    }

    // MARK: - Event propagation

    @Test func optionalScope_withEventReturningNil_doesNotCallOnEvent() {
        let store = Store<AppReducerWithOptional>(state: .init(label: .init()))
        var onEventCallCount = 0

        let childStore: Store<LabelReducer>? = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { _, _, _ in onEventCallCount += 1; return nil }
        )

        childStore!.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "no event", in: &state)
            return nil
        }

        #expect(store.label?.label == "no event")
        #expect(onEventCallCount == 0)
    }

    @Test func optionalScope_withEventReturningValue_callsOnEventWithCorrectEvent() {
        let store = Store<AppReducerWithOptional>(state: .init(label: .init()))
        var receivedEvent: LabelReducer.Event?

        let childStore: Store<LabelReducer>? = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { event, _, _ in receivedEvent = event; return nil }
        )

        childStore!.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "with event", in: &state)
            return .labelChanged("with event")
        }

        #expect(store.label?.label == "with event")
        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "with event")
    }

    @Test func optionalScope_onEventCanMutateParentState() {
        let store = Store<AppReducerWithOptional>(state: .init(label: .init()))

        let childStore: Store<LabelReducer>? = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { event, feature, parentState in
                if case .labelChanged(let value) = event {
                    feature.set(extra: "received: \(value)", in: &parentState)
                }
                return nil
            }
        )

        childStore!.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "ping", in: &state)
            return .labelChanged("ping")
        }

        #expect(store.extra == "received: ping")
    }

    // MARK: - Caching

    @Test func optionalScope_cachingReturnsSameInstanceForSameKeyPath() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 0)))
        let childStore1: Store<CounterReducer>? = store.scope(\.counter)
        let childStore2: Store<CounterReducer>? = store.scope(\.counter)

        #expect(childStore1 === childStore2)
    }

    @Test func optionalScope_nilClearsCache_thenNonNilCreatesFreshStore() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 5)))
        let firstStore: Store<CounterReducer> = store.scope(\.counter)!

        store.apply { _, state in state.counter = nil; return nil }
        let nilResult: Store<CounterReducer>? = store.scope(\.counter)
        #expect(nilResult == nil)

        store.apply { _, state in state.counter = .init(count: 77); return nil }
        let secondStore: Store<CounterReducer> = store.scope(\.counter)!

        #expect(firstStore !== secondStore)
        #expect(secondStore.count == 77)
    }

    // MARK: - Async apply

    @Test func optionalScope_asyncApply_mutatesStateAfterTaskCompletes() async {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 0)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)!

        let task = childStore.apply { feature, _ -> Store<CounterReducer>.DeferredStateMutation? in
            return { state in
                feature.set(count: 55, in: &state)
                return nil
            }
        }
        _ = await task.value

        #expect(store.counter?.count == 55)
    }

    @Test func optionalScope_asyncApply_dropsWritebackWhenOptionalBecomesNilAfterAwait() async {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 0)))
        let childStore: Store<CounterReducer> = store.scope(\.counter)!

        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let task = childStore.apply { _, _ -> Store<CounterReducer>.DeferredStateMutation? in
            for await _ in stream { break }
            return { state in
                state.count = 99
                return nil
            }
        }

        store.apply { _, state in state.counter = nil; return nil }

        continuation.finish()
        _ = await task.value

        #expect(store.counter == nil)
    }

    // MARK: - EmptyInitializing convenience

    @Test func optionalScope_emptyInitializingVariant_returnsNilWhenChildNil() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: nil))

        let childStore: Store<CounterReducer>? = store.scope(\.counter)

        #expect(childStore == nil)
    }

    @Test func optionalScope_emptyInitializingVariant_createsChildWithDefaultFeature() {
        let store = Store<AppReducerWithOptional>(state: .init(counter: .init(count: 11)))

        let childStore: Store<CounterReducer>? = store.scope(\.counter)

        #expect(childStore?.count == 11)
    }
}
