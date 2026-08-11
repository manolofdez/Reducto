# Reducto

A lightweight, closure-based, Redux-inspired state management library for Swift. Unidirectional data flow, explicit state mutations, parent-child composition. That's about it.

**What this library borrows from Redux:** a single store, an entity in charge of mutating your state, and one-way data flow from state to UI.

**What this library omits:** action enums, middleware, and typed effect management. These are deliberate trade-offs made to keep the library light and reduce boilerplate.

**What this library adds beyond Redux:** child-to-parent communication via Events. This keeps parent-child boundaries clean without needing a global action bus.

If you're looking for stronger guarantees, exhaustive testing tools, or navigation support, [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) covers all of that.

---

## Glossary

Before we go any further, let's make sure we're on the same page:

- **Feature** — a type that describes a feature. It defines a `State` shape and optionally an `Event` type. Think of it as the blueprint: it knows how to mutate state and what a feature can communicate to the outside world. It's also where you store dependencies.

- **State** — a value type (usually a `struct`) that represents the current snapshot of a feature. All UI is derived from state. All mutations go through the store.

- **Store** — the live, running instance of a feature. It holds the current `State`, owns a `Feature`, owns a `TaskManager`, and is the only thing that can mutate state. You read from it, `apply` into it, and pass it to views.

- **Event** — something a child feature wants to tell its parent. Events go *out* — up the tree. A child returns an `Event` from an `apply` closure; the parent handles it in the `onEvent` closure passed to `scope`.

- **Scope** — the mechanism for composing stores. A parent store produces a child `Store` focused on a sub-slice of the parent's state, via a keypath. The child reads from and writes to the parent automatically.

- **apply** — how you synchronously mutate state. You pass a closure to `store.apply`, which receives the feature and an `inout` reference to state.

- **TaskManager** — how you run async, multi-step work. Access one via `store.task { feature, taskManager in ... }`, then hand `taskManager.run` a closure; it receives a callback for applying mutations as your work completes — call it zero, one, or many times. It also owns cancellation for that work.

---

## Usage

### The Basics

Every feature is a `Feature` — a type that defines a `State` shape and knows how to mutate it.

```swift
struct CounterFeature: Feature, EmptyInitializing {
    struct State: Equatable {
        var count: Int = 0
        var label: String = "Tap me"
    }

    var labelService: LabelService
    
    init(labelService: LabelService = LiveLabelService()) {
        self.labelService = labelService
    }

    func increment(_ state: inout State) { 
    	state.count += 1 
    }

    func set(label: String, in state: inout State) {
        state.label = label
    }

    func fetchLabel() async -> String {
        await labelService.fetchLabel()
    }
}
```

`EmptyInitializing` marks your feature as having a no-arg `init()`, which unlocks shorter APIs throughout the library.

Create a `Store` to hold the state and drive the feature:

```swift
let store = Store(state: CounterFeature.State())
// or, without EmptyInitializing:
let store = Store(state: CounterFeature.State(), feature: { CounterFeature() })
```

