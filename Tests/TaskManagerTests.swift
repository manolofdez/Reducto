// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation
import Testing
import Reducto

@MainActor
struct TaskManagerTests {

    // MARK: - Basic mutation

    @Test func run_appliesMutation_afterWorkCompletes() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in
                        feature.set(count: 99, in: &state)
                    }
                    continuation.resume()
                }
            }
        }

        #expect(store.count == 99)
    }

    @Test func run_neverCallingMutationCallback_leavesStateUnchanged() async {
        let store = Store<CounterReducer>(state: .init(count: 3))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { _, taskManager in
                taskManager.run { (_: @escaping ((inout CounterReducer.State) -> Void) -> Void) in
                    continuation.resume()
                }
            }
        }

        #expect(store.count == 3)
    }

    // MARK: - Multiple mutations

    @Test func run_appliesMultipleMutations_eachSeeingThePriorOnesEffect() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in feature.set(count: 10, in: &state) }
                    apply { state in feature.add(5, to: &state) }
                    apply { state in feature.add(1, to: &state) }
                    continuation.resume()
                }
            }
        }

        #expect(store.count == 16)
    }

    // MARK: - State visibility

    @Test func run_readingStateAfterApply_reflectsTheMutationImmediately() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        var countBeforeApply: Int?
        var countAfterApply: Int?

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    countBeforeApply = taskManager.state.count
                    apply { state in feature.set(count: 42, in: &state) }
                    countAfterApply = taskManager.state.count
                    continuation.resume()
                }
            }
        }

        #expect(countBeforeApply == 0)
        #expect(countAfterApply == 42)
    }

    @Test func run_multipleApplies_eachStateReadSeesThePriorApplysEffectImmediately() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        var snapshots: [Int] = []

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in feature.set(count: 10, in: &state) }
                    snapshots.append(taskManager.state.count)

                    apply { state in feature.add(5, to: &state) }
                    snapshots.append(taskManager.state.count)

                    continuation.resume()
                }
            }
        }

        #expect(snapshots == [10, 15])
    }

    // MARK: - Post-completion safety

    @Test func run_callingMutationCallbackAfterWorkReturns_isSilentlyIgnored() async {
        let store = Store<CounterReducer>(state: .init(count: 1))
        var capturedApply: (((inout CounterReducer.State) -> Void) -> Void)?

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { _, taskManager in
                taskManager.run { apply in
                    capturedApply = apply
                    continuation.resume()
                }
            }
        }

        capturedApply?({ state in
            state.count = 999
        })

        #expect(store.count == 1)
    }

    // MARK: - Cancellation

    @Test func taskManagerCancelAll_cancelsInFlightTask_beforeItAppliesItsMutation() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in feature.set(count: 42, in: &state) }
                    continuation.resume()
                }

                taskManager.cancelAll()
            }
        }

        #expect(store.count == 0)
    }

    @Test func taskManagerCancel_cancelsOnlyTheMatchingTask() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let idToCancel = UUID()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run(id: idToCancel) { apply in
                    apply { state in feature.set(count: 1, in: &state) }
                    continuation.resume()
                }

                taskManager.cancel(taskID: idToCancel)
            }
        }
        #expect(store.count == 0)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in feature.add(10, to: &state) }
                    continuation.resume()
                }
            }
        }
        #expect(store.count == 10)
    }

    @Test func run_reusingSameID_cancelsThePreviouslyRegisteredTask() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let sharedID = UUID()

        var firstRanToCompletion: Bool?
        var secondRanToCompletion: Bool?

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            func resumeWhenBothAreDone() {
                guard firstRanToCompletion != nil, secondRanToCompletion != nil else { return }
                continuation.resume()
            }

            store.task { feature, taskManager in
                taskManager.run(id: sharedID) { apply in
                    apply { state in feature.add(100, to: &state) }
                    firstRanToCompletion = !Task.isCancelled
                    resumeWhenBothAreDone()
                }

                taskManager.run(id: sharedID) { apply in
                    apply { state in feature.set(count: 2, in: &state) }
                    secondRanToCompletion = true
                    resumeWhenBothAreDone()
                }
            }
        }

        #expect(firstRanToCompletion == false)
        #expect(secondRanToCompletion == true)
        #expect(store.count == 2)
    }

    @Test func taskManagerCancelAll_duringReduceSuspension_stillDropsTheMutationOnResume() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        final class ContinuationBox: @unchecked Sendable {
            var continuation: CheckedContinuation<Void, Never>?
        }
        let suspensionBox = ContinuationBox()

        await withCheckedContinuation { (outer: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    // Stands in for real in-flight async work (e.g. a network call): genuinely
                    // suspended, not just "cancelled before this task ever ran".
                    await withCheckedContinuation { (inner: CheckedContinuation<Void, Never>) in
                        suspensionBox.continuation = inner
                    }

                    // Resumes after cancellation below — deliberately not checking Task.isCancelled,
                    // to prove the *framework* is what drops this, not caller cooperation.
                    apply { state in feature.set(count: 42, in: &state) }
                    outer.resume()
                }

                Task { @MainActor in
                    while suspensionBox.continuation == nil {
                        await Task.yield()
                    }
                    taskManager.cancelAll()
                    suspensionBox.continuation?.resume()
                }
            }
        }

        #expect(store.count == 0)
    }

    @Test func run_reusingSameID_endsThePreviousReducesStreamLoop_andDropsItsMutation() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        let sharedID = UUID()
        let (stream, _) = AsyncStream<Void>.makeStream() // deliberately never yielded/finished

        var firstLoopEnded: Bool?
        var secondRan: Bool?

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            func resumeWhenBothAreDone() {
                guard firstLoopEnded != nil, secondRan != nil else { return }
                continuation.resume()
            }

            store.task { feature, taskManager in
                taskManager.run(id: sharedID) { apply in
                    for await _ in stream {}
                    firstLoopEnded = true
                    apply { state in feature.add(100, to: &state) }
                    resumeWhenBothAreDone()
                }

                taskManager.run(id: sharedID) { apply in
                    apply { state in feature.set(count: 2, in: &state) }
                    secondRan = true
                    resumeWhenBothAreDone()
                }
            }
        }

        #expect(firstLoopEnded == true)
        #expect(store.count == 2)
    }

    // MARK: - Convenience overload (Event == Never)

    @Test func run_forNeverEventFeature_mutatesStateWithoutReturningAnEvent() async {
        let store = Store<CounterReducer>(state: .init(count: 0))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { applyChange in
                    applyChange { state in feature.set(count: 7, in: &state) }
                    continuation.resume()
                }
            }
        }

        #expect(store.count == 7)
    }

    // MARK: - Event propagation

    @Test func run_onScopedChildFeature_propagatesReturnedEventToParent() async {
        let store = Store<AppReducer>(state: .init())
        var receivedEvent: LabelReducer.Event?

        let childStore: Store<LabelReducer> = store.scope(
            \.label,
            feature: { LabelReducer() },
            onEvent: { event, feature, parentState in
                receivedEvent = event
                if case .labelChanged(let value) = event {
                    feature.set(extra: value, in: &parentState)
                }
                return nil
            }
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            childStore.withTaskManager { feature, taskManager in
                taskManager.run { apply in
                    apply { state in
                        feature.set(label: "async", in: &state)
                        return .labelChanged("async")
                    }
                    continuation.resume()
                }
            }
        }

        #expect(childStore.label == "async")
        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "async")
        #expect(store.extra == "async")
    }
}
