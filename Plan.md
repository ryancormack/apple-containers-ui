# Apple Container Mac Desktop App - Implementation Plan

## Project Overview

Build a native macOS desktop application to manage Apple Containers with a graphical interface. The app will provide an easy way to view running containers, inspect logs, stop/kill containers, and manage images without memorizing CLI commands.

**Target User**: Developers familiar with web/TypeScript/.NET who want a GUI for Apple's container system  
**Platform**: macOS with Apple Silicon (required by Apple Container)  
**Tech Stack**: SwiftUI + Containerization Swift Package  

---

## Technical Architecture

### Integration Approach - IMPORTANT UPDATE

**This app wraps the `container` CLI tool, NOT the Containerization framework directly.**

There are two different things:
1. **Containerization Framework** - Low-level APIs for building your own container system
2. **Container CLI Tool** - Apple's Docker-like CLI that uses XPC services to manage containers

**Why wrap the CLI instead of using Containerization directly?**

The `container` CLI tool manages its own container and image storage through XPC services (`container-apiserver`, `container-core-images`, `container-runtime-linux`). To view containers and images created with `container run` or `container image pull`, you need to either:
- Communicate with the container CLI's XPC services (complex, undocumented)
- Wrap the CLI commands (simpler, supported approach)

**This app uses the CLI wrapper approach** - executing `container` commands and parsing their output.

### System Requirements

```
Required:
- Mac with Apple Silicon (M1 or later)
- macOS 26 (recommended) or macOS 15.5+ (limited support)
- Xcode 15.0+ for building the app
- Container CLI installed from: https://github.com/apple/container/releases
- Container system running: `container system start`
```

**Important Notes:**
- The container CLI must be installed and running
- Run `container system start` before using the app
- The app executes `/usr/local/bin/container` commands
- JSON output parsing for structured data

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

### Phase 1: Project Setup & CLI Verification

**Tasks:**

1. **Install Container CLI** (if not already installed)
   - Download from: https://github.com/apple/container/releases
   - Double-click the .pkg installer
   - Enter admin password when prompted
   - Files install to `/usr/local/bin/container`

2. **Start Container system**
   ```bash
   container system start
   # This starts the apiserver and installs the default kernel
   # Accept kernel download if prompted
   ```

3. **Verify CLI is working**
   ```bash
   # Test basic commands
   container --version
   container list
   container image list
   ```

4. **Create new SwiftUI macOS app project in Xcode**
   ```
   Xcode → New Project → macOS → App
   Product Name: ContainerManager
   Interface: SwiftUI
   Language: Swift
   Minimum deployment: macOS 14.0
   ```

5. **Set up project structure**
   - Create groups: Models, Services, ViewModels, Views, Views/Components, Utilities, App
   - Right-click project → New Group for each

6. **Configure app entitlements**
   - Target → Signing & Capabilities
   - **Disable App Sandbox** (required to execute external binaries)
   - Signing → Select your development team

**Deliverable**: Empty SwiftUI app that builds successfully, with Container CLI installed and running

**Verification**:
```swift
// Add to ContentView to test CLI access
func testCLI() async {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/local/bin/container")
    task.arguments = ["--version"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    try? task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print("Container CLI working: \(output)")
    }
}
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

### Phase 3: Container Service Layer (CLI Wrapper)

**Create `Services/ContainerService.swift`**:

```swift
import Foundation

