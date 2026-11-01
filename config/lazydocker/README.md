# lazydocker Configuration & Architecture Specification

Specification and operational guide for the global [lazydocker](https://github.com/jesseduffield/lazydocker) deployment.

- **Config Path**: `~/.config/lazydocker/config.yml`
- **Target Platform**: macOS (Darwin arm64 / Apple Silicon)
- **Active Binary**: lazydocker 0.25.2 (Homebrew)
- **Target Engine**: Docker 29+ & Docker Compose v5+ (`desktop-linux` context)
- **Validation Script**: [`~/.local/bin/lazydocker/validate.sh`](file:///Users/x0r/.local/bin/lazydocker/validate.sh)
- **Shell Abbreviation**: `lzd` -> `lazydocker`

---

## 1. Architectural Principles & System Boundaries

`lazydocker` provides a terminal user interface for Docker container lifecycle management, image inspection, volume governance, and multi-service orchestration. The configuration enforces the following architectural standards:

1. **Docker Compose v2 Specification**:
   - Legacy `docker-compose` (Python standalone v1 binary) is deprecated and relies on compatibility translation layers.
   - The configuration strictly specifies `docker compose` (Docker CLI v2 plugin) across all `commandTemplates` and `bulkCommands`, guaranteeing native support for compose profiles, parallel builds, and modern resource constraints.
2. **Buffer Exhaustion Guard (`logs.tail: "300"`)**:
   - Containers generating high-throughput log streams can overwhelm the terminal emulator and gocui event loop if unconstrained.
   - Limiting cold-start log ingestion to `tail: "300"` lines with `since: "60m"` preserves sub-millisecond UI responsiveness while providing immediate diagnostic context.
3. **UX & Visual Density Alignment**:
   - **Panel Ratio (`sidePanelWidth: 0.3333`)**: Standardized to one-third screen width, preventing truncation of long container names, hashes, and service labels.
   - **Contextual Keybinding Visibility (`showBottomLine: true`)**: Retains the contextual bottom bar displaying available actions and operational state.
   - **Accordion Focus (`expandFocusedSidePanel: true`)**: Dynamically allocates vertical space to the active section (Containers, Images, Volumes, Networks).
4. **Environment X Theme Tokens**:
   - Synchronized with the canonical terminal palette ([`kitty/themes/x.conf`](file:///Users/x0r/.config/kitty/themes/x.conf), [`lazygit/config.yml`](file:///Users/x0r/.config/lazygit/config.yml)).
   - Active borders: Neon Cyan (`#00FFFF`, bold).
   - Inactive borders: Muted Slate (`#44475A`).
   - Selection background: Slate (`#44475A`).
   - Keybinding labels: Slate Blue (`#6272A4`).

---

## 2. Configuration Structure ([`config.yml`](file:///Users/x0r/.config/lazydocker/config.yml))

```yaml
# yaml-language-server: $schema=https://json.schemastore.org/lazydocker.json

gui:
  scrollHeight: 2
  language: "auto"
  theme:
    activeBorderColor:
      - "#00ffff" # Neon Cyan (Environment X active border/cursor token)
      - bold
    inactiveBorderColor:
      - "#44475a" # Muted Slate
    optionsTextColor:
      - "#6272a4" # Comment Slate (bottom bar options)
    selectedLineBgColor:
      - "#44475a" # Selection Background (consistent with lazygit/fzf)
  returnImmediately: false
  wrapMainPanel: true
  sidePanelWidth: 0.3333
  showBottomLine: true
  expandFocusedSidePanel: true
  screenMode: "normal"
  containerStatusHealthStyle: "long"

logs:
  timestamps: false
  since: "60m"
  tail: "300"

commandTemplates:
  dockerCompose: "docker compose"
  restartService: "{{ .DockerCompose }} restart {{ .Service.Name }}"
  startService: "{{ .DockerCompose }} start {{ .Service.Name }}"
  stopService: "{{ .DockerCompose }} stop {{ .Service.Name }}"
  up: "{{ .DockerCompose }} up -d"
  upService: "{{ .DockerCompose }} up -d {{ .Service.Name }}"
  down: "{{ .DockerCompose }} down"
  downWithVolumes: "{{ .DockerCompose }} down --volumes"
  serviceLogs: "{{ .DockerCompose }} logs --since=60m --follow {{ .Service.Name }}"
  viewServiceLogs: "{{ .DockerCompose }} logs --follow {{ .Service.Name }}"
  rebuildService: "{{ .DockerCompose }} up -d --build {{ .Service.Name }}"
  recreateService: "{{ .DockerCompose }} up -d --force-recreate {{ .Service.Name }}"
  allLogs: "{{ .DockerCompose }} logs --tail=300 --follow"
  viewAlLogs: "{{ .DockerCompose }} logs"
  dockerComposeConfig: "{{ .DockerCompose }} config"
  checkDockerComposeConfig: "{{ .DockerCompose }} config --quiet"
  serviceTop: "{{ .DockerCompose }} top {{ .Service.Name }}"

customCommands:
  containers:
    - name: "Interactive Shell (sh)"
      attach: true
      command: "docker exec -it {{ .Container.ID }} /bin/sh"
      serviceNames: []
    - name: "Interactive Shell (bash)"
      attach: true
      command: "docker exec -it {{ .Container.ID }} /bin/bash"
      serviceNames: []
    - name: "Inspect Container (JSON)"
      attach: true
      command: "docker inspect {{ .Container.ID }}"
      serviceNames: []
    - name: "Process Tree (top)"
      attach: true
      command: "docker top {{ .Container.ID }}"
      serviceNames: []
    - name: "Live Stats (One-shot)"
      attach: true
      command: "docker stats --no-stream {{ .Container.ID }}"
      serviceNames: []
    - name: "Container Environment"
      attach: true
      command: "docker exec -it {{ .Container.ID }} env"
      serviceNames: []
    - name: "Prune Stopped Containers"
      attach: false
      command: "docker container prune -f"
      serviceNames: []

bulkCommands:
  services:
    - name: "up"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} up -d"
      serviceNames: []
    - name: "up (attached)"
      attach: true
      shell: false
      command: "{{ .DockerCompose }} up"
      serviceNames: []
    - name: "stop"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} stop"
      serviceNames: []
    - name: "pull"
      attach: true
      shell: false
      command: "{{ .DockerCompose }} pull"
      serviceNames: []
    - name: "build"
      attach: true
      shell: false
      command: "{{ .DockerCompose }} build --parallel --force-rm"
      serviceNames: []
    - name: "down"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} down"
      serviceNames: []
    - name: "down with volumes"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} down --volumes"
      serviceNames: []
    - name: "down with images"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} down --rmi all"
      serviceNames: []
    - name: "down with volumes and images"
      attach: false
      shell: false
      command: "{{ .DockerCompose }} down --volumes --rmi all"
      serviceNames: []

os:
  openCommand: "open {{filename}}"
  openLinkCommand: "open {{link}}"

stats:
  graphs:
    - caption: "CPU (%)"
      statPath: DerivedStats.CPUPercentage
      color: cyan
    - caption: "Memory (%)"
      statPath: DerivedStats.MemoryPercentage
      color: green
  maxDuration: 3m0s
```

---

## 3. Custom Commands Architecture

Custom commands are accessible within `lazydocker` by pressing `x` on any focused container:

| Action Name | Execution Command | Mode | Purpose |
| :--- | :--- | :--- | :--- |
| **Interactive Shell (sh)** | `docker exec -it {{ .Container.ID }} /bin/sh` | Attached | Immediate shell access into minimal (Alpine/distroless) containers. |
| **Interactive Shell (bash)** | `docker exec -it {{ .Container.ID }} /bin/bash` | Attached | Full bash shell access with history and readline support. |
| **Inspect Container (JSON)** | `docker inspect {{ .Container.ID }}` | Attached | Detailed runtime state, mount bindings, and network settings. |
| **Process Tree (top)** | `docker top {{ .Container.ID }}` | Attached | Real-time PID listing running inside the isolated cgroup namespace. |
| **Live Stats (One-shot)** | `docker stats --no-stream {{ .Container.ID }}` | Attached | CPU, memory limit, network I/O, and block I/O snapshot. |
| **Container Environment** | `docker exec -it {{ .Container.ID }} env` | Attached | Environment variable inspection for debugging injection errors. |
| **Prune Stopped** | `docker container prune -f` | Detached | Reclaims dead container cgroups and writable layers. |

---

## 4. Bulk Commands Architecture

Bulk commands are accessed by pressing `b` on the Services panel for batch Docker Compose actions:

- **Lifecycle**: `up` (detached), `up (attached)`, `stop`, `down`.
- **Image Operations**: `pull` (updates upstream tags), `build` (parallel multi-stage re-compilation with `--force-rm`).
- **Deep Clean**: `down with volumes` (`--volumes`), `down with images` (`--rmi all`), and complete teardown (`--volumes --rmi all`).

---

## 5. Architectural Traps & Guardrails

> [!CAUTION]
> **Trap 1: Docker Desktop Daemon Socket Topology on macOS**  
> On macOS Apple Silicon, Docker Desktop defaults to user-scoped sockets:  
> `unix:///Users/x0r/.docker/run/docker.sock`  
> rather than the traditional `/var/run/docker.sock`.  
> *Rule*: If `lazydocker` reports `Cannot connect to Docker daemon`, ensure Docker Desktop is started or verify the active context with `docker context ls`. Never hardcode raw paths in aliases; rely on Docker context management (`desktop-linux`).

> [!WARNING]
> **Trap 2: Compose v1 Hyphenation (`docker-compose`)**  
> Standalone `docker-compose` v1 binaries are obsolete. Hardcoding hyphenated commands breaks on environments with only Docker Compose v2 CLI plugins installed.  
> *Rule*: Always declare `dockerCompose: "docker compose"`.

> [!IMPORTANT]
> **Trap 3: Log Buffer Saturation**  
> Setting `tail: ""` without constraints forces `lazydocker` to fetch all logs generated in the `since` window. For production-like databases or event buses, this can cause terminal freezing.  
> *Rule*: Keep `logs.tail` set to a bounded integer (`300`).

---

## 6. Verification & Conformance Script

A standalone validation script is maintained at [`~/.local/bin/lazydocker/validate.sh`](file:///Users/x0r/.local/bin/lazydocker/validate.sh).

### Invariants Tested

1. **Binary & Environment**: Resolves executable, verifies version ($\ge 0.20.0$), validates Darwin arm64 architecture.
2. **Configuration Integrity**: Confirms `config.yml` existence, validates YAML syntax with PyYAML, checks schema integrity.
3. **Compose v2 Conformance**: Confirms `commandTemplates.dockerCompose` uses `docker compose`.
4. **Theme Tokens**: Verifies activeBorderColor, inactiveBorderColor, and selectedLineBgColor definitions.
5. **Custom & Bulk Actions**: Verifies interactive shell attachments, inspect triggers, and bulk lifecycle actions.
6. **Toolchain Integration**: Verifies Docker CLI, Docker Compose plugin, and Docker context responsiveness.
7. **Performance Benchmark**: Asserts configuration deserialization latency $< 150\text{ ms}$.

### Execution

```bash
# Run validation (defaults to zero flags, exit code 0 on success)
~/.local/bin/lazydocker/validate.sh

# JSON output mode
~/.local/bin/lazydocker/validate.sh --json
```

---

## 7. Directory Layout

```
~/.config/lazydocker/
├── README.md               # Architectural specification (this file)
└── config.yml              # Master lazydocker configuration

~/.local/bin/lazydocker/
└── validate.sh             # Conformance and benchmark test script
```
