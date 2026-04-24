--- @since 25.2.13

local M = {}

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
		ya.dbg { common = tostring(common_url), current = tostring(current_url) }
		while common_url ~= nil and not current_url:starts_with(common_url) do
			common_url = common_url.parent
		end
		if common_url == nil then
			return nil
		end
	end

	ya.dbg("Common url is:", tostring(common_url))
	return common_url
end

local function normalize_path(path)
	return path and path:gsub("\\", "/") or path
end

local selected_urls = ya.sync(function()
	local paths = {}
	for _, u in pairs(cx.active.selected) do
		paths[#paths + 1] = u
	end
	return paths
end)

local hovered_url = ya.sync(function()
	local h = cx.active.current.hovered
	return h and h.url
end)

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
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

function M.entry(st, job)
	job = type(job) == "string" and { args = { job } } or job
	local act = job.args[1]
	local rc_cmd = ""
	local rc_cmd_name = ""
	local rc_cmd_options = {}
	if act == "copy" then
		rc_cmd = "copy"
		rc_cmd_name = "Copy"
	elseif act == "delete" then
		rc_cmd = "delete"
		rc_cmd_name = "Delete"
		rc_cmd_options = { "--rmdirs" }
	elseif act == "move" then
		rc_cmd = "move"
		rc_cmd_name = "Move"
		rc_cmd_options = { "--delete-empty-src-dirs" }
	elseif act == "sync" then
		rc_cmd = "sync"
		rc_cmd_name = "Sync"
		rc_cmd_options = {}
	elseif act == "bisync" then
		rc_cmd = "bisync"
		rc_cmd_name = "BiSync"
		rc_cmd_options = {}
	elseif act == "biresync" then
		rc_cmd = "bisync"
		rc_cmd_name = "BiReSync"
		rc_cmd_options = { "--resync" }
	else
		ya.notify { title = "Rclone plugin", content = "Unknown operation: " .. act, timeout = 5, level = "error" }
	end

	local selected = selected_urls()
	if #selected == 0 and act ~= "delete" then
		ya.notify { title = "Rclone " .. rc_cmd_name, content = "No files or folders selected.", timeout = 5, level = "error" }
		return
	end

	if not hovered_url() then
		ya.notify { title = "Rclone " .. rc_cmd_name, content = "Destination path is required.", timeout = 5, level = "error" }
		return
	end
	local destination = hovered_url()

	if act == "delete" and #selected == 0 then
		table.insert(selected, destination)
	end

	if act ~= "delete" then
		for _, path in ipairs(selected) do
			if path == destination then
				ya.notify {
					title = "Rclone " .. rc_cmd_name,
					content = "Source cannot match destination.",
					timeout = 5,
					level = "error",
				}
				return
			end
		end
	end

	local dest_cha = fs.cha(destination)
	if not dest_cha.is_dir then
		destination = destination.parent
	end

	local common_path = find_common_path(selected)
	if not common_path then
		ya.notify {
			title = "Rclone " .. rc_cmd_name,
			content = "Failed to determine common path.",
			timeout = 5,
			level = "error",
		}
		return
	end

	local items_to_copy = {}
	local include_flags = {}
	if #selected == 1 then
		common_path = selected[1].parent
	end
	table.insert(
		items_to_copy,
		ui.Line({
			ui.Span("Source: "):fg("lightgreen"),
			ui.Span(normalize_path(tostring(common_path))):fg("cyan"),
		}):align(ui.Text.LEFT)
	)
	table.insert(items_to_copy, "")
	for _, path in ipairs(selected) do
		local cha = fs.cha(path)
		local relative_path = path:strip_prefix(common_path)
		local path = normalize_path(tostring(relative_path)) .. (cha.is_dir and "/**" or "")
		table.insert(items_to_copy, ui.Line("    " .. path):align(ui.Text.LEFT))
		table.insert(include_flags, "--include")
		table.insert(include_flags, path)
	end
	table.insert(items_to_copy, "")

	local rc_dst = normalize_path(tostring(destination))
	if act == "delete" then
		rc_dst = ""
	else
		local value, event = ya.input {
			title = "Confirm or edit Destination",
			value = rc_dst,
			pos = { "center", w = 100, h = 30 },
		}
		if event == 1 then
			rc_dst = value
		end
		table.insert(
			items_to_copy,
			ui.Line({
				ui.Span("Destination: "):fg("lightgreen"),
				ui.Span(rc_dst):fg("cyan"),
			}):align(ui.Text.LEFT)
		)
	end

	if ya.confirm then
		local continue_restore = ya.confirm {
			title = ui.Line("Rclone " .. rc_cmd_name),
			content = ui.Text(items_to_copy):align(ui.Text.CENTER):wrap(ui.Text.WRAP),
			list = items_to_copy,
			pos = { "center", w = 60, h = 25 },
		}
		if not continue_restore then
			ya.notify {
				title = "Rclone " .. rc_cmd_name,
				content = rc_cmd_name .. " operation cancelled.",
				timeout = 1,
				level = "warn",
			}
			return
		end
	end

	ya.emit("escape", { select = true })

	local rc_src_dst_args = { rc_cmd, normalize_path(tostring(common_path)), rc_dst }
	if act == "delete" then
		rc_src_dst_args = { rc_cmd, normalize_path(tostring(common_path)) }
	end
	local cmd = Command("rclone")
		:arg(rc_src_dst_args)
		:arg(include_flags)
		:arg(rc_cmd_options)
		:arg({ "--progress", "--stats-one-line", "--stats", "1s" })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)

	ya.dbg("rc_src_dst_args:", rc_src_dst_args, "include_flags:", include_flags, "rc_cmd_options:", rc_cmd_options)

	local child, err = cmd:spawn()

	if not child then
		ya.notify {
			title = "Rclone " .. rc_cmd_name,
			content = "Failed to execute rclone: " .. err,
			timeout = 5,
			level = "error",
		}
		return
	end

	local extractProgressMessages = function(data, msgs)
		local str = ""
		for _, ascii_code in ipairs(data) do
			str = str .. string.char(ascii_code)
		end

		local msg_pattern = "%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d [%a ]+: [^\n]+\n"
		for match in string.gmatch(str, msg_pattern) do
			table.insert(msgs, match)
		end

		local pattern1 = "([%d.]+%s*[KMGTP]?i?B)%s*/%s*([%d.]+%s*[KMGTP]?i?B),%s*(%d+)%%,%s*([%d.]+%s*[KMGTP]?i?B/s),%s*ETA%s*([^%s]*)"
		local copied, total, percent, speed, eta = string.match(str, pattern1)
		if copied and total and percent and speed and eta then
			return true, {
				copied = copied,
				total = total,
				percent = percent,
				speed = speed,
				eta = eta,
			}
		else
			return false, str
		end
	end

	messages = {}
	while true do
		local line, event = child:read(512)
		if event == 2 then
			break
		else
			result, out = extractProgressMessages(line, messages)
			if result then
				set_progress(out)
			else
				ya.dbg("stdout evt:", event, out)
			end
		end
	end

	child:wait()
	set_progress(nil)
	if #messages > 0 then
		local content = table.concat(messages, "\n")
		ya.notify {
			title = "Rclone operation completed",
			content = content .. "Note: Messages will be copied to clipboard..",
			timeout = 10,
			level = "warn",
		}
		ya.clipboard(content)
	else
		ya.notify {
			title = "Rclone " .. rc_cmd_name,
			content = rc_cmd_name .. " operation completed",
			timeout = 1,
			level = "info",
		}
	end
end

return M
