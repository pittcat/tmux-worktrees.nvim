-- 第二层：插件包装器
-- 提供插件专属配置、环境变量控制、结构化日志

local vlog = require("worktree-tmux.log.vlog")

-- 创建插件专用日志实例
local log = vlog.new({
    plugin = "worktree-tmux.nvim",
    use_console = true,
    use_file = true,
    highlights = true,
    level = vim.env.WORKTREE_LOG_LEVEL or "info",
})

-- 生产环境优化：禁用 trace/debug
local is_debug = vim.env.WORKTREE_ENV ~= "production"
local original_trace = log.trace
local original_debug = log.debug

log.trace = function(...)
    if is_debug then
        original_trace(...)
    end
end

log.debug = function(...)
    if is_debug then
        original_debug(...)
    end
end

--- 结构化日志
---@param level string 日志级别
---@param event string 事件名称
---@param data? table 额外数据
function log.structured(level, event, data)
    local msg = string.format("[%s]", event)
    if data then
        msg = msg .. " " .. vim.inspect(data)
    end
    if log[level] then
        log[level](msg)
    end
end

--- 带上下文的日志
---@param level string 日志级别
---@param context string 上下文
---@param message string 消息
---@param data? table 额外数据
function log.with_context(level, context, message, data)
    local msg = string.format("[%s] %s", context, message)
    if data then
        msg = msg .. " | " .. vim.inspect(data)
    end
    if log[level] then
        log[level](msg)
    end
end

--- 条件日志（仅在条件为真时记录）
---@param condition boolean 条件
---@param level string 日志级别
---@param ... any 日志参数
function log.if_true(condition, level, ...)
    if condition and log[level] then
        log[level](...)
    end
end

--- 更新日志级别
---@param level string 新的日志级别
function log.set_level(level)
    -- 重新创建日志实例
    local new_log = vlog.new({
        plugin = "worktree-tmux.nvim",
        use_console = true,
        use_file = true,
        highlights = true,
        level = level,
    })

    -- 更新方法
    for _, mode_name in ipairs({ "trace", "debug", "info", "warn", "error", "fatal" }) do
        log[mode_name] = new_log[mode_name]
    end
end

return log
