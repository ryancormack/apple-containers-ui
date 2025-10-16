# Apple Container Mac Desktop App - Implementation Plan

## Project Overview

Build a native macOS desktop application to manage Apple Containers with a graphical interface. The app will provide an easy way to view running containers, inspect logs, stop/kill containers, and manage images without memorizing CLI commands.

**Target User**: Developers familiar with web/TypeScript/.NET who want a GUI for Apple's container system  
**Platform**: macOS with Apple Silicon (required by Apple Container)  
**Tech Stack**: SwiftUI + Containerization Swift Package  

---

## Technical Architecture

### Integration Approach

Use the **Containerization Swift Package** directly in your SwiftUI app. This is Apple's official Swift package that provides APIs for managing Linux containers on macOS using Virtualization.framework.

**Package URL**: `https://github.com/apple/containerization`

**Benefits:**
- Native Swift APIs with proper type safety
- Better performance than wrapping CLI commands
- Direct access to container operations
- Proper async/await integration
- Access to streaming APIs for logs

### System Requirements

```
Required:
- Mac with Apple Silicon (M1 or later)
- macOS 26 beta (or later when released)
- Xcode 26 beta (or later when released)
- Linux kernel for containers (can be fetched automatically)
```

**Important Notes:**
- The Containerization package requires macOS 26+ and is currently in beta
- Version 0.1.0+ guarantees source stability within minor versions only
- A Linux kernel is required for spawning VMs (can use Kata Containers kernel)

### Project Structure

```
ContainerManagerApp/
├── App/
│   └── ContainerManagerApp.swift    # App entry point
├── Models/
│   ├── ContainerInfo.swift          # Container model
│   ├── ImageInfo.swift              # Image model
│   ├── ContainerState.swift         # Container state enum
│   └── AppError.swift               # Error types
├── Services/
│   ├── ContainerService.swift       # Container operations
│   └── ImageService.swift           # Image operations
├── ViewModels/
│   ├── ContainersViewModel.swift    # Container list logic
│   ├── ImagesViewModel.swift        # Image list logic
│   └── LogsViewModel.swift          # Logs viewer logic
├── Views/
│   ├── ContentView.swift            # Main app layout
│   ├── ContainersListView.swift     # Container list UI
│   ├── ImagesListView.swift         # Images list UI
│   ├── LogsView.swift               # Logs viewer UI
│   └── Components/
│       ├── EmptyStateView.swift     # Reusable empty state
│       └── ErrorView.swift          # Reusable error display
└── Utilities/
    ├── ByteFormatter.swift          # Format file sizes
    └── DateFormatter+Extensions.swift
```

---

## Implementation Phases

### Phase 1: Project Setup & Dependencies

**Tasks:**

1. **Create new SwiftUI macOS app project in Xcode**
   ```
   Xcode → New Project → macOS → App
   Product Name: ContainerManager
   Interface: SwiftUI
   Language: Swift
   Minimum deployment: macOS 14.0+ (will need 26+ for runtime)
   ```

2. **Add Containerization package dependency**
   - In Xcode: File → Add Package Dependencies
   - Enter URL: `https://github.com/apple/containerization`
   - Select version: Up to Next Minor from 0.1.0
   - Add to your target

3. **Set up project structure**
   - Create groups: Models, Services, ViewModels, Views, Views/Components, Utilities, App
   - Right-click project → New Group for each

4. **Configure app entitlements and settings**
   - Target → Signing & Capabilities
   - Ensure proper team is selected
   - Note: App Sandbox may need to be disabled or configured for VM operations
   - Set minimum deployment to macOS 14.0 (but note runtime requires 26+)

5. **Fetch default kernel (required for containers)**
   ```bash
   # In terminal, navigate to a suitable location
   # Download Kata Containers kernel or use containerization's fetch
   # See: https://github.com/kata-containers/kata-containers/releases/
   ```

