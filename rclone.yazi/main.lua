--- @since 25.2.13

local M = {}

local CACHE_NAMES = { [0] = "off", [1] = "minimal", [2] = "writes", [3] = "full" }
local CACHE_MAP = { off = 0, minimal = 1, writes = 2, full = 3 }

local CAND_KEYS = "1234567890abcdefghijklmnopqrstuvwxyz"

local function json_decode(str)
	local pos = 1
	local parse_value

	local function skip_ws()
		while pos <= #str do
			local c = str:sub(pos, pos)
			if c == " " or c == "\t" or c == "\n" or c == "\r" then
				pos = pos + 1
			else
				break
			end
		end
	end

	local function parse_string()
		pos = pos + 1
		local r = {}
		while pos <= #str do
			local c = str:sub(pos, pos)
			if c == "\\" then
				pos = pos + 1
				local e = str:sub(pos, pos)
				if e == "n" then
					r[#r + 1] = "\n"
				elseif e == "t" then
					r[#r + 1] = "\t"
				elseif e == "r" then
					r[#r + 1] = "\r"
				elseif e == '"' then
					r[#r + 1] = '"'
				elseif e == "\\" then
					r[#r + 1] = "\\"
				elseif e == "/" then
					r[#r + 1] = "/"
				elseif e == "u" then
					r[#r + 1] = str:sub(pos - 1, pos + 4)
					pos = pos + 4
				else
					r[#r + 1] = e
				end
				pos = pos + 1
			elseif c == '"' then
				pos = pos + 1
				return table.concat(r)
			else
				r[#r + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(r)
	end

	local function parse_number()
		local s = pos
		if str:sub(pos, pos) == "-" then pos = pos + 1 end
		while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
		if pos <= #str and str:sub(pos, pos) == "." then
			pos = pos + 1
			while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
		end
		if pos <= #str and (str:sub(pos, pos) == "e" or str:sub(pos, pos) == "E") then
			pos = pos + 1
			if pos <= #str and (str:sub(pos, pos) == "+" or str:sub(pos, pos) == "-") then pos = pos + 1 end
			while pos <= #str and str:sub(pos, pos):match("%d") do pos = pos + 1 end
		end
		return tonumber(str:sub(s, pos - 1))
	end

	local function parse_array()
		pos = pos + 1
		local a = {}
		skip_ws()
		if str:sub(pos, pos) == "]" then pos = pos + 1; return a end
		while true do
			a[#a + 1] = parse_value()
			skip_ws()
			local c = str:sub(pos, pos)
			if c == "]" then pos = pos + 1; return a end
			if c == "," then pos = pos + 1 end
		end
	end

	local function parse_object()
		pos = pos + 1
		local o = {}
		skip_ws()
		if str:sub(pos, pos) == "}" then pos = pos + 1; return o end
		while true do
			skip_ws()
			local k = parse_string()
			skip_ws()
			pos = pos + 1
			o[k] = parse_value()
			skip_ws()
			local c = str:sub(pos, pos)
			if c == "}" then pos = pos + 1; return o end
			if c == "," then pos = pos + 1 end
		end
	end

	parse_value = function()
		skip_ws()
		local c = str:sub(pos, pos)
		if c == "{" then
			return parse_object()
		elseif c == "[" then
			return parse_array()
		elseif c == '"' then
			return parse_string()
		elseif c == "t" then
			pos = pos + 4
			return true
		elseif c == "f" then
			pos = pos + 5
			return false
		elseif c == "n" then
			pos = pos + 4
			return nil
		elseif c == "-" or c:match("%d") then
			return parse_number()
		end
		return nil
	end

	skip_ws()
	return parse_value()
end

local function fail(s, ...)
	ya.notify({ title = "rclone", content = string.format(s, ...), timeout = 5, level = "error" })
end

local function data_to_string(data)
	if not data then return "" end
	if type(data) == "string" then return data end
	local s = {}
	for _, b in ipairs(data) do s[#s + 1] = string.char(b) end
	return table.concat(s)
end

local function make_cands(items)
	local c = {}
	for i, item in ipairs(items) do
		if i > #CAND_KEYS then break end
		c[#c + 1] = { on = CAND_KEYS:sub(i, i), desc = item }
	end
	return c
end

local function format_bytes(n)
	if not n or n <= 0 then return "0 B" end
	if n >= 1073741824 then return string.format("%.1f GiB", n / 1073741824)
	elseif n >= 1048576 then return string.format("%.1f MiB", n / 1048576)
	elseif n >= 1024 then return string.format("%.1f KiB", n / 1024)
	else return string.format("%d B", n) end
end

local function format_eta(s)
	if not s or s <= 0 then return "?" end
	if s >= 3600 then return string.format("%dh%dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
	elseif s >= 60 then return string.format("%dm%ds", math.floor(s / 60), math.floor(s % 60))
	else return string.format("%ds", math.floor(s)) end
end

local function make_bar(percent, width)
	width = width or 10
	local pct = math.max(0, math.min(100, percent or 0))
	local filled = math.floor(pct / 100 * width + 0.5)
	return string.rep("█", filled) .. string.rep("░", width - filled)
end

local current_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd):gsub("\\", "/"):gsub("/+$", "")
end)

local get_url = ya.sync(function(state)
	return state.url
end)

local get_cache_mode = ya.sync(function(state)
	return state.cache_mode
end)

local get_unmount_on_exit = ya.sync(function(state)
	return state.unmount_on_exit
end)

local get_hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then return nil end
	local url = tostring(h.url):gsub("\\", "/")
	if not (url:match("%.zip$") or url:match("%.sqfs$")) then return nil end
	return url
end)

local set_progress = ya.sync(function(state, jobid, info)
	if not state.progress_jobs then state.progress_jobs = {} end
	if info then
		state.progress_jobs[jobid] = info
	else
		state.progress_jobs[jobid] = nil
	end
	ui.render()
end)

local get_progress = ya.sync(function(state)
	if not state.progress_jobs then return "" end
	local count = 0
	for _ in pairs(state.progress_jobs) do count = count + 1 end
	if count == 0 then return "" end

	local spans = { ui.Span(" 󰑌 "):fg("lightcyan") }
	local first = true
	for _, p in pairs(state.progress_jobs) do
		if not first then
			spans[#spans + 1] = ui.Span(" │ "):fg("darkgray")
		end
		first = false
		local pct = tonumber(p.percent) or 0
		local bar_w = count == 1 and 10 or count == 2 and 6 or 4
		spans[#spans + 1] = ui.Span(make_bar(pct, bar_w)):fg("lightgreen")
		if count == 1 then
			spans[#spans + 1] = ui.Span(string.format(" %d%%", pct)):fg("lightgreen")
			spans[#spans + 1] = ui.Span(" ")
			spans[#spans + 1] = ui.Span(p.speed or ""):fg("yellow")
			spans[#spans + 1] = ui.Span(" ")
		elseif count == 2 then
			spans[#spans + 1] = ui.Span(" ")
			spans[#spans + 1] = ui.Span(p.speed or ""):fg("yellow")
			spans[#spans + 1] = ui.Span(" ")
		else
			spans[#spans + 1] = ui.Span(" ")
		end
		spans[#spans + 1] = ui.Span(p.eta or "?"):fg("lightcyan")
	end
	spans[#spans + 1] = ui.Span(" ")
	return ui.Line(spans)
end)

function M.setup(state, opts)
	state.progress_jobs = {}
	opts = opts or {}
	state.url = opts.url or "http://localhost:5572/"
	local cm = opts.cache_mode or "full"
	state.cache_mode = type(cm) == "number" and cm or CACHE_MAP[cm] or 3
	state.unmount_on_exit = opts.unmount_on_exit or false
	Status:children_add(get_progress, 1000, Status.RIGHT)
end

local function rc_call(cmd, params)
	local url = get_url()
	local c = Command("rclone"):arg("rc"):arg("--url"):arg(url):arg(cmd)
	if params then
		local keys = {}
		for k in pairs(params) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			c = c:arg(k .. "=" .. tostring(params[k]))
		end
	end
	-- ya.dbg("rclone rc", "--url", url, cmd)
	local child, err = c:stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then return nil, "spawn: " .. (err or "") end

	local chunks = {}
	while true do
		local data, event = child:read(8192)
		if event == 2 then break end
		if event == 0 then chunks[#chunks + 1] = data_to_string(data) end
	end

	local output = child:wait_with_output()
	local code = (output and output.status and output.status.code) or -1
	local stdout = table.concat(chunks):gsub("\r\n", "\n"):match("^%s*(.-)%s*$") or ""

	if code ~= 0 then
		local stderr = ""
		if output and output.stderr then stderr = data_to_string(output.stderr):gsub("\r\n", "\n") end
		local msg = stderr ~= "" and stderr or stdout
		return nil, msg ~= "" and msg or ("exit " .. code)
	end

	if stdout == "" or stdout == "{}" then return {} end
	local ok, result = pcall(json_decode, stdout)
	if not ok then return nil, "json: " .. tostring(result) end
	return result
end

local function do_mount()
	local result = rc_call("config/listremotes")
	if not result then return fail("Failed to list remotes") end
	local remotes = result.remotes or {}

	local names = {}
	for _, r in ipairs(remotes) do
		names[#names + 1] = r:gsub(":$", "")
	end

	local hovered = get_hovered()
	if hovered then
		local short = hovered:match("([^/]+)$")
		names[#names + 1] = ":archive:" .. hovered
		short_names = short_names or {}
		short_names[#names] = "archive:" .. short
	end

	if #names == 0 then return fail("No remotes configured") end

	local cands = {}
	for i, n in ipairs(names) do
		if i > #CAND_KEYS then break end
		local is_last_archive = (i == #names and short_names and short_names[i])
		cands[#cands + 1] = {
			on = is_last_archive and "<Enter>" or CAND_KEYS:sub(i, i),
			desc = (short_names and short_names[i]) or n,
		}
	end
	local idx = ya.which({ cands = cands })
	if not idx then return end
	local remote_name = names[idx]
	local is_archive = remote_name:sub(1, 9) == ":archive:"
	local remote_path

	if is_archive then
		remote_path = remote_name
		local file_path = remote_path:sub(10)
		local mount_point = file_path:gsub("%.[^.]+$", ".archive")
		local cache_mode = get_cache_mode()

		local mounts = rc_call("mount/listmounts")
		if mounts then
			for _, m in ipairs(mounts.mountPoints or {}) do
				local mp = type(m) == "table" and (m.MountPoint or m.mountPoint) or tostring(m)
				if mp:gsub("\\", "/") == mount_point:gsub("\\", "/") then
					ya.emit("cd", { mount_point:gsub("\\", "/") })
					return
				end
			end
		end

		local mount_result, err = rc_call("mount/mount", {
			fs = remote_path,
			mountPoint = mount_point,
			vfsOpt = '{"CacheMode":' .. cache_mode .. '}',
		})
		if not mount_result then
			return fail("Mount failed: %s", err or "unknown")
		end

		ya.emit("cd", { mount_point:gsub("\\", "/") })
		return
	end

	local rp_input, rp_event = ya.input({
		title = "Remote path (Enter for root):",
		value = remote_name .. ":",
		pos = { "center", w = 80 },
	})
	if rp_event ~= 1 then return end
	remote_path = rp_input

	local mount_point, me = ya.input({
		title = "Mount point (drive letter, path, or * for auto):",
		value = "Z:",
		pos = { "center", w = 80 },
	})
	if me ~= 1 then return end

	local cache_mode = get_cache_mode()

	local ok = ya.confirm({
		pos = { "center", w = 80, h = 8 },
		title = ui.Line("Rclone Mount"):bold(),
		body = ui.Text({
			ui.Line({ ui.Span("Remote: "):fg("lightgreen"), ui.Span(remote_path):fg("cyan") }),
			ui.Line({ ui.Span("Mount:   "):fg("lightgreen"), ui.Span(mount_point):fg("cyan") }),
			ui.Line({ ui.Span("Cache:   "):fg("lightgreen"), ui.Span(CACHE_NAMES[cache_mode] or tostring(cache_mode)):fg("cyan") }),
		}),
	})
	if not ok then return end

	local mount_result, err = rc_call("mount/mount", {
		fs = remote_path,
		mountPoint = mount_point,
		vfsOpt = '{"CacheMode":' .. cache_mode .. '}',
	})
	if not mount_result then
		return fail("Mount failed: %s", err or "unknown")
	end

	local actual = (type(mount_result) == "table" and mount_result.mountPoint) or mount_point
	ya.notify({
		title = "Rclone Mount",
		content = string.format("%s -> %s", remote_path, actual),
		timeout = 5,
		level = "info",
	})

	if actual == "*" then actual = mount_point end
	ya.emit("cd", { actual:gsub("\\", "/") })
end

local function do_unmount()
	local result = rc_call("mount/listmounts")
	if not result then return fail("Failed to list mounts") end
	local mounts = result.mountPoints or {}
	if #mounts == 0 then return fail("No active mounts") end

	local descs = {}
	local mps = {}
	for i, m in ipairs(mounts) do
		local fs, mp
		if type(m) == "table" then
			fs = m.Fs or m.fs or "?"
			mp = m.MountPoint or m.mountPoint or "?"
		else
			fs = "?"
			mp = tostring(m)
		end
		descs[#descs + 1] = string.format("%s -> %s", fs, mp)
		mps[i] = mp
	end

	local cands = make_cands(descs)
	local idx = ya.which({ cands = cands })
	if not idx then return end

	local ok = ya.confirm({
		pos = { "center", w = 80, h = 6 },
		title = ui.Line("Rclone Unmount"):bold(),
		body = ui.Text({
			ui.Line({ ui.Span("Unmount "):fg("yellow"), ui.Span(descs[idx]):fg("cyan") }),
		}),
	})
	if not ok then return end

	local _, err = rc_call("mount/unmount", { mountPoint = mps[idx] })
	if err then return fail("Unmount failed: %s", err) end
	ya.notify({
		title = "Rclone Unmount",
		content = string.format("Unmounted %s", mps[idx]),
		timeout = 3,
		level = "info",
	})
end

local function do_unmountall()
	local ok = ya.confirm({
		pos = { "center", w = 60, h = 5 },
		title = ui.Line("Unmount All"):bold(),
		body = ui.Text({ ui.Line("Unmount all active mounts?"):fg("yellow") }),
	})
	if not ok then return end
	local _, err = rc_call("mount/unmountall")
	if err then return fail("Unmount all failed: %s", err) end
	ya.notify({ title = "Rclone", content = "All mounts unmounted", timeout = 3, level = "info" })
end

local function do_status()
	local result = rc_call("mount/listmounts")
	if not result then return fail("Failed to get status") end
	local mounts = result.mountPoints or {}
	if #mounts == 0 then
		ya.notify({ title = "Rclone Status", content = "No active mounts", timeout = 3, level = "info" })
		return
	end
	local lines = {}
	for _, m in ipairs(mounts) do
		if type(m) == "table" then
			lines[#lines + 1] = string.format("%s -> %s", m.Fs or m.fs or "?", m.MountPoint or m.mountPoint or "?")
		else
			lines[#lines + 1] = tostring(m)
		end
	end
	ya.notify({ title = "Rclone Mounts", content = table.concat(lines, "\n"), timeout = 10, level = "info" })
end

local mark_cancelled = ya.sync(function(state, jobid)
	if not state.cancelled_jobs then state.cancelled_jobs = {} end
	state.cancelled_jobs[jobid] = true
end)

local pop_cancelled = ya.sync(function(state, jobid)
	if not state.cancelled_jobs then return false end
	local v = state.cancelled_jobs[jobid]
	state.cancelled_jobs[jobid] = nil
	return v or false
end)

local function pick_path(label, cwd_suffix)
	local cwd = current_cwd()

	local result = rc_call("config/listremotes")
	local remotes = (result and result.remotes) or {}

	local cands = {}
	local paths = {}
	for i, r in ipairs(remotes) do
		if i > #CAND_KEYS - 1 then break end
		local name = r:gsub(":$", "")
		cands[#cands + 1] = { on = CAND_KEYS:sub(i, i), desc = name }
		paths[#paths + 1] = r:match(":$") and r or r .. ":"
	end

	local cwd_default = cwd_suffix and (cwd .. "/" .. cwd_suffix) or cwd
	cands[#cands + 1] = { on = "<Enter>", desc = cwd }
	paths[#paths + 1] = cwd_default

	local idx = ya.which({ cands = cands })
	if not idx then return nil end

	local default = paths[idx]
	local input, event = ya.input({
		title = label .. ":",
		value = default,
		pos = { "center", w = 80 },
	})
	if event ~= 1 then return nil end
	return input
end

local function do_sync(bisync)
	local title = bisync and "BiSync" or "Sync"
	local src_label = bisync and "path1" or "srcFs"
	local dst_label = bisync and "path2" or "dstFs"

	local src = pick_path(title .. " - " .. src_label)
	if not src then return end

	local _, src_path = src:match("^(.-):(.+)$")
	if src_path and src_path:sub(1, 1) ~= "/" and src_path:sub(1, 1) ~= "\\" then
	else
		src_path = src
	end
	local src_folder = (src_path or src):match("([^/\\]+)/?$") or ""
	local dst = pick_path(title .. " - " .. dst_label, src_folder)
	if not dst then return end

	local cmd = bisync and "sync/bisync" or "sync/sync"
	local params = {}
	if bisync then
		params.path1 = src
		params.path2 = dst
	else
		params.srcFs = src
		params.dstFs = dst
	end
	params._async = "true"

	local ok = ya.confirm({
		pos = { "center", w = 80, h = 6 },
		title = ui.Line("Rclone " .. title):bold(),
		body = ui.Text({
			ui.Line({ ui.Span(src_label .. ": "):fg("lightgreen"), ui.Span(src):fg("cyan") }),
			ui.Line({ ui.Span(dst_label .. ": "):fg("lightgreen"), ui.Span(dst):fg("cyan") }),
		}),
	})
	if not ok then return end

	local result, err = rc_call(cmd, params)
	if not result then return fail("%s failed: %s", title, err or "unknown") end

	local jobid = result.jobid
	if not jobid then return fail("No jobid returned") end

	local short_src = src:match("([^/]+)[/]?$") or src
	local short_dst = dst:match("([^/]+)[/]?$") or dst
	local job_name = title .. ": " .. short_src .. " → " .. short_dst

	while true do
		ya.sleep(1)

		local status = rc_call("job/status", { jobid = jobid })
		if not status or status.finished then break end

		local stats = rc_call("core/stats", { group = "job/" .. jobid })
		if stats then
			local progress = { name = job_name }
			if stats.speed and stats.speed > 0 then
				progress.speed = format_bytes(stats.speed) .. "/s"
			end
			if stats.bytes and stats.totalBytes and stats.totalBytes > 0 then
				progress.percent = string.format("%.0f", stats.bytes / stats.totalBytes * 100)
			end
			if stats.eta and stats.eta > 0 then
				progress.eta = format_eta(stats.eta)
			end
			set_progress(jobid, progress)
		end
	end

	set_progress(jobid, nil)

	if pop_cancelled(jobid) then
		ya.notify({ title = "Rclone " .. title, content = job_name .. " cancelled", timeout = 3, level = "warn" })
		return
	end

	local final = rc_call("job/status", { jobid = jobid })
	if final and final.success then
		ya.notify({ title = "Rclone " .. title, content = "Completed", timeout = 3, level = "info" })
	else
		local msg = (final and final.error) or "Unknown error"
		fail("%s failed: %s", title, msg)
	end
end

local get_active_jobs = ya.sync(function(state)
	if not state.progress_jobs then return {} end
	local jobs = {}
	for jobid, p in pairs(state.progress_jobs) do
		jobs[#jobs + 1] = { id = jobid, desc = (p.name or "job") .. " (id:" .. jobid .. ")" }
	end
	return jobs
end)

local function do_cancel()
	local jobs = get_active_jobs()
	if #jobs == 0 then
		ya.notify({ title = "Rclone", content = "No running jobs", timeout = 3, level = "info" })
		return
	end

	local descs = {}
	for _, j in ipairs(jobs) do descs[#descs + 1] = j.desc end

	local cands = make_cands(descs)
	local idx = ya.which({ cands = cands })
	if not idx then return end

	local ok = ya.confirm({
		pos = { "center", w = 60, h = 5 },
		title = ui.Line("Cancel Job"):bold(),
		body = ui.Text({ ui.Line("Stop " .. descs[idx] .. "?"):fg("yellow") }),
	})
	if not ok then return end

	mark_cancelled(jobs[idx].id)
	local _, err = rc_call("job/stop", { jobid = jobs[idx].id })
	if err then return fail("Cancel failed: %s", err) end
	set_progress(jobs[idx].id, nil)
	ya.notify({ title = "Rclone", content = descs[idx] .. " stopped", timeout = 3, level = "warn" })
end

function M.entry(st, job)
	job = type(job) == "string" and { args = { job } } or job
	local act = job.args[1]

	if act == "menu" then
		local cands = {
			{ on = "1", desc = "Mount remote" },
			{ on = "2", desc = "Unmount" },
			{ on = "3", desc = "Unmount all" },
			{ on = "4", desc = "Status" },
		}
		local idx = ya.which({ cands = cands })
		if not idx then return end
		if idx == 1 then return do_mount()
		elseif idx == 2 then return do_unmount()
		elseif idx == 3 then return do_unmountall()
		elseif idx == 4 then return do_status() end
	elseif act == "sync_menu" then
		local cands = {
			{ on = "1", desc = "Sync" },
			{ on = "2", desc = "BiSync" },
			{ on = "3", desc = "Cancel job" },
		}
		local idx = ya.which({ cands = cands })
		if not idx then return end
		if idx == 1 then return do_sync(false)
		elseif idx == 2 then return do_sync(true)
		elseif idx == 3 then return do_cancel() end
	elseif act == "mount" then
		return do_mount()
	elseif act == "unmount" then
		return do_unmount()
	elseif act == "unmountall" then
		return do_unmountall()
	elseif act == "status" then
		return do_status()
	elseif act == "sync" then
		return do_sync(false)
	elseif act == "bisync" then
		return do_sync(true)
	elseif act == "cancel" then
		return do_cancel()
	elseif act == "quit" then
		if get_unmount_on_exit() then rc_call("mount/unmountall") end
		ya.emit("quit", {})
	else
		return fail("Unknown action: %s", act)
	end
end

return M
