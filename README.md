# yazi-plugins

A collection of plugins for the [Yazi](https://github.com/sxyazi/yazi) file manager.

## Plugins

| Plugin | Description | Platform |
|--------|-------------|----------|
| [everything-search](everything-search.yazi/) | Search files using [Everything](https://www.voidtools.com/) with interactive [fzf](https://github.com/junegunn/fzf) selection | Windows |
| [rclone](rclone.yazi/) | Cloud storage operations (copy, move, sync, bisync, delete) via [rclone](https://rclone.org/) | Cross-platform |

## Installation

Install individual plugins using `ya pack`:

```sh
# Everything Search (Windows)
ya pkg add omovomo/yazi-plugins:everything-search

# Rclone
ya pkg add omovomo/yazi-plugins:rclone
```

### Manual Installation

**Linux/macOS:**
```sh
git clone https://github.com/omovomo/yazi-plugins.git ~/.config/yazi/plugins/yazi-plugins
```

**Windows:**
```sh
git clone https://github.com/omovomo/yazi-plugins.git %AppData%\yazi\config\plugins\yazi-plugins
```

Then add keybindings for each plugin as described in their individual READMEs.

## Requirements

- [Yazi](https://github.com/sxyazi/yazi) file manager (v0.3.0 or newer)
- Individual plugin dependencies (see each plugin's README)

## License

MIT
