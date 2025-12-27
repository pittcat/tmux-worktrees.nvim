-- Tmux operation wrapper module
-- Provides all tmux-related CLI operations

local log = require("worktree-tmux.log")

local M = {}

--- Check if running in tmux environment
---@return boolean
function M.in_tmux()
    return vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
end

--- Get current tmux version
---@return string|nil
function M.get_version()
    local output = vim.fn.system("tmux -V 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:match("tmux%s+([%d%.]+)")
end

--- Check if session exists
---@param name string session name
---@return boolean
function M.session_exists(name)
    local cmd = string.format("tmux has-session -t %s 2>/dev/null", vim.fn.shellescape(name))
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Create session
---@param name string session name
---@param opts? table { cwd?: string, detached?: boolean }
---@return boolean success
---@return string? error_msg
function M.create_session(name, opts)
    opts = opts or {}
    local cmd_parts = { "tmux", "new-session" }

    -- Default: create detached
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
    log.debug("Create session:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- Check if window exists
---@param session string session name
---@param window string window name
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

--- Create window
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

    -- If startup command exists, append at end
    if opts.cmd then
        table.insert(cmd_parts, vim.fn.shellescape(opts.cmd))
    end

    local cmd = table.concat(cmd_parts, " ")
    log.debug("Create window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- Delete window
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
    log.debug("Delete window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- List all windows of specified session
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

--- Switch to specified window
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
    log.debug("Switch window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- Switch to specified session
---@param session string
---@return boolean success
---@return string? error_msg
function M.switch_session(session)
    local cmd = string.format("tmux switch-client -t %s", vim.fn.shellescape(session))
    log.debug("Switch session:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- Get current session name
---@return string|nil
function M.get_current_session()
    local output = vim.fn.system("tmux display-message -p '#{session_name}' 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- Get current window name
---@return string|nil
function M.get_current_window()
    local output = vim.fn.system("tmux display-message -p '#{window_name}' 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- Rename window
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
    log.debug("Rename window:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- Send command to window
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
    log.debug("Send command:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

return M
