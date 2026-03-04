import SwiftUI

struct RunConfigurationSheet: View {
    let image: ImageInfo
    let onCopy: (RunConfiguration) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var workspacePath: URL?
    @State private var containerWorkspacePath = "/workspace"
    @State private var enabledQuickMounts: Set<UUID> = []
    @State private var extraMounts: [MountEntry] = []
    @State private var envVars: [EnvVar] = []
    @State private var showingQuickMountManager = false
    
    private var store: QuickMountStore { QuickMountStore.shared }
    
    private let envPresets: [(String, [String])] = [
        ("AWS Credentials", [
            "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN",
            "AWS_REGION", "AWS_DEFAULT_REGION", "AWS_PROFILE"
        ]),
        ("SSH Agent", ["SSH_AUTH_SOCK"]),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Form {
                    workspaceSection
                    quickMountsSection
                    extraMountsSection
                    envSection
                }
                .formStyle(.grouped)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 560)
        .sheet(isPresented: $showingQuickMountManager) {
            QuickMountsManagerView()
        }
    }
    
    // MARK: - Header / Footer
    
    private var header: some View {
        HStack {
            Text("Configure Run Command")
                .font(.headline)
            Spacer()
            Text(image.displayName)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .help("Cancel without copying")
            Spacer()
            Button("Copy Command") {
                let allMounts = buildMounts()
                let config = RunConfiguration(
                    mounts: allMounts,
                    envVars: envVars.filter { !$0.key.isEmpty }
                )
                onCopy(config)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .help("Copy the configured run command to clipboard")
        }
        .padding()
    }
    
    // MARK: - Workspace
    
    private var workspaceSection: some View {
        Section("Workspace Folder") {
            HStack {
                Text(workspacePath?.path ?? "No folder selected")
                    .foregroundStyle(workspacePath == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if workspacePath != nil {
                    Button("Clear") { workspacePath = nil }
                        .help("Remove workspace mount")
                }
                Button("Browse…") { selectFolder() }
                    .help("Select your project folder to mount into the container")
            }
            if workspacePath != nil {
                TextField("Container path", text: $containerWorkspacePath)
                    .help("Path inside the container where the folder will be mounted")
            }
        }
    }
    
    // MARK: - Quick Mounts
    
    private var quickMountsSection: some View {
        Section {
            if store.mounts.isEmpty {
                Text("No quick mounts saved yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.mounts) { mount in
                    Toggle(isOn: Binding(
                        get: { enabledQuickMounts.contains(mount.id) },
                        set: { enabled in
                            if enabled { enabledQuickMounts.insert(mount.id) }
                            else { enabledQuickMounts.remove(mount.id) }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(mount.name)
                            Text("\(mount.hostPath) → \(mount.containerPath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Mount \(mount.hostPath) into the container")
                }
            }
            Button {
                showingQuickMountManager = true
            } label: {
                Label("Manage Quick Mounts…", systemImage: "gear")
            }
            .help("Create, edit, or delete saved quick mounts")
        } header: {
            Text("Quick Mounts")
        } footer: {
            Text("Quick mounts are saved and reusable across runs. Use them for credential directories like ~/.aws or ~/.claude.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Extra Mounts
    
    private var extraMountsSection: some View {
        Section("Additional Mounts") {
            ForEach($extraMounts) { $mount in
                HStack {
                    TextField("Host path", text: $mount.hostPath)
                        .textFieldStyle(.roundedBorder)
                    Text("→")
                    TextField("Container path", text: $mount.containerPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        extraMounts.removeAll { $0.id == mount.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this mount")
                }
            }
            Button {
                extraMounts.append(MountEntry())
            } label: {
                Label("Add Mount", systemImage: "plus.circle")
            }
            .help("Add a one-off volume mount")
        }
    }
    
    // MARK: - Env Vars
    
    private var envSection: some View {
        Section {
            ForEach($envVars) { $env in
                HStack {
                    TextField("KEY", text: $env.key)
                        .textFieldStyle(.roundedBorder)
                    if env.inheritFromHost {
                        Text("← from shell")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("=")
                        TextField("value", text: $env.value)
                            .textFieldStyle(.roundedBorder)
                    }
                    Toggle("Inherit", isOn: $env.inheritFromHost)
                        .toggleStyle(.checkbox)
                        .help("Inherit value from your shell environment")
                    Button {
                        envVars.removeAll { $0.id == env.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this environment variable")
                }
            }
            HStack {
                Button {
                    envVars.append(EnvVar())
                } label: {
                    Label("Add Variable", systemImage: "plus.circle")
                }
                .help("Add an environment variable")
                Spacer()
                Menu("Presets") {
                    ForEach(envPresets, id: \.0) { name, keys in
                        Button(name) {
                            let existing = Set(envVars.map(\.key))
                            for key in keys where !existing.contains(key) {
                                envVars.append(EnvVar(key: key, inheritFromHost: true))
                            }
                        }
                    }
                }
                .help("Add common environment variable presets")
            }
        } header: {
            Text("Environment Variables")
        } footer: {
            Text("\"Inherit\" passes -e KEY so the container inherits the value from the shell where you paste the command.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your project folder"
        if panel.runModal() == .OK {
            workspacePath = panel.url
        }
    }
    
    private func buildMounts() -> [MountPair] {
        var result: [MountPair] = []
        if let wp = workspacePath {
            result.append(MountPair(hostPath: wp.path, containerPath: containerWorkspacePath))
        }
        for qm in store.mounts where enabledQuickMounts.contains(qm.id) {
            result.append(MountPair(hostPath: qm.hostPath, containerPath: qm.containerPath))
        }
        for m in extraMounts where !m.hostPath.isEmpty && !m.containerPath.isEmpty {
            result.append(MountPair(hostPath: m.hostPath, containerPath: m.containerPath))
        }
        return result
    }
}

// MARK: - Supporting Types

struct RunConfiguration {
    var mounts: [MountPair]
    var envVars: [EnvVar]
}

struct MountPair {
    var hostPath: String
    var containerPath: String
}

struct MountEntry: Identifiable {
    let id = UUID()
    var hostPath = ""
    var containerPath = ""
}

struct EnvVar: Identifiable {
    let id = UUID()
    var key = ""
    var value = ""
    var inheritFromHost = false
    
    init(key: String = "", value: String = "", inheritFromHost: Bool = false) {
        self.key = key
        self.value = value
        self.inheritFromHost = inheritFromHost
    }
}
