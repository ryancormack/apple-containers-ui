# Containers

The Containers view is the main screen for managing your running and stopped containers.

<!-- screenshot: containers-list — the containers list view showing a mix of running and stopped containers -->

## Browsing Containers

The container list shows each container's status, name, image, ID, and IP address in a sortable table. Use the search bar to filter by name, ID, or image.

## Toolbar Controls

| Control | Description |
|---------|-------------|
| **Auto-refresh** | Polls the container list every 3 seconds so you can watch state changes in real time. |
| **Show stopped** | Toggle between showing only running containers or all containers including stopped ones. |
| **Refresh** | Manually reload the container list. |

## Container Actions

Each container row has action buttons that appear in the Actions column.

<!-- screenshot: container-actions — close-up of the action buttons on a container row -->

| Button | Description |
|--------|-------------|
| ℹ️ **Inspect** | Opens a sheet with the full JSON output of `container inspect`. |
| ▶️ **Start** | Starts a stopped container. Only visible when the container is stopped. |
| ⏹ **Stop** | Gracefully stops a running container. Asks for confirmation. |
| ✖️ **Kill** | Force-kills a running container. Asks for confirmation. |
| 📄 **Logs** | Opens the [log viewer](#logs) for this container. |
| 🗑 **Remove** | Permanently deletes the container. Asks for confirmation. |

## Logs

Selecting the logs button opens a dedicated log viewer for that container.

<!-- screenshot: logs-view — the logs view showing streamed output with line numbers -->

| Control | Description |
|---------|-------------|
| **Follow** | Stream new log entries as they arrive. |
| **Auto-scroll** | Automatically scroll to the bottom when new lines appear. |
| **Clear** | Clear the displayed log output. |
| **Refresh** | Restart log streaming. |

Logs are displayed with line numbers and a monospaced font. You can select and copy text from the log output.
