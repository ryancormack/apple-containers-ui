import Foundation

struct MountPath: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    
    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
