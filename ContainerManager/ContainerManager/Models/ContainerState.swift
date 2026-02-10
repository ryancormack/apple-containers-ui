import SwiftUI

enum ContainerState: String, Codable, CaseIterable {
    case running
    case stopped
    case stopping
    case unknown
    
    var displayColor: Color {
        switch self {
        case .running: return .green
        case .stopped: return .gray
        case .stopping: return .orange
        case .unknown: return .secondary
        }
    }
    
    var systemImage: String {
        switch self {
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle.fill"
        case .stopping: return "hourglass.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
