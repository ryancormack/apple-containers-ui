import Foundation

struct ContainerInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let state: ContainerState
    let ipAddress: String?
    let createdAt: Date?
    let command: [String]?
    
    init(id: String, name: String, image: String, state: ContainerState, 
         ipAddress: String? = nil, createdAt: Date? = nil, command: [String]? = nil) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.ipAddress = ipAddress
        self.createdAt = createdAt
        self.command = command
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContainerInfo, rhs: ContainerInfo) -> Bool {
        lhs.id == rhs.id
    }
}
