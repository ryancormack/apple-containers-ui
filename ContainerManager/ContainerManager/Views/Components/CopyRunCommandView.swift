import SwiftUI

struct CopyRunCommandView: View {
    let image: ImageInfo
    let onCopy: (String) -> Void
    let onCancel: () -> Void
    
    @State private var containerName: String = ""
    @State private var selectedPathIds: Set<UUID> = []
    
    private var availablePaths: [MountPath] {
        AppConfiguration.shared.mountPaths
    }
    
    private var generatedCommand: String {
        buildRunCommand()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Copy Run Command")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    TextField("Container name (optional)", text: $containerName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Container Name")
                }
                
                Section {
                    if availablePaths.isEmpty {
                        Text("No mount paths configured. Add paths in Settings.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(availablePaths) { mountPath in
                            Toggle(isOn: Binding(
                                get: { selectedPathIds.contains(mountPath.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedPathIds.insert(mountPath.id)
                                    } else {
                                        selectedPathIds.remove(mountPath.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mountPath.name)
                                        .fontWeight(.medium)
                                    Text(mountPath.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Mount Paths")
                }
                
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(generatedCommand)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(height: 60)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } header: {
                    Text("Command Preview")
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Copy to Clipboard") {
                    onCopy(generatedCommand)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    private func buildRunCommand() -> String {
        var components: [String] = [AppConfiguration.shared.cliPath, "run", "-it"]
        
        if !containerName.trimmingCharacters(in: .whitespaces).isEmpty {
            components.append("--name")
            components.append(containerName.trimmingCharacters(in: .whitespaces))
        }
        
        let selectedPaths = availablePaths.filter { selectedPathIds.contains($0.id) }
        for mountPath in selectedPaths {
            components.append("-v")
            components.append("\"\(mountPath.path)\":\"\(mountPath.path)\"")
        }
        
        components.append(image.id)
        components.append("/bin/sh")
        
        return components.joined(separator: " ")
    }
}
