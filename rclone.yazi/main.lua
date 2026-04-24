--- @since 25.2.13

local M = {}

-- Helper function to find the common parent path
local function find_common_path(urls)
    -- Проверка на пустой массив
    if #urls == 0 then
        return nil
    end
    
    -- Если только один URL, вернуть его
    if #urls == 1 then
        return urls[1]
    end
    
    -- Берем первый URL как начальный кандидат
    local common_url = urls[1]
    
    -- Проходим по остальным URL
    for i = 2, #urls do

        local current_url = urls[i]
        ya.dbg({common = tostring(common_url), current = tostring(current_url)});
        
        -- Пока текущий URL не начинается с common_url и common_url не nil
        while common_url ~= nil and not current_url:starts_with(common_url) do
            -- Переходим к родительскому URL
            common_url = common_url.parent
        end
        
        -- Если common_url стал nil, общего пути нет
        if common_url == nil then
            return nil
        end
    end
    
    ya.dbg("Common url is:", tostring(common_url));
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
    ya.render()
end)

local get_progress = ya.sync(function(state)
    local progress = state.progress_info
    if not progress then
        return ""
    end
	return ui.Line({
        ui.Span(' 󰑌 '):fg('lightcyan'),
        -- ui.Span(progress.copied):fg('lightgreen'),
        -- ui.Span("/"),
        -- ui.Span(progress.total):fg('lightgreen'),
        -- ui.Span(':'),
        ui.Span(progress.speed):fg('lightgreen'),
        ui.Span(':'),
        ui.Span(progress.percent .. "%"):fg('lightgreen'),
        ui.Span(':'),
        ui.Span(progress.eta):fg('lightgreen'),
        ui.Span(' '),
      }) 
end)

function M.setup(state)
    state.progress_info = nil
    --Status:children_remove(4, Status.RIGHT)
    Status:children_add(get_progress, 1000, Status.RIGHT)
end