**Deliverable**: Empty SwiftUI app that builds successfully with Containerization package imported

**Verification**:
```swift
// Add to ContentView to test import
import Containerization

// If this compiles, you're good to go
```

---

### Phase 2: Core Models & Error Handling

**Create `Models/AppError.swift`**:

```swift
import Foundation

struct AppError: Error, LocalizedError {
    let message: String
    let underlyingError: Error?
    
    init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        if let underlying = underlyingError {
            return "\(message): \(underlying.localizedDescription)"
        }
        return message
    }
}
```

**Create `Models/ContainerState.swift`**:

```swift
import SwiftUI

enum ContainerState: String, Codable, CaseIterable {
    case running
    case stopped
    case paused
    case created
    case exited
    case unknown
    
    var displayColor: Color {
        switch self {
        case .running:
            return .green
        case .stopped, .exited:
            return .gray
        case .paused:
            return .yellow
        case .created:
            return .blue
        case .unknown:
            return .secondary
        }
    }
    
    var systemImage: String {
        switch self {
        case .running:
            return "play.circle.fill"
        case .stopped, .exited:
            return "stop.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .created:
            return "circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}
```

**Create `Models/ContainerInfo.swift`**:

```swift
import Foundation
import Containerization

struct ContainerInfo: Identifiable {
    let id: String
    let name: String
    let image: String
    let state: ContainerState
    let ipAddress: String?
    let createdAt: Date?
    let command: [String]?
    
    // Initialize from Containerization types
    // Note: Adjust based on actual Container type from package
    init(id: String, name: String, image: String, state: ContainerState, 
         ipAddress: String? = nil, createdAt: Date? = nil, command: [String]? = nil) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.ipAddress = ipAddress
        self.createdAt = createdAt
        self.command = command
    }
}
```

**Create `Models/ImageInfo.swift`**:

```swift
import Foundation

struct ImageInfo: Identifiable {
    let id: String
    let name: String
    let tag: String
    let digest: String
    let size: Int64?
    let createdAt: Date?
    
    var displayName: String {
        "\(name):\(tag)"
    }
}
```

**Create `Utilities/ByteFormatter.swift`**:

```swift
import Foundation

enum ByteFormatter {
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
```

**Deliverable**: Complete model layer with proper type definitions

---

### Phase 3: Container Service Layer

**Create `Services/ContainerService.swift`**:

```swift
import Foundation
import Containerization
import ContainerizationOCI

actor ContainerService {
    private let containerManager: ContainerManager
    private let kernelURL: URL
    
    init(kernelPath: String) throws {
        // Initialize kernel configuration
        self.kernelURL = URL(fileURLWithPath: kernelPath)
        
        // Create kernel object
        let kernel = Kernel(
            path: kernelURL,
            platform: .linuxArm
        )
        
        // Initialize ContainerManager
        // Note: Adjust based on actual API - may need initfsReference
        self.containerManager = try ContainerManager(kernel: kernel)
    }
    
    /// List all containers
    func listContainers() async throws -> [ContainerInfo] {
        do {
            // Get containers from ContainerManager
            // Note: Adjust based on actual API
            let containers = try await containerManager.listContainers()
            
            // Convert to our model
            return containers.map { container in
                ContainerInfo(
                    id: container.id,
                    name: container.name ?? container.id,
                    image: container.imageName ?? "unknown",
                    state: mapState(container.state),
                    ipAddress: container.ipAddress
                )
            }
        } catch {
            throw AppError(
                message: "Failed to list containers",
                underlyingError: error
            )
        }
    }
    
    /// Get specific container by ID
    func getContainer(id: String) async throws -> ContainerInfo? {
        let containers = try await listContainers()
        return containers.first { $0.id == id }
    }
    
    /// Stop a container gracefully
    func stopContainer(id: String) async throws {
        do {
            // Note: Adjust based on actual API
            try await containerManager.stop(containerId: id)
        } catch {
            throw AppError(
                message: "Failed to stop container",
                underlyingError: error
            )
        }
    }
    
    /// Kill a container forcefully
    func killContainer(id: String) async throws {
        do {
            // Note: Adjust based on actual API
            try await containerManager.kill(containerId: id)
        } catch {
            throw AppError(
                message: "Failed to kill container",
                underlyingError: error
            )
        }
    }
    
    /// Stream logs from a container
    func streamLogs(containerId: String) async throws -> AsyncStream<String> {
        // Note: Adjust based on actual API for log streaming
        return AsyncStream { continuation in
            Task {
                do {
                    // Get log stream from container
                    let logStream = try await containerManager.logs(containerId: containerId)
                    
                    for await logLine in logStream {
                        continuation.yield(logLine)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    /// Remove a container
    func removeContainer(id: String) async throws {
        do {
            try await containerManager.remove(containerId: id)
        } catch {
            throw AppError(
                message: "Failed to remove container",
                underlyingError: error
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func mapState(_ state: Any) -> ContainerState {
        // Map Containerization state to our enum
        // Note: Adjust based on actual state type from package
        return .unknown
    }
}
```

