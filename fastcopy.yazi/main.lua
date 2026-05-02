--- @since 26.1.22

local FILTER_FIELDS = { "Include", "Exclude", "FromDate", "ToDate", "MinSize", "MaxSize" }
local FILTER_FLAGS = {
	Include = "/include",
	Exclude = "/exclude",
	FromDate = "/from_date",
	ToDate = "/to_date",
	MinSize = "/min_size",
	MaxSize = "/max_size",
}
local DEFAULT_FILTERS = "Include: Exclude: FromDate: ToDate: MinSize: MaxSize:"

local COPY_CANDS = {
	{ on = "d", desc = "Diff (Size/Date)", cmd = "diff" },
	{ on = "f", desc = "Force Copy", cmd = "force_copy" },
	{ on = "n", desc = "No Overwrite", cmd = "noexist_only" },
	{ on = "u", desc = "Update (Newer)", cmd = "update" },
}
local MOVE_CANDS = {
	{ on = "o", desc = "Move (Overwrite)", cmd = "move" },
	{ on = "s", desc = "Sync (Size/Date)", cmd = "sync" },
	{ on = "e", desc = "Sync (Newer)", cmd = "sync_update" },
}
local DELETE_CANDS = {
	{ on = "d", desc = "Delete", cmd = "delete" },
	{ on = "w", desc = "Wipe & Delete", cmd = "delete", wipe = true },
}

local function fail(s, ...)
	ya.notify({ title = "fastcopy", content = string.format(s, ...), timeout = 5, level = "error" })
end

local selected = ya.sync(function()
	local tab = cx.active
	local paths = {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u):gsub("/", "\\")
	end
	return paths
end)

local current_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd):gsub("/", "\\")
end)

local hovered_url_str = ya.sync(function()
	local h = cx.active.current.hovered
	return h and tostring(h.url):gsub("/", "\\")
end)

local function parse_filters(input)
	if not input or #input == 0 then
		return {}
	end
	local result = {}
	for i, field in ipairs(FILTER_FIELDS) do
		local marker = field .. ":"
		local start = input:find(marker, 1, true)
		if start then
			local vs = start + #marker
			local ve = #input + 1
			for j = i + 1, #FILTER_FIELDS do
				local ni = input:find(FILTER_FIELDS[j] .. ":", vs, true)
				if ni then
					ve = ni
					break
				end
			end
			local val = input:sub(vs, ve - 1):match("^%s*(.-)%s*$")
			if val and #val > 0 then
				result[#result + 1] = { field = field, value = val }
			end
		end
	end
	return result
end

local function paths_overlap(sources, dest)
	for _, src in ipairs(sources) do
		local sl = src:lower():gsub("\\+$", "")
		local dl = dest:lower():gsub("\\+$", "")
		if sl == dl then
			return true
		end
		if #dl > #sl and dl:sub(1, #sl) == sl and dl:sub(#sl + 1, #sl + 1) == "\\" then
			return true
		end
	end
	return false
end

local function build_filter_args(filters)
	local parts = {}
	for _, f in ipairs(filters) do
		local flag = FILTER_FLAGS[f.field]
		if flag then
			parts[#parts + 1] = string.format(' %s="%s"', flag, f.value)
		end
	end
	return table.concat(parts)
end

local function entry(_, job)
	local act = job.args[1]
	local noexec = false
	local force_filter = false
	for i = 2, #job.args do
		if job.args[i] == "noexec" then
			noexec = true
		elseif job.args[i] == "filter" then
			force_filter = true
		end
	end

	local sources = selected()
	if #sources == 0 then
		if act == "delete" then
			local h = hovered_url_str()
			if h then
				sources = { h }
			end
		end
		if #sources == 0 then
			return fail("No files selected")
		end
	end

	local single_file = false
	if #sources == 1 then
		local cha = fs.cha(Url(sources[1]:gsub("\\", "/")))
		single_file = cha and not cha.is_dir or false
	end

	local cands
	if act == "copy" then
		cands = COPY_CANDS
	elseif act == "move" then
		cands = MOVE_CANDS
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

	local dest = nil
	if act ~= "delete" then
		dest = current_cwd() .. "\\"

		local dest_input, event = ya.input({
			title = "Destination:",
			value = dest,
			pos = { "center", w = 80 },
		})
		if event ~= 1 then
			return
		end
		dest = dest_input

		if paths_overlap(sources, dest) then
			return fail("Destination overlaps with source")
		end
	end

	if act == "delete" then
		local lines = {}
		for _, src in ipairs(sources) do
			lines[#lines + 1] = ui.Line("  " .. src):align(ui.Align.LEFT)
		end
		local h = math.min(#sources + 4, 30)
		local ok = ya.confirm({
			pos = { "center", w = 80, h = h },
			title = ui.Line("FastCopy Delete - Files will be permanently deleted!"):fg("red"):bold(),
			body = ui.Text(lines),
		})
		if not ok then
			return
		end
	end

	local filter_args = ""
	if force_filter and not single_file then
		local filter_input, fevent = ya.input({
			title = "Filters (Enter to skip):",
			value = DEFAULT_FILTERS,
			pos = { "center", w = 80 },
		})
		if fevent ~= 1 then
			return
		end
		local filters = parse_filters(filter_input)
		filter_args = build_filter_args(filters)
	end

	local sources_str = ""
	for _, src in ipairs(sources) do
		sources_str = sources_str .. string.format(' "%s"', src)
	end

	local opts = string.format(
		'/cmd=%s /estimate /auto_close%s%s%s%s',
		mode.cmd,
		filter_args,
		mode.wipe and " /wipe_del" or "",
		act == "delete" and " /no_confirm_del" or "",
		noexec and " /no_exec" or ""
	)

	local cmd = string.format(
		'start "" "fastcopy.exe" %s%s%s',
		opts,
		sources_str,
		dest and string.format(' /to="%s"', dest) or ""
	)

	ya.emit("escape", { select = true })

	os.execute(cmd)
end

return { entry = entry }
