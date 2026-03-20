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
    var pruneMessage: String?
    
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
    
    func copyInteractiveRunCommand(for image: ImageInfo, config: RunConfiguration? = nil) {
        var parts = [AppConfiguration.shared.cliPath, "run", "-it"]
        
        if let config {
            for mount in config.mounts {
                parts.append("-v")
                parts.append("\(mount.hostPath):\(mount.containerPath)")
            }
            for env in config.envVars where !env.key.isEmpty {
                parts.append("-e")
                parts.append(env.inheritFromHost ? env.key : "\(env.key)=\(env.value)")
            }
            if config.readOnly {
                parts.append("--read-only")
            }
        }
        
        parts.append(image.id)
        parts.append("/bin/sh")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: " "), forType: .string)
    }
    
    func runImage(_ image: ImageInfo, name: String?) async {
        do {
            try await imageService.runImage(reference: image.id, name: name)
        } catch {
            errorMessage = "Failed to run image: \(error.localizedDescription)"
        }
    }
    
    func pruneImages(all: Bool) async {
        do {
            let result = try await imageService.pruneImages(all: all)
            pruneMessage = result.trimmingCharacters(in: .whitespacesAndNewlines)
            await loadImages()
        } catch {
            errorMessage = "Failed to prune images: \(error.localizedDescription)"
        }
    }
}
