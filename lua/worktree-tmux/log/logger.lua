-- Layer 2: Plugin wrapper
-- Provides plugin-specific config, environment variable control, structured logging

local vlog = require("worktree-tmux.log.vlog")

-- Lazy initialization flag
local _initialized = false
local _log_instance = nil

-- Get log settings from config or environment
local function get_log_settings()
    local config = nil
    local ok, config_module = pcall(require, "worktree-tmux.config")
    if ok then
        config = config_module
    end

    -- Get settings from config or use defaults
    local settings = {
        use_console = true,
        use_file = true,
        highlights = true,
        level = "info",
    }

    if config and config.options and config.options.log then
        local log_cfg = config.options.log
        settings.use_console = log_cfg.use_console
        settings.use_file = log_cfg.use_file
        settings.highlights = log_cfg.highlights
        settings.level = log_cfg.level
    end

    -- Environment variable overrides
    if vim.env.WORKTREE_LOG_LEVEL then
        settings.level = vim.env.WORKTREE_LOG_LEVEL
    end

    return settings
end

-- Initialize or get log instance
local function get_log()
    if not _initialized then
        local settings = get_log_settings()
        _log_instance = vlog.new({
            plugin = "worktree-tmux.nvim",
            use_console = settings.use_console,
            use_file = settings.use_file,
            highlights = settings.highlights,
            level = settings.level,
        })
        _initialized = true
    end
    return _log_instance
end

-- Create plugin-specific logger instance
local log = {}

-- Production optimization: disable trace/debug based on environment
local is_debug = vim.env.WORKTREE_ENV ~= "production"

-- Delegate all methods to the log instance
local function delegate_method(method)
    log[method] = function(...)
        local instance = get_log()
        if instance[method] then
            instance[method](...)
        end
    end
end

for _, mode_name in ipairs({ "trace", "debug", "info", "warn", "error", "fatal" }) do
    delegate_method(mode_name)
end

-- Override trace/debug to respect debug mode
local original_trace = log.trace
local original_debug = log.debug

log.trace = function(...)
    if is_debug then
        local instance = get_log()
        if instance.trace then
            instance.trace(...)
        end
    end
end

log.debug = function(...)
    if is_debug then
        local instance = get_log()
        if instance.debug then
            instance.debug(...)
        end
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
    -- Get current settings from config
    local settings = get_log_settings()
    settings.level = level

    -- Recreate logger instance
    _log_instance = vlog.new({
        plugin = "worktree-tmux.nvim",
        use_console = settings.use_console,
        use_file = settings.use_file,
        highlights = settings.highlights,
        level = settings.level,
    })

    -- Reset initialization flag to force re-read on next call
    _initialized = true
end

return log
