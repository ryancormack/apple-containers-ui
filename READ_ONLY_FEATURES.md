# Read-Only Features to Implement

Based on the `container` CLI command reference, here are the read-only (inspection/viewing) features we can add to the app:

## ✅ Already Implemented

1. **container list** - List containers ✅
2. **container image list** - List images ✅
3. **container logs** - View container logs ✅

## 🔍 Container Inspection Features

### container inspect
**Command**: `container inspect CONTAINER-ID`
**Output**: Detailed JSON information about a container
**UI Implementation**: 
- Add "Inspect" button/action in container list
- Show in a detail panel or modal
- Display formatted JSON or structured view with:
  - Container ID, Name, Image
  - State, Status, Exit Code
  - Network settings (IP, ports, DNS)
  - Mounts and volumes
  - Resource limits (CPU, memory)
  - Labels and metadata
  - Creation/start times

### container list --all
**Command**: `container list --all`
**Current**: Only shows running containers
**Enhancement**: Add toggle to show stopped containers too

### container list --format json
**Command**: `container list --format json`
**Enhancement**: Use JSON output for more reliable parsing

## 🖼️ Image Inspection Features

### container image inspect
**Command**: `container image inspect IMAGE`
**Output**: Detailed JSON information about an image
**UI Implementation**:
- Add "Inspect" button in images list
- Show detail panel with:
  - Image ID, Name, Tags
  - Digest, Size
  - Architecture, OS
  - Layers information
  - Creation date
  - Labels and annotations
  - Config (env vars, entrypoint, cmd)

### container image list --verbose
**Command**: `container image list --verbose`
**Enhancement**: Show additional columns (ID, creation time, size)

### container image list --format json
**Command**: `container image list --format json`
**Enhancement**: Use JSON for better data extraction

## 🌐 Network Inspection (macOS 26+)

### container network list
**Command**: `container network list`
**UI Implementation**:
- New "Networks" tab in sidebar
- Table showing:
  - Network name
  - Subnet
  - Gateway
  - Labels

### container network inspect
**Command**: `container network inspect NAME`
**UI Implementation**:
- Detail view for network
- Show connected containers
- Network configuration

## 💾 Volume Inspection

### container volume list
**Command**: `container volume list`
**UI Implementation**:
- New "Volumes" tab in sidebar
- Table showing:
  - Volume name
  - Driver
  - Mount point
  - Size
  - Labels

### container volume inspect
**Command**: `container volume inspect NAME`
**UI Implementation**:
- Detail view for volume
- Show which containers use it
- Size and usage info

## ⚙️ System Information

### container system status
**Command**: `container system status`
**UI Implementation**:
- Status indicator in app (green/red dot)
- Show in About/Settings:
  - API server status
  - Version information
  - System readiness

### container system logs
**Command**: `container system logs [--follow]`
**UI Implementation**:
- New "System Logs" view
- Similar to container logs view
- Follow mode for live updates
- Filter by time period

### container system property list
**Command**: `container system property list`
**UI Implementation**:
- Settings/Preferences panel
- Show all system properties:
  - build.rosetta
  - dns.domain
  - registry.domain
  - image.builder
  - image.init
  - kernel.url
  - kernel.binaryPath
  - network.subnet
- Display as read-only table

### container system property get
**Command**: `container system property get PROPERTY_ID`
**UI Implementation**:
- Detail view for individual properties
- Show current value, type, description

### container system dns list
**Command**: `container system dns list`
**UI Implementation**:
- Show configured DNS domains
- Part of network settings view

## 🏗️ Builder Information

### container builder status
**Command**: `container builder status [--json]`
**UI Implementation**:
- Show builder status in UI
- Display:
  - Running/stopped state
  - Resource allocation (CPU, memory)
  - Version info

## 📊 Recommended Implementation Priority

### Phase 1: Enhanced Container/Image Details
1. **container inspect** - Most valuable for debugging
2. **container image inspect** - Essential for image management
3. **container list --all** - Show stopped containers
4. Use JSON format for all list commands

### Phase 2: System Monitoring
1. **container system status** - Health indicator
2. **container system logs** - System debugging
3. **container builder status** - Build monitoring

### Phase 3: Resource Management Views
1. **container volume list/inspect** - Volume management
2. **container network list/inspect** - Network management (macOS 26+)
3. **container system property list** - Configuration viewing

## Implementation Notes

### JSON Output Benefits
Most commands support `--format json` which provides:
- Structured, parseable data
- More reliable than text table parsing
- Additional fields not shown in table format
- Easier to maintain as CLI evolves

### Example JSON Parsing
```swift
// Instead of parsing text tables:
let output = try await execute(arguments: ["list", "--format", "json"])
let containers = try JSONDecoder().decode([ContainerJSON].self, from: output.data(using: .utf8)!)
```

### UI Patterns

**Detail Views**:
- Use NavigationLink to detail view
- Or show in inspector panel (right sidebar)
- Format JSON nicely with syntax highlighting

**Status Indicators**:
- Traffic light colors (green/yellow/red)
- SF Symbols for visual feedback
- Real-time updates where appropriate

**Tabs/Sections**:
- Containers (existing)
- Images (existing)
- Volumes (new)
- Networks (new)
- System (new) - logs, status, properties

## Quick Wins (Easy to Implement)

1. **Add `--all` flag to container list** - One line change
2. **Add `--format json` to existing commands** - Better parsing
3. **System status indicator** - Simple health check
4. **Container/Image inspect buttons** - Execute command, show JSON

These features are all read-only and safe to implement without risk of breaking containers or images.