**Important Implementation Notes:**

The above code contains placeholder method names that need to be verified against the actual Containerization API. To implement correctly:

1. **Study the API documentation**: Visit `https://apple.github.io/containerization/documentation/`
2. **Examine example code**: Look at `Sources/cctl/RunCommand.swift` and other examples in the package
3. **Check ContainerManager API**: Determine exact method names and parameters
4. **Verify async patterns**: Ensure proper use of async/await with the package APIs

**Key areas to verify:**
- How to initialize `ContainerManager` (may need initfs reference)
- Actual method names for listing, stopping, killing containers
- How container state is represented
- How to access container logs
- Proper error handling patterns

**Deliverable**: Working service layer that can interact with containers using Containerization APIs

---

### Phase 4: Image Service Layer

**Create `Services/ImageService.swift`**:

```swift
import Foundation
import Containerization
import ContainerizationOCI

actor ImageService {
    private let imageStore: ImageStore
    
    init() throws {
        // Initialize ImageStore from Containerization
        self.imageStore = try ImageStore()
    }
    
    /// List all local images
    func listImages() async throws -> [ImageInfo] {
        do {
            let images = try await imageStore.list()
            
            return images.map { image in
                ImageInfo(
                    id: image.digest,
                    name: image.reference.name,
                    tag: image.reference.tag ?? "latest",
                    digest: image.digest,
                    size: image.size,
                    createdAt: nil
                )
            }
        } catch {
            throw AppError(
                message: "Failed to list images",
                underlyingError: error
            )
        }
    }
    
    /// Get specific image by reference
    func getImage(reference: String) async throws -> ImageInfo? {
        let images = try await listImages()
        return images.first { $0.displayName == reference }
    }
    
    /// Pull an image from a registry
    func pullImage(reference: String, onProgress: @escaping (Double) -> Void) async throws {
        do {
            // Note: Adjust based on actual API for pulling images
            let ref = try Reference.parse(reference)
            
            // Pull with progress tracking
            try await imageStore.pull(reference: ref) { progress in
                onProgress(progress)
            }
        } catch {
            throw AppError(
                message: "Failed to pull image",
                underlyingError: error
            )
        }
    }
    
    /// Remove an image
    func removeImage(reference: String) async throws {
        do {
            let ref = try Reference.parse(reference)
            try await imageStore.remove(reference: ref)
        } catch {
            throw AppError(
                message: "Failed to remove image",
                underlyingError: error
            )
        }
    }
    
    /// Tag an image
    func tagImage(source: String, target: String) async throws {
        do {
            let sourceRef = try Reference.parse(source)
            let targetRef = try Reference.parse(target)
            try await imageStore.tag(source: sourceRef, target: targetRef)
        } catch {
            throw AppError(
                message: "Failed to tag image",
                underlyingError: error
            )
        }
    }
}
```