Optionally, a Feature can also define an `Event` type for talking to its parent. See [Child → Parent Communication](#child-parent-communication).

### Applying

Mutations happen by calling `apply` on the store. The closure always receives the feature as its first argument.

```swift
// Synchronous mutation
store.apply { feature, state in
    feature.increment(&state)
}
```

For async work, use `store.task` instead. It hands you the feature and a `TaskManager`; call `taskManager.run` with a closure that receives a callback for applying mutations as your work completes. Call it zero times, once, or several times; each call takes effect immediately, against whatever the current state is at that moment.

```swift
// Async work, applied when it's ready
store.task { feature, taskManager in
    taskManager.run { apply in
        let newLabel = await feature.fetchLabel()
        apply { state in
            feature.set(label: newLabel, in: &state)
        }
    }
}
```

Because you control when `apply` gets called, a single task can update state more than once over its lifetime — handy for streaming or paginated work:

```swift
store.task { feature, taskManager in
    taskManager.run { apply in
        for await page in feature.searchResultPages() {
            apply { state in
                feature.append(page, to: &state)
            }
        }
    }
}
```

If your feature has an `Event` type (see [Child → Parent Communication](#child-parent-communication)), a mutation closure follows the same contract as the synchronous one: return the `Event?` from inside `apply { state in ... }` and it propagates through `onEvent` exactly as it would synchronously.

`taskManager.run` doesn't return anything to await — it's fire-and-forget by design, tracked internally so it can be cancelled. See [Task Management](#task-management) below.

<a id="task-management"></a>
### Task Management

Every `run` call can take an `id`. Registering a new one under an `id` that's already in flight cancels the previous one first — handy for search-as-you-type, where each keystroke should replace the last pending request rather than race it:

```swift
func search(for query: String) {
    store.task { feature, taskManager in
        taskManager.run(id: "search") { apply in
            let results = await feature.searchService.search(query)
            apply { state in
                feature.set(results: results, in: &state)
            }
        }
    }
}
```

You can also cancel explicitly:

```swift
store.task { _, taskManager in
    taskManager.cancelAll()                  // cancels every in-flight task
    taskManager.cancel(taskID: "search")     // cancels one specific task, by whatever id you gave it
}
```

`cancel(taskID:)` takes the same kind of `id` you passed to `run(id:)` — a `UUID`, a `String`, anything `Hashable`. To cancel a specific task later, pass your own `id` and keep a reference to it. The default `id` (used when you omit it) is generated fresh on every call and never handed back to you, so it's only reachable via `cancelAll()` or by registering another task under the same custom `id`.

Cancellation is cooperative, the same as Swift's own `Task`: once a task is cancelled, the task manager guarantees any mutation it tries to apply afterward is dropped — even if your closure never checks for cancellation itself. What cancellation does *not* do is interrupt your closure mid-flight. If you want to skip doing further work early, not just discard its result, check `Task.isCancelled` yourself:

```swift
store.task { feature, taskManager in
    taskManager.run(id: "search") { apply in
        guard !Task.isCancelled else { return }
        let results = await feature.searchService.search(query)
        apply { state in
            feature.set(results: results, in: &state)
        }
    }
}
```

### Reading State

The store supports dynamic member lookup, so you can access state properties directly:

```swift
let currentCount = store.count   // reads store.state.count
let label = store.label           // reads store.state.label
```

### SwiftUI Integration

Pass the store around as an `@State` or `@Bindable` and observe state changes directly — the store is `@Observable` under the hood.

```swift
struct CounterView: View {
    @State var store = Store(state: CounterFeature.State())

    var body: some View {
        VStack {
            Text("\(store.count)")
            Button("Increment") {
                store.apply { feature, state in
                    feature.increment(&state)
                }
            }
        }
    }
}
```

Need a `Binding` for a text field or toggle? Use `binding(_:reducing:)`:

```swift
struct LabelEditorView: View {
    var store: Store<CounterFeature>

    var body: some View {
        TextField("Label", text: store.binding(\.label) { feature, state, newValue in
            feature.set(label: newValue, in: &state)
        })
    }
}
```

### Scoping: Parent → Child

Large features are just smaller features composed together. Scope a parent store down to a child store by providing a keypath into the parent's state:

```swift
struct AppFeature: Feature, EmptyInitializing {
    struct State: Equatable {
        var counter: CounterFeature.State = .init()
        var isLimitReached: Bool = false
    }
    
    init() {}
}

let appStore = Store(state: AppFeature.State())

// Child store — reads from and writes to appStore.state.counter
let counterStore: Store<CounterFeature> = appStore.scope(\.counter)
```

Changes made through `counterStore` automatically reflect in `appStore`.

<a id="child-parent-communication"></a>
### Child → Parent Communication

When a child needs to tell its parent something happened, define an `Event` type on the child reducer and handle it in `scope`:

```swift
struct CounterFeature: Feature, EmptyInitializing {
    enum Event {
        case limitReached(Int)
    }

    struct State: Equatable {
        var count: Int = 0
    }
    
    func increment(_ state: inout State) -> Event? {
        state.count += 1
        return state.count >= 100 ? .limitReached(state.count) : nil
    }
    
    init() {}
}
```

```swift
let counterStore = appStore.scope(\.counter) { event, feature, parentState in
    feature.handleEvent(event, state: &parentState)
}
```

```swift
// Inside CounterView, apply with an event:
counterStore.apply { feature, state in
    feature.increment(&state)
}
```

#### Multi-level propagation

`onEvent` returns `ParentFeature.Event?`. Return `nil` to stop the chain at that level; return an Event to pass it to the next ancestor's `onEvent`. This lets deeply nested features inform ancestors without either side knowing about each other's internals.

```swift
struct AppFeature: Feature, EmptyInitializing {
    enum Event { case limitExceeded }
    
    struct State: Equatable {
        var counter: CounterFeature.State = .init()
        var isLimitReached: Bool = false
    }
    
    func handleLimitReached(_ count: Int, state: inout State) -> Event? {
        state.isLimitReached = true
        return count > 200 ? .limitExceeded : nil  // propagate further only if extreme
    }
    
    init() {}
}

struct RootFeature: Feature, EmptyInitializing {
    struct State: Equatable {
        var app: AppFeature.State = .init()
        var showCriticalAlert: Bool = false
    }
    
    init() {}
}

let rootStore = Store(state: RootFeature.State())
let appStore = rootStore.scope(\.app) { event, _, rootState in
    switch event {
    case .limitExceeded:
        rootState.showCriticalAlert = true
        return nil
    }
}
let counterStore = appStore.scope(\.counter) { event, feature, appState in
    switch event {
    case .limitReached(let count):
        return feature.handleLimitReached(count, state: &appState)  // may return .limitExceeded
    }
}

// Applying to counterStore can ripple all the way up to rootStore.
counterStore.apply { feature, state in
    feature.increment(&state)
}
```

### Combine / Publisher

Every store can vend a Combine publisher for any keypath. It emits the current value immediately on subscription, then again on every change.

```swift
var cancellables = Set<AnyCancellable>()

store.publisher(for: \.count)
    .filter { $0 > 50 }
    .sink { count in
        print("Halfway there: \(count)")
    }
    .store(in: &cancellables)
```

All the usual Combine operators work.

---

## Testing

The store is just a class with a closure-based interface. Testing is straightforward — create a store, send actions, assert on state.

```swift
import XCTest

final class CounterFeatureTests: XCTestCase {
    func testIncrement() {
        let store = Store(state: CounterFeature.State())

        store.apply { feature, state in 
            feature.increment(&state) 
        }
        store.apply { feature, state in 
            feature.increment(&state) 
        }

        XCTAssertEqual(store.count, 2)
    }

    func testLimitReachedEvent() {
        var eventFired = false
        let appStore = Store(state: AppFeature.State())
        let counterStore = appStore.scope(\.counter) { event, feature, parentState in
            feature.handleEvent(event, state: &parentState)
        }

        for _ in 0..<100 {
            counterStore.apply { feature, state in
                feature.increment(&state)
            }
        }

        XCTAssertTrue(eventFired)
        XCTAssertTrue(appStore.isLimitReached)
    }
}
```

### Mocking Dependencies in a Feature

The feature instance is passed into every `apply` closure — that's your dependency container. Make dependencies properties of your feature, and swap them in tests:

```swift
struct CounterFeature: Feature {
    struct State: Equatable {
        var label: String = ""
    }

    var labelService: LabelService

    init(labelService: LabelService = LiveLabelService()) {
        self.labelService = labelService
    }

    func set(label: String, in state: inout State) {
        state.label = label
    }
}

// In tests, inject a mock:
let store = Store(
    state: CounterFeature.State(), 
    feature: { 
            CounterFeature(
                labelService: MockLabelService(stubValue: "hello from mock")
            ) 
        }
    )

// taskManager.run doesn't return a Task to await, so use an expectation (or any other
// signal) to wait for it in tests:
let expectation = expectation(description: "label fetched")

store.task { feature, taskManager in
    taskManager.run { apply in
        let label = await feature.labelService.fetchLabel()
        apply { state in
            feature.set(label: label, in: &state)
        }
        expectation.fulfill()
    }
}

await fulfillment(of: [expectation])

XCTAssertEqual(store.label, "hello from mock")
```

---

## Best Practices

### Let the feature own the logic

The `apply` closure receives the feature for a reason — mutation logic belongs there, not inline in the closure. The closure should be wiring inputs to outputs, not computing them.

```swift
// Don't
store.apply { _, state in
    state.count += 1
}

// Do
store.apply { feature, state in
    feature.increment(&state)
}
```

The closure's only job is to hand state to the feature. All logic and mutation stays inside the feature, where it's testable in isolation.

### Let the feature own the event

The same principle applies to events. If an apply might fire an event, the feature method should decide and return it — not the closure.

```swift
// Don't
counterStore.apply { feature, state -> CounterFeature.Event? in
    feature.increment(&state)
    return state.count >= 100 ? .limitReached(state.count) : nil
}

// Do
counterStore.apply { feature, state -> CounterFeature.Event? in
    feature.increment(&state)
}
```

Where `increment` is defined as:

```swift
func increment(_ state: inout State) -> Event? {
    state.count += 1
    return state.count >= 100 ? .limitReached(state.count) : nil
}
```

---

## Installation

Add Reducto to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/manolofdez/Reducto", from: "1.0.0")
]
```

Then add `"Reducto"` as a dependency to your target.

---

That's it. Go build something.
