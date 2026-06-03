// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Testing
import Combine
import Reducto

@MainActor
struct StoreCombineTests {

    @Test func publisher_emitsCurrentValueImmediatelyOnSubscription() {
        let store = Store<CounterReducer>(state: .init(count: 42))
        var received: [Int] = []

        let cancellable = store.publisher(for: \.count).sink { received.append($0) }

        #expect(received == [42])
        _ = cancellable
    }

    @Test func publisher_emitsNewValueAfterStateMutation() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        var received: [Int] = []

        let cancellable = store.publisher(for: \.count).sink { received.append($0) }
        store.apply { _, state in state.count = 7 }
        await Task.yield()

        #expect(received == [0, 7])
        _ = cancellable
    }

    @Test func publisher_multipleSubscriptionsEachReceiveValues() async {
        let store = Store<CounterReducer>(state: .init(count: 0))
        var receivedA: [Int] = []
        var receivedB: [Int] = []

        let cancellableA = store.publisher(for: \.count).sink { receivedA.append($0) }
        let cancellableB = store.publisher(for: \.count).sink { receivedB.append($0) }
        store.apply { _, state in state.count = 5 }
        await Task.yield()

        #expect(receivedA == [0, 5])
        #expect(receivedB == [0, 5])
        _ = cancellableA
        _ = cancellableB
    }

    @Test func publisher_alwaysEmitsCorrectValueEvenAfterUnrelatedMutation() async {
        let store = Store<AppReducer>(state: .init(counter: .init(count: 5)))
        var lastReceived: Int?

        let cancellable = store.publisher(for: \.counter.count).sink { lastReceived = $0 }
        store.apply { _, state in state.extra = "unrelated" }
        await Task.yield()

        #expect(lastReceived == 5)
        _ = cancellable
    }
}
