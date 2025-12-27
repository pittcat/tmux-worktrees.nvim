-- Layer 2: Plugin wrapper
-- Provides plugin-specific config, environment variable control, structured logging

local vlog = require("worktree-tmux.log.vlog")

-- Create plugin-specific logger instance
local log = vlog.new({
    plugin = "worktree-tmux.nvim",
    use_console = true,
    use_file = true,
    highlights = true,
    level = vim.env.WORKTREE_LOG_LEVEL or "info",
})

-- Production optimization: disable trace/debug
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

--- Structured log
---@param level string Log level
---@param event string Event name
---@param data? table Extra data
function log.structured(level, event, data)
    local msg = string.format("[%s]", event)
    if data then
        msg = msg .. " " .. vim.inspect(data)
    end
    if log[level] then
        log[level](msg)
    end
end

--- Log with context
---@param level string Log level
---@param context string Context
---@param message string Message
---@param data? table Extra data
function log.with_context(level, context, message, data)
    local msg = string.format("[%s] %s", context, message)
    if data then
        msg = msg .. " | " .. vim.inspect(data)
    end
    if log[level] then
        log[level](msg)
    end
end

--- Conditional log (only log when condition is true)
---@param condition boolean Condition
---@param level string Log level
---@param ... any Log arguments
function log.if_true(condition, level, ...)
    if condition and log[level] then
        log[level](...)
    end
end

--- Update log level
---@param level string New log level
function log.set_level(level)
    -- Recreate logger instance
    local new_log = vlog.new({
        plugin = "worktree-tmux.nvim",
        use_console = true,
        use_file = true,
        highlights = true,
        level = level,
    })

    -- Update methods
    for _, mode_name in ipairs({ "trace", "debug", "info", "warn", "error", "fatal" }) do
        log[mode_name] = new_log[mode_name]
    end
end

return log
