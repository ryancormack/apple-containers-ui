import SwiftUI
import Observation

@Observable
final class NetworksViewModel {
    var networks: [NetworkInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedNetwork: NetworkInfo.ID?
    
    private let containerService = ContainerService()
    
    func loadNetworks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            networks = try await containerService.listNetworks()
        } catch {
            errorMessage = error.localizedDescription
            networks = []
        }
        
        isLoading = false
    }
    
    func inspectNetwork(_ name: String) async throws -> String {
        return try await containerService.inspectNetwork(name: name)
    }
}