**Deliverable**: Working image management service

---

### Phase 5: View Models

**Create `ViewModels/ContainersViewModel.swift`**:

```swift
import SwiftUI
import Observation

@Observable
final class ContainersViewModel {
    var containers: [ContainerInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedContainer: ContainerInfo?
    var autoRefreshEnabled = false
    
    private var containerService: ContainerService?
    private var refreshTask: Task<Void, Never>?
    
    init() {
        // Initialize service with kernel path
        // TODO: Make kernel path configurable
        do {
            self.containerService = try ContainerService(
                kernelPath: "/path/to/kernel/vmlinux"
            )
        } catch {
            self.errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    func loadContainers() async {
        guard let service = containerService else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            containers = try await service.listContainers()
        } catch {
            errorMessage = error.localizedDescription
            containers = []
        }
        
        isLoading = false
    }
    
    func startAutoRefresh(interval: TimeInterval = 3.0) {
        stopAutoRefresh()
        autoRefreshEnabled = true
        
        refreshTask = Task {
            while !Task.isCancelled && autoRefreshEnabled {
                await loadContainers()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    func stopAutoRefresh() {
        autoRefreshEnabled = false
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func stopContainer(_ container: ContainerInfo) async {
        guard let service = containerService else { return }
        
        do {
            try await service.stopContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to stop container: \(error.localizedDescription)"
        }
    }
    
    func killContainer(_ container: ContainerInfo) async {
        guard let service = containerService else { return }
        
        do {
            try await service.killContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to kill container: \(error.localizedDescription)"
        }
    }
    
    func removeContainer(_ container: ContainerInfo) async {
        guard let service = containerService else { return }
        
        do {
            try await service.removeContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to remove container: \(error.localizedDescription)"
        }
    }
    
    deinit {
        stopAutoRefresh()
    }
}
```

**Create `ViewModels/ImagesViewModel.swift`**:

```swift
import SwiftUI
import Observation

@Observable
final class ImagesViewModel {
    var images: [ImageInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedImage: ImageInfo?
    
    private var imageService: ImageService?
    
    init() {
        do {
            self.imageService = try ImageService()
        } catch {
            self.errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    func loadImages() async {
        guard let service = imageService else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            images = try await service.listImages()
        } catch {
            errorMessage = error.localizedDescription
            images = []
        }
        
        isLoading = false
    }
    
    func removeImage(_ image: ImageInfo) async {
        guard let service = imageService else { return }
        
        do {
            try await service.removeImage(reference: image.displayName)
            await loadImages()
        } catch {
            errorMessage = "Failed to remove image: \(error.localizedDescription)"
        }
    }
}
```

**Create `ViewModels/LogsViewModel.swift`**:

```swift
import SwiftUI
import Observation

@Observable
final class LogsViewModel {
    var logs: [String] = []
    var isLoading = false
    var errorMessage: String?
    var isFollowing = false
    
    private var containerService: ContainerService?
    private var streamTask: Task<Void, Never>?
    
    init(kernelPath: String) {
        do {
            self.containerService = try ContainerService(kernelPath: kernelPath)
        } catch {
            self.errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    func loadLogs(containerId: String, follow: Bool = false) async {
        guard let service = containerService else { return }
        
        isLoading = true
        errorMessage = nil
        isFollowing = follow
        logs = []
        
        streamTask?.cancel()
        
        do {
            let logStream = try await service.streamLogs(containerId: containerId)
            
            streamTask = Task {
                for await logLine in logStream {
                    if Task.isCancelled { break }
                    logs.append(logLine)
                }
                isFollowing = false
            }
            
            await streamTask?.value
        } catch {
            errorMessage = "Failed to load logs: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func stopFollowing() {
        streamTask?.cancel()
        isFollowing = false
    }
    
    func clearLogs() {
        logs = []
    }
    
    deinit {
        streamTask?.cancel()
    }
}
```

