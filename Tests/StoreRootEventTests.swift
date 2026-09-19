// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Reducto

@MainActor
struct StoreRootEventTests {

    @Test func rootApply_returningEvent_callsOnEventWithCorrectEvent() {
        var receivedEvent: LabelReducer.Event?
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { event, _, _ in receivedEvent = event }
        )

        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "hello", in: &state)
            return .labelChanged("hello")
        }

        #expect(store.label == "hello")
        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "hello")
    }

    @Test func rootOnEvent_canMutateStateInSameTransaction() {
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { event, feature, state in
                guard case .labelChanged(let value) = event else { return }
                feature.set(label: value.uppercased(), in: &state)
            }
        )

        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "hello", in: &state)
            return .labelChanged("hello")
        }

        #expect(store.label == "HELLO")
    }

    @Test func rootOnEvent_mutatingState_publishesOnlyOnce() async {
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { event, feature, state in
                guard case .labelChanged(let value) = event else { return }
                feature.set(label: value.uppercased(), in: &state)
            }
        )
        var received: [String] = []

        let cancellable = store.publisher(for: \.label).sink { received.append($0) }
        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "hello", in: &state)
            return .labelChanged("hello")
        }
        await Task.yield()

        #expect(received == ["", "HELLO"])
        _ = cancellable
    }

    @Test func rootApply_returningNilEvent_stillMutatesStateButDoesNotCallOnEvent() {
        var onEventCallCount = 0
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { _, _, _ in onEventCallCount += 1 }
        )

        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "no event", in: &state)
            return nil
        }

        #expect(store.label == "no event")
        #expect(onEventCallCount == 0)
    }

    @Test func rootVoidApply_doesNotCallOnEvent() {
        var onEventCallCount = 0
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { _, _, _ in onEventCallCount += 1 }
        )

        store.apply { feature, state in
            feature.set(label: "void", in: &state)
        }

        #expect(store.label == "void")
        #expect(onEventCallCount == 0)
    }

    @Test func trailingClosureInit_resolvesToOnEventOverload() {
        var receivedEvent: LabelReducer.Event?
        let store = Store<LabelReducer>(state: .init()) { event, _, _ in
            receivedEvent = event
        }

        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "trailing", in: &state)
            return .labelChanged("trailing")
        }

        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "trailing")
    }

    @Test func initWithExplicitFeatureAndOnEvent_setsInitialStateAndHandlesEvents() {
        var receivedEvent: LabelReducer.Event?
        let store = Store<LabelReducer>(
            state: .init(label: "initial"),
            feature: { LabelReducer() },
            onEvent: { event, _, _ in receivedEvent = event }
        )

        #expect(store.label == "initial")

        store.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "changed", in: &state)
            return .labelChanged("changed")
        }

        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "changed")
    }

    @Test func childEvent_bubblesToEventHandlingRoot() {
        var rootReceivedEvent: MiddleReducer.Event?
        let rootStore = Store<MiddleReducer>(
            state: .init(),
            onEvent: { event, feature, state in
                rootReceivedEvent = event
                guard case .noteSet(let value) = event else { return }
                feature.setNote("root:\(value)", in: &state)
            }
        )

        let childStore: Store<LabelReducer> = rootStore.scope(
            \.label,
            onEvent: { event, _, _ -> MiddleReducer.Event? in
                guard case .labelChanged(let value) = event else { return nil }
                return .noteSet(value)
            }
        )

        childStore.apply { feature, state -> LabelReducer.Event? in
            feature.set(label: "bubbled", in: &state)
            return .labelChanged("bubbled")
        }

        #expect(childStore.label == "bubbled")
        #expect(rootStore.label.label == "bubbled")
        #expect(rootStore.note == "root:bubbled")
        guard case .noteSet(let value) = rootReceivedEvent else {
            Issue.record("Expected noteSet event")
            return
        }
        #expect(value == "bubbled")
    }

    @Test func taskRun_onEventHandlingRoot_propagatesEventToOnEvent() async {
        var receivedEvent: LabelReducer.Event?
        let store = Store<LabelReducer>(
            state: .init(),
            onEvent: { event, feature, state in
                receivedEvent = event
                guard case .labelChanged(let value) = event else { return }
                feature.set(label: value.uppercased(), in: &state)
            }
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.task { feature, taskManager in
                taskManager.run { apply in
                    apply { state in
                        feature.set(label: "async", in: &state)
                        return .labelChanged("async")
                    }
                    continuation.resume()
                }
            }
        }

        #expect(store.label == "ASYNC")
        guard case .labelChanged(let value) = receivedEvent else {
            Issue.record("Expected labelChanged event")
            return
        }
        #expect(value == "async")
    }
}