actor ContainerService {
    private let cliPath: String
    
    init(cliPath: String = "/usr/local/bin/container") {
        self.cliPath = cliPath
    }
    
    /// List all containers
    func listContainers() async throws -> [ContainerInfo] {
        do {
            // Execute: container list
            let output = try await execute(arguments: ["list"])
            return try parseContainerList(output)
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
        return containers.first { $0.id == id || $0.id.hasPrefix(id) }
    }
    
    /// Stop a container gracefully
    func stopContainer(id: String) async throws {
        do {
            _ = try await execute(arguments: ["stop", id])
        } catch {
            throw AppError(
                message: "Failed to stop container '\(id)'",
                underlyingError: error
            )
        }
    }
    
    /// Kill a container forcefully
    func killContainer(id: String) async throws {
        do {
            _ = try await execute(arguments: ["kill", id])
        } catch {
            throw AppError(
                message: "Failed to kill container '\(id)'",
                underlyingError: error
            )
        }
    }
    
    /// Remove a stopped container
    func removeContainer(id: String) async throws {
        do {
            _ = try await execute(arguments: ["delete", id])
        } catch {
            throw AppError(
                message: "Failed to remove container '\(id)'",
                underlyingError: error
            )
        }
    }
    
    /// Stream logs from a container
    func streamLogs(containerId: String, follow: Bool = false) async throws -> AsyncStream<String> {
        var args = ["logs", containerId]
        if follow {
            args.append("--follow")
        }
        
        return try await executeStreaming(arguments: args)
    }
    
    /// Inspect container details
    func inspectContainer(id: String) async throws -> String {
        return try await execute(arguments: ["inspect", id])
    }
    
    // MARK: - Private Helper Methods
    
    /// Execute a container command and return output
    private func execute(arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            
            guard FileManager.default.fileExists(atPath: cliPath) else {
                continuation.resume(throwing: AppError(
                    message: "Container CLI not found at \(cliPath). Please install it first."
                ))
                return
            }
            
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AppError(message: errorMessage))
                    return
                }
                
                guard let output = String(data: outputData, encoding: .utf8) else {
                    continuation.resume(throwing: AppError(message: "Invalid output encoding"))
                    return
                }
                
                continuation.resume(returning: output)
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: AppError(
                    message: "Failed to execute container command",
                    underlyingError: error
                ))
            }
        }
    }
    
    /// Execute command and stream output line by line
    private func executeStreaming(arguments: [String]) async throws -> AsyncStream<String> {
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw AppError(message: "Container CLI not found at \(cliPath)")
        }
        
        return AsyncStream { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            let handle = pipe.fileHandleForReading
            
            // Set up data available notification
            NotificationCenter.default.addObserver(
                forName: .NSFileHandleDataAvailable,
                object: handle,
                queue: nil
            ) { _ in
                let data = handle.availableData
                if data.isEmpty {
                    continuation.finish()
                } else if let line = String(data: data, encoding: .utf8) {
                    // Split by newlines and yield each line
                    line.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .forEach { continuation.yield($0) }
                    handle.waitForDataInBackgroundAndNotify()
                }
            }
            
            handle.waitForDataInBackgroundAndNotify()
            
            do {
                try task.run()
            } catch {
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                task.terminate()
            }
        }
    }
    
    /// Parse container list output
    private func parseContainerList(_ output: String) throws -> [ContainerInfo] {
        // Container list output format (table):
        // CONTAINER ID   NAME        IMAGE           STATUS
        // abc123...      my-cont     alpine:latest   Up 5 minutes
        
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            // No containers (only header or empty)
            return []
        }
        
        // Skip the header line
        let dataLines = lines.dropFirst()
        
        return dataLines.compactMap { line in
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            
            guard components.count >= 4 else { return nil }
            
            let id = components[0]
            let name = components[1]
            let image = components[2]
            let statusParts = components.dropFirst(3)
            let status = statusParts.joined(separator: " ")
            
            // Determine state from status
            let state: ContainerState
            if status.lowercased().contains("up") {
                state = .running
            } else if status.lowercased().contains("exited") {
                state = .exited
            } else if status.lowercased().contains("paused") {
                state = .paused
            } else {
                state = .stopped
            }
            
            return ContainerInfo(
                id: id,
                name: name,
                image: image,
                state: state,
                ipAddress: nil, // Not provided in list output
                createdAt: nil,
                command: nil
            )
        }
    }
}
```

**Key Implementation Notes:**

1. **CLI Command Format:**
   - `container list` - Lists all containers
   - `container stop <id>` - Stop gracefully
   - `container kill <id>` - Force kill
   - `container delete <id>` - Remove container
   - `container logs <id> [--follow]` - View logs
   - `container inspect <id>` - Detailed info

2. **Output Parsing:**
   - The container CLI outputs text tables by default
   - Parse the table format (space-separated columns)
   - Extract: ID, NAME, IMAGE, STATUS
   - Map status text to ContainerState enum

3. **Error Handling:**
   - Check if CLI exists before executing
   - Capture stderr for error messages
   - Check termination status
   - Wrap errors in AppError with context

4. **Async Execution:**
   - Use Process class for spawning CLI
   - Use continuations for async/await
   - Handle termination callbacks properly
   - Stream output for logs using AsyncStream

**Testing the Service:**

```swift
// In a View or test file
Task {
    let service = ContainerService()
    
    // Test listing
    let containers = try await service.listContainers()
    print("Found \(containers.count) containers")
    
    // Test logs
    if let first = containers.first {
        let logs = try await service.streamLogs(containerId: first.id)
        for await line in logs {
            print(line)
        }
    }
}
```

**Deliverable**: Working service layer that executes CLI commands and parses output

---

### Phase 4: Image Service Layer (CLI Wrapper)

**Create `Services/ImageService.swift`**:

```swift
import Foundation

