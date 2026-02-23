import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showingAddDialog = false
    @State private var newPathName = ""
    @State private var selectedPath: URL?
    @State private var editingMountPath: MountPath?
    @State private var editedName = ""
    @State private var showingDeleteConfirmation = false
    @State private var pathToDelete: MountPath?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(viewModel.mountPaths.count) mount path(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.mountPaths.isEmpty {
                    EmptyStateView(
                        icon: "folder.badge.plus",
                        title: "No Mount Paths",
                        message: "Add folders from your Mac to mount into containers"
                    )
                } else {
                    mountPathsTable
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let url = viewModel.selectFolder() {
                        selectedPath = url
                        newPathName = url.lastPathComponent
                        showingAddDialog = true
                    }
                } label: {
                    Label("Add Mount Path", systemImage: "plus")
                }
            }
        }
        .alert("Add Mount Path", isPresented: $showingAddDialog) {
            TextField("Display name", text: $newPathName)
            Button("Add") {
                if let url = selectedPath {
                    viewModel.addMountPath(name: newPathName, path: url.path)
                }
                newPathName = ""
                selectedPath = nil
            }
            .disabled(newPathName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                newPathName = ""
                selectedPath = nil
            }
        } message: {
            if let url = selectedPath {
                Text("Path: \(url.path)")
            }
        }
        .alert("Rename Mount Path", isPresented: Binding(
            get: { editingMountPath != nil },
            set: { if !$0 { editingMountPath = nil } }
        )) {
            TextField("Display name", text: $editedName)
            Button("Save") {
                if var mountPath = editingMountPath {
                    mountPath.name = editedName
                    viewModel.updateMountPath(mountPath)
                }
                editingMountPath = nil
                editedName = ""
            }
            .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                editingMountPath = nil
                editedName = ""
            }
        } message: {
            if let mountPath = editingMountPath {
                Text("Path: \(mountPath.path)")
            }
        }
        .confirmationDialog("Remove Mount Path?", isPresented: $showingDeleteConfirmation, presenting: pathToDelete) { mountPath in
            Button("Remove", role: .destructive) {
                viewModel.removeMountPath(id: mountPath.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { mountPath in
            Text("Remove '\(mountPath.name)' from mount paths?")
        }
    }
    
    private var mountPathsTable: some View {
        Table(viewModel.mountPaths) {
            TableColumn("Name") { mountPath in
                Text(mountPath.name)
                    .fontWeight(.medium)
            }
            .width(min: 100, ideal: 150)
            
            TableColumn("Path") { mountPath in
                HStack {
                    Text(mountPath.path)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if !viewModel.validatePathExists(mountPath.path) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .help("Path does not exist")
                    }
                }
            }
            .width(min: 200, ideal: 400)
            
            TableColumn("Actions") { mountPath in
                HStack(spacing: 4) {
                    Button {
                        editingMountPath = mountPath
                        editedName = mountPath.name
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Rename")
                    
                    Button {
                        pathToDelete = mountPath
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Remove")
                }
            }
            .width(ideal: 80)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
