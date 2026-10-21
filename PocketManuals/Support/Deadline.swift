//
//  Deadline.swift
//  PocketManuals
//

import Foundation
import Synchronization

/// Returns `operation`'s result, or throws `timeoutError` after `seconds`, whichever comes first.
///
/// Unstructured on purpose. A task-group race waits for every child before it returns, so an
/// operation that ignores cancellation (an asset request that never completes) would hold it
/// forever. Here the operation runs in its own task, is cancelled on timeout, and is abandoned
/// if it keeps going.
func withDeadline<T: Sendable>(
    seconds: Double,
    timeoutError: @escaping @Sendable () -> Error,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = DeadlineRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            race.install(continuation)
            let work = Task {
                do { race.finish(.success(try await operation())) } catch { race.finish(.failure(error)) }
            }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                work.cancel()
                race.finish(.failure(timeoutError()))
            }
        }
    } onCancel: {
        race.finish(.failure(CancellationError()))
    }
}

/// First result wins; later ones are dropped.
private final class DeadlineRace<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, Error>?
        var early: Result<T, Error>?
        var finished = false
    }
    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<T, Error>) {
        let pending: Result<T, Error>? = state.withLock { state in
            if let early = state.early {
                state.early = nil
                return early
            }
            state.continuation = continuation
            return nil
        }
        if let pending { continuation.resume(with: pending) }
    }

    func finish(_ result: Result<T, Error>) {
        let continuation: CheckedContinuation<T, Error>? = state.withLock { state in
            guard !state.finished else { return nil }
            state.finished = true
            if let continuation = state.continuation {
                state.continuation = nil
                return continuation
            }
            state.early = result
            return nil
        }
        continuation?.resume(with: result)
    }
}
