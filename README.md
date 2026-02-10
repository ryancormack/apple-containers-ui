# Container Manager

A native macOS app for managing [Apple Containers](https://github.com/apple/container) through a graphical interface. Think of it as a lightweight desktop companion for the `container` CLI — browse containers, images, volumes, and networks without memorizing commands.

Built with SwiftUI. Requires macOS 26 and Apple Silicon.

<!-- TODO: Add a screenshot here once the app is running -->
<!-- ![Container Manager screenshot](docs/screenshot.png) -->

## Why This Exists

Apple's [container CLI](https://github.com/apple/container) is powerful, but switching between terminal windows to check container status, read logs, or inspect images gets tedious. This app puts everything in one window with a native macOS interface — sidebar navigation, table views, search, and real-time log streaming.

The app wraps the `container` CLI rather than using the low-level [Containerization framework](https://github.com/apple/containerization) directly. This means it manages the same containers and images you create from the command line. See [ARCHITECTURE.md](ARCHITECTURE.md) for more on this decision.

## Features

- **Containers** — List, stop, kill, remove, and inspect containers. Auto-refresh to watch state changes. Toggle between running-only and all containers.
- **Images** — Browse local images, run new containers from them, inspect metadata, and delete unused images.
- **Volumes** — View and inspect container volumes.
- **Networks** — View and inspect container networks.
- **Logs** — Stream container logs in real-time with follow mode, auto-scroll, and line numbers.
- **System Status** — At-a-glance indicator showing whether the container system is running.

## Prerequisites

- Mac with Apple Silicon (M1 or later)
- macOS 26 beta or later
- Xcode 26 beta or later
- [Apple Container CLI](https://github.com/apple/container/releases) installed

## Getting Started

### 1. Install the Container CLI

Download the latest `.pkg` from the [container releases page](https://github.com/apple/container/releases) and run the installer. This places the `container` binary at `/usr/local/bin/container`.

### 2. Start the Container System

```bash
container system start
```

This launches the background services that manage containers. You'll need to do this once after each reboot (or set it up to start automatically).

### 3. Build and Run the App

```bash
git clone https://github.com/ryancormack/apple-containers-ui.git
cd apple-containers-ui/ContainerManager
open ContainerManager.xcodeproj
```

In Xcode:
1. Select your Mac as the run destination
2. Press **Cmd+R** to build and run

> **Note:** The App Sandbox must be disabled for the app to execute the `container` CLI. The project is already configured this way.

### 4. Verify It Works

If you have containers or images from previous CLI usage, they'll appear immediately. If not, pull an image and run something:

```bash
container image pull alpine:latest
container run alpine:latest echo "hello from a container"
```

Then switch back to the app and hit refresh (or enable auto-refresh).

## Configuration

The app auto-detects the `container` CLI at these paths (in order):

1. Custom path set via `UserDefaults` key `cliPath`
2. `/usr/local/bin/container` (default install location)
3. `/opt/homebrew/bin/container` (Homebrew)

The auto-refresh interval defaults to 3 seconds and can be changed via the `autoRefreshInterval` UserDefaults key.

## Project Structure

```
ContainerManager/
├── App/                    # App entry point
├── Models/                 # Data models (ContainerInfo, ImageInfo, etc.)
├── Services/               # CLI wrapper and business logic
├── ViewModels/             # State management (@Observable classes)
├── Views/                  # SwiftUI views
│   └── Components/         # Reusable UI components
└── Utilities/              # Configuration, formatters
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed explanation of the design and the reasoning behind key decisions.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to get involved.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Related Projects

- [apple/container](https://github.com/apple/container) — The CLI tool this app wraps
- [apple/containerization](https://github.com/apple/containerization) — Apple's low-level container framework
