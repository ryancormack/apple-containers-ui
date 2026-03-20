import Foundation

struct ContainerStats: Identifiable, Hashable {
    let id: String
    let name: String
    let cpuPercentage: Double
    let memoryUsage: String
    let memoryLimit: String
    let networkIO: String
    let blockIO: String
    let pids: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContainerStats, rhs: ContainerStats) -> Bool {
        lhs.id == rhs.id
    }
}
