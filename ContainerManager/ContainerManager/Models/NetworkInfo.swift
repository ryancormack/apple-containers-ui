import Foundation

struct NetworkInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let subnet: String?
    let subnetV6: String?
    
    var displayName: String { name }
}
