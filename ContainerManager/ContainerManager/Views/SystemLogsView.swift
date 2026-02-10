import SwiftUI

struct SystemLogsView: View {
    @State private var viewModel = SystemLogsViewModel()
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: $viewModel.followEnabled) {
                    Label("Follow", systemImage: "arrow.down.circle")
                }
                .onChange(of: viewModel.followEnabled) { _, enabled in
                    if enabled && viewModel.isStreaming {
                        Task { await viewModel.startStreaming() }
                    }
                }
                
                Toggle(isOn: $autoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                }
                
                Spacer()
                
                Button {
                    viewModel.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.logs.isEmpty)
                
                Text("\(viewModel.logs.count) lines")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.startStreaming() }
                    }
                } else if viewModel.logs.isEmpty && !viewModel.isStreaming {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No System Logs",
                        message: "Click refresh to load system logs"
                    )
                } else {
                    logContent
                }
            }
        }
        .navigationTitle("System Logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.startStreaming() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isStreaming)
            }
        }
        .task {
            await viewModel.startStreaming()
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }
    
    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .foregroundStyle(.tertiary)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 50, alignment: .trailing)
                            
                            Text(line)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                        .id(index)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.logs.count) { _, _ in
                if autoScroll, let lastIndex = viewModel.logs.indices.last {
                    withAnimation {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SystemLogsView()
    }
}
