import SwiftUI

struct QuickMountsManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = QuickMountStore.shared
    @State private var newName = ""
    @State private var newHostPath = ""
    @State private var newContainerPath = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Quick Mounts")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .help("Close quick mounts manager")
            }
            .padding()
            
            Divider()
            
            List {
                Section("Saved Quick Mounts") {
                    if store.mounts.isEmpty {
                        Text("No quick mounts yet. Add one below or use a suggestion.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.mounts) { mount in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mount.name).fontWeight(.medium)
                                Text("\(mount.hostPath) → \(mount.containerPath)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                store.delete(mount)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete this quick mount")
                        }
                    }
                }
                
                Section("Add New") {
                    TextField("Name (e.g. AWS Credentials)", text: $newName)
                    TextField("Host path (e.g. ~/.aws)", text: $newHostPath)
                    TextField("Container path (e.g. /root/.aws)", text: $newContainerPath)
                    Button("Add") {
                        store.add(QuickMount(name: newName, hostPath: newHostPath, containerPath: newContainerPath))
                        newName = ""
                        newHostPath = ""
                        newContainerPath = ""
                    }
                    .disabled(newName.isEmpty || newHostPath.isEmpty || newContainerPath.isEmpty)
                    .help("Save this quick mount")
                }
                
                Section("Suggestions") {
                    ForEach(QuickMount.builtInSuggestions, id: \.0) { name, host, container in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                Text("\(host) → \(container)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.mounts.contains(where: { $0.hostPath == host }) {
                                Text("Added")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Add") {
                                    store.add(QuickMount(name: name, hostPath: host, containerPath: container))
                                }
                                .help("Add \(name) as a quick mount")
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 480, height: 440)
    }
}
