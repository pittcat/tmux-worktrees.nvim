-- Tmux 操作封装模块
-- 提供所有 tmux 相关的 CLI 操作

local log = require("worktree-tmux.log")

local M = {}

--- 检查是否在 tmux 环境中
---@return boolean
function M.in_tmux()
    return vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
end

--- 获取当前 tmux 版本
---@return string|nil
function M.get_version()
    local output = vim.fn.system("tmux -V 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:match("tmux%s+([%d%.]+)")
end

--- 检查 session 是否存在
---@param name string session 名称
---@return boolean
function M.session_exists(name)
    local cmd = string.format("tmux has-session -t %s 2>/dev/null", vim.fn.shellescape(name))
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- 创建 session
---@param name string session 名称
---@param opts? table { cwd?: string, detached?: boolean }
---@return boolean success
---@return string? error_msg
function M.create_session(name, opts)
    opts = opts or {}
    local cmd_parts = { "tmux", "new-session" }

    -- 默认后台创建
    if opts.detached ~= false then
        table.insert(cmd_parts, "-d")
    end

    table.insert(cmd_parts, "-s")
    table.insert(cmd_parts, vim.fn.shellescape(name))

    if opts.cwd then
        table.insert(cmd_parts, "-c")
        table.insert(cmd_parts, vim.fn.shellescape(opts.cwd))
    end

    local cmd = table.concat(cmd_parts, " ")
    log.debug("创建 session:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 检查 window 是否是否存在
---@param session string session 名称
---@param window string window 名称
---@return boolean
function M.window_exists(session, window)
    local cmd = string.format(
        "tmux list-windows -t %s -F '#{window_name}' 2>/dev/null | grep -x %s",
        vim.fn.shellescape(session),
        vim.fn.shellescape(window)
    )
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- 创建 window
---@param opts WorktreeTmux.CreateWindowOpts
---@return boolean success
---@return string? error_msg
function M.create_window(opts)
    local cmd_parts = {
        "tmux",
        "new-window",
        "-t",
        vim.fn.shellescape(opts.session),
        "-n",
        vim.fn.shellescape(opts.name),
    }

    if opts.cwd then
        table.insert(cmd_parts, "-c")
        table.insert(cmd_parts, vim.fn.shellescape(opts.cwd))
    end

    -- 如果有启动命令，添加到末尾
    if opts.cmd then
        table.insert(cmd_parts, vim.fn.shellescape(opts.cmd))
    end

    local cmd = table.concat(cmd_parts, " ")
    log.debug("创建 window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 删除 window
---@param session string
---@param window string
---@return boolean success
---@return string? error_msg
function M.delete_window(session, window)
    local cmd = string.format(
        "tmux kill-window -t %s:%s",
        vim.fn.shellescape(session),
        vim.fn.shellescape(window)
    )
    log.debug("删除 window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 列出指定 session 的所有 windows
---@param session string
---@return WorktreeTmux.TmuxWindow[]
function M.list_windows(session)
    local cmd = string.format(
        "tmux list-windows -t %s -F '#{window_index}:#{window_name}:#{window_active}' 2>/dev/null",
        vim.fn.shellescape(session)
    )
    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        return {}
    end

    local windows = {}
    for line in output:gmatch("[^\r\n]+") do
        local index, name, active = line:match("(%d+):([^:]+):(%d)")
        if index and name then
            table.insert(windows, {
                index = tonumber(index),
                name = name,
                active = active == "1",
            })
        end
    end

    return windows
end

--- 切换到指定 window
---@param session string
---@param window string
---@return boolean success
---@return string? error_msg
function M.select_window(session, window)
    local cmd = string.format(
        "tmux select-window -t %s:%s",
        vim.fn.shellescape(session),
        vim.fn.shellescape(window)
    )
    log.debug("切换 window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 切换到指定 session
---@param session string
---@return boolean success
---@return string? error_msg
function M.switch_session(session)
    local cmd = string.format("tmux switch-client -t %s", vim.fn.shellescape(session))
    log.debug("切换 session:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 获取当前 session 名称
---@return string|nil
function M.get_current_session()
    local output = vim.fn.system("tmux display-message -p '#{session_name}' 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- 获取当前 window 名称
---@return string|nil
function M.get_current_window()
    local output = vim.fn.system("tmux display-message -p '#{window_name}' 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- 重命名 window
---@param session string
---@param old_name string
---@param new_name string
---@return boolean success
---@return string? error_msg
function M.rename_window(session, old_name, new_name)
    local cmd = string.format(
        "tmux rename-window -t %s:%s %s",
        vim.fn.shellescape(session),
        vim.fn.shellescape(old_name),
        vim.fn.shellescape(new_name)
    )
    log.debug("重命名 window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 在 window 中发送命令
---@param session string
---@param window string
---@param command string
---@return boolean success
---@return string? error_msg
function M.send_keys(session, window, command)
    local cmd = string.format(
        "tmux send-keys -t %s:%s %s Enter",
        vim.fn.shellescape(session),
        vim.fn.shellescape(window),
        vim.fn.shellescape(command)
    )
    log.debug("发送命令:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

return M