actor ImageService {
    private let cliPath: String
    
    init(cliPath: String = "/usr/local/bin/container") {
        self.cliPath = cliPath
    }
    
    /// List all local images
    func listImages() async throws -> [ImageInfo] {
        do {
            // Execute: container image list
            let output = try await execute(arguments: ["image", "list"])
            return try parseImageList(output)
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
    func pullImage(reference: String) async throws {
        do {
            _ = try await execute(arguments: ["image", "pull", reference])
        } catch {
            throw AppError(
                message: "Failed to pull image '\(reference)'",
                underlyingError: error
            )
        }
    }
    
    /// Remove an image
    func removeImage(reference: String) async throws {
        do {
            _ = try await execute(arguments: ["image", "remove", reference])
        } catch {
            throw AppError(
                message: "Failed to remove image '\(reference)'",
                underlyingError: error
            )
        }
    }
    
    /// Tag an image
    func tagImage(source: String, target: String) async throws {
        do {
            _ = try await execute(arguments: ["image", "tag", source, target])
        } catch {
            throw AppError(
                message: "Failed to tag image",
                underlyingError: error
            )
        }
    }
    
    /// Inspect image details
    func inspectImage(reference: String) async throws -> String {
        return try await execute(arguments: ["image", "inspect", reference])
    }
    
    // MARK: - Private Helper Methods
    
    /// Execute a container command and return output
    private func execute(arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            
            guard FileManager.default.fileExists(atPath: cliPath) else {
                continuation.resume(throwing: AppError(
                    message: "Container CLI not found at \(cliPath)"
                ))
                return
            }
            
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AppError(message: errorMessage))
                    return
                }
                
                guard let output = String(data: outputData, encoding: .utf8) else {
                    continuation.resume(throwing: AppError(message: "Invalid output encoding"))
                    return
                }
                
                continuation.resume(returning: output)
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: AppError(
                    message: "Failed to execute container command",
                    underlyingError: error
                ))
            }
        }
    }
    
    /// Parse image list output
    private func parseImageList(_ output: String) throws -> [ImageInfo] {
        // Image list output format (table):
        // NAME              TAG       DIGEST
        // alpine            latest    b4d299311845...
        // python            3.11      8f7c45a3c967...
        
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            // No images (only header or empty)
            return []
        }
        
        // Skip the header line
        let dataLines = lines.dropFirst()
        
        return dataLines.compactMap { line in
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            
            guard components.count >= 3 else { return nil }
            
            let name = components[0]
            let tag = components[1]
            let digest = components[2]
            
            // Generate a unique ID from name:tag
            let id = "\(name):\(tag)"
            
            return ImageInfo(
                id: id,
                name: name,
                tag: tag,
                digest: digest,
                size: nil, // Not provided in list output
                createdAt: nil
            )
        }
    }
}
```

**Key Implementation Notes:**

1. **CLI Commands for Images:**
   - `container image list` - List all local images
   - `container image pull <reference>` - Pull from registry
   - `container image remove <reference>` - Delete image
   - `container image tag <source> <target>` - Tag image
   - `container image inspect <reference>` - Detailed info

2. **Output Parsing:**
   - Parse table format: NAME, TAG, DIGEST
   - Extract components using space separation
   - Handle empty results gracefully
   - Generate ID from name:tag combination

3. **Size Information:**
   - The `container image list` command doesn't show size by default
   - Could parse `container image inspect` for detailed size info
   - For now, size is nil in the list view

4. **Error Handling:**
   - Same pattern as ContainerService
   - Verify CLI exists
   - Capture stderr for errors
   - Wrap in AppError with context

**Alternative: Using JSON Output (if available)**

The container CLI may support `--format json` for structured output:

```swift
// If JSON format is available:
private func listImagesJSON() async throws -> [ImageInfo] {
    let output = try await execute(arguments: ["image", "list", "--format", "json"])
    
    guard let data = output.data(using: .utf8) else {
        throw AppError(message: "Invalid output encoding")
    }
    
    struct ImageListResponse: Codable {
        let name: String
        let tag: String
        let digest: String
        let size: Int64?
    }
    
    let images = try JSONDecoder().decode([ImageListResponse].self, from: data)
    
    return images.map { img in
        ImageInfo(
            id: "\(img.name):\(img.tag)",
            name: img.name,
            tag: img.tag,
            digest: img.digest,
            size: img.size,
            createdAt: nil
        )
    }
}
```

**Testing the Service:**

```swift
Task {
    let service = ImageService()
    
    // List images
    let images = try await service.listImages()
    print("Found \(images.count) images")
    
    // Pull an image
    try await service.pullImage(reference: "alpine:latest")
    print("Pulled alpine:latest")
}
```

**Deliverable**: Working image management service using CLI commands

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
    
    private let containerService = ContainerService()
    private var refreshTask: Task<Void, Never>?
    
    func loadContainers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            containers = try await containerService.listContainers()
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
        do {
            try await containerService.stopContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to stop container: \(error.localizedDescription)"
        }
    }
    
    func killContainer(_ container: ContainerInfo) async {
        do {
            try await containerService.killContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = "Failed to kill container: \(error.localizedDescription)"
        }
    }
    
    func removeContainer(_ container: ContainerInfo) async {
        do {
            try await containerService.removeContainer(id: container.id)
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
    
    private let imageService = ImageService()
    
    func loadImages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            images = try await imageService.listImages()
        } catch {
            errorMessage = error.localizedDescription
            images = []
        }
        
        isLoading = false
    }
    
    func removeImage(_ image: ImageInfo) async {
        do {
            try await imageService.removeImage(reference: image.displayName)
            await loadImages()
        } catch {
            errorMessage = "Failed to remove image: \(error.localizedDescription)"
        }
    }
    
    func pullImage(reference: String) async {
        errorMessage = nil
        
        do {
            try await imageService.pullImage(reference: reference)
            await loadImages()
        } catch {
            errorMessage = "Failed to pull image: \(error.localizedDescription)"
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
    
    private let containerService = ContainerService()
    private var streamTask: Task<Void, Never>?
    
    func loadLogs(containerId: String, follow: Bool = false) async {
        isLoading = true
        errorMessage = nil
        isFollowing = follow
        logs = []
        
        streamTask?.cancel()
        
        do {
            let logStream = try await containerService.streamLogs(
                containerId: containerId,
                follow: follow
            )
            
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
    
    @State private var viewModel = LogsViewModel()
    @State private var autoScroll = true
    
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
    
    var cliPath: String {
        // Check user defaults first
        if let customPath = UserDefaults.standard.string(forKey: "cliPath"),
           FileManager.default.fileExists(atPath: customPath) {
            return customPath
        }
        
        // Standard installation location
        let standardPath = "/usr/local/bin/container"
        if FileManager.default.fileExists(atPath: standardPath) {
            return standardPath
        }
        
        // Homebrew location
        let homebrewPath = "/opt/homebrew/bin/container"
        if FileManager.default.fileExists(atPath: homebrewPath) {
            return homebrewPath
        }
        
        // Default - user will need to install CLI
        return "/usr/local/bin/container"
    }
    
    var autoRefreshInterval: TimeInterval {
        UserDefaults.standard.double(forKey: "autoRefreshInterval") ?? 3.0
    }
    
    func setCLIPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "cliPath")
    }
    
    func setAutoRefreshInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: "autoRefreshInterval")
    }
    
    /// Check if container CLI is installed and accessible
    func isCLIInstalled() -> Bool {
        FileManager.default.fileExists(atPath: cliPath) &&
        FileManager.default.isExecutableFile(atPath: cliPath)
    }
    
    /// Check if container system is running
    func isSystemRunning() async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["list"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
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

### 1. Container System Must Be Running

Before your app can show any data, the container system must be started:

```bash
container system start
```

Without this, all commands will fail with "XPC connection error: Connection invalid".

**Add a startup check in your app:**

```swift
// In App launch or ContentView.onAppear
Task {
    let config = AppConfiguration.shared
    
    if !config.isCLIInstalled() {
        // Show alert: "Container CLI not installed"
        return
    }
    
    if !await config.isSystemRunning() {
        // Show alert: "Please run 'container system start' in Terminal"
        return
    }
}
```

### 2. CLI Output Parsing

The container CLI outputs text tables. Your parsing code needs to be robust:

**Example output:**
```
CONTAINER ID   NAME        IMAGE           STATUS
abc123def456   my-app      alpine:latest   Up 5 minutes
```

**Parsing considerations:**
- Header line should be skipped
- Columns are space-separated
- STATUS can contain multiple words
- Empty results are valid (no containers)
- Handle errors gracefully

### 3. JSON Format Alternative

Check if the container CLI supports `--format json` for easier parsing:

```bash
container list --format json
container image list --format json
```

If available, update your services to use JSON parsing instead of text parsing.

### 4. Testing Strategy

Start with minimal functionality:
1. Verify CLI is installed and accessible
2. Execute `container --version` successfully
3. List containers (even if empty)
4. Add UI for the list
5. Add one action (stop/kill)
6. Gradually add more features

### 5. Error Handling

Every CLI command should be wrapped in proper error handling:

```swift
do {
    let output = try await execute(arguments: ["list"])
    // Parse and return
} catch {
    // Show user-friendly error
    throw AppError(message: "Failed to list containers: \(error.localizedDescription)")
}
```

### 6. Performance Considerations

- CLI execution has overhead compared to direct APIs
- Cache results when appropriate
- Don't poll too frequently (3-5 second intervals)
- Use streaming for logs instead of repeated polling
- Consider debouncing refresh operations

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

**Issue**: App shows no containers or images (THIS WAS YOUR PROBLEM!)
- **Cause**: The Containerization framework is for BUILDING container systems, not viewing containers created by the `container` CLI
- **Solution**: Use the CLI wrapper approach in this updated plan
- **Verification**: 
  ```bash
  # In Terminal, verify you have containers/images
  container list
  container image list
  ```
- **Then**: Make sure your app executes these same commands and parses the output

**Issue**: "XPC connection error: Connection invalid"
- **Cause**: Container system services aren't running
- **Solution**: Run `container system start` in Terminal before launching your app
- **Prevention**: Add a system check in your app that alerts users to start the system

**Issue**: "Container CLI not found"
- **Cause**: CLI isn't installed or isn't at expected path
- **Solution**: Install from https://github.com/apple/container/releases
- **Alternative**: Check `/opt/homebrew/bin/container` if installed via Homebrew

**Issue**: Permission denied errors
- **Cause**: App Sandbox is preventing CLI execution
- **Solution**: Disable App Sandbox in app entitlements

**Issue**: Containers list is empty but containers exist
- **Cause**: Parsing logic is incorrect or CLI output format changed
- **Solution**: Print raw CLI output to debug:
  ```swift
  let output = try await execute(arguments: ["list"])
  print("Raw output:", output)
  ```

**Issue**: App crashes on launch
- **Cause**: Service initialization fails
- **Solution**: Remove any initialization errors and use lazy initialization

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

## Understanding the Architecture: Why CLI Wrapper vs Direct APIs

### The Two Approaches Explained

**Approach 1: Use Containerization Framework Directly (Low-level)**
- Build your OWN container system from scratch
- Manage your own storage, networking, VMs
- Create your own container runtime
- **Use case**: Building a Docker alternative or custom container solution
- **Complexity**: High - you're building everything

**Approach 2: Wrap the Container CLI Tool (High-level)** ← **This plan uses this**
- Use Apple's `container` tool that already exists
- View and manage containers/images created with `container run`, `container image pull`, etc.
- Communicate through CLI commands or XPC services
- **Use case**: GUI for existing container CLI (like Docker Desktop is to Docker)
- **Complexity**: Medium - you're wrapping existing functionality

### Why Your Images/Containers Weren't Showing

When you used the Containerization framework directly, you were creating an entirely separate container system. The containers and images created by the `container` CLI tool live in a different storage location managed by the CLI's XPC services.

Think of it like this:
- **container CLI** = Manages containers in `/Users/you/Library/Application Support/com.apple.container/`
- **Your direct Containerization app** = Would manage containers in its own storage location

They're separate systems! That's why your app showed no images or containers - it was looking in the wrong place.

### The Fix

This updated plan uses the CLI wrapper approach, which means:
1. Your app executes `container list` and `container image list` commands
2. These commands return data from the same storage the CLI uses
3. You see all the containers and images you created with `container run` and `container image pull`
4. Your GUI manages the same containers that the CLI manages

### When to Use Each Approach

**Use CLI Wrapper (this plan) when:**
- You want a GUI for the existing `container` tool
- You want to manage containers created via CLI
- You want faster development with less complexity
- You're building a user-facing container management app

**Use Containerization Framework Directly when:**
- You're building a completely new container runtime
- You need full control over VM creation and management
- You're building infrastructure/platform tools
- You don't need compatibility with the `container` CLI

---

## Next Steps

1. **Verify container CLI is working**
   ```bash
   container system start
   container run -it alpine sh
   container list  # Should show your running container
   ```

2. **Set up Xcode project** following Phase 1

3. **Build incrementally** starting with CLI verification

4. **Test the parsing** by printing raw CLI output

5. **Add UI** once data is loading correctly

6. **Iterate on features** once core functionality works

Good luck building your Container Manager app! 🚀

The updated approach should now show your containers and images correctly.