-- Main plugin function
function M.entry(st, job)
    -- parse args
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
        rc_cmd_options = {"--rmdirs"}    
	elseif act == "move" then
        rc_cmd = "move"
        rc_cmd_name = "Move"
        rc_cmd_options = {"--delete-empty-src-dirs"} --  "--create-empty-src-dirs", "--delete-empty-src-dirs"    
	elseif act == "sync" then
        rc_cmd = "sync"
        rc_cmd_name = "Sync"
        rc_cmd_options = {} --  "--create-empty-src-dirs"
	elseif act == "bisync" then
        rc_cmd = "bisync"
        rc_cmd_name = "BiSync"
        rc_cmd_options = {} -- 
	elseif act == "biresync" then
        rc_cmd = "bisync"
        rc_cmd_name = "BiReSync"
        rc_cmd_options = {"--resync"} -- 
    else
        ya.notify({ title = "Rclone plugin", content = "Unknown operation: " .. act, timeout = 5, level = "error" })    
    end

    -- Get selected files/folders
    local selected = selected_urls()
    if #selected == 0 and act ~= "delete" then
        ya.notify({ title = "Rclone " .. rc_cmd_name, content = "No files or folders selected.", timeout = 5, level = "error" })
        return
    end
    
    -- Get destination from args
    if not hovered_url() then
        ya.notify({ title = "Rclone " .. rc_cmd_name, content = "Destination path is required.", timeout = 5, level = "error" })
        return
    end
    local destination = hovered_url()
  
    if act == "delete" and #selected == 0 then
        table.insert(selected, destination)
    end

    if act ~= "delete" then
        -- Check if any selected path matches destination
        for _, path in ipairs(selected) do
            if path == destination then
                ya.notify({ title = "Rclone " .. rc_cmd_name, content = "Source cannot match destination.", timeout = 5, level = "error" })
                return
            end
        end
    end
    
    -- Handle destination: if it's a file, use its parent directory
    local dest_cha = fs.cha(destination)
    if not dest_cha.is_dir then
        destination = destination.parent
    end
    
    -- Find common parent path
    local common_path = find_common_path(selected)
    if not common_path then
        ya.notify({ title = "Rclone " .. rc_cmd_name, content = "Failed to determine common path.", timeout = 5, level = "error" })
        return
    end
    
    -- Prepare items to copy (relative paths)
    local items_to_copy = {}
    local include_flags = {}
    if #selected == 1  then
        common_path = selected[1].parent
    end
    table.insert(items_to_copy, 
    ui.Line({ 
        ui.Span("Source: "):fg("lightgreen"), 
        ui.Span(normalize_path(tostring(common_path))):fg("cyan")
    }):align(ui.Text.LEFT))
    table.insert(items_to_copy, "")
    --if #selected > 1 or act == "delete" then
        for _, path in ipairs(selected) do
            local cha = fs.cha(path)
            local relative_path = path:strip_prefix(common_path)
            local path = normalize_path(tostring(relative_path)) .. (cha.is_dir and "/**" or "")
            table.insert(items_to_copy, ui.Line("    " .. path):align(ui.Text.LEFT))
            table.insert(include_flags, "--include")
            table.insert(include_flags, path)
        end
        table.insert(items_to_copy, "")
    --end
    
    local rc_dst = normalize_path(tostring(destination))
    if act == "delete" then
        rc_dst = ""
    else    
        -- Confirm and edit Destination
        local value, event  = ya.input {
            title = "Confirm or edit Destination",
            value = rc_dst,
            position = { "center", w = 100, h = 30 },
        }
        if event == 1 then
            rc_dst = value
        end 
        table.insert(items_to_copy, 
        ui.Line({
            ui.Span("Destination: "):fg("lightgreen"),
            ui.Span(rc_dst):fg("cyan")
        }):align(ui.Text.LEFT))
    end
    
 
     -- Prompt for confirmation
    if ya.confirm then

		local continue_restore = ya.confirm({
            title = ui.Line("Rclone " .. rc_cmd_name),
			content = ui.Text(items_to_copy)
				:align(ui.Text.CENTER)
				:wrap(ui.Text.WRAP),
            list = items_to_copy,
			pos = { "center", w = 60, h = 25},
		})
		-- stopping
		if not continue_restore then
            ya.notify({ title = "Rclone " .. rc_cmd_name, content = rc_cmd_name .. " operation cancelled.", timeout = 1, level = "warn" })
			return
		end
	end

    ya.mgr_emit("escape", { select = true })
    
    local rc_src_dst_args = {rc_cmd, normalize_path(tostring(common_path)), rc_dst}
    if act == "delete" then
        rc_src_dst_args = {rc_cmd, normalize_path(tostring(common_path))}
    end
    -- Execute rclone command
    local cmd = Command("rclone")
        :args(rc_src_dst_args)
        :args(include_flags)
        :args(rc_cmd_options)
        :args({"--progress", "--stats-one-line", "--stats", "1s"}) 
        :stdout(Command.PIPED)
        :stderr(Command.PIPED)

    ya.dbg("rc_src_dst_args:", rc_src_dst_args, "include_flags:", include_flags, "rc_cmd_options:", rc_cmd_options)

    local child, err = cmd:spawn()
   
    if not child then
        ya.notify({ title = "Rclone " .. rc_cmd_name, content = "Failed to execute rclone: " .. err, timeout = 5, level = "error" })
        return
    end

    local extractProgressMessages = function(data, msgs)
        local str = ""
        for _, ascii_code in ipairs(data) do
            str = str .. string.char(ascii_code)
        end

        -- Шаблон для строк вида: "2025/04/16 11:42:59 ERROR : <сообщение>\n" или "NOTICE: <сообщение>\n"
        local msg_pattern = "%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d [%a ]+: [^\n]+\n"
                
        -- Используем string.gmatch для извлечения всех совпадений
        for match in string.gmatch(str, msg_pattern) do
            table.insert(msgs, match)
        end

        local pattern1 = "([%d.]+%s*[KMGTP]?i?B)%s*/%s*([%d.]+%s*[KMGTP]?i?B),%s*(%d+)%%,%s*([%d.]+%s*[KMGTP]?i?B/s),%s*ETA%s*([^%s]*)"
        local copied, total, percent, speed, eta = string.match(str, pattern1)
        --ya.dbg(copied, total, percent, speed, eta)
        if copied and total and percent and speed and eta then
            return true, {
                copied = copied,    -- Сколько скопировано (например, "501.644 MiB")
                total = total,      -- Общий объём (например, "522.804 MiB")
                percent = percent,  -- Процент завершения (например, "96")
                speed = speed,      -- Скорость передачи (например, "6.456 MiB/s")
                eta = eta           -- Оставшееся время (например, "3s")
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

    -- Notify completion
    child:wait()
    set_progress(nil)
    if #messages > 0 then
        local content = table.concat(messages, "\n")
        ya.notify({ title = "Rclone operation completed", content = content .. "Note: Messages will be copied to clipboard.." , timeout = 10, level = "warn" })
        ya.clipboard(content)
    else
        ya.notify({ title = "Rclone " .. rc_cmd_name, content =  rc_cmd_name .. " operation completed", timeout = 1, level = "info" })
    end
end

return M
