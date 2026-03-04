import SwiftUI

struct InspectView: View {
    let title: String
    let jsonData: String
    @Environment(\.dismiss) private var dismiss
    @State private var showRawJSON = false
    
    private var summary: ImageSummary? {
        guard let data = jsonData.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let obj = arr.first
        else { return nil }
        return ImageSummary(from: obj)
    }
    
    private var prettyJSON: String {
        guard let data = jsonData.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8)
        else { return jsonData }
        return str
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Toggle("Raw JSON", isOn: $showRawJSON)
                    .toggleStyle(.checkbox)
                    .help("Show full raw JSON output")
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prettyJSON, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy JSON to clipboard")
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .help("Close inspector")
            }
            .padding()
            
            Divider()
            
            if showRawJSON {
                ScrollView([.horizontal, .vertical]) {
                    Text(prettyJSON)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else if let summary {
                summaryView(summary)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(prettyJSON)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .frame(width: 700, height: 500)
    }
    
    private func summaryView(_ s: ImageSummary) -> some View {
        List {
            if let name = s.name {
                Section("Image") {
                    row("Name", name)
                }
            }
            
            Section("Variants") {
                ForEach(s.variants) { v in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(v.platform)
                                .fontWeight(.medium)
                            Spacer()
                            Text(ByteFormatter.format(v.size))
                                .foregroundStyle(.secondary)
                        }
                        if let cmd = v.cmd {
                            row("CMD", cmd)
                        }
                        if let entrypoint = v.entrypoint {
                            row("Entrypoint", entrypoint)
                        }
                        if !v.env.isEmpty {
                            Text("Env")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(v.env, id: \.self) { e in
                                Text(e)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        if !v.labels.isEmpty {
                            Text("Labels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(v.labels.sorted(by: { $0.key < $1.key })), id: \.key) { k, val in
                                Text("\(k)=\(val)")
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        if let created = v.created {
                            row("Created", created)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

// MARK: - Summary Model

private struct ImageSummary {
    let name: String?
    let variants: [VariantSummary]
    
    init(from dict: [String: Any]) {
        name = dict["name"] as? String
        let rawVariants = dict["variants"] as? [[String: Any]] ?? []
        variants = rawVariants.compactMap { VariantSummary(from: $0) }
    }
}

private struct VariantSummary: Identifiable {
    let id = UUID()
    let platform: String
    let size: Int64
    let cmd: String?
    let entrypoint: String?
    let env: [String]
    let labels: [String: String]
    let created: String?
    
    init?(from dict: [String: Any]) {
        let p = dict["platform"] as? [String: Any] ?? [:]
        let os = p["os"] as? String ?? "unknown"
        let arch = p["architecture"] as? String ?? "unknown"
        guard os != "unknown" || arch != "unknown" else { return nil }
        
        let variant = p["variant"] as? String
        platform = variant != nil ? "\(os)/\(arch)/\(variant!)" : "\(os)/\(arch)"
        size = (dict["size"] as? NSNumber)?.int64Value ?? 0
        
        let config = dict["config"] as? [String: Any] ?? [:]
        let inner = config["config"] as? [String: Any] ?? [:]
        
        cmd = (inner["Cmd"] as? [String])?.joined(separator: " ")
        entrypoint = (inner["Entrypoint"] as? [String])?.joined(separator: " ")
        env = inner["Env"] as? [String] ?? []
        labels = inner["Labels"] as? [String: String] ?? [:]
        created = config["created"] as? String
    }
}
