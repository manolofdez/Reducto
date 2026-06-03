// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Reducto

struct AppState: Equatable {
    var counter: CounterReducer.State = .init()
    var label: LabelReducer.State = .init()
    var extra: String = ""
}

struct CounterReducer: Feature, EmptyInitializing {
    struct State: Equatable {
        var count: Int = 0
    }

    func increment(_ state: inout State) { state.count += 1 }
    func add(_ amount: Int, to state: inout State) { state.count += amount }
    func set(count: Int, in state: inout State) { state.count = count }
}

struct LabelReducer: Feature, EmptyInitializing {
    struct State: Equatable {
        var label: String = ""
    }

    enum Event {
        case labelChanged(String)
    }

    func set(label: String, in state: inout State) { state.label = label }
}


struct AppReducer: Feature, EmptyInitializing {
    typealias State = AppState

    func set(extra: String, in state: inout State) { state.extra = extra }
}

struct AppStateWithOptional: Equatable {
    var counter: CounterReducer.State? = nil
    var label: LabelReducer.State? = nil
    var extra: String = ""
}

struct AppReducerWithOptional: Feature, EmptyInitializing {
    typealias State = AppStateWithOptional

    func set(extra: String, in state: inout State) { state.extra = extra }
}

// MARK: - Three-level hierarchy fixtures

struct MiddleState: Equatable {
    var label: LabelReducer.State = .init()
    var note: String = ""
}

struct MiddleReducer: Feature, EmptyInitializing {
    typealias State = MiddleState

    enum Event {
        case noteSet(String)
    }

    func setNote(_ note: String, in state: inout State) { state.note = note }
}

struct DeepRootState: Equatable {
    var middle: MiddleState = .init()
    var log: String = ""
}

struct DeepRootReducer: Feature, EmptyInitializing {
    typealias State = DeepRootState

    func appendLog(_ entry: String, to state: inout State) { state.log += entry }
}
