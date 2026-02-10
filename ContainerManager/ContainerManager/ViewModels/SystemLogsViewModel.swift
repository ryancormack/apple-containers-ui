import SwiftUI
import Observation

@Observable
final class SystemLogsViewModel {
    var logs: [String] = []
    var isStreaming = false
    var errorMessage: String?
    var followEnabled = false
    
    private let containerService = ContainerService()
    private var streamTask: Task<Void, Never>?
    
    func startStreaming() async {
        stopStreaming()
        isStreaming = true
        errorMessage = nil
        
        streamTask = Task {
            do {
                let stream = try await containerService.streamSystemLogs(follow: followEnabled)
                for await line in stream {
                    if !Task.isCancelled {
                        logs.append(line)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isStreaming = false
        }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    deinit {
        stopStreaming()
    }
}
