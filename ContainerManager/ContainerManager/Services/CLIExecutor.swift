import Foundation

struct CLIExecutor {
    private var cliPath: String { AppConfiguration.shared.cliPath }
    
    func execute(arguments: [String]) async throws -> String {
        let path = cliPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppError(message: "Container CLI not found at \(path)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        // Read both pipes concurrently to avoid deadlock when output exceeds pipe buffer
        async let outputData = Task.detached {
            outputPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let errorData = Task.detached {
            errorPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        
        let (output, error) = await (try outputData, try errorData)
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorMessage = String(data: error, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw AppError(message: errorMessage)
        }
        
        guard let result = String(data: output, encoding: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        return result
    }
    
    func executeStreaming(arguments: [String]) throws -> AsyncStream<String> {
        let path = cliPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppError(message: "Container CLI not found at \(path)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        let handle = pipe.fileHandleForReading
        
        try process.run()
        
        return AsyncStream { continuation in
            process.terminationHandler = { _ in
                let data = handle.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                        continuation.yield(line)
                    }
                }
                continuation.finish()
            }
            
            NotificationCenter.default.addObserver(
                forName: .NSFileHandleDataAvailable,
                object: handle,
                queue: nil
            ) { _ in
                let data = handle.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                        continuation.yield(line)
                    }
                    handle.waitForDataInBackgroundAndNotify()
                }
            }
            
            handle.waitForDataInBackgroundAndNotify()
            
            continuation.onTermination = { @Sendable _ in
                process.terminate()
            }
        }
    }
}
