import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem? = .containers
    @State private var systemStatus: SystemStatus = .unknown
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(SidebarItem.allCases, selection: $selection) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
                
                Divider()
                
                HStack {
                    Circle()
                        .fill(systemStatus.color)
                        .frame(width: 8, height: 8)
                    Text(systemStatus.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Container Manager")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
            .task {
                await checkSystemStatus()
            }
        } detail: {
            NavigationStack {
                Group {
                    switch selection {
                    case .containers:
                        ContainersListView()
                    case .images:
                        ImagesListView()
                    case .volumes:
                        VolumesListView()
                    case .networks:
                        NetworksListView()
                    case .systemLogs:
                        SystemLogsView()
                    case .none:
                        placeholderView
                    }
                }
            }
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("Container Manager")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Select a section from the sidebar to get started")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func checkSystemStatus() async {
        let service = ContainerService()
        do {
            _ = try await service.getSystemStatus()
            systemStatus = .running
        } catch {
            systemStatus = .error(error.localizedDescription)
        }
    }
}

enum SystemStatus {
    case unknown, running, error(String)
    
    var label: String {
        switch self {
        case .unknown: return "Checking..."
        case .running: return "System Ready"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .running: return .green
        case .error: return .red
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case containers
    case images
    case volumes
    case networks
    case systemLogs
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        case .volumes: return "Volumes"
        case .networks: return "Networks"
        case .systemLogs: return "System Logs"
        }
    }
    
    var icon: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "photo.stack"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .systemLogs: return "doc.text"
        }
    }
}

#Preview {
    ContentView()
}
