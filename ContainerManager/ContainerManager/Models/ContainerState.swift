import SwiftUI

enum ContainerState: String, Codable, CaseIterable {
    case running
    case stopped
    case paused
    case created
    case exited
    case unknown
    
    var displayColor: Color {
        switch self {
        case .running:
            return .green
        case .stopped, .exited:
            return .gray
        case .paused:
            return .yellow
        case .created:
            return .blue
        case .unknown:
            return .secondary
        }
    }
    
    var systemImage: String {
        switch self {
        case .running:
            return "play.circle.fill"
        case .stopped, .exited:
            return "stop.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .created:
            return "circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}
