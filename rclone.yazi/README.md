# rclone.yazi

A plugin for [Yazi](https://github.com/sxyazi/yazi) that provides cloud storage operations via [rclone](https://rclone.org/).

## Prerequisites

- Yazi v0.3.0 or newer
- [rclone](https://rclone.org/) (must be in `PATH`)

## Installation

```sh
ya pkg add omovomo/yazi-plugins:rclone
```

## Keybinding

Add to your `keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "g", "r", "c" ]
run  = "plugin rclone copy"
desc = "Rclone copy to hovered directory"

[[manager.prepend_keymap]]
on   = [ "g", "r", "m" ]
run  = "plugin rclone move"
desc = "Rclone move to hovered directory"

[[manager.prepend_keymap]]
on   = [ "g", "r", "s" ]
run  = "plugin rclone sync"
desc = "Rclone sync to hovered directory"

[[manager.prepend_keymap]]
on   = [ "g", "r", "b" ]
run  = "plugin rclone bisync"
desc = "Rclone bisync with hovered directory"

[[manager.prepend_keymap]]
on   = [ "g", "r", "d" ]
run  = "plugin rclone delete"
desc = "Rclone delete selected"
```

## Setup

Initialize the status bar widget in your `init.lua`:

```lua
require("rclone"):setup()
```

This adds a progress indicator to the status bar showing transfer speed, percentage, and ETA.

## Usage

1. Select files/folders (or hover a single item)
2. Hover the target directory
3. Press the keybinding for the desired operation
4. Confirm the destination and operation in the dialog
5. Progress is shown in the status bar during transfer
