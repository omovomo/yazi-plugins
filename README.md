# yazi-plugins

A collection of plugins for the [Yazi](https://github.com/sxyazi/yazi) file manager.

> The plugin system is still in its early stages. Make sure both your Yazi and plugins are up to date to ensure proper functionality.

## Plugins

- [everything-search.yazi](everything-search.yazi/) - Search files using [Everything](https://www.voidtools.com/) with interactive [fzf](https://github.com/junegunn/fzf) selection
- [rclone.yazi](rclone.yazi/) - Cloud storage operations (copy, move, sync, bisync, delete) via [rclone](https://rclone.org/)

## Installation

```sh
ya pkg add omovomo/yazi-plugins:everything-search
ya pkg add omovomo/yazi-plugins:rclone
```

For specific configuration instructions, check the individual `README.md` of each plugin.

## License

MIT
