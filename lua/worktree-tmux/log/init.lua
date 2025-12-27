-- Log module entry point
-- Unified export of logging functionality

local M = {}

-- Lazy load submodules
local _logger = nil
local _debug = nil
local _file_logger = nil

--- Get basic logger
---@return table
function M.get_logger()
    if not _logger then
        _logger = require("worktree-tmux.log.logger")
    end
    return _logger
end

--- Get debug tools
---@return table
function M.get_debug()
    if not _debug then
        _debug = require("worktree-tmux.log.debug")
    end
    return _debug
end

--- Get file logger
---@return table
function M.get_file_logger()
    if not _file_logger then
        _file_logger = require("worktree-tmux.log.file_logger")
    end
    return _file_logger
end

-- Export shortcut methods (proxy to logger)
function M.trace(...)
    M.get_logger().trace(...)
end

function M.debug(...)
    M.get_logger().debug(...)
end

function M.info(...)
    M.get_logger().info(...)
end

function M.warn(...)
    M.get_logger().warn(...)
end

function M.error(...)
    M.get_logger().error(...)
end

function M.fatal(...)
    M.get_logger().fatal(...)
end

--- Set log level
---@param level string
function M.set_level(level)
    M.get_logger().set_level(level)
end

--- Start debug session
---@param context string Context name
---@return string request_id
function M.begin_debug(context)
    return M.get_debug().begin(context)
end

--- End debug session
function M.end_debug()
    M.get_debug().done()
end

--- Enable file logging
---@param path? string Log file path
function M.enable_file_log(path)
    local file_logger = M.get_file_logger()
    file_logger.init(path)
    file_logger.write_env_info()
end

--- Disable file logging
function M.disable_file_log()
    M.get_file_logger().close()
end

return M
