// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

@MainActor
public final class TaskManager<StoreFeature: Feature> {
    public typealias ApplyBlock = (inout StoreFeature.State) -> StoreFeature.Event?
    
    @MainActor
    final class ApplyToken {
        private(set) var isValid = true

        func invalidate() {
            isValid = false
        }
    }
    
    public var state: StoreFeature.State {
        store.state
    }
    
    private let store: any InternalStoring<StoreFeature>
    private let cancellationBag = TaskCancellationBag()
    
    init(store: some InternalStoring<StoreFeature>) {
        self.store = store
    }

    /// Asynchronously performs work that can apply multiple state mutations via the provided callback.
    @_disfavoredOverload
    public func run(
        id: some Hashable = UUID(),
        _ work: @escaping (@escaping (ApplyBlock) -> Void) async -> Void
    ) {
        let token = ApplyToken()
        let task = Task { @MainActor [weak self] in
            defer { token.invalidate() }

            guard let self else { return }

            let wrappedApplyBlock: (ApplyBlock) -> Void = { [weak self, token] applyBlock in
                guard token.isValid else {
                    LogUtils.showLog(
                        message: "Cannot perform state mutations after the apply function has completed",
                        category: "TaskManager"
                    )
                    return
                }

                guard !Task.isCancelled else {
                    LogUtils.showLog(
                        message: "Cannot perform state mutations after the task has been cancelled",
                        category: "TaskManager"
                    )
                    return
                }

                guard let self else { return }

                store.apply { _, state in
                    return applyBlock(&state)
                }
            }
            
            await work(wrappedApplyBlock)
        }
        
        cancellationBag.store(id: id, task)
    }
    
    /// Cancels all tasks started via the async apply with callback.
    public func cancelAll() {
        cancellationBag.cancelAll()
    }

    /// Cancels a specific task by its registered ID.
    public func cancel(taskID: some Hashable) {
        cancellationBag.cancel(id: taskID)
    }
}

extension TaskManager where StoreFeature.Event == Never {
    public typealias EventlessApplyBlock = (inout StoreFeature.State) -> Void
    
    /// Asynchronously performs work that can apply multiple state mutations via the provided callback.
    public func run(
        id: some Hashable = UUID(),
        _ work: @escaping (@escaping (EventlessApplyBlock) -> Void) async -> Void
    ) {
        self.run(id: id) { applyBlock in
            await work { eventlessApplyBlock in
                applyBlock { state in
                    eventlessApplyBlock(&state)
                    return nil
                }
            }
        }
    }
}
