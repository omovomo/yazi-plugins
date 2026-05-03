# rclone.yazi

Cloud storage operations via [rclone](https://rclone.org/) - copy, move, sync, bisync, delete, mount.

## Installation

```sh
ya pkg add omovomo/yazi-plugins:rclone
```

## Prerequisites

- Yazi v25.2.13 or newer
- [rclone](https://rclone.org/) (must be in `PATH`)
- [WinFsp](https://winfsp.dev/) (required for `mount` on Windows)

## Keybinding

Add to your `keymap.toml`:

```toml
prepend_keymap = [
	{ on = [ "g", "r", "c" ], run = "plugin rclone copy",    desc = "Rclone: copy/move/sync/bisync" },
	{ on = [ "g", "r", "d" ], run = "plugin rclone delete",  desc = "Rclone: delete selected" },
	{ on = [ "g", "r", "m" ], run = "plugin rclone mount",   desc = "Rclone: mount remote" },
	{ on = [ "g", "r", "u" ], run = "plugin rclone unmount", desc = "Rclone: unmount" },
]
```

## Setup

Initialize the status bar widget in your `init.lua`:

```lua
require("rclone"):setup()
```

This adds a progress indicator to the status bar showing transfer speed, percentage, and ETA.

## Usage

### Copy / Move / Sync

1. **Select** files/folders to operate on
2. Press the copy keybinding
3. **Select mode** from the `ya.which` dialog
4. **Edit destination** path (defaults to current directory)
5. **Confirm** the operation in the preview dialog
6. Progress is shown in the status bar during transfer

### Delete

1. **Select** files/folders (or hover a single item)
2. Press the delete keybinding
3. **Select mode** from the `ya.which` dialog
4. **Confirm** deletion in the warning dialog

### Mount

1. Press the mount keybinding
2. **Select remote** from `rclone listremotes`
3. **Enter remote path** (press Enter for root)
4. **Enter mount point** (drive letter, e.g. `Z:`)
5. **Select cache mode** (Full recommended)
6. **Confirm** — rclone mount starts in a new console window

The mount runs in a separate console window. Close that window or use the unmount command to disconnect.

### Unmount

1. Press the unmount keybinding
2. **Select active mount** from the list (shows remote, drive letter, PID)
3. **Confirm** — the rclone process is terminated

## Modes

### Copy / Move / Sync modes

| Key | Mode | Description |
|-----|------|-------------|
| `c` | Copy | Copy files to destination |
| `m` | Move | Move files (deletes empty source dirs) |
| `s` | Sync | Sync source to destination |
| `b` | BiSync | Bidirectional sync |
| `r` | BiReSync | Bidirectional sync (resync) |

### Delete modes

| Key | Mode | Description |
|-----|------|-------------|
| `d` | Delete | Delete selected files |
| `w` | Delete + Rmdirs | Delete files and remove empty directories |

### Mount cache modes

| Key | Mode | Description |
|-----|------|-------------|
| `f` | Full | Cache all reads and writes (recommended) |
| `w` | Writes | Cache writes only |
| `m` | Minimal | Minimal read-ahead caching |
| `n` | None | No caching |

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
