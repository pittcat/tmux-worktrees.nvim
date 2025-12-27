-- 日志模块入口
-- 统一导出日志功能

local M = {}

-- 懒加载子模块
local _logger = nil
local _debug = nil
local _file_logger = nil

--- 获取基础日志器
---@return table
function M.get_logger()
    if not _logger then
        _logger = require("worktree-tmux.log.logger")
    end
    return _logger
end

--- 获取调试工具
---@return table
function M.get_debug()
    if not _debug then
        _debug = require("worktree-tmux.log.debug")
    end
    return _debug
end

--- 获取文件日志器
---@return table
function M.get_file_logger()
    if not _file_logger then
        _file_logger = require("worktree-tmux.log.file_logger")
    end
    return _file_logger
end

-- 导出快捷方法（代理到 logger）
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

--- 设置日志级别
---@param level string
function M.set_level(level)
    M.get_logger().set_level(level)
end

--- 开始调试会话
---@param context string 上下文名称
---@return string request_id
function M.begin_debug(context)
    return M.get_debug().begin(context)
end

--- 结束调试会话
function M.end_debug()
    M.get_debug().done()
end

--- 启用文件日志
---@param path? string 日志文件路径
function M.enable_file_log(path)
    local file_logger = M.get_file_logger()
    file_logger.init(path)
    file_logger.write_env_info()
end

--- 关闭文件日志
function M.disable_file_log()
    M.get_file_logger().close()
end

return M
