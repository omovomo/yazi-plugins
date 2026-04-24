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
desc = "Everything search in current directory (fzf)"

[[manager.prepend_keymap]]
on   = [ "g", "E" ]
run  = "plugin everything-search global"
desc = "Everything search globally (fzf)"

[[manager.prepend_keymap]]
on   = [ "g", "s" ]
run  = "plugin everything-search gui"
desc = "Everything search in GUI"
```

## Usage

1. Press `g` then `e` to search within the current directory with fzf, `g` then `E` for a global fzf search
2. Press `g` then `s` to open the Everything GUI with your query
3. Supports [Everything search syntax](https://www.voidtools.com/support/everything/search_syntax/), e.g. `pic: \bin`, `ext:exe;ini dm:today`
