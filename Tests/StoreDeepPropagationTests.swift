// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreDeepPropagationTests {

    // MARK: - Helpers

    /// Builds a three-level store hierarchy:
    ///   rootStore (DeepRootReducer, Event == Never)
    ///     └── middleStore (MiddleReducer, Event: noteSet)
    ///           └── leafStore (LabelReducer, Event: labelChanged)
    ///
    /// - Parameters:
    ///   - leafOnEvent: Handles leaf events in the middle layer.
    ///   - middleOnEvent: Handles middle events in the root layer.
    private func makeStores(
        leafOnEvent: @escaping Store<MiddleReducer>.ChildEventHandler<LabelReducer>,
        middleOnEvent: @escaping Store<DeepRootReducer>.ChildEventHandler<MiddleReducer>
    ) -> (
        rootStore: Store<DeepRootReducer>,
        middleStore: Store<MiddleReducer>,
        leafStore: Store<LabelReducer>
    ) {
        let rootStore = Store<DeepRootReducer>(state: .init())
        let middleStore: Store<MiddleReducer> = rootStore.scope(\.middle, onEvent: middleOnEvent)
        let leafStore: Store<LabelReducer> = middleStore.scope(\.label, onEvent: leafOnEvent)
        return (rootStore, middleStore, leafStore)
    }

    // MARK: - Tests

    @Test func deepPropagation_leafEvent_reachesMiddleOnEventHandler() {
        var receivedLeafEvent: LabelReducer.Event?

        let (_, _, leafStore) = makeStores(
            leafOnEvent: { event, _, _ in
                receivedLeafEvent = event
                return nil
            },
            middleOnEvent: { _, _, _ in nil }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "hello", in: &state)
            return .labelChanged("hello")
        }

        guard case .labelChanged(let value) = receivedLeafEvent else {
            Issue.record("Expected leafOnEvent to be called with labelChanged")
            return
        }
        #expect(value == "hello")
    }

    @Test func deepPropagation_leafEvent_middleOnEventCanMutateMiddleState() {
        let (rootStore, _, leafStore) = makeStores(
            leafOnEvent: { event, middleFeature, middleState in
                if case .labelChanged(let value) = event {
                    middleFeature.setNote("noted: \(value)", in: &middleState)
                }
                return nil
            },
            middleOnEvent: { _, _, _ in nil }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "ping", in: &state)
            return .labelChanged("ping")
        }

        #expect(rootStore.middle.note == "noted: ping")
    }

    @Test func deepPropagation_leafEvent_middleOnEventReturningEvent_reachesRootOnEventHandler() {
        var receivedMiddleEvent: MiddleReducer.Event?

        let (_, _, leafStore) = makeStores(
            leafOnEvent: { event, _, _ in
                if case .labelChanged(let value) = event {
                    return .noteSet(value)
                }
                return nil
            },
            middleOnEvent: { event, _, _ in
                receivedMiddleEvent = event
                return nil
            }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "propagate", in: &state)
            return .labelChanged("propagate")
        }

        guard case .noteSet(let value) = receivedMiddleEvent else {
            Issue.record("Expected middleOnEvent to be called with noteSet")
            return
        }
        #expect(value == "propagate")
    }

    @Test func deepPropagation_leafEvent_fullChain_rootStateUpdated() {
        let (rootStore, _, leafStore) = makeStores(
            leafOnEvent: { event, middleFeature, middleState in
                if case .labelChanged(let value) = event {
                    middleFeature.setNote("mid:\(value)", in: &middleState)
                    return .noteSet(value)
                }
                return nil
            },
            middleOnEvent: { event, rootFeature, rootState in
                if case .noteSet(let value) = event {
                    rootFeature.appendLog("root:\(value)", to: &rootState)
                }
                return nil
            }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "deep", in: &state)
            return .labelChanged("deep")
        }

        #expect(rootStore.middle.label.label == "deep")
        #expect(rootStore.middle.note == "mid:deep")
        #expect(rootStore.log == "root:deep")
    }

    @Test func deepPropagation_middleOnEventReturningNil_doesNotCallRootHandler() {
        var rootOnEventCallCount = 0

        let (_, _, leafStore) = makeStores(
            leafOnEvent: { _, _, _ in return .noteSet("ignored") },
            middleOnEvent: { _, _, _ in
                rootOnEventCallCount += 1
                return nil
            }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "x", in: &state)
            return nil
        }

        #expect(rootOnEventCallCount == 0)
    }

    @Test func deepPropagation_leafOnEventReturningNil_stopsAtMiddle() {
        var middleOnEventCallCount = 0

        let (_, _, leafStore) = makeStores(
            leafOnEvent: { _, _, _ in return nil },
            middleOnEvent: { _, _, _ in
                middleOnEventCallCount += 1
                return nil
            }
        )

        leafStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "no-propagate", in: &state)
            return .labelChanged("no-propagate")
        }

        #expect(middleOnEventCallCount == 0)
    }

    @Test func deepPropagation_leafStateMutation_visibleAtAllLevels() {
        let (rootStore, middleStore, leafStore) = makeStores(
            leafOnEvent: { _, _, _ in nil },
            middleOnEvent: { _, _, _ in nil }
        )

        leafStore.apply { feature, state in feature.set(label: "visible", in: &state) }

        #expect(leafStore.label == "visible")
        #expect(middleStore.label.label == "visible")
        #expect(rootStore.middle.label.label == "visible")
    }

    @Test func deepPropagation_rootMutation_visibleAtAllLevels() {
        let (rootStore, middleStore, leafStore) = makeStores(
            leafOnEvent: { _, _, _ in nil },
            middleOnEvent: { _, _, _ in nil }
        )

        rootStore.apply { feature, state in feature.appendLog("top-down", to: &state) }

        #expect(rootStore.log == "top-down")
        #expect(middleStore.note == "")
        #expect(leafStore.label == "")
    }

    @Test func deepPropagation_multipleLeafEvents_allPropagateThroughChain() {
        let (_, _, leafStore) = makeStores(
            leafOnEvent: { event, _, _ in
                if case .labelChanged(let value) = event {
                    return .noteSet(value)
                }
                return nil
            },
            middleOnEvent: { event, _, rootState in
                if case .noteSet(let value) = event {
                    rootState.log += value + ","
                }
                return nil
            }
        )

        for label in ["a", "b", "c"] {
            leafStore.apply { feature, state -> LabelReducer.Event? in
                feature.set(label: label, in: &state)
                return .labelChanged(label)
            }
        }

        #expect(leafStore.label == "c")
    }
}
