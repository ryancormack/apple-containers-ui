import SwiftUI
import Observation

@Observable
final class VolumesViewModel {
    var volumes: [VolumeInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedVolume: VolumeInfo.ID?
    var pruneMessage: String?
    
    private let containerService = ContainerService()
    
    func loadVolumes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            volumes = try await containerService.listVolumes()
        } catch {
            errorMessage = error.localizedDescription
            volumes = []
        }
        
        isLoading = false
    }
    
    func inspectVolume(_ name: String) async throws -> String {
        return try await containerService.inspectVolume(name: name)
    }
    
    func pruneVolumes() async {
        do {
            let result = try await containerService.pruneVolumes()
            pruneMessage = result.trimmingCharacters(in: .whitespacesAndNewlines)
            await loadVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
