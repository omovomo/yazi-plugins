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

local function entry(_, job)
    local mode = job and job.args and job.args[1] or "local"
    local title = mode == "global" and "EveryThing Search (global):" or "EveryThing Search:"

    local query, _ = ya.input {
        title = title,
        pos = { "center", w = 50 },
    }

    if not query or query:len() == 0 then
        return
    end

    local es_search_command
    if mode == "global" then
        es_search_command = string.format('es "%s" | fzf', query)
    else
        local parentDir = root()
        es_search_command = string.format('es -path "%s" "%s" | fzf', parentDir, query)
    end

    local _permit = ui.hide()

    local child, err = Command("cmd"):args({ "/c", es_search_command }):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.PIPED):spawn()

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
