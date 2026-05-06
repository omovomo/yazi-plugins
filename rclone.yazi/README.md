# rclone.yazi

Mount, sync, and manage cloud storage via [rclone](https://rclone.org/) with `rclone rcd` daemon.

Uses [rclone rcd](https://rclone.org/commands/rclone_rcd/) (remote control daemon) and [rclone rc](https://rclone.org/commands/rclone_rc/) (remote control API) for all operations.

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
	{ on = "<F9>", run = "plugin rclone menu",       desc = "Rclone: mount/manage" },
	{ on = "<F7>", run = "plugin rclone sync_menu",   desc = "Rclone: sync/bisync" },
	{ on = "q",    run = "plugin rclone quit",        desc = "Rclone: Quit yazi with unmount all" },
]
```

Press `<F9>` to open the rclone menu, then select an action by number (layout-independent):

| Key | Action |
|-----|--------|
| `1` | Mount remote |
| `2` | Unmount |
| `3` | Unmount all |
| `4` | Status |

Press `<F7>` for sync operations:

| Key | Action |
|-----|--------|
| `1` | Sync |
| `2` | BiSync |

Individual actions can also be bound directly: `plugin rclone mount`, `plugin rclone unmount`, `plugin rclone unmountall`, `plugin rclone status`, `plugin rclone sync`, `plugin rclone bisync`.

## Setup

Initialize the plugin in your `init.lua`:

```lua
require("rclone"):setup()
```

### Options

```lua
require("rclone"):setup({
	url = "http://localhost:5572/",   -- rcd daemon address
	cache_mode = "full",               -- "off", "minimal", "writes", "full"
	unmount_on_exit = true,            -- unmount all when quitting yazi
})
```

`cache_mode` controls the VFS cache mode used when mounting. Default is `"full"`.

When `unmount_on_exit` is `true`, the `q` keybinding above replaces the default quit action to unmount all remotes before exiting.

The progress indicator in the status bar shows transfer speed, percentage, and ETA during sync operations.

## Architecture

The plugin uses `rclone rcd` as a background daemon:

- **Setup**: Start `rclone rcd` manually (e.g. `rclone rcd --rc-addr localhost:5572`). The plugin connects to it via `rclone rc`.
- **Operations**: All actions (mount, sync, etc.) are performed via `rclone rc` commands sent to the daemon.

## Usage

### Mount

1. Press the mount keybinding
2. **Select remote** from configured remotes
3. **Enter remote path** (press Enter for root)
4. **Enter mount point** (drive letter, path, or `*` for auto-assign on Windows)
5. **Confirm** — mount is created via rc API with the configured cache mode

On Windows, use `*` as mount point to let the system assign the next available drive letter.

### Unmount

1. Press the unmount keybinding
2. **Select active mount** from the list
3. **Confirm** — mount is removed via rc API

### Status

Shows all active mounts via `mount/listmounts`.

### Sync

1. **Enter source path** (defaults to current directory)
2. **Enter destination path**
3. **Confirm** — sync runs asynchronously via rc API
4. Progress is shown in the status bar

### BiSync

Same as sync but performs bidirectional synchronization between two paths.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
