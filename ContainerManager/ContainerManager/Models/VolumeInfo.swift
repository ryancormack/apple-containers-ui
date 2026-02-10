import Foundation

struct VolumeInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let driver: String
    let mountpoint: String?
    
    var displayName: String { name }
}
