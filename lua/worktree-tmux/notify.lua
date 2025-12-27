-- 通知模块
-- 封装 snacks.nvim 通知系统，提供 fallback 到 vim.notify

local config = require("worktree-tmux.config")

local M = {}

-- 检查 snacks.nvim 是否可用
local has_snacks, snacks = pcall(require, "snacks")

--- 发送通知
---@param message string 消息内容
---@param level number vim.log.levels.*
---@param opts? { title?: string, icon?: string, timeout?: number }
local function notify(message, level, opts)
    opts = opts or {}
    local notify_config = config.get("notify") or {}

    -- 优先使用 snacks.nvim
    if has_snacks and snacks.notify and notify_config.use_snacks ~= false then
        snacks.notify(message, {
            level = level,
            title = opts.title or "Worktree-Tmux",
            icon = opts.icon,
            timeout = opts.timeout or notify_config.timeout or 3000,
        })
    else
        -- 回退到 vim.notify
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

--- 成功通知
---@param message string
---@param opts? table
function M.success(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "✅"
    notify(message, vim.log.levels.INFO, opts)
end

--- 错误通知
---@param message string
---@param opts? table
function M.error(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "❌"
    notify(message, vim.log.levels.ERROR, opts)
end

--- 警告通知
---@param message string
---@param opts? table
function M.warn(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "⚠️"
    notify(message, vim.log.levels.WARN, opts)
end

--- 信息通知
---@param message string
---@param opts? table
function M.info(message, opts)
    opts = opts or {}
    opts.icon = opts.icon or "ℹ️"
    notify(message, vim.log.levels.INFO, opts)
end

--- 调试通知（仅在调试模式下显示）
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

--- 进度通知（用于异步操作）
---@param message string
---@param opts? { progress?: number, total?: number }
function M.progress(message, opts)
    opts = opts or {}

    if has_snacks and snacks.notify then
        -- snacks.nvim 支持进度通知
        snacks.notify(message, {
            level = vim.log.levels.INFO,
            title = "Worktree-Tmux",
            icon = "⏳",
        })
    else
        -- fallback: 普通通知带进度信息
        local progress_str = ""
        if opts.progress and opts.total then
            progress_str = string.format(" (%d/%d)", opts.progress, opts.total)
        end
        vim.notify("⏳ " .. message .. progress_str, vim.log.levels.INFO)
    end
end

--- 持久通知（不自动消失）
---@param message string
---@param level number
---@param opts? table
---@return table|nil notification 通知对象（用于关闭）
function M.persistent(message, level, opts)
    opts = opts or {}

    if has_snacks and snacks.notify then
        return snacks.notify(message, {
            level = level,
            title = opts.title or "Worktree-Tmux",
            icon = opts.icon,
            timeout = 0, -- 不自动消失
        })
    else
        vim.notify(message, level)
        return nil
    end
end

--- 关闭通知
---@param notification table snacks.nvim 通知对象
function M.dismiss(notification)
    if notification and has_snacks and snacks.notify then
        -- snacks.nvim 的通知关闭方法
        if notification.dismiss then
            notification:dismiss()
        end
    end
end

--- 清除所有通知
function M.clear_all()
    if has_snacks and snacks.notify and snacks.notify.dismiss then
        snacks.notify.dismiss()
    end
end

return M