**Deliverable**: Complete view model layer with state management

---

### Phase 6: Reusable UI Components

**Create `Views/Components/EmptyStateView.swift`**:

```swift
import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        icon: String,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
```

**Create `Views/Components/ErrorView.swift`**:

```swift
import SwiftUI

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            
            VStack(spacing: 8) {
                Text("Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
```

**Deliverable**: Reusable UI components

---

### Phase 7: Container List View

**Create `Views/ContainersListView.swift`**:

```swift
import SwiftUI

struct ContainersListView: View {
    @State private var viewModel = ContainersViewModel()
    @State private var searchText = ""
    @State private var showingStopConfirmation = false
    @State private var showingKillConfirmation = false
    @State private var showingRemoveConfirmation = false
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
            // Toolbar
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
                
                Spacer()
                
                Text("\(filteredContainers.count) container(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            Group {
                if viewModel.isLoading && viewModel.containers.isEmpty {
                    ProgressView("Loading containers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadContainers()
                        }
                    }
                } else if filteredContainers.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No Containers",
                        message: searchText.isEmpty
                            ? "No containers are currently available"
                            : "No containers match '\(searchText)'"
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
                    Task {
                        await viewModel.loadContainers()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadContainers()
        }
        .confirmationDialog(
            "Stop Container?",
            isPresented: $showingStopConfirmation,
            presenting: containerToAct
        ) { container in
            Button("Stop") {
                Task {
                    await viewModel.stopContainer(container)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Stop '\(container.name)' gracefully?")
        }
        .confirmationDialog(
            "Kill Container?",
            isPresented: $showingKillConfirmation,
            presenting: containerToAct
        ) { container in
            Button("Kill", role: .destructive) {
                Task {
                    await viewModel.killContainer(container)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Force kill '\(container.name)'? This cannot be undone.")
        }
        .confirmationDialog(
            "Remove Container?",
            isPresented: $showingRemoveConfirmation,
            presenting: containerToAct
        ) { container in
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.removeContainer(container)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { container in
            Text("Permanently remove '\(container.name)'?")
        }
    }
    
    private var containerTable: some View {
        Table(filteredContainers, selection: $viewModel.selectedContainer) {
            TableColumn("Status", value: \.state.rawValue) { container in
                HStack(spacing: 6) {
                    Image(systemName: container.state.systemImage)
                        .foregroundStyle(container.state.displayColor)
                    Text(container.state.rawValue.capitalized)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Name", value: \.name) { container in
                Text(container.name)
                    .fontWeight(.medium)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Image", value: \.image) { container in
                Text(container.image)
                    .foregroundStyle(.secondary)
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("ID", value: \.id) { container in
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
                    
                    NavigationLink {
                        LogsView(
                            containerId: container.id,
                            containerName: container.name
                        )
                    } label: {
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
```

**Deliverable**: Fully functional container list view with actions

---

### Phase 8: Logs View

**Create `Views/LogsView.swift`**:

