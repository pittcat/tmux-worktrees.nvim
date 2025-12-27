-- Notification module
-- Wrapper for snacks.nvim notification system, with fallback to vim.notify

local config = require("worktree-tmux.config")

local M = {}

-- Check if snacks.nvim is available
local has_snacks, snacks = pcall(require, "snacks")

--- Send notification
---@param message string Message content
---@param level number vim.log.levels.*
---@param opts? { title?: string, icon?: string, timeout?: number }
local function notify(message, level, opts)
    opts = opts or {}
    local notify_config = config.get("notify") or {}

    -- Prefer snacks.nvim
    if has_snacks and snacks.notify and notify_config.use_snacks ~= false then
        snacks.notify(message, {
            level = level,
            title = opts.title or "Worktree-Tmux",
            icon = opts.icon,
            timeout = opts.timeout or notify_config.timeout or 3000,
        })
    else
        -- Fallback to vim.notify
        local level_names = {
            [vim.log.levels.TRACE] = "TRACE",
            [vim.log.levels.DEBUG] = "DEBUG",
            [vim.log.levels.INFO] = "INFO",
            [vim.log.levels.WARN] = "WARN",
            [vim.log.levels.ERROR] = "ERROR",
        }

        local prefix = opts.icon and (opts.icon .. " ") or ""
        local title = opts.title or "Worktree-Tmux"
        local full_message = string.format("[%s] %s%s", title, prefix, message)

        vim.notify(full_message, level)
    end
end

--- Success notification
---@param message string
---@param opts? table
function M.success(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "✅"
    notify(message, vim.log.levels.INFO, opts)
end

--- Error notification
---@param message string
---@param opts? table
function M.error(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "❌"
    notify(message, vim.log.levels.ERROR, opts)
end

--- Warning notification
---@param message string
---@param opts? table
function M.warn(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "⚠️"
    notify(message, vim.log.levels.WARN, opts)
end

--- Info notification
---@param message string
---@param opts? table
function M.info(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "ℹ️"
    notify(message, vim.log.levels.INFO, opts)
end

--- Debug notification (only shown in debug mode)
---@param message string
---@param opts? table
function M.debug(message, opts)
    local log_config = config.get("log") or {}
    if log_config.debug_mode or vim.env.WORKTREE_ENV ~= "production" then
        opts = opts or {}
        opts.icon = opts.icon or "🔍"
        notify(message, vim.log.levels.DEBUG, opts)
    end
end

--- Progress notification (for async operations)
---@param message string
---@param opts? { progress?: number, total?: number }
function M.progress(message, opts)
    opts = opts or {}

    if has_snacks and snacks.notify then
        -- snacks.nvim supports progress notification
        snacks.notify(message, {
            level = vim.log.levels.INFO,
            title = "Worktree-Tmux",
            icon = "⏳",
        })
    else
        -- fallback: regular notification with progress info
        local progress_str = ""
        if opts.progress and opts.total then
            progress_str = string.format(" (%d/%d)", opts.progress, opts.total)
        end
        vim.notify("⏳ " .. message .. progress_str, vim.log.levels.INFO)
    end
end

--- Persistent notification (doesn't auto-dismiss)
---@param message string
---@param level number
---@param opts? table
---@return table|nil notification Notification object (for dismissal)
function M.persistent(message, level, opts)
    opts = opts or {}

    if has_snacks and snacks.notify then
        return snacks.notify(message, {
            level = level,
            title = opts.title or "Worktree-Tmux",
            icon = opts.icon,
            timeout = 0, -- Don't auto-dismiss
        })
    else
        vim.notify(message, level)
        return nil
    end
end

--- Dismiss notification
---@param notification table snacks.nvim notification object
function M.dismiss(notification)
    if notification and has_snacks and snacks.notify then
        -- snacks.nvim notification dismissal method
        if notification.dismiss then
            notification:dismiss()
        end
    end
end

--- Clear all notifications
function M.clear_all()
    if has_snacks and snacks.notify and snacks.notify.dismiss then
        snacks.notify.dismiss()
    end
end

return M
