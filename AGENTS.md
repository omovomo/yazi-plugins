# AGENTS.md

## Project

Monorepo of Yazi plugins for the `omovomo` GitHub account.
Repository: https://github.com/omovomo/yazi-plugins (branch: main)

## Structure

```
*.yazi/          — each directory is a separate Yazi plugin
  main.lua       — plugin entry point
  README.md      — plugin documentation
  LICENSE        — MIT, Copyright (c) 2025 omovomo
.gitignore       — allows all *.yazi/** files
README.md        — monorepo overview with plugin table
```

## Deploy & Test

Plugin source is in repo, test copy at: `C:\Portables\.config\yazi\plugins\<name>.yazi\`
After editing, copy main.lua to test location before user verifies.

## Yazi Plugin API (v26.x) — Critical Notes

### Common Mistakes (learned the hard way)

- **No `args()` method** on Command — only `arg()`
- **No `ya.manager_emit()`** — use `ya.emit(action, { args })`
- **No `ya.mgr_emit()`** — same, use `ya.emit()`
- **No `ya.hide()`** — use `ui.hide()` (returns permit)
- **No `position`** in ya.input — use `pos`
- **No `write()` on Child** — use `write_all(data)` + `flush()`
- **No `Command("pwsh"):arg("/c", ...)`** — correct is `arg("-NoProfile"):arg("-Command"):arg(...)`
- **Scoop shims** may not launch via `Command("name")` — use `os.execute()` or `Command("cmd"):arg("/c"):arg("name")`
- **Windows paths from external tools** — normalize with `gsub("\\", "/")` and `gsub("\r\n", "\n")`
- **Passing user query with flags (e.g. `-r regex$`)** — split by whitespace with `gmatch("%S+")` and pass each as `arg()`, otherwise Command quotes the whole string
- **`fs.cha()` is async-only** — cannot be called inside `ya.sync()`. Use cached `file.cha.is_dir` from `cx.active.current.hovered` instead
- **`ui.Text.LEFT` / `ui.Line.LEFT` don't exist** — alignment constants are on `ui.Align` (e.g. `ui.Align.LEFT`, `ui.Align.CENTER`)
- **`ya.which` uses `cands`** (not `items`) — returns 1-based index or nil
- **`cx.active.selected` is not indexable by Url** — convert to strings for key lookup: `tostring(f.url)`
- **`os.time()` not available** in Yazi sandbox — avoid it, use `duration` from rclone API or other alternatives
- **`ya.sleep(n)`** — async sleep for n seconds, available in plugin async context
- **Lua locals must be declared before use** — forward references don't work; define helpers before functions that call them
- **Plugin args use `--` separator** — `plugin fastcopy -- copy filter noexec` passes `{"copy", "filter", "noexec"}`

### Command API

```lua
local child, err = Command("prog"):arg("flag"):arg("value"):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
local output = child:wait_with_output()
-- output.status.code, output.stdout, output.stderr
-- child:write_all(data), child:flush()
-- child:read(512) returns (data, event) — event: 0=stdout, 1=stderr, 2=eof
```

### Key APIs

- `ya.emit(action, { args })` — send action to manager
- `ya.input({ title, pos, value })` — returns (value, event)
- `ya.notify({ title, content, timeout, level })` — show notification
- `ya.confirm({ title, content, pos })` — returns boolean
- `ya.sync(fn)` — create sync wrapper for async context
- `ui.hide()` — hide yazi UI, returns permit
- `cx.active.current.cwd` — current directory URL
- `cx.active.current.hovered` — hovered file
- `cx.active.selected` — selected files

### Plugin entry

```lua
local function entry(_, job)
    local mode = job.args[1]  -- from keymap: plugin name arg1 arg2
end
return { entry = entry }
```

## Code Style

- No comments in code
- `@since` annotation at top of main.lua (date format: YY.MM.DD)
- MIT license, Copyright (c) 2025 omovomo

## Commands

No lint/typecheck commands configured. Test by copying to yazi plugins dir and restarting yazi.
