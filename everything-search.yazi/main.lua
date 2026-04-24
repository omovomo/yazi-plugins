--- @since 25.5.31

local function fail(s, ...)
    ya.notify {
        title = "everything-search",
        content = string.format(s, ...),
        timeout = 5,
        level = "error",
    }
end

local root = ya.sync(function()
    return cx.active.current.cwd
end)

local function entry(_)
    local query, _ = ya.input {
        title = "EveryThing Search:",
        pos = { "center", w = 50 },
    }

    if not query or query:len() == 0 then
        return
    end

    local parentDir = root()
    local es_search_command = string.format('es "%s" -path "%s" | fzf', query, parentDir)
    local _permit = ya.hide()

    local child, err = Command("pwsh"):arg({ "/c", es_search_command }):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.PIPED):spawn()

    if not child then
        return fail("Spawn command failed with error code %s.", err)
    end

    local output, err = child:wait_with_output()
    if not output then
        return fail("Cannot read command output, error code %s", err)
    end

    local target = output.stdout:gsub("\n$", "")

    if target ~= "" then
        local is_dir = target:sub(-1) == "/"
        ya.manager_emit(is_dir and "cd" or "reveal", { target })
    end
end

return {
    entry = entry,
}
