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
        VStack(spacing: 0) {
            HStack {
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
        .searchable(text: $searchText, prompt: "Search images...")
        .navigationTitle("Images")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadImages() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadImages()
        }
        .confirmationDialog("Remove Image?", isPresented: $showingRemoveConfirmation, presenting: imageToRemove) { image in
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeImage(image) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { image in
            Text("Permanently remove '\(image.displayName)'?")
        }
        .sheet(isPresented: $showingInspect) {
            InspectView(title: "Image Inspect", jsonData: inspectData)
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