```swift
import SwiftUI

struct LogsView: View {
    let containerId: String
    let containerName: String
    
    @State private var viewModel: LogsViewModel
    @State private var autoScroll = true
    
    init(containerId: String, containerName: String) {
        self.containerId = containerId
        self.containerName = containerName
        // TODO: Pass actual kernel path from app configuration
        self._viewModel = State(wrappedValue: LogsViewModel(
            kernelPath: "/path/to/kernel/vmlinux"
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Toggle(isOn: $autoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                }
                
                Spacer()
                
                if viewModel.isFollowing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Following...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Logs content
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading logs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadLogs(containerId: containerId)
                        }
                    }
                } else if viewModel.logs.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Logs",
                        message: "This container hasn't produced any logs yet"
                    )
                } else {
                    logsContent
                }
            }
        }
        .navigationTitle("Logs: \(containerName)")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.logs.isEmpty)
                
                Button {
                    Task {
                        if viewModel.isFollowing {
                            viewModel.stopFollowing()
                        } else {
                            await viewModel.loadLogs(
                                containerId: containerId,
                                follow: true
                            )
                        }
                    }
                } label: {
                    Label(
                        viewModel.isFollowing ? "Stop Following" : "Follow",
                        systemImage: viewModel.isFollowing ? "pause.fill" : "play.fill"
                    )
                }
            }
        }
        .task {
            await viewModel.loadLogs(containerId: containerId)
        }
    }
    
    private var logsContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 50, alignment: .trailing)
                            
                            Text(log)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 12)
                        .id(index)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: viewModel.logs.count) { _, count in
                if autoScroll && count > 0 {
                    withAnimation {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LogsView(
            containerId: "abc123",
            containerName: "test-container"
        )
    }
}
```

**Deliverable**: Functional logs viewer with streaming support

---

### Phase 9: Images List View

**Create `Views/ImagesListView.swift`**:

```swift
import SwiftUI

struct ImagesListView: View {
    @State private var viewModel = ImagesViewModel()
    @State private var searchText = ""
    @State private var showingRemoveConfirmation = false
    @State private var imageToRemove: ImageInfo?
    
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
            // Toolbar
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
            
            // Content
            Group {
                if viewModel.isLoading && viewModel.images.isEmpty {
                    ProgressView("Loading images...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadImages()
                        }
                    }
                } else if filteredImages.isEmpty {
                    EmptyStateView(
                        icon: "photo.stack",
                        title: "No Images",
                        message: searchText.isEmpty
                            ? "No container images are available locally"
                            : "No images match '\(searchText)'"
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
                    Task {
                        await viewModel.loadImages()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadImages()
        }
        .confirmationDialog(
            "Remove Image?",
            isPresented: $showingRemoveConfirmation,
            presenting: imageToRemove
        ) { image in
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.removeImage(image)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { image in
            Text("Permanently remove '\(image.displayName)'?")
        }
    }
    
    private var imageTable: some View {
        Table(filteredImages, selection: $viewModel.selectedImage) {
            TableColumn("Repository", value: \.name) { image in
                Text(image.name)
                    .fontWeight(.medium)
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Tag", value: \.tag) { image in
                Text(image.tag)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)
            
            TableColumn("Digest", value: \.digest) { image in
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
            .width(ideal: 80)
        }
    }
}

#Preview {
    NavigationStack {
        ImagesListView()
    }
}
```

**Deliverable**: Functional images list view

---

### Phase 10: Main App Layout

**Create `Views/ContentView.swift`**:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem? = .containers
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .navigationTitle("Container Manager")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            // Detail view
            Group {
                switch selection {
                case .containers:
                    ContainersListView()
                case .images:
                    ImagesListView()
                case .none:
                    placeholderView
                }
            }
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("Container Manager")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Select a section from the sidebar to get started")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case containers
    case images
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        }
    }
    
    var icon: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "photo.stack"
        }
    }
}

#Preview {
    ContentView()
}
```

**Create `App/ContainerManagerApp.swift`**:

```swift
import SwiftUI

@main
struct ContainerManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Container Manager Help") {
                    // TODO: Open help documentation
                }
            }
        }
    }
}
```

**Deliverable**: Complete working application with navigation

---

### Phase 11: Configuration & Polish

**Create app configuration system**:

```swift
// Add to Utilities/AppConfiguration.swift
import Foundation

struct AppConfiguration {
    static var shared = AppConfiguration()
    
