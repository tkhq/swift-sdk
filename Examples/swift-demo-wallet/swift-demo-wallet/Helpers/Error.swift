import Foundation

func formatError(_ error: Error, fallback: String) -> String {
    if let turnkeyError = error.turnkeyRequestError {
        return "\(fallback): \(turnkeyError.fullMessage)"
    }
    if let localized = (error as? LocalizedError)?.errorDescription {
        return "\(fallback): \(localized)"
    }
    return "\(fallback): \(String(describing: error))"
}
