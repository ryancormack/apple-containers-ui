import SwiftUI

struct ImagesListView: View {
    @State private var viewModel = ImagesViewModel()
    @State private var searchText = ""
    @State private var showingRemoveConfirmation = false
    @State private var showingInspect = false
    @State private var showingRunDialog = false
    @State private var inspectData = ""
    @State private var imageToRemove: ImageInfo?
    @State private var imageToRun: ImageInfo?
    @State private var containerName = ""
    @State private var showingPullDialog = false
    @State private var pullImageReference = ""
    @State private var imageForConfig: ImageInfo?
    @State private var showingCopiedNotice = false
    @State private var showingPruneConfirmation = false
    @State private var showingPruneNotice = false
    
    var filteredImages: [ImageInfo] {
        if searchText.isEmpty {
            return viewModel.images
        }
        return viewModel.images.filter { image in
            image.name.localizedCaseInsensitiveContains(searchText) ||
            image.tag.localizedCaseInsensitiveContains(searchText) ||
            image.digest.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        mainContent
            .overlay { noticeOverlay }
            .searchable(text: $searchText, prompt: "Search images...")
            .navigationTitle("Images")
            .toolbar { toolbarContent }
            .task {
                await viewModel.loadImages()
            }
            .modifier(ImageDialogsModifier(
                showingRemoveConfirmation: $showingRemoveConfirmation,
                showingPruneConfirmation: $showingPruneConfirmation,
                showingInspect: $showingInspect,
                showingPruneNotice: $showingPruneNotice,
                showingPullDialog: $showingPullDialog,
                showingRunDialog: $showingRunDialog,
                showingCopiedNotice: $showingCopiedNotice,
                imageToRemove: $imageToRemove,
                imageToRun: $imageToRun,
                imageForConfig: $imageForConfig,
                pullImageReference: $pullImageReference,
                containerName: $containerName,
                inspectData: inspectData,
                viewModel: viewModel
            ))
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.isPulling {
                    ProgressView()
                        .controlSize(.small)
                    Text("Pulling image…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Spacer()
                
                Text("\(filteredImages.count) image(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            Group {
                if viewModel.isLoading && viewModel.images.isEmpty {
                    ProgressView("Loading images...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadImages() }
                    }
                } else if filteredImages.isEmpty {
                    EmptyStateView(
                        icon: "photo.stack",
                        title: "No Images",
                        message: searchText.isEmpty ? "No container images are available locally" : "No images match '\(searchText)'"
                    )
                } else {
                    imageTable
                }
            }
        }
    }
    
    @ViewBuilder
    private var noticeOverlay: some View {
        if showingCopiedNotice {
            Text("Command copied to clipboard")
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showingCopiedNotice = false }
                    }
                }
        }
        if showingPruneNotice {
            Text("Images pruned")
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
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingPruneConfirmation = true
            } label: {
                Label("Prune Images", systemImage: "scissors")
            }
            .help("Remove unused images")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingPullDialog = true
            } label: {
                Label("Pull Image", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.isPulling)
            .help("Pull an image from a registry")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await viewModel.loadImages() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .help("Refresh image list")
        }
    }
    
    private var imageTable: some View {
        Table(filteredImages, selection: $viewModel.selectedImage) {
            TableColumn("Repository") { image in
                Text(image.name)
                    .fontWeight(.medium)
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Tag") { image in
                Text(image.tag)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)
            
            TableColumn("Digest") { image in
                Text(image.digest.prefix(16))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("Size") { image in
                if let size = image.size {
                    Text(ByteFormatter.format(size))
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Actions") { image in
                HStack(spacing: 4) {
                    Button {
                        imageForConfig = image
                    } label: {
                        Image(systemName: "terminal.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Configure and copy interactive run command")
                    
                    Button {
                        imageToRun = image
                        showingRunDialog = true
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.green)
                    .help("Run container")
                    
                    Button {
                        Task {
                            do {
                                inspectData = try await viewModel.inspectImage(image.id)
                                showingInspect = true
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Image(systemName: "info.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Inspect image")
                    
                    Button {
                        imageToRemove = image
                        showingRemoveConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Remove image")
                }
            }
            .width(ideal: 120)
        }
    }
}

#Preview {
    NavigationStack {
        ImagesListView()
    }
}

private struct ImageDialogsModifier: ViewModifier {
    @Binding var showingRemoveConfirmation: Bool
    @Binding var showingPruneConfirmation: Bool
    @Binding var showingInspect: Bool
    @Binding var showingPruneNotice: Bool
    @Binding var showingPullDialog: Bool
    @Binding var showingRunDialog: Bool
    @Binding var showingCopiedNotice: Bool
    @Binding var imageToRemove: ImageInfo?
    @Binding var imageToRun: ImageInfo?
    @Binding var imageForConfig: ImageInfo?
    @Binding var pullImageReference: String
    @Binding var containerName: String
    var inspectData: String
    var viewModel: ImagesViewModel
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("Remove Image?", isPresented: $showingRemoveConfirmation, presenting: imageToRemove) { image in
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeImage(image) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { image in
                Text("Permanently remove '\(image.displayName)'?")
            }
            .confirmationDialog("Prune Images?", isPresented: $showingPruneConfirmation) {
                Button("Prune Unused") {
                    Task {
                        await viewModel.pruneImages(all: false)
                        withAnimation { showingPruneNotice = true }
                    }
                }
                Button("Prune All Unused", role: .destructive) {
                    Task {
                        await viewModel.pruneImages(all: true)
                        withAnimation { showingPruneNotice = true }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove unused images? This cannot be undone.")
            }
            .sheet(isPresented: $showingInspect) {
                InspectView(title: "Image Inspect", jsonData: inspectData)
            }
            .sheet(item: $imageForConfig) { image in
                RunConfigurationSheet(image: image) { config in
                    viewModel.copyInteractiveRunCommand(for: image, config: config)
                    withAnimation { showingCopiedNotice = true }
                }
            }
            .alert("Pull Image", isPresented: $showingPullDialog) {
                TextField("Image reference (e.g. alpine:latest)", text: $pullImageReference)
                Button("Pull") {
                    let ref = pullImageReference
                    pullImageReference = ""
                    Task { await viewModel.pullImage(reference: ref) }
                }
                .disabled(pullImageReference.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {
                    pullImageReference = ""
                }
            } message: {
                Text("Enter the image name and tag to pull from a registry.")
            }
            .alert("Run Container", isPresented: $showingRunDialog, presenting: imageToRun) { image in
                TextField("Container name (optional)", text: $containerName)
                Button("Run") {
                    Task { await viewModel.runImage(image, name: containerName.isEmpty ? nil : containerName) }
                    containerName = ""
                }
                Button("Cancel", role: .cancel) {
                    containerName = ""
                }
            } message: { image in
                Text("Run container from '\(image.displayName)'")
            }
    }
}