    var kernelPath: String {
        // Check user defaults first
        if let customPath = UserDefaults.standard.string(forKey: "kernelPath"),
           FileManager.default.fileExists(atPath: customPath) {
            return customPath
        }
        
        // Check standard locations
        let standardPaths = [
            "/usr/local/share/container/vmlinux",
            "/opt/kata/share/kata-containers/vmlinux.container",
            "~/Library/Application Support/ContainerManager/vmlinux"
        ]
        
        for path in standardPaths {
            let expanded = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }
        
        // Default - user will need to set this
        return "/path/to/vmlinux"
    }
    
    var autoRefreshInterval: TimeInterval {
        UserDefaults.standard.double(forKey: "autoRefreshInterval") ?? 3.0
    }
    
    func setKernelPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "kernelPath")
    }
    
    func setAutoRefreshInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: "autoRefreshInterval")
    }
}
```

**Polish tasks:**

1. **Add app icon**
   - Create 1024x1024 icon in Assets.xcassets
   - Use SF Symbol "shippingbox" as inspiration

2. **Add keyboard shortcuts**
   ```swift
   .keyboardShortcut("r", modifiers: .command) // Refresh
   .keyboardShortcut("l", modifiers: .command) // View logs
   ```

3. **Add proper loading states**
   - Ensure all async operations show progress
   - Add timeout handling for long operations

4. **Error handling improvements**
   - Add specific error messages for common failures
   - Provide actionable suggestions in error states

5. **Accessibility**
   - Add proper labels for all interactive elements
   - Ensure keyboard navigation works throughout

**Deliverable**: Polished, production-ready application

---

## Key Swift/SwiftUI Concepts for TypeScript/C# Developers

### 1. Value Types vs Reference Types
```swift
struct Container { }  // Value type (like TypeScript interfaces)
class ViewModel { }   // Reference type (like TypeScript classes)
```

### 2. Optionals (Similar to TypeScript's nullable types)
```swift
var name: String?              // Like string | null in TypeScript
let value = name ?? "default"  // Like name ?? "default" in TypeScript
if let unwrapped = name {      // Safe unwrapping
    print(unwrapped)
}
```

### 3. Async/Await (Same as TypeScript/C#)
```swift
func loadData() async throws -> Data {
    let data = try await network.fetch()
    return data
}

// Call from Task
Task {
    let data = try await loadData()
}
```

### 4. SwiftUI State Management
```swift
@State var count = 0           // Local state (like useState)
@Observable class VM { }       // Observable object (like MobX/Redux)
```

### 5. Error Handling
```swift
do {
    try await riskyOperation()
} catch {
    print("Error: \(error)")
}
```

---

## Development Workflow

### Build & Run
1. **Build**: Cmd+B
2. **Run**: Cmd+R
3. **Stop**: Cmd+.

### Debugging
- Set breakpoints by clicking line numbers
- Use `print()` statements (appear in Xcode console)
- Use LLDB debugger commands in console

### SwiftUI Previews
```swift
#Preview {
    ContainersListView()
}
```
Previews appear in canvas (Editor → Canvas)

### Testing
```swift
// Create tests in Tests folder
import XCTest

