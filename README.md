# Container Manager - macOS App

A native macOS desktop application for managing Apple Containers with a graphical interface built with SwiftUI.

## Project Status

✅ **Code Structure Complete** - All Swift files have been created according to the plan.

⚠️ **Next Steps Required** - The project needs to be set up in Xcode before it can run.

## What's Been Built

### Models (4 files)
- `AppError.swift` - Error handling with localized descriptions
- `ContainerState.swift` - Container state enum with UI properties (colors, icons)
- `ContainerInfo.swift` - Container data model
- `ImageInfo.swift` - Image data model

### Services (2 files)
- `ContainerService.swift` - Container operations (list, stop, kill, logs, remove)
- `ImageService.swift` - Image operations (list, pull, remove, tag)

### ViewModels (3 files)
- `ContainersViewModel.swift` - Container list state with auto-refresh
- `ImagesViewModel.swift` - Image list state management
- `LogsViewModel.swift` - Log streaming state management

### Views (6 files)
- `ContentView.swift` - Main app layout with sidebar navigation
- `ContainersListView.swift` - Container list with table and actions
- `ImagesListView.swift` - Image list with table
- `LogsView.swift` - Log viewer with streaming and auto-scroll
- `Components/EmptyStateView.swift` - Reusable empty state component
- `Components/ErrorView.swift` - Reusable error display component

### Utilities (2 files)
- `AppConfiguration.swift` - Kernel path and settings management
- `ByteFormatter.swift` - File size formatting

### App (1 file)
- `ContainerManagerApp.swift` - App entry point

## Requirements

- macOS 26 beta (or later)
- Xcode 26 beta (or later)
- Mac with Apple Silicon (M1 or later)
- Linux kernel for containers (Kata Containers or custom)

## Next Steps to Run the App

### 1. Create Xcode Project

```bash
# Open Xcode
# File → New → Project
# Select: macOS → App
# Product Name: ContainerManager
# Interface: SwiftUI
# Language: Swift
# Minimum deployment: macOS 14.0
```

### 2. Add Containerization Package

In Xcode:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/apple/containerization`
3. Select version: Up to Next Minor from 0.1.0
4. Add to your target

### 3. Copy Source Files

Copy all the Swift files from this directory into your Xcode project, maintaining the folder structure:
- Drag folders into Xcode's Project Navigator
- Ensure "Copy items if needed" is checked
- Add to your app target

### 4. Configure Kernel Path

Download a Linux kernel:
```bash
# Option A: Kata Containers kernel
curl -LO https://github.com/kata-containers/kata-containers/releases/download/[VERSION]/kata-containers-[VERSION]-arm64.tar.xz
tar -xf kata-containers-[VERSION]-arm64.tar.xz

# Option B: Follow containerization repo instructions
```

Update kernel path in:
- `ViewModels/ContainersViewModel.swift`
- `ViewModels/LogsViewModel.swift`
- Or use `AppConfiguration.shared.kernelPath`

### 5. Verify API Methods

⚠️ **Important**: The Containerization API methods in the service files are placeholders. You must verify them against the actual package:

1. Check documentation: https://apple.github.io/containerization/documentation/
2. Examine examples in the package's `cctl` directory
3. Update method names and signatures in:
   - `Services/ContainerService.swift`
   - `Services/ImageService.swift`

### 6. Build and Run

1. Select your Mac as the run destination
2. Press Cmd+B to build
3. Fix any compilation errors (likely API method names)
4. Press Cmd+R to run

## Features

- **Container Management**
  - View all containers with status, name, image, ID, IP
  - Stop containers gracefully
  - Kill containers forcefully
  - Remove containers
  - Auto-refresh container list
  - Search/filter containers

- **Image Management**
  - View all local images
  - Remove images
  - Search/filter images
  - Display image size and digest

- **Log Viewing**
  - Stream container logs in real-time
  - Follow mode for live updates
  - Auto-scroll to latest logs
  - Clear logs
  - Line numbers and monospaced font

- **UI/UX**
  - Native macOS design with SwiftUI
  - Sidebar navigation
  - Table views with sorting
  - Confirmation dialogs for destructive actions
  - Empty states and error handling
  - Search functionality

## Architecture

```
App Entry Point (ContainerManagerApp)
    ↓
ContentView (Sidebar Navigation)
    ↓
Views (ContainersListView, ImagesListView, LogsView)
    ↓
ViewModels (State Management)
    ↓
Services (Business Logic)
    ↓
Containerization Package (Apple's API)
```

## Known Limitations

1. **API Placeholders**: Service methods need verification against actual Containerization API
2. **Kernel Path**: Hardcoded paths need to be updated for your system
3. **State Mapping**: `mapState()` in ContainerService returns `.unknown` - needs implementation
4. **No Tests**: Unit tests not yet implemented
5. **Beta Software**: Requires macOS 26 beta and Xcode 26 beta

## Future Enhancements

See `Plan.md` for detailed roadmap including:
- Start/restart containers
- Pull images from registries
- Container resource stats
- Build images from Dockerfile
- Volume management
- Menu bar app mode

## Resources

- [Containerization Package](https://github.com/apple/containerization)
- [API Documentation](https://apple.github.io/containerization/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Plan.md](./Plan.md) - Detailed implementation plan

## License

This project structure follows the implementation plan for building a Container Manager app. Adjust licensing as needed for your use case.
