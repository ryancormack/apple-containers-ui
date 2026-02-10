import Foundation

struct VolumeInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let driver: String
    let format: String?
    let source: String?
    let createdAt: Date?
    let sizeInBytes: UInt64?
    
    var displayName: String { name }
}
