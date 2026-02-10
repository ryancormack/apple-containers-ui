import Foundation

struct AppError: Error, LocalizedError {
    let message: String
    let underlyingError: Error?
    
    init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        if let underlying = underlyingError {
            return "\(message): \(underlying.localizedDescription)"
        }
        return message
    }
}
