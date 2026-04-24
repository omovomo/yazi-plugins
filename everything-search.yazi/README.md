# everything-search.yazi

A plugin for [Yazi](https://github.com/sxyazi/yazi) that searches files on Windows using [Everything](https://www.voidtools.com/) with interactive [fzf](https://github.com/junegunn/fzf) selection.

## Prerequisites

- Yazi v0.3.0 or newer
- [Everything](https://www.voidtools.com/) (`es.exe` must be in `PATH`)
- [fzf](https://github.com/junegunn/fzf) (`fzf.exe` must be in `PATH`)

## Installation

```sh
ya pkg add omovomo/yazi-plugins:everything-search
```

## Keybinding

Add to your `keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "g", "e" ]
run  = "plugin everything-search"
desc = "Everything search (es.exe + fzf)"
```

## Usage

1. Press `g` then `e` to open the search prompt
2. Type your query and press Enter
3. Select a result from the fzf list
4. Yazi will navigate to or reveal the selected file
