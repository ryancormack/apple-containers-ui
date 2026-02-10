import SwiftUI

struct ContainersListView: View {
    @State private var viewModel = ContainersViewModel()
    @State private var searchText = ""
    @State private var showingStopConfirmation = false
    @State private var showingKillConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingInspect = false
    @State private var inspectData = ""
    @State private var containerToAct: ContainerInfo?
    
    var filteredContainers: [ContainerInfo] {
        if searchText.isEmpty {
            return viewModel.containers
        }
        return viewModel.containers.filter { container in
            container.name.localizedCaseInsensitiveContains(searchText) ||
            container.id.localizedCaseInsensitiveContains(searchText) ||
            container.image.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: $viewModel.autoRefreshEnabled) {
                    Label("Auto-refresh", systemImage: "arrow.clockwise")
                }
                .onChange(of: viewModel.autoRefreshEnabled) { _, enabled in
                    if enabled {
                        viewModel.startAutoRefresh()
                    } else {
                        viewModel.stopAutoRefresh()
                    }
                }
                
                Toggle(isOn: $viewModel.showAllContainers) {
                    Label("Show stopped", systemImage: "eye")
                }
                .onChange(of: viewModel.showAllContainers) { _, _ in
                    Task { await viewModel.loadContainers() }
                }
                
                Spacer()
                
                Text("\(filteredContainers.count) container(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.isLoading && viewModel.containers.isEmpty {
                    ProgressView("Loading containers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadContainers() }
                    }
                } else if filteredContainers.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No Containers",
                        message: searchText.isEmpty ? "No containers are currently available" : "No containers match '\(searchText)'"
                    )
                } else {
                    containerTable
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search containers...")
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadContainers() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadContainers()
        }
        .confirmationDialog("Stop Container?", isPresented: $showingStopConfirmation, presenting: containerToAct) { container in
            Button("Stop") {
                Task { await viewModel.stopContainer(container) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Stop '\(container.name)' gracefully?")
        }
        .confirmationDialog("Kill Container?", isPresented: $showingKillConfirmation, presenting: containerToAct) { container in
            Button("Kill", role: .destructive) {
                Task { await viewModel.killContainer(container) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Force kill '\(container.name)'? This cannot be undone.")
        }
        .confirmationDialog("Remove Container?", isPresented: $showingRemoveConfirmation, presenting: containerToAct) { container in
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeContainer(container) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Permanently remove '\(container.name)'?")
        }
        .sheet(isPresented: $showingInspect) {
            InspectView(title: "Container Inspect", jsonData: inspectData)
        }
    }
    
    private var containerTable: some View {
        Table(filteredContainers, selection: $viewModel.selectedContainer) {
            TableColumn("Status") { container in
                HStack(spacing: 6) {
                    Image(systemName: container.state.systemImage)
                        .foregroundStyle(container.state.displayColor)
                    Text(container.state.rawValue.capitalized)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Name") { container in
                Text(container.name)
                    .fontWeight(.medium)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Image") { container in
                Text(container.image)
                    .foregroundStyle(.secondary)
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("ID") { container in
                Text(container.id.prefix(12))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .width(min: 120, ideal: 140)
            
            TableColumn("IP Address") { container in
                Text(container.ipAddress ?? "-")
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
            
            TableColumn("Actions") { container in
                HStack(spacing: 4) {
                    Button {
                        Task {
                            do {
                                inspectData = try await viewModel.inspectContainer(container.id)
                                showingInspect = true
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Image(systemName: "info.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Inspect container")
                    
                    Button {
                        containerToAct = container
                        showingStopConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Stop container")
                    
                    Button {
                        containerToAct = container
                        showingKillConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Kill container")
                    
                    NavigationLink(destination: LogsView(containerId: container.id, containerName: container.name)) {
                        Image(systemName: "doc.text.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("View logs")
                    
                    Button {
                        containerToAct = container
                        showingRemoveConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.orange)
                    .help("Remove container")
                }
            }
            .width(ideal: 150)
        }
    }
}

#Preview {
    NavigationStack {
        ContainersListView()
    }
}
