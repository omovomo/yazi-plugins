--- @since 25.2.13

local M = {}

local COPY_CANDS = {
	{ on = "c", desc = "Copy", cmd = "copy" },
	{ on = "m", desc = "Move", cmd = "move", extra = { "--delete-empty-src-dirs" } },
	{ on = "s", desc = "Sync", cmd = "sync" },
	{ on = "b", desc = "BiSync", cmd = "bisync" },
	{ on = "r", desc = "BiReSync", cmd = "bisync", extra = { "--resync" } },
}

local DELETE_CANDS = {
	{ on = "d", desc = "Delete", cmd = "delete" },
	{ on = "w", desc = "Delete + Rmdirs", cmd = "delete", extra = { "--rmdirs" } },
}

local CACHE_CANDS = {
	{ on = "f", desc = "Full (Recommended)", cache = "full" },
	{ on = "w", desc = "Writes", cache = "writes" },
	{ on = "m", desc = "Minimal", cache = "minimal" },
	{ on = "n", desc = "None", cache = "off" },
}

local CAND_KEYS = "1234567890abcdefghijklmnopqrstuvwxyz"

local mount_handles = {}

local function fail(s, ...)
	ya.notify({ title = "rclone", content = string.format(s, ...), timeout = 5, level = "error" })
end

local function normalize_path(path)
	return path and path:gsub("\\", "/") or path
end

local function paths_overlap(sources, dest)
	local dest_n = normalize_path(dest):lower():gsub("/+$", "")
	for _, src in ipairs(sources) do
		local src_n = normalize_path(src):lower():gsub("/+$", "")
		if src_n == dest_n then
			return true
		end
		if #dest_n > #src_n and dest_n:sub(1, #src_n) == src_n and dest_n:sub(#src_n + 1, #src_n + 1) == "/" then
			return true
		end
	end
	return false
end

