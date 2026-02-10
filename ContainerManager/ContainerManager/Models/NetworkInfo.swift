import Foundation

struct NetworkInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let subnet: String?
    let gateway: String?
    
    var displayName: String { name }
}
