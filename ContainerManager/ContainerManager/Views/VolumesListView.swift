import SwiftUI

struct VolumesListView: View {
    @State private var viewModel = VolumesViewModel()
    @State private var searchText = ""
    @State private var showingInspect = false
    @State private var inspectData = ""
    
    var filteredVolumes: [VolumeInfo] {
        if searchText.isEmpty {
            return viewModel.volumes
        }
        return viewModel.volumes.filter { volume in
            volume.name.localizedCaseInsensitiveContains(searchText) ||
            volume.driver.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(filteredVolumes.count) volume(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.isLoading && viewModel.volumes.isEmpty {
                    ProgressView("Loading volumes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadVolumes() }
                    }
                } else if filteredVolumes.isEmpty {
                    EmptyStateView(
                        icon: "externaldrive",
                        title: "No Volumes",
                        message: searchText.isEmpty ? "No volumes are available" : "No volumes match '\(searchText)'"
                    )
                } else {
                    volumeTable
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search volumes...")
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadVolumes() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadVolumes()
        }
        .sheet(isPresented: $showingInspect) {
            InspectView(title: "Volume Inspect", jsonData: inspectData)
        }
    }
    
    private var volumeTable: some View {
        Table(filteredVolumes, selection: $viewModel.selectedVolume) {
            TableColumn("Name") { volume in
                Text(volume.name)
                    .fontWeight(.medium)
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Driver") { volume in
                Text(volume.driver)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 150)
            
            TableColumn("Source") { volume in
                Text(volume.source ?? "-")
                    .foregroundStyle(.tertiary)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Actions") { volume in
                Button {
                    Task {
                        do {
                            inspectData = try await viewModel.inspectVolume(volume.name)
                            showingInspect = true
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Inspect volume")
            }
            .width(ideal: 80)
        }
    }
}

#Preview {
    NavigationStack {
        VolumesListView()
    }
}
