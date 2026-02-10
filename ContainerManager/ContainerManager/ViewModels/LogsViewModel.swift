import SwiftUI
import Observation

@Observable
final class LogsViewModel {
    var logs: [String] = []
    var isStreaming = false
    var errorMessage: String?
    var followEnabled = false
    
    private let containerService = ContainerService()
    private var streamTask: Task<Void, Never>?
    
    func startStreaming(containerId: String) async {
        stopStreaming()
        
        isStreaming = true
        errorMessage = nil
        logs = []
        
        streamTask = Task {
            do {
                let logStream = try containerService.streamLogs(containerId: containerId, follow: followEnabled)
                
                for await logLine in logStream {
                    if Task.isCancelled { break }
                    logs.append(logLine)
                }
            } catch {
                errorMessage = "Failed to load logs: \(error.localizedDescription)"
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
        logs = []
    }
    
    deinit {
        streamTask?.cancel()
    }
}
