# everything-search.yazi

Search files on Windows using [Everything](https://www.voidtools.com/) with interactive [fzf](https://github.com/junegunn/fzf) selection.

## Installation

```sh
ya pkg add omovomo/yazi-plugins:everything-search
```

## Prerequisites

- Yazi v25.5.31 or newer
- [Everything](https://www.voidtools.com/) (`es.exe` must be in `PATH`)
- [fzf](https://github.com/junegunn/fzf) (`fzf.exe` must be in `PATH`)

## Keybinding

Add to your `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "e" ]
run  = "plugin everything-search"
desc = "Everything search in current directory (fzf)"

[[mgr.prepend_keymap]]
on   = [ "g", "E" ]
run  = "plugin everything-search global"
desc = "Everything search globally (fzf)"

[[mgr.prepend_keymap]]
on   = [ "g", "s" ]
run  = "plugin everything-search gui"
desc = "Everything search in GUI"
```

## Usage

- `g` then `e` - search within the current directory with fzf
- `g` then `E` - global search with fzf
- `g` then `s` - open the Everything GUI with your query

Supports [Everything search syntax](https://www.voidtools.com/support/everything/search_syntax/), e.g. `pic: \bin`, `ext:exe;ini dm:today`.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
