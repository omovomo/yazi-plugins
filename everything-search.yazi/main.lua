--- @since 25.5.31

local function fail(s, ...)
    ya.notify {
        title = "everything-search",
        content = string.format(s, ...),
        timeout = 5,
        level = "error",
    }
end

local ES_ERRORS = {
    [0] = "No error",
    [1] = "Failed to register window class",
    [2] = "Failed to create listening window",
    [3] = "Out of memory",
    [4] = "Missing command line option",
    [5] = "Failed to create export file",
    [6] = "Unknown switch",
    [7] = "Failed to send IPC query",
    [8] = "Everything is not running. Please start Everything first.",
}

local root = ya.sync(function()
    return cx.active.current.cwd
end)

local function entry(_, job)
    local mode = job and job.args and job.args[1] or "local"

    if mode == "gui" then
        local query, _ = ya.input {
            title = "EveryThing Search (GUI):",
            pos = { "center", w = 50 },
        }
        if not query or query:len() == 0 then
            return
        end
        os.execute(string.format('everything -s "%s"', query))
        return
    end

    local title = mode == "global" and "EveryThing Search (global):" or "EveryThing Search:"

    local query, _ = ya.input {
        title = title,
        pos = { "center", w = 50 },
    }

    if not query or query:len() == 0 then
        return
    end

    local es_cmd = Command("es"):stdout(Command.PIPED):stderr(Command.PIPED)
    if mode ~= "global" then
        local parentDir = root()
        es_cmd:arg("-path"):arg(tostring(parentDir))
    end
    for word in query:gmatch("%S+") do
        es_cmd:arg(word)
    end

    local es_child, err = es_cmd:spawn()
    if not es_child then
        return fail("Failed to start es: %s", err)
    end

    local es_output = es_child:wait_with_output()
    if not es_output then
        return fail("Failed to read es output: %s", err)
    end

    local code = es_output.status.code or -1
    if code ~= 0 then
        local msg = ES_ERRORS[code] or string.format("Unknown error (code %d)", code)
        return fail(msg)
    end

    local results = es_output.stdout
    if results:len() == 0 then
        return fail("No results found")
    end

    local _permit = ui.hide()

    local fzf_cmd = Command("fzf")
        :stdin(Command.PIPED)
        :stdout(Command.PIPED)
        :stderr(Command.PIPED)
    local fzf_child = fzf_cmd:spawn()
    if not fzf_child then
        return fail("Failed to start fzf")
    end

    fzf_child:write_all(results)
    fzf_child:flush()

    local fzf_output = fzf_child:wait_with_output()
    if not fzf_output then
        return fail("Failed to read fzf output")
    end

    local target = fzf_output.stdout
        :gsub("\r\n", "\n")
        :gsub("\n$", "")
        :gsub("\\", "/")

    if target ~= "" then
        local is_dir = target:sub(-1) == "/"
        ya.emit(is_dir and "cd" or "reveal", { target })
    end
end

return {
    entry = entry,
}
