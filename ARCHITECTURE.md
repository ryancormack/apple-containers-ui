# Architecture

This document explains how the app is structured, what each layer does, and why certain design decisions were made.

## Overview

Container Manager is a SwiftUI macOS app that wraps Apple's `container` CLI. It follows a standard MVVM (Model-View-ViewModel) pattern:

```
Views → ViewModels → Services → CLIExecutor → container CLI
```

Each layer has a single responsibility:

- **Views** render UI and respond to user interaction
- **ViewModels** hold state and coordinate between views and services
- **Services** translate app operations into CLI commands and parse the results
- **CLIExecutor** handles the mechanics of spawning processes and reading output

## Why Wrap the CLI?

Apple provides two ways to work with containers:

1. **Containerization framework** — A low-level Swift framework for building your own container runtime. You manage VMs, storage, networking, and everything else from scratch.
2. **`container` CLI** — A high-level tool (like Docker) that manages containers through background XPC services. When you run `container run alpine`, the CLI talks to `container-apiserver`, `container-core-images`, and `container-runtime-linux` behind the scenes.

This app wraps the CLI (option 2). The reason is straightforward: if you create containers with `container run` from the terminal, those containers live in the CLI's storage managed by its XPC services. The Containerization framework doesn't know about them — it would create a completely separate set of containers in its own storage. Wrapping the CLI means the app sees the same containers and images you use from the command line.

The tradeoff is that CLI output parsing is more fragile than a native API. We mitigate this by using `--format json` wherever the CLI supports it, which gives us structured data instead of text tables.

## File Structure

```
ContainerManager/
├── App/
│   └── ContainerManagerApp.swift       # @main entry point, window configuration
├── Models/
│   ├── AppError.swift                  # Error type with user-facing messages
│   ├── ContainerInfo.swift             # Container data (id, name, image, state, IP)
│   ├── ContainerState.swift            # Enum: running, stopped, stopping, unknown
│   ├── ImageInfo.swift                 # Image data (name, tag, digest, size)
│   ├── VolumeInfo.swift                # Volume data (name, driver, source, size)
│   └── NetworkInfo.swift               # Network data (name, subnet, subnetV6)
├── Services/
│   ├── CLIExecutor.swift               # Process spawning and output capture
│   ├── ContainerService.swift          # Container, volume, network, system operations
│   └── ImageService.swift              # Image operations (list, pull, remove, run, tag)
├── ViewModels/
│   ├── ContainersViewModel.swift       # Container list state, auto-refresh, actions
│   ├── ImagesViewModel.swift           # Image list state, run/remove actions
│   ├── VolumesViewModel.swift          # Volume list state
│   ├── NetworksViewModel.swift         # Network list state
│   ├── LogsViewModel.swift             # Container log streaming state
│   └── SystemLogsViewModel.swift       # System log streaming state
├── Views/
│   ├── ContentView.swift               # NavigationSplitView with sidebar + detail
│   ├── ContainersListView.swift        # Container table with actions
│   ├── ImagesListView.swift            # Image table with run/inspect/delete
│   ├── VolumesListView.swift           # Volume table with inspect
│   ├── NetworksListView.swift          # Network table with inspect
│   ├── LogsView.swift                  # Container log viewer with follow mode
│   ├── SystemLogsView.swift            # System log viewer
│   └── Components/
│       ├── EmptyStateView.swift        # "No items" placeholder
│       ├── ErrorView.swift             # Error display with retry button
│       └── InspectView.swift           # JSON detail modal
└── Utilities/
    ├── AppConfiguration.swift          # CLI path detection, UserDefaults settings
    └── ByteFormatter.swift             # Human-readable file sizes
```

## Key Design Decisions

### CLIExecutor as a shared primitive

All CLI interaction goes through `CLIExecutor`, a small struct with two methods:

