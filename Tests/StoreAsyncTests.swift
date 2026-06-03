// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreAsyncTests {

    @Test func asyncApplyWithMutation_mutatesStateAfterTaskCompletes() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        let task = store.apply { feature, _ -> Store<CounterReducer>.DeferredStateMutation? in
            return { state in
                feature.set(count: 99, in: &state)
                return nil
            }
        }
        await task.value

        #expect(store.count == 99)
    }

    @Test func asyncApplyReturningNil_leavesStateUnchanged() async {
        let store = Store<CounterReducer>(state: .init(count: 5))

        let task = store.apply { _, _ -> Store<CounterReducer>.DeferredStateMutation? in
            return nil
        }
        await task.value

        #expect(store.count == 5)
    }

    @Test func asyncApplyVoidConvenience_completesWithoutMutation() async {
        let store = Store<CounterReducer>(state: .init(count: 3))

        let task = store.apply { _, _ async -> Void in }
        await task.value

        #expect(store.count == 3)
    }

    @Test func asyncApply_writesReturnedValueToState() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        let task = store.apply { feature, _ in
            return { state in
                feature.set(count: 77, in: &state)
                return nil
            }
        }
        await task.value

        #expect(store.count == 77)
    }

    @Test func asyncApply_snapshotsStateAtCallTime() async {
        let store = Store<CounterReducer>(state: .init(count: 1))

        let task = store.apply { feature, state in
            var snapshot = state
            feature.add(10, to: &snapshot)
            return { state in
                feature.set(count: snapshot.count, in: &state)
                return nil
            }
        }
        await task.value

        #expect(store.count == 11)
    }
}
