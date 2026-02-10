import Foundation

struct ImageInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let tag: String
    let digest: String
    let size: Int64?
    let createdAt: Date?
    
    var displayName: String {
        "\(name):\(tag)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ImageInfo, rhs: ImageInfo) -> Bool {
        lhs.id == rhs.id
    }
}
