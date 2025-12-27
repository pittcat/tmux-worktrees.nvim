-- 文件日志器
-- 生成 debug_log.txt 文件，完全符合调试日志规范

local M = {}

local log_file_path = nil
local log_file = nil

--- 初始化日志文件
---@param path? string 日志文件路径，默认为工作目录下的 debug_log.txt
function M.init(path)
    log_file_path = path or (vim.fn.getcwd() .. "/debug_log.txt")

    -- 删除旧文件，创建新文件
    os.remove(log_file_path)

    log_file = io.open(log_file_path, "w")
    if log_file then
        log_file:setvbuf("line") -- 行缓冲，实时写入
    end
end

--- 获取毫秒级时间戳
---@return string
local function get_timestamp()
    local time = vim.loop.hrtime() / 1e6
    local ms = math.floor(time % 1000)
    return os.date("%Y-%m-%d %H:%M:%S") .. string.format(".%03d", ms)
end

--- 写入日志
---@param level string 日志级别
---@param request_id? string 请求 ID
---@param message string 消息
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

--- 写入环境信息（任务开始时调用）
function M.write_env_info()
    local version = vim.version()

    M.write("INFO", nil, string.format(
        "环境: %s | 版本: %s | Neovim: %s.%s.%s | Lua: %s",
        vim.env.WORKTREE_ENV or "dev",
        "v0.1.0",
        version.major,
        version.minor,
        version.patch,
        _VERSION
    ))

    -- 尝试读取配置信息
    local ok, config = pcall(require, "worktree-tmux.config")
    if ok and config.options then
        M.write("INFO", nil, string.format(
            "配置: session=%s, sync=%s, async_progress=%s",
            config.options.session_name or "worktrees",
            tostring(config.options.sync_ignored_files),
            tostring(config.options.async and config.options.async.show_progress)
        ))
    end
end

--- 写入调用栈
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
        M.write("DEBUG", request_id, "调用栈:")
        for _, s in ipairs(stack) do
            M.write("DEBUG", request_id, s)
        end
    end
end

--- 写入分隔线
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

--- 关闭日志文件
function M.close()
    if log_file then
        log_file:close()
        log_file = nil
    end
end

--- 获取日志文件路径
---@return string|nil
function M.get_path()
    return log_file_path
end

--- 刷新缓冲区
function M.flush()
    if log_file then
        log_file:flush()
    end
end

return M
