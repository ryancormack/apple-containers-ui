import SwiftUI
import AppKit
import Observation

@Observable
final class SettingsViewModel {
    var mountPaths: [MountPath] = []
    var errorMessage: String?
    
    init() {
        loadMountPaths()
    }
    
    func loadMountPaths() {
        mountPaths = AppConfiguration.shared.mountPaths
    }
    
    func addMountPath(name: String, path: String) {
        let newPath = MountPath(name: name, path: path)
        AppConfiguration.shared.addMountPath(newPath)
        loadMountPaths()
    }
    
    func removeMountPath(id: UUID) {
        AppConfiguration.shared.removeMountPath(id: id)
        loadMountPaths()
    }
    
    func updateMountPath(_ mountPath: MountPath) {
        AppConfiguration.shared.updateMountPath(mountPath)
        loadMountPaths()
    }
    
    func validatePathExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to mount into containers"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
