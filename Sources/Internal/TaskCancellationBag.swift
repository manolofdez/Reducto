// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

@MainActor
final class TaskCancellationBag {
    private struct InternalTaskID: Hashable {
        private let id: AnyHashable
        private let typeID: ObjectIdentifier
        
        init(_ id: some Hashable) {
            self.id = id
            self.typeID = .init(type(of: id))
        }
    }
    
    private struct StoredTask {
        let storageID: UUID
        let task: Task<Void, Never>
    }

    private var storedTasks: [InternalTaskID: StoredTask] = [:]

    deinit {
        // Note cancellAll is main-actor isolated, and deinit is not guaranteed
        // to run on the main actor. Since deinit has exclusive access to self,
        // we don't need any isolation proof and can just remove the tasks
        // ourselves.
        for storedTask in storedTasks.values {
            storedTask.task.cancel()
        }
        storedTasks.removeAll()
    }

    func store(id: some Hashable = UUID(), _ task: Task<Void, Never>) {
        cancel(id: id)
        
        let taskID = InternalTaskID(id)
        let storageID = UUID()
        storedTasks[taskID] = StoredTask(storageID: storageID, task: task)
        
        Task { [weak self] in
            _ = await task.value
            guard let self else { return }
            guard self.storedTasks[taskID]?.storageID == storageID else { return }
            self.storedTasks.removeValue(forKey: taskID)
        }
    }

    func cancel(id: some Hashable) {
        cancel(internalTaskID: InternalTaskID(id))
    }

    func cancelAll() {
        for internalTaskID in Array(storedTasks.keys) {
            cancel(internalTaskID: internalTaskID)
        }
    }
    
    private func cancel(internalTaskID: InternalTaskID) {
        guard let registeredTask = storedTasks[internalTaskID] else { return }
        storedTasks.removeValue(forKey: internalTaskID)
        registeredTask.task.cancel()
    }
}
