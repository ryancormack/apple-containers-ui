# Contributing to Container Manager

Thanks for your interest in contributing. This document covers the basics of how to get involved.

## Getting Set Up

1. Fork the repo and clone your fork
2. Open `ContainerManager/ContainerManager.xcodeproj` in Xcode 26 beta
3. Make sure you have the [container CLI](https://github.com/apple/container/releases) installed and `container system start` running
4. Build and run with **Cmd+R**

See the [README](README.md) for full prerequisites.

## How to Contribute

### Reporting Bugs

Open an issue with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your macOS version and hardware (Intel vs Apple Silicon)

### Suggesting Features

Open an issue describing the feature and why it would be useful. If it involves UI changes, a rough sketch or description of the interaction helps.

### Submitting Code

1. Create a branch from `main` for your change
2. Make your changes — keep commits focused and descriptive
3. Test that the app builds and runs correctly
4. Open a pull request against `main`

## Code Style

- Follow standard Swift conventions and SwiftUI patterns
- Use `@Observable` for view models (not `ObservableObject`)
- Keep views focused — extract reusable components into `Views/Components/`
- All CLI interaction goes through `CLIExecutor` in the Services layer, not directly in views or view models
- Parse CLI output as JSON (`--format json`) where the CLI supports it

## Architecture

The app follows a straightforward MVVM pattern:

```
Views → ViewModels → Services → CLIExecutor → container CLI
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full breakdown and the reasoning behind design decisions.

## What's Helpful Right Now

- Bug reports from people actually using the app with real containers
- UI/UX improvements — better layouts, accessibility, keyboard shortcuts
- Support for more container CLI features (e.g., `container run` options, build support)
- Testing on different macOS 26 beta versions

## Code of Conduct

Be respectful. This is a small project and everyone's here to make it better. Harassment, trolling, or unconstructive criticism won't be tolerated.
