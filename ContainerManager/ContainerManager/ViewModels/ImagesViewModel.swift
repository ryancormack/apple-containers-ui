import SwiftUI
import AppKit
import Observation

@Observable
final class ImagesViewModel {
    var images: [ImageInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedImage: ImageInfo.ID?
    var isPulling = false
    
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
    
    func pullImage(reference: String) async {
        isPulling = true
        errorMessage = nil
        do {
            try await imageService.pullImage(reference: reference, onProgress: { _ in })
            await loadImages()
        } catch {
            errorMessage = "Failed to pull image: \(error.localizedDescription)"
        }
        isPulling = false
    }
    
    func copyInteractiveRunCommand(for image: ImageInfo) {
        let command = "\(AppConfiguration.shared.cliPath) run -it \(image.id) /bin/sh"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
    
    func buildRunCommand(for image: ImageInfo, name: String?, selectedPaths: [MountPath]) -> String {
        var components: [String] = [AppConfiguration.shared.cliPath, "run", "-it"]
        
        if let containerName = name, !containerName.trimmingCharacters(in: .whitespaces).isEmpty {
            components.append("--name")
            components.append(containerName.trimmingCharacters(in: .whitespaces))
        }
        
        for mountPath in selectedPaths {
            components.append("-v")
            components.append("\"\(mountPath.path)\":\"\(mountPath.path)\"")
        }
        
        components.append(image.id)
        components.append("/bin/sh")
        
        return components.joined(separator: " ")
    }
    
    func copyCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
    
    func runImage(_ image: ImageInfo, name: String?) async {
        do {
            try await imageService.runImage(reference: image.id, name: name)
        } catch {
            errorMessage = "Failed to run image: \(error.localizedDescription)"
        }
    }
}
