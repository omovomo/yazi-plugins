# fastcopy.yazi

File operations via [FastCopy](https://fastcopy.jp/help/fastcopy_eng.htm) - copy, move, delete with high performance.

## Installation

```sh
ya pkg add omovomo/yazi-plugins:fastcopy
```

## Prerequisites

- Yazi v26.1.22 or newer
- [FastCopy](https://fastcopy.jp/) (`fastcopy.exe` must be in `PATH`, e.g. installed via [Scoop](https://scoop.sh/): `scoop install fastcopy`)

## Keybinding

Add to your `keymap.toml`:

```toml
prepend_keymap = [
	{ on = "<F5>",     run = "plugin fastcopy -- copy",              desc = "FastCopy: copy selected to hovered" },
	{ on = "<F6>",     run = "plugin fastcopy -- move",              desc = "FastCopy: move selected to hovered" },
	{ on = "<F8>",     run = "plugin fastcopy -- delete",            desc = "FastCopy: delete selected" },
	{ on = "<S-F5>",   run = "plugin fastcopy -- copy noexec",       desc = "FastCopy: copy preview (no exec)" },
	{ on = "<S-F6>",   run = "plugin fastcopy -- move noexec",       desc = "FastCopy: move preview (no exec)" },
	{ on = "<S-F8>",   run = "plugin fastcopy -- delete noexec",     desc = "FastCopy: delete preview (no exec)" },
	{ on = "<C-F5>",   run = "plugin fastcopy -- copy filter",       desc = "FastCopy: copy with filter" },
	{ on = "<C-F6>",   run = "plugin fastcopy -- move filter",       desc = "FastCopy: move with filter" },
	{ on = "<C-F8>",   run = "plugin fastcopy -- delete filter",     desc = "FastCopy: delete with filter" },
	{ on = "<C-S-F5>", run = "plugin fastcopy -- copy filter noexec",desc = "FastCopy: copy with filter (no exec)" },
	{ on = "<C-S-F6>", run = "plugin fastcopy -- move filter noexec",desc = "FastCopy: move with filter (no exec)" },
	{ on = "<C-S-F8>", run = "plugin fastcopy -- delete filter noexec",desc = "FastCopy: delete with filter (no exec)" },
]
```

### Arguments

| Argument | Description |
|----------|-------------|
| *(none)* | Normal execution |
| `noexec` | Preview mode (`/no_exec`) |
| `filter` | Force filter input (even for single file) |
| `filter noexec` | Force filter + preview |

Arguments can be combined in any order.

## Usage

1. **Select** files/folders (for delete, hovering also works)
2. Press the keybinding for the desired operation
3. **Select mode** from the `ya.which` dialog
4. For copy/move: **edit destination** path (defaults to current directory, control trailing `\` behavior)
5. **Edit filters** or press Enter to skip (only with `filter` argument)
6. FastCopy GUI opens with `/estimate /auto_close`

### Destination path trailing `\`

FastCopy behaves differently depending on the trailing backslash:

- `D:\Target\` — copies source directory **into** `D:\Target\SourceName\`
- `D:\Target` — copies source directory **contents** into `D:\Target\`

The plugin pre-fills with trailing `\` by default. Edit the destination input to change this behavior.

### Copy modes

| Key | Mode | Description |
|-----|------|-------------|
| `d` | Diff (Size/Date) | Copy if size or date differs |
| `f` | Force Copy | Always overwrite |
| `n` | No Overwrite | Skip existing files |
| `u` | Update (Newer) | Copy if source is newer |

### Move modes

| Key | Mode | Description |
|-----|------|-------------|
| `o` | Move (Overwrite) | Move and overwrite |
| `s` | Sync (Size/Date) | Mirror source to destination |
| `e` | Sync (Newer) | Mirror with newer files |

### Delete modes

| Key | Mode | Description |
|-----|------|-------------|
| `d` | Delete | Delete files and folders |
| `w` | Wipe & Delete | Overwrite with random data before deleting |

### Filters

The filter input is pre-filled with a template:

```
Include: Exclude: FromDate: ToDate: MinSize: MaxSize:
```

Fill in values after the colons to apply filters. Leave empty to skip. Examples:

```
Include:*.txt;*.doc Exclude:*.bak FromDate: ToDate: MinSize: MaxSize:
Include: Exclude:*.tmp FromDate:-30D ToDate: MinSize:1K MaxSize:1G
```

Supported filter fields (see [FastCopy filter docs](https://fastcopy.jp/help/fastcopy_eng.htm#filter)):

- **Include** — UNIX wildcard pattern (`*.txt;*.doc`)
- **Exclude** — UNIX wildcard pattern (`*.bak;*.log`)
- **FromDate** — oldest timestamp (`-10D`, `20260101`, `2016/09/26 12:30:56`)
- **ToDate** — newest timestamp (same format)
- **MinSize** — minimum file size (`1K`, `10M`, `1G`)
- **MaxSize** — maximum file size (same format)

### Preview mode (noexec)

`Shift` keybindings (`Shift+F5`, `Shift+F6`, `Shift+F8`) launch FastCopy with `/no_exec` — the FastCopy UI opens showing the file list and estimate but does not execute. Use this to preview what will happen before running for real.

### Filter mode

`Ctrl` keybindings (`Ctrl+F5`, `Ctrl+F6`, `Ctrl+F8`) force the filter input to appear even for single files. `Ctrl+Shift` combines filter input with preview mode.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