local function make_cands(items)
	local cands = {}
	for i, item in ipairs(items) do
		if i > #CAND_KEYS then
			break
		end
		cands[#cands + 1] = { on = CAND_KEYS:sub(i, i), desc = item }
	end
	return cands
end

local selected_urls = ya.sync(function()
	local tab = cx.active
	local urls = {}
	for _, u in pairs(tab.selected) do
		urls[#urls + 1] = u
	end
	return urls
end)

local hovered_url = ya.sync(function()
	local h = cx.active.current.hovered
	return h and h.url
end)

local current_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

local set_progress = ya.sync(function(state, progress_info)
	state.progress_info = progress_info
	ui.render()
end)

local get_progress = ya.sync(function(state)
	local progress = state.progress_info
	if not progress then
		return ""
	end
	return ui.Line {
		ui.Span(" 󰑌 "):fg("lightcyan"),
		ui.Span(progress.speed):fg("lightgreen"),
		ui.Span(":"),
		ui.Span(progress.percent .. "%"):fg("lightgreen"),
		ui.Span(":"),
		ui.Span(progress.eta):fg("lightgreen"),
		ui.Span(" "),
	}
end)

function M.setup(state)
	state.progress_info = nil
	Status:children_add(get_progress, 1000, Status.RIGHT)
end

local function find_common_path(urls)
	if #urls == 0 then
		return nil
	end
	if #urls == 1 then
		return urls[1]
	end
	local common_url = urls[1]
	for i = 2, #urls do
		local current_url = urls[i]
		while common_url ~= nil and not current_url:starts_with(common_url) do
			common_url = common_url.parent
		end
		if common_url == nil then
			return nil
		end
	end
	return common_url
end

local function data_to_string(data)
	if type(data) == "string" then
		return data
	end
	local str = ""
	for _, b in ipairs(data) do
		str = str .. string.char(b)
	end
	return str
end

local function extract_progress(data, msgs)
	local str = data_to_string(data)

	local msg_pattern = "%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d [%a ]+: [^\n]+\n"
	for match in string.gmatch(str, msg_pattern) do
		table.insert(msgs, match)
	end

	local pattern = "([%d.]+%s*[KMGTP]?i?B)%s*/%s*([%d.]+%s*[KMGTP]?i?B),%s*(%d+)%%,%s*([%d.]+%s*[KMGTP]?i?B/s),%s*ETA%s*([^%s]*)"
	local copied, total, percent, speed, eta = string.match(str, pattern)
	if copied and total and percent and speed and eta then
		return true, {
			copied = copied,
			total = total,
			percent = percent,
			speed = speed,
			eta = eta,
		}
	end
	return false, str
end

local function get_listremotes()
	local child = Command("rclone"):arg("listremotes"):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		return nil
	end
	local chunks = {}
	while true do
		local data, event = child:read(4096)
		if event == 2 then
			break
		end
		if event == 0 then
			chunks[#chunks + 1] = data
		end
	end
	child:wait()
	local stdout = ""
	for _, chunk in ipairs(chunks) do
		stdout = stdout .. data_to_string(chunk)
	end
	local remotes = {}
	for remote in stdout:gmatch("(%S+)") do
		remotes[#remotes + 1] = remote:gsub(":$", "")
	end
	return remotes
end

local function do_mount()
	local remotes = get_listremotes()
	if not remotes or #remotes == 0 then
		return fail("No rclone remotes configured. Run 'rclone config' first.")
	end

	local cands = make_cands(remotes)
	local idx = ya.which({ cands = cands })
	if not idx then
		return
	end
	local remote_name = remotes[idx]

	local subpath, se = ya.input({
		title = "Remote path (Enter for root):",
		value = "",
		pos = { "center", w = 80 },
	})
	if se ~= 1 then
		return
	end
	local remote_path = remote_name .. ":" .. subpath

	local mount_point, me = ya.input({
		title = "Mount point (drive letter or path):",
		value = "Z:",
		pos = { "center", w = 80 },
	})
	if me ~= 1 then
		return
	end

	local ci = ya.which({ cands = CACHE_CANDS })
	if not ci then
		return
	end
	local cache = CACHE_CANDS[ci].cache

	local ok = ya.confirm({
		pos = { "center", w = 80, h = 8 },
		title = ui.Line("Rclone Mount"):bold(),
		body = ui.Text({
			ui.Line({
				ui.Span("Remote: "):fg("lightgreen"),
				ui.Span(remote_path):fg("cyan"),
			}),
			ui.Line({
				ui.Span("Mount:   "):fg("lightgreen"),
				ui.Span(mount_point):fg("cyan"),
			}),
			ui.Line({
				ui.Span("Cache:   "):fg("lightgreen"),
				ui.Span(cache):fg("cyan"),
			}),
		}),
	})
	if not ok then
		return
	end

	local cmd_str = string.format("rclone mount %s %s --vfs-cache-mode %s --volname %s --no-console", remote_path, mount_point, cache, remote_name)

	local child, err = Command("rclone")
		:arg("mount"):arg(remote_path):arg(mount_point)
		:arg("--vfs-cache-mode"):arg(cache)
		:arg("--volname"):arg(remote_name)
		:arg("--no-console")
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:spawn()
	if not child then
		return fail("Mount failed: %s", err)
	end

	mount_handles[remote_path] = {
		child = child,
		remote = remote_path,
		drive = mount_point,
	}

	ya.notify({
		title = "Rclone Mount",
		content = cmd_str,
		timeout = 10,
		level = "info",
	})
end

local function do_unmount()
	local mounts_info = {}
	for _, m in pairs(mount_handles) do
		mounts_info[#mounts_info + 1] = { remote = m.remote, drive = m.drive }
	end

	if #mounts_info == 0 then
		return fail("No active mounts")
	end

	local descs = {}
	for _, m in ipairs(mounts_info) do
		descs[#descs + 1] = string.format("%s -> %s", m.remote, m.drive)
	end

	local cands = make_cands(descs)
	local idx = ya.which({ cands = cands })
	if not idx then
		return
	end
	local selected = mounts_info[idx]

	local ok = ya.confirm({
		pos = { "center", w = 80, h = 6 },
		title = ui.Line("Rclone Unmount"):bold(),
		body = ui.Text({
			ui.Line({
				ui.Span("Unmount "):fg("yellow"),
				ui.Span(selected.remote):fg("cyan"),
				ui.Span(" -> "):fg("yellow"),
				ui.Span(selected.drive):fg("cyan"),
			}),
		}),
	})
	if not ok then
		return
	end

	local handle = mount_handles[selected.remote]
	if handle and handle.child then
		handle.child:start_kill()
		mount_handles[selected.remote] = nil
	end

	ya.notify({
		title = "Rclone Unmount",
		content = string.format("Unmounted %s -> %s", selected.remote, selected.drive),
		timeout = 3,
		level = "info",
	})
end

function M.entry(st, job)
	job = type(job) == "string" and { args = { job } } or job
	local act = job.args[1]

	if act == "mount" then
		return do_mount()
	elseif act == "unmount" then
		return do_unmount()
	end

	local cands
	if act == "copy" or act == "move" or act == "sync" or act == "bisync" or act == "biresync" then
		cands = COPY_CANDS
	elseif act == "delete" then
		cands = DELETE_CANDS
	else
		return fail("Unknown action: %s", act)
	end

	local idx = ya.which({ cands = cands })
	if not idx then
		return
	end
	local mode = cands[idx]
	if not mode then
		return
	end

	local urls = selected_urls()
	if #urls == 0 then
		if act == "delete" then
			local h = hovered_url()
			if h then
				urls = { h }
			end
		end
		if #urls == 0 then
			return fail("No files selected")
		end
	end

	local is_dir_map = {}
	for _, u in ipairs(urls) do
		local cha = fs.cha(u)
		is_dir_map[tostring(u)] = cha and cha.is_dir or false
	end

	local common_path = find_common_path(urls)
	if not common_path then
		return fail("Failed to determine common path")
	end

	if #urls == 1 then
		common_path = urls[1].parent
	end

	local dest = nil
	if act ~= "delete" then
		dest = current_cwd()

		local dest_str = normalize_path(tostring(dest))
		local dest_input, event = ya.input({
			title = "Destination:",
			value = dest_str,
			pos = { "center", w = 80 },
		})
		if event ~= 1 then
			return
		end
		dest_str = dest_input

		local src_strs = {}
		for _, u in ipairs(urls) do
			src_strs[#src_strs + 1] = tostring(u)
		end
		if paths_overlap(src_strs, dest_str) then
			return fail("Destination overlaps with source")
		end

		dest = Url(dest_str:gsub("/+$", ""))
	end

	if act == "delete" then
		local lines = {}
		for _, u in ipairs(urls) do
			lines[#lines + 1] = ui.Line("  " .. normalize_path(tostring(u))):align(ui.Align.LEFT)
		end
		local ch = math.min(#urls + 4, 30)
		local ok = ya.confirm({
			pos = { "center", w = 80, h = ch },
			title = ui.Line("Rclone Delete - Files will be permanently deleted!"):fg("red"):bold(),
			body = ui.Text(lines),
		})
		if not ok then
			return
		end
	end

	local include_flags = {}
	local preview_lines = {}
	table.insert(preview_lines, ui.Line({
		ui.Span("Source: "):fg("lightgreen"),
		ui.Span(normalize_path(tostring(common_path))):fg("cyan"),
	}):align(ui.Align.LEFT))
	table.insert(preview_lines, "")
	for _, u in ipairs(urls) do
		local relative = u:strip_prefix(common_path)
		local path_str = normalize_path(tostring(relative))
		local is_dir = is_dir_map[tostring(u)]
		table.insert(preview_lines, ui.Line("    " .. path_str .. (is_dir and "/**" or "")):align(ui.Align.LEFT))
		table.insert(include_flags, "--include")
		table.insert(include_flags, path_str .. (is_dir and "/**" or ""))
	end
	table.insert(preview_lines, "")
	if dest then
		table.insert(preview_lines, ui.Line({
			ui.Span("Destination: "):fg("lightgreen"),
			ui.Span(normalize_path(tostring(dest))):fg("cyan"),
		}):align(ui.Align.LEFT))
	end

	local ok = ya.confirm({
		pos = { "center", w = 80, h = math.min(#preview_lines + 4, 30) },
		title = ui.Line("Rclone " .. mode.desc):bold(),
		body = ui.Text(preview_lines),
	})
	if not ok then
		return
	end

	ya.emit("escape", { select = true })

	local rc_args = { mode.cmd, normalize_path(tostring(common_path)) }
	if dest then
		rc_args[#rc_args + 1] = normalize_path(tostring(dest))
	end
	for _, flag in ipairs(mode.extra or {}) do
		rc_args[#rc_args + 1] = flag
	end
	for _, flag in ipairs(include_flags) do
		rc_args[#rc_args + 1] = flag
	end
	rc_args[#rc_args + 1] = "--progress"
	rc_args[#rc_args + 1] = "--stats-one-line"
	rc_args[#rc_args + 1] = "--stats"
	rc_args[#rc_args + 1] = "1s"

	local child, err = Command("rclone"):arg(rc_args):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		return fail("Failed to execute rclone: %s", err)
	end

	local messages = {}
	while true do
		local line, event = child:read(512)
		if event == 2 then
			break
		end
		local result, out = extract_progress(line, messages)
		if result then
			set_progress(out)
		end
	end

	child:wait()
	set_progress(nil)

	if #messages > 0 then
		local content = table.concat(messages, "\n")
		ya.notify({
			title = "Rclone operation completed",
			content = content .. "\nNote: Messages copied to clipboard.",
			timeout = 10,
			level = "warn",
		})
		ya.clipboard(content)
	else
		ya.notify({
			title = "Rclone " .. mode.desc,
			content = mode.desc .. " operation completed",
			timeout = 1,
			level = "info",
		})
	end
end

return M