final class ContainerServiceTests: XCTestCase {
    func testListContainers() async throws {
        let service = try ContainerService(kernelPath: "/path/to/kernel")
        let containers = try await service.listContainers()
        XCTAssertNotNil(containers)
    }
}
```

---

## Critical Implementation Notes

### 1. Verify API Methods
The Containerization package API may differ from what's shown in this plan. Before implementing each service:

1. Check the official documentation
2. Look at example code in the `cctl` directory
3. Verify method signatures and return types
4. Test incrementally

### 2. Kernel Setup
You must have a Linux kernel available. Options:

**Option A: Fetch Kata Containers kernel**
```bash
# Download from GitHub releases
curl -LO https://github.com/kata-containers/kata-containers/releases/download/[VERSION]/kata-containers-[VERSION]-[ARCH].tar.xz
tar -xf kata-containers-[VERSION]-[ARCH].tar.xz
# Copy vmlinux.container to a known location
```

**Option B: Build custom kernel**
Follow instructions in the containerization repo's `kernel/` directory

### 3. Testing Strategy
Start with minimal functionality:
1. Initialize ContainerManager successfully
2. List containers (even if empty)
3. Add UI for list
4. Add one action (stop/kill)
5. Gradually add more features

### 4. Error Handling
Every Containerization API call should be wrapped in try/catch and provide helpful error messages to users.

---

## Testing Checklist

### Phase 1-3: Foundation
- [ ] App builds without errors
- [ ] Containerization package imports successfully
- [ ] Models compile correctly
- [ ] Services initialize without crashing

### Phase 4-6: Services & ViewModels
- [ ] Container service can list containers
- [ ] Image service can list images
- [ ] ViewModels load data successfully
- [ ] Error states are handled properly

### Phase 7-9: Views
- [ ] Container list displays correctly
- [ ] Images list displays correctly
- [ ] Logs view shows output
- [ ] Navigation works between views
- [ ] Search/filter functionality works

### Phase 10-11: Integration & Polish
- [ ] All features work together
- [ ] Auto-refresh updates data
- [ ] Confirmation dialogs appear
- [ ] App works in light and dark mode
- [ ] Keyboard shortcuts function
- [ ] Error messages are helpful

---

## Future Enhancements

After MVP is complete, consider adding:

### v1.1 Features
- [ ] Start/restart containers
- [ ] Pull images from registries
- [ ] Container resource usage stats
- [ ] Export logs to file
- [ ] Custom kernel configuration UI

### v1.2 Features
- [ ] Build images from Dockerfile
- [ ] Container networking configuration
- [ ] Volume management
- [ ] Multi-container compose-like functionality
- [ ] Container templates/favorites

### v2.0 Features
- [ ] Menu bar app mode
- [ ] Notifications for container events
- [ ] Container metrics and monitoring
- [ ] Remote container management
- [ ] Teams/collaboration features

---

## Resources

### Documentation
- **Containerization Package**: https://github.com/apple/containerization
- **API Docs**: https://apple.github.io/containerization/documentation/
- **Container CLI**: https://github.com/apple/container
- **SwiftUI**: https://developer.apple.com/documentation/swiftui
- **Swift**: https://docs.swift.org

### Learning Resources
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui
- **Virtualization Framework**: https://developer.apple.com/documentation/virtualization
- **Async/Await**: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/

### Community
- **Swift Forums**: https://forums.swift.org
- **Stack Overflow**: Tag [swift] [swiftui]
- **Apple Developer Forums**: https://developer.apple.com/forums/

---

## Troubleshooting

### Common Issues

**Issue**: Cannot find Containerization package
- **Solution**: Ensure you're using Xcode 26 beta and macOS 26 beta

**Issue**: Kernel not found
- **Solution**: Download Kata Containers kernel or build custom kernel per docs

**Issue**: App crashes on launch
- **Solution**: Check kernel path is correct and file exists

**Issue**: Containers list is empty
- **Solution**: Ensure containers are actually running (test with `container` CLI)

**Issue**: Permission denied errors
- **Solution**: Check app entitlements and sandboxing settings

---

## Success Criteria

Your MVP is complete when:

1. ✅ App launches without errors
2. ✅ Container list loads and displays
3. ✅ Can stop/kill containers
4. ✅ Can view container logs
5. ✅ Image list loads and displays
6. ✅ UI is responsive and intuitive
7. ✅ Errors are handled gracefully
8. ✅ Basic polish (icons, spacing, colors) is complete

---

## Next Steps

1. **Set up Xcode project** following Phase 1
2. **Add Containerization dependency**
3. **Explore the API** by examining cctl examples
4. **Build incrementally** starting with models and services
5. **Test frequently** to catch issues early
6. **Iterate on UI/UX** based on usage

Good luck building your Container Manager app! 🚀
