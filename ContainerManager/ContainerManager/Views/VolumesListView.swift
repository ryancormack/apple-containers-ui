import SwiftUI

struct VolumesListView: View {
    @State private var viewModel = VolumesViewModel()
    @State private var searchText = ""
    @State private var showingInspect = false
    @State private var inspectData = ""
    @State private var showingPruneConfirmation = false
    @State private var showingPruneNotice = false
    
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
        .overlay {
            if showingPruneNotice {
                Text("Volumes pruned")
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showingPruneNotice = false }
                        }
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search volumes...")
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPruneConfirmation = true
                } label: {
                    Label("Prune Volumes", systemImage: "scissors")
                }
                .help("Remove unused volumes")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadVolumes() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Refresh volume list")
            }
        }
        .task {
            await viewModel.loadVolumes()
        }
        .confirmationDialog("Prune Volumes?", isPresented: $showingPruneConfirmation) {
            Button("Prune", role: .destructive) {
                Task {
                    await viewModel.pruneVolumes()
                    withAnimation { showingPruneNotice = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove all unused volumes? This cannot be undone.")
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
