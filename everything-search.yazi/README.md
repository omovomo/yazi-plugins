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
prepend_keymap = [
	{ on = "<C-f>",   run = "plugin everything-search",       desc = "Everything search from CD" },
	{ on = "<C-а>",   run = "plugin everything-search",       desc = "Everything search from CD (ru/ukr)" },
	{ on = "<A-f>",   run = "plugin everything-search global", desc = "Everything search global" },
	{ on = "<A-а>",   run = "plugin everything-search global", desc = "Everything search global (ru/ukr)" },
	{ on = "<C-A-f>", run = "plugin everything-search gui",    desc = "Everything search GUI" },
	{ on = "<C-A-а>", run = "plugin everything-search gui",    desc = "Everything search GUI (ru/ukr)" },
]
```

## Usage

- `Ctrl+F` — search within the current directory with fzf
- `Alt+F` — global search with fzf
- `Ctrl+Alt+F` — open the Everything GUI with your query

Supports [Everything search syntax](https://www.voidtools.com/support/everything/search_syntax/), e.g. `pic: \bin`, `ext:exe;ini dm:today`.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
