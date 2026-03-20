import SwiftUI

struct NetworksListView: View {
    @State private var viewModel = NetworksViewModel()
    @State private var searchText = ""
    @State private var showingInspect = false
    @State private var inspectData = ""
    @State private var showingPruneConfirmation = false
    @State private var showingPruneNotice = false
    
    var filteredNetworks: [NetworkInfo] {
        if searchText.isEmpty {
            return viewModel.networks
        }
        return viewModel.networks.filter { network in
            network.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(filteredNetworks.count) network(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.isLoading && viewModel.networks.isEmpty {
                    ProgressView("Loading networks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadNetworks() }
                    }
                } else if filteredNetworks.isEmpty {
                    EmptyStateView(
                        icon: "network",
                        title: "No Networks",
                        message: searchText.isEmpty ? "No networks are available" : "No networks match '\(searchText)'"
                    )
                } else {
                    networkTable
                }
            }
        }
        .overlay {
            if showingPruneNotice {
                Text("Networks pruned")
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
        .searchable(text: $searchText, prompt: "Search networks...")
        .navigationTitle("Networks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPruneConfirmation = true
                } label: {
                    Label("Prune Networks", systemImage: "scissors")
                }
                .help("Remove unused networks")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadNetworks() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Refresh network list")
            }
        }
        .task {
            await viewModel.loadNetworks()
        }
        .confirmationDialog("Prune Networks?", isPresented: $showingPruneConfirmation) {
            Button("Prune", role: .destructive) {
                Task {
                    await viewModel.pruneNetworks()
                    withAnimation { showingPruneNotice = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove all unused networks? This cannot be undone.")
        }
        .sheet(isPresented: $showingInspect) {
            InspectView(title: "Network Inspect", jsonData: inspectData)
        }
    }
    
    private var networkTable: some View {
        Table(filteredNetworks, selection: $viewModel.selectedNetwork) {
            TableColumn("Name") { network in
                Text(network.name)
                    .fontWeight(.medium)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Subnet") { network in
                Text(network.subnet ?? "-")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("IPv6 Subnet") { network in
                Text(network.subnetV6 ?? "-")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Actions") { network in
                Button {
                    Task {
                        do {
                            inspectData = try await viewModel.inspectNetwork(network.name)
                            showingInspect = true
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Inspect network")
            }
            .width(ideal: 80)
        }
    }
}

#Preview {
    NavigationStack {
        NetworksListView()
    }
}
