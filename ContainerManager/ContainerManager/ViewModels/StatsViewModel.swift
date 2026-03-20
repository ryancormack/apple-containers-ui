import SwiftUI
import Observation

@Observable
final class StatsViewModel {
    var stats: [ContainerStats] = []
    var isLoading = false
    var errorMessage: String?
    
    var autoRefreshEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoRefreshEnabled, forKey: "statsAutoRefreshEnabled")
        }
    }
    
    private let containerService = ContainerService()
    private var refreshTask: Task<Void, Never>?
    
    init() {
        self.autoRefreshEnabled = UserDefaults.standard.bool(forKey: "statsAutoRefreshEnabled")
    }
    
    func loadStats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            stats = try await containerService.getContainerStats()
        } catch {
            errorMessage = error.localizedDescription
            stats = []
        }
        
        isLoading = false
    }
    
    func startAutoRefresh(interval: TimeInterval = 3.0) {
        stopAutoRefresh()
        autoRefreshEnabled = true
        
        refreshTask = Task {
            while !Task.isCancelled && autoRefreshEnabled {
                await loadStats()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    func stopAutoRefresh() {
        autoRefreshEnabled = false
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    deinit {
        refreshTask?.cancel()
    }
}