- `execute(arguments:)` — Runs a command, waits for it to finish, returns the full output as a string. Used for list/inspect/stop/kill/delete operations.
- `executeStreaming(arguments:)` — Runs a command and returns an `AsyncStream<String>` that yields output line by line as it arrives. Used for log streaming.

This keeps process management in one place. Services don't need to know about `Process`, pipes, or termination handlers.

### Services are structs, not actors

`ContainerService` and `ImageService` are plain structs. They don't hold mutable state — they just translate method calls into CLI commands and parse the output. Each call is independent. There's no shared connection or session to protect, so actor isolation would add complexity without benefit.

### ViewModels use @Observable

The app uses Swift's `@Observable` macro (not the older `ObservableObject` protocol). This gives automatic fine-grained observation — SwiftUI only re-renders views that read properties that actually changed. It also means less boilerplate (no `@Published` wrappers needed).

### JSON parsing over text parsing

Where the CLI supports `--format json`, we use it. The container and image list commands both support JSON output, which we decode into typed structs using `JSONDecoder`. This is more reliable than splitting text table output by whitespace, and it gives us access to fields (like IP addresses and image sizes) that don't appear in the default table format.

For commands that don't support JSON output (like `inspect`), we display the raw output directly in an `InspectView` modal.

### Auto-refresh with cancellable tasks

The containers list supports auto-refresh via a `Task` that loops with `Task.sleep`. The task checks `Task.isCancelled` on each iteration and stops cleanly when the user toggles auto-refresh off or the view disappears. The refresh interval defaults to 3 seconds and is configurable via `UserDefaults`.

### Log streaming with AsyncStream

Container and system logs use `CLIExecutor.executeStreaming`, which sets up `NSFileHandle` notifications to yield lines as they arrive from the CLI process. The stream terminates when the process exits. The view can cancel streaming by calling `stopStreaming()` on the view model, which cancels the task and terminates the underlying process.

### App Sandbox is disabled

The app needs to execute `/usr/local/bin/container` as a child process. macOS App Sandbox blocks this by default. Rather than requesting specific entitlements (which wouldn't cover arbitrary CLI paths), the sandbox is disabled entirely. This is a conscious tradeoff — the app can't be distributed through the Mac App Store, but it can interact freely with the container CLI.

### CLI path auto-detection

`AppConfiguration` checks three locations in order:

1. A custom path stored in `UserDefaults` (for non-standard installs)
2. `/usr/local/bin/container` (the default `.pkg` install location)
3. `/opt/homebrew/bin/container` (Homebrew)

This covers the common cases without requiring user configuration.

## Data Flow Example

Here's what happens when the user opens the Containers tab:

1. `ContainersListView` appears and its `.task` modifier fires
2. It calls `viewModel.loadContainers()`
3. `ContainersViewModel` sets `isLoading = true`, calls `containerService.listContainers(showAll:)`
4. `ContainerService` calls `cli.execute(arguments: ["list", "--format", "json", "--all"])`
5. `CLIExecutor` spawns a `Process`, captures stdout, waits for exit
6. `ContainerService` decodes the JSON into `[ContainerInfo]` and returns it
7. `ContainersViewModel` sets `containers = result`, `isLoading = false`
8. SwiftUI re-renders the table with the new data

If the CLI isn't installed or the system isn't running, step 5 throws an error, which propagates up to the view model and gets displayed via `ErrorView`.

## What's Not Here (and Why)

- **No unit tests** — The app is a thin wrapper around a CLI. Most logic is in parsing JSON output, which is straightforward. Tests would mostly be testing `JSONDecoder`, which isn't very useful. Integration tests against a running container system would be more valuable but require the full environment.
- **No dependency injection** — Services are created directly in view models. For an app this size, the indirection of protocols and injection isn't worth the complexity. If the app grows significantly, this would be worth revisiting.
- **No Swift Package Manager** — The project uses a plain Xcode project (`.xcodeproj`) with no external dependencies. Everything is built with the standard library and SwiftUI.
