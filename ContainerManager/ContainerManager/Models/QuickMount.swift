import Foundation

struct QuickMount: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hostPath: String
    var containerPath: String
    
    static let builtInSuggestions: [(String, String, String)] = [
        ("AWS Credentials", "~/.aws", "/root/.aws"),
        ("Claude Code", "~/.claude", "/root/.claude"),
        ("SSH Keys", "~/.ssh", "/root/.ssh"),
        ("Git Config", "~/.gitconfig", "/root/.gitconfig"),
    ]
}

@Observable
final class QuickMountStore {
    static let shared = QuickMountStore()
    
    var mounts: [QuickMount] {
        didSet { save() }
    }
    
    private let key = "savedQuickMounts"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([QuickMount].self, from: data) {
            mounts = decoded
        } else {
            mounts = []
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(mounts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func add(_ mount: QuickMount) {
        mounts.append(mount)
    }
    
    func remove(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            mounts.remove(at: index)
        }
    }
    
    func delete(_ mount: QuickMount) {
        mounts.removeAll { $0.id == mount.id }
    }
}
