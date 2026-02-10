import SwiftUI
import Observation

@Observable
final class ImagesViewModel {
    var images: [ImageInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedImage: ImageInfo.ID?
    
    private let imageService = ImageService()
    
    init() {
    }
    
    func loadImages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            images = try await imageService.listImages()
        } catch {
            errorMessage = error.localizedDescription
            images = []
        }
        
        isLoading = false
    }
    
    func removeImage(_ image: ImageInfo) async {
        do {
            try await imageService.removeImage(reference: image.displayName)
            await loadImages()
        } catch {
            errorMessage = "Failed to remove image: \(error.localizedDescription)"
        }
    }
    
    func inspectImage(_ reference: String) async throws -> String {
        return try await imageService.inspectImage(reference: reference)
    }
    
    func runImage(_ image: ImageInfo, name: String?) async {
        do {
            try await imageService.runImage(reference: image.id, name: name)
        } catch {
            errorMessage = "Failed to run image: \(error.localizedDescription)"
        }
    }
}
