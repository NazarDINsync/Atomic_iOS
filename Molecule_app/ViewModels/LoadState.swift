import Foundation

/// The lifecycle of an asynchronous screen load.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

/// Runs an async throwing operation and captures its outcome as a `Result`.
func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) } catch { return .failure(error) }
}

extension Error {
    /// A message suitable for showing in the UI.
    var userMessage: String { (self as? LocalizedError)?.errorDescription ?? localizedDescription }
}
