import SwiftUI
import Observation

@Observable
final class ContainersViewModel {
    var containers: [ContainerInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedContainer: ContainerInfo.ID?
    
    var autoRefreshEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoRefreshEnabled, forKey: "autoRefreshEnabled")
        }
    }
    
    var showAllContainers: Bool {
        didSet {
            UserDefaults.standard.set(showAllContainers, forKey: "showAllContainers")
        }
    }
    
    private let containerService = ContainerService()
    private var refreshTask: Task<Void, Never>?
    
    init() {
        self.autoRefreshEnabled = UserDefaults.standard.bool(forKey: "autoRefreshEnabled")
        self.showAllContainers = UserDefaults.standard.object(forKey: "showAllContainers") as? Bool ?? true
    }
    
    func loadContainers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            containers = try await containerService.listContainers(showAll: showAllContainers)
        } catch {
            errorMessage = error.localizedDescription
            containers = []
        }
        
        isLoading = false
    }
    
    func startAutoRefresh(interval: TimeInterval = 3.0) {
        stopAutoRefresh()
        autoRefreshEnabled = true
        
        refreshTask = Task {
            while !Task.isCancelled && autoRefreshEnabled {
                await loadContainers()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    func stopAutoRefresh() {
        autoRefreshEnabled = false
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func stopContainer(_ container: ContainerInfo) async {
        do {
            try await containerService.stopContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to stop container: \(error.localizedDescription)"
        }
    }
    
    func killContainer(_ container: ContainerInfo) async {
        do {
            try await containerService.killContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to kill container: \(error.localizedDescription)"
        }
    }
    
    func removeContainer(_ container: ContainerInfo) async {
        do {
            try await containerService.removeContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to remove container: \(error.localizedDescription)"
        }
    }
    
    func inspectContainer(_ id: String) async throws -> String {
        return try await containerService.inspectContainer(id: id)
    }
    
    deinit {
        stopAutoRefresh()
    }
}
