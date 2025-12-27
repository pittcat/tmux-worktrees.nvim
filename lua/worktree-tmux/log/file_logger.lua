-- File logger
-- Generates debug_log.txt file, fully compliant with debug log specifications

local M = {}

local log_file_path = nil
local log_file = nil

--- Initialize log file
---@param path? string Log file path, defaults to debug_log.txt in working directory
function M.init(path)
    log_file_path = path or (vim.fn.getcwd() .. "/debug_log.txt")

    -- Delete old file, create new file
    os.remove(log_file_path)

    log_file = io.open(log_file_path, "w")
    if log_file then
        log_file:setvbuf("line") -- Line buffer, real-time write
    end
end

--- Get millisecond timestamp
---@return string
local function get_timestamp()
    local time = vim.loop.hrtime() / 1e6
    local ms = math.floor(time % 1000)
    return os.date("%Y-%m-%d %H:%M:%S") .. string.format(".%03d", ms)
end

--- Write log
---@param level string Log level
---@param request_id? string Request ID
---@param message string Message
function M.write(level, request_id, message)
    if not log_file then
        return
    end

    local id_part = request_id and request_id ~= "" and string.format("[%s] ", request_id) or ""

    local line = string.format(
        "[%s] [%s] %s%s\n",
        get_timestamp(),
        level,
        id_part,
        message
    )

    log_file:write(line)
end

--- Write environment info (called at task start)
function M.write_env_info()
    local version = vim.version()

    M.write("INFO", nil, string.format(
        "Env: %s | Version: %s | Neovim: %s.%s.%s | Lua: %s",
        vim.env.WORKTREE_ENV or "dev",
        "v0.1.0",
        version.major,
        version.minor,
        version.patch,
        _VERSION
    ))

    -- Try to read config info
    local ok, config = pcall(require, "worktree-tmux.config")
    if ok and config.options then
        M.write("INFO", nil, string.format(
            "Config: session=%s, sync=%s, async_progress=%s",
            config.options.session_name or "worktrees",
            tostring(config.options.sync_ignored_files),
            tostring(config.options.async and config.options.async.show_progress)
        ))
    end
end

--- Write call stack
---@param request_id? string
---@param depth number
function M.write_call_stack(request_id, depth)
    local stack = {}
    for i = depth, depth + 10 do
        local info = debug.getinfo(i, "nSl")
        if not info then
            break
        end
        local name = info.name or "anonymous"
        local src = info.short_src or "unknown"
        local line = info.currentline or 0
        table.insert(stack, string.format("  %s() at %s:%d", name, src, line))
    end

    if #stack > 0 then
        M.write("DEBUG", request_id, "Call stack:")
        for _, s in ipairs(stack) do
            M.write("DEBUG", request_id, s)
        end
    end
end

--- Write separator line
---@param request_id? string
---@param title? string
function M.write_separator(request_id, title)
    local sep = "=" .. string.rep("=", 50)
    if title then
        M.write("INFO", request_id, string.format("%s %s %s", sep, title, sep))
    else
        M.write("INFO", request_id, sep)
    end
end

--- Close log file
function M.close()
    if log_file then
        log_file:close()
        log_file = nil
    end
end

--- Get log file path
---@return string|nil
function M.get_path()
    return log_file_path
end

--- Flush buffer
function M.flush()
    if log_file then
        log_file:flush()
    end
end

return M
