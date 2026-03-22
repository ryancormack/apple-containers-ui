import SwiftUI

struct StatsView: View {
    @State private var viewModel = StatsViewModel()
    @State private var searchText = ""
    
    var filteredStats: [ContainerStats] {
        if searchText.isEmpty {
            return viewModel.stats
        }
        return viewModel.stats.filter { stat in
            stat.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: $viewModel.autoRefreshEnabled) {
                    Label("Auto-refresh", systemImage: "arrow.clockwise")
                }
                .help("Automatically refresh stats")
                .onChange(of: viewModel.autoRefreshEnabled) { _, enabled in
                    if enabled {
                        viewModel.startAutoRefresh()
                    } else {
                        viewModel.stopAutoRefresh()
                    }
                }
                
                Spacer()
                
                Text("\(filteredStats.count) container(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.isLoading && viewModel.stats.isEmpty {
                    ProgressView("Loading stats...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadStats() }
                    }
                } else if filteredStats.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "No Stats",
                        message: searchText.isEmpty ? "No running containers to display stats for" : "No containers match '\(searchText)'"
                    )
                } else {
                    statsTable
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search containers...")
        .navigationTitle("Stats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadStats() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Refresh stats")
            }
        }
        .task {
            await viewModel.loadStats()
        }
    }
    
    private var statsTable: some View {
        Table(filteredStats) {
            TableColumn("Container") { stat in
                Text(stat.name)
                    .fontWeight(.medium)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("CPU %") { stat in
                Text(String(format: "%.1f%%", stat.cpuPercentage))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Memory") { stat in
                Text("\(stat.memoryUsage) / \(stat.memoryLimit)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Net I/O") { stat in
                Text(stat.networkIO)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
            
            TableColumn("Block I/O") { stat in
                Text(stat.blockIO)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
            
            TableColumn("PIDs") { stat in
                Text("\(stat.pids)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
}
