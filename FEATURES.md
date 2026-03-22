# Apple Containers UI - Feature Tracking

This document tracks the implementation status of all [Apple Containers](https://github.com/apple/container) CLI features in the **Containers UI** macOS app. It serves as a reference for contributors looking to understand what is already built and what remains to be implemented.

## Summary

| Category              | Implemented | Partial | Not Implemented | Total |
|-----------------------|:-----------:|:-------:|:---------------:|:-----:|
| Container Management  | 8           | 1       | 4               | 13    |
| Image Management      | 6           | 0       | 3               | 9     |
| Volume Management     | 3           | 0       | 2               | 5     |
| Network Management    | 3           | 0       | 2               | 5     |
| Builder Management    | 0           | 0       | 4               | 4     |
| Registry Management   | 0           | 0       | 3               | 3     |
| System Management     | 2           | 0       | 7               | 9     |
| Run Options           | 5           | 1       | 17              | 23    |
| **Overall**           | **27**      | **2**   | **42**          | **71**|

---

## Container Management

| Feature            | CLI Command                  | Status              | Notes |
|--------------------|------------------------------|----------------------|-------|
| Run container      | `container run`              | :yellow_circle: Partial | RunConfigurationSheet generates a copy-to-clipboard command with mounts, env vars, and read-only flag. ImagesViewModel runs containers with `-d`/`--name`. Many run options not yet exposed (see [Run Options](#run-options)). The app copies an interactive run command to the clipboard rather than running directly with all options. |
| Create container   | `container create`           | :red_circle: Not Implemented | Would create a container without starting it. Could share UI with the run dialog. |
| Start container    | `container start`            | :green_circle: Implemented | ContainersListView action button |
| Stop container     | `container stop`             | :green_circle: Implemented | ContainersListView action button with confirmation dialog |
| Kill container     | `container kill`             | :green_circle: Implemented | ContainersListView action button with confirmation dialog |
| Delete container   | `container rm`               | :green_circle: Implemented | ContainersListView action button with confirmation dialog |
| List containers    | `container ls`               | :green_circle: Implemented | ContainersListView with `--format json --all`, auto-refresh, search, toggle to show/hide stopped containers |
| Exec into container| `container exec`             | :red_circle: Not Implemented | Would require terminal integration or an embedded shell view |
| Export container   | `container export`           | :red_circle: Not Implemented | Would export container filesystem as a tarball |
| Container logs     | `container logs`             | :green_circle: Implemented | LogsView with `--follow`, auto-scroll, line numbers |
| Inspect container  | `container inspect`          | :green_circle: Implemented | InspectView modal with pretty-printed JSON and summary view |
| Container stats    | `container stats`            | :green_circle: Implemented | StatsView with auto-refresh, Table with CPU/Memory/Net IO/Block IO/PIDs. *Added in this PR, targets CLI v0.7.0+.* |
| Prune containers   | `container prune`            | :green_circle: Implemented | ContainersListView toolbar button with confirmation dialog. *Added in this PR, targets CLI v0.9.0+.* |

---

## Image Management

| Feature           | CLI Command                   | Status              | Notes |
|-------------------|-------------------------------|----------------------|-------|
| List images       | `container image list`        | :green_circle: Implemented | ImagesListView with `--format json`, search, per-image arm64 size from inspect |
| Pull image        | `container image pull`        | :green_circle: Implemented | ImagesListView pull dialog |
| Push image        | `container image push`        | :red_circle: Not Implemented | Would push a local image to a remote registry |
| Save image        | `container image save`        | :red_circle: Not Implemented | Would save an image to a tarball file |
| Load image        | `container image load`        | :red_circle: Not Implemented | Would load an image from a tarball file |
| Tag image         | `container image tag`         | :green_circle: Implemented | ImageService.tagImage (service method exists, no UI button exposed yet) |
| Delete image      | `container image rm`          | :green_circle: Implemented | ImagesListView action button with confirmation dialog |
| Prune images      | `container image prune`       | :green_circle: Implemented | ImagesListView toolbar button with confirmation, supports `--all` option. *Added in this PR, targets CLI v0.7.0+.* |
| Inspect image     | `container image inspect`     | :green_circle: Implemented | InspectView modal |

---

## Volume Management

| Feature           | CLI Command                   | Status              | Notes |
|-------------------|-------------------------------|----------------------|-------|
| Create volume     | `container volume create`     | :red_circle: Not Implemented | Would create a named volume with optional options |
| Delete volume     | `container volume rm`         | :red_circle: Not Implemented | Would delete one or more volumes by name |
| Prune volumes     | `container volume prune`      | :green_circle: Implemented | VolumesListView toolbar button with confirmation dialog. *Added in this PR, targets CLI v0.6.0+.* |
| List volumes      | `container volume list`       | :green_circle: Implemented | VolumesListView with `--format json`, search |
| Inspect volume    | `container volume inspect`    | :green_circle: Implemented | InspectView modal |

---

## Network Management

| Feature           | CLI Command                    | Status              | Notes |
|-------------------|--------------------------------|----------------------|-------|
| Create network    | `container network create`     | :red_circle: Not Implemented | Would create a user-defined network |
| Delete network    | `container network rm`         | :red_circle: Not Implemented | Would delete one or more networks by name |
| Prune networks    | `container network prune`      | :green_circle: Implemented | NetworksListView toolbar button with confirmation dialog. *Added in this PR, targets CLI v0.8.0+.* |
| List networks     | `container network list`       | :green_circle: Implemented | NetworksListView with `--format json`, search |
| Inspect network   | `container network inspect`    | :green_circle: Implemented | InspectView modal |

---

## Builder Management

| Feature           | CLI Command                    | Status              | Notes |
|-------------------|--------------------------------|----------------------|-------|
| Start builder     | `container builder start`      | :red_circle: Not Implemented | Would start the builder service |
| Stop builder      | `container builder stop`       | :red_circle: Not Implemented | Would stop the builder service |
| Builder status    | `container builder status`     | :red_circle: Not Implemented | Could show builder health in the sidebar |
| Delete builder    | `container builder delete`     | :red_circle: Not Implemented | Would delete the builder instance |

---

## Registry Management

| Feature           | CLI Command                    | Status              | Notes |
|-------------------|--------------------------------|----------------------|-------|
| Registry login    | `container registry login`     | :red_circle: Not Implemented | Would authenticate with a container registry |
| Registry logout   | `container registry logout`    | :red_circle: Not Implemented | Would remove stored credentials |
| List registries   | `container registry list`      | :red_circle: Not Implemented | Would list configured registries |

---

## System Management

| Feature              | CLI Command                         | Status              | Notes |
|----------------------|-------------------------------------|----------------------|-------|
| Start system         | `container system start`            | :red_circle: Not Implemented | Managed externally via terminal |
| Stop system          | `container system stop`             | :red_circle: Not Implemented | Managed externally via terminal |
| System status        | `container system status`           | :green_circle: Implemented | ContentView sidebar status indicator (green/red dot) |
| System version       | `container system version`          | :red_circle: Not Implemented | Could display version info in an About panel or sidebar |
| System logs          | `container system logs`             | :green_circle: Implemented | SystemLogsView with `--follow`, auto-scroll, line numbers |
| Disk usage           | `container system df`               | :red_circle: Not Implemented | Would show disk usage for images, containers, and volumes |
| DNS management       | `container system dns create/delete/list` | :red_circle: Not Implemented | Would manage DNS entries for containers |
| Kernel configuration | `container system kernel set`       | :red_circle: Not Implemented | Would configure the container runtime kernel |
| System properties    | `container system property list/get/set/clear` | :red_circle: Not Implemented | Would manage system-level configuration properties |

---

## Run Options

These are flags for `container run` that may or may not be exposed in the RunConfigurationSheet UI.

| Option                          | CLI Flag(s)                        | Status              | Notes |
|---------------------------------|------------------------------------|----------------------|-------|
| Detached mode                   | `-d`, `--detach`                   | :green_circle: Implemented | Used when running from ImagesViewModel |
| Container name                  | `--name`                           | :green_circle: Implemented | Run dialog in ImagesListView |
| Volume mounts                   | `-v`, `--volume`                   | :green_circle: Implemented | RunConfigurationSheet workspace + quick mounts + extra mounts |
| Environment variables           | `-e`, `--env`                      | :green_circle: Implemented | RunConfigurationSheet with presets and inherit-from-host |
| Read-only root filesystem       | `--read-only`                      | :green_circle: Implemented | RunConfigurationSheet toggle. *Added in this PR, targets CLI v0.8.0+.* |
| Interactive + TTY               | `-i`, `-t`, `--interactive`, `--tty` | :yellow_circle: Partial | Used in the copied command (`-it`) but not fully configurable in the UI |
| CPU/memory limits               | `--cpus`, `--memory`               | :red_circle: Not Implemented | Would add resource constraint controls to RunConfigurationSheet |
| Port publishing                 | `--publish`                        | :red_circle: Not Implemented | Would add port mapping fields to RunConfigurationSheet |
| Network selection               | `--network`                        | :red_circle: Not Implemented | Would add a network picker to RunConfigurationSheet |
| SSH forwarding                  | `--ssh`                            | :red_circle: Not Implemented | |
| Rosetta translation             | `--rosetta`                        | :red_circle: Not Implemented | |
| Init process                    | `--init`, `--init-image`           | :red_circle: Not Implemented | |
| Custom entrypoint               | `--entrypoint`                     | :red_circle: Not Implemented | |
| User/UID/GID                    | `--user`, `--uid`, `--gid`         | :red_circle: Not Implemented | |
| Working directory               | `--workdir`                        | :red_circle: Not Implemented | |
| DNS configuration               | `--dns`, `--dns-domain`, `--dns-search` | :red_circle: Not Implemented | |
| Platform selection              | `--platform`, `--os`, `--arch`     | :red_circle: Not Implemented | |
| Auto-remove on exit             | `--rm`, `--remove`                 | :red_circle: Not Implemented | |
| Advanced mounts                 | `--mount`                          | :red_circle: Not Implemented | Separate from `-v`; supports more mount options |
| Tmpfs mounts                    | `--tmpfs`                          | :red_circle: Not Implemented | |
| Virtualization backend          | `--virtualization`                 | :red_circle: Not Implemented | |
| Container ID file               | `--cidfile`                        | :red_circle: Not Implemented | |
| Labels                          | `--label`                          | :red_circle: Not Implemented | |

---

## Recently Added

The following features were added as part of the current set of changes:

| Feature              | UI Component                        | Minimum CLI Version |
|----------------------|-------------------------------------|---------------------|
| Container stats      | StatsView (new sidebar item)        | v0.7.0+             |
| Image prune          | ImagesListView toolbar button       | v0.7.0+             |
| Volume prune         | VolumesListView toolbar button      | v0.6.0+             |
| Network prune        | NetworksListView toolbar button     | v0.8.0+             |
| Container prune      | ContainersListView toolbar button   | v0.9.0+             |
| Read-only filesystem | RunConfigurationSheet toggle        | v0.8.0+             |

---

## Contributing

Want to help implement one of the missing features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code style, architecture, and how to submit a pull request.

When picking a feature to work on, consider starting with:

- **Volume/network create and delete** - straightforward CRUD operations following existing patterns
- **Port publishing (`--publish`)** - highly requested for running web services
- **CPU/memory limits** - simple flag additions to RunConfigurationSheet
- **System version** - quick win for an About panel or sidebar display

All CLI interaction should go through `CLIExecutor` via the appropriate service layer. Follow the existing MVVM pattern: Views -> ViewModels -> Services -> CLIExecutor -> CLI.
