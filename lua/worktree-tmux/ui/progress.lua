-- Progress display component

local config = require("worktree-tmux.config")

local M = {}

-- Current progress window
local progress_win = nil
local progress_buf = nil

--- Show progress
---@param opts { message: string, progress?: number, total?: number }
function M.show(opts)
    local notify_config = config.get("notify") or {}

    -- Check if snacks.nvim is available
    local has_snacks, snacks = pcall(require, "snacks")
    if has_snacks and snacks.notify and notify_config.use_snacks ~= false then
        -- Use snacks.nvim progress notification
        local progress_str = ""
        if opts.progress and opts.total then
            progress_str = string.format(" (%d/%d)", opts.progress, opts.total)
        end

        snacks.notify(opts.message .. progress_str, {
            level = vim.log.levels.INFO,
            title = "Worktree-Tmux",
            icon = "⏳",
        })
        return
    end

    -- Use float window to show progress
    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
        -- Update existing window
        M.update(opts)
        return
    end

    -- Create new progress window
    progress_buf = vim.api.nvim_create_buf(false, true)

    local width = 50
    local height = 3

    progress_win = vim.api.nvim_open_win(progress_buf, false, {
        relative = "editor",
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2 - 5,
        style = "minimal",
        border = "rounded",
        title = " ⏳ Progress ",
        title_pos = "center",
    })

    M.update(opts)
end

--- Update progress
---@param opts { message: string, progress?: number, total?: number }
function M.update(opts)
    if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
        return
    end

    local lines = {}

    -- Message line
    table.insert(lines, " " .. opts.message)

    -- Progress bar line
    if opts.progress and opts.total then
        local ratio = opts.progress / opts.total
        local bar_width = 40
        local filled = math.floor(ratio * bar_width)
        local empty = bar_width - filled

        local bar = " [" .. string.rep("█", filled) .. string.rep("░", empty) .. "]"
        table.insert(lines, bar)

        local percent = string.format(" %d/%d (%.0f%%)", opts.progress, opts.total, ratio * 100)
        table.insert(lines, percent)
    else
        table.insert(lines, "")
        table.insert(lines, "")
    end

    vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, lines)
end

--- Hide progress
function M.hide()
    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
        vim.api.nvim_win_close(progress_win, true)
        progress_win = nil
    end

    if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
        vim.api.nvim_buf_delete(progress_buf, { force = true })
        progress_buf = nil
    end
end

--- Async operation with progress
---@param opts { message: string, total: number, operation: fun(progress_callback: fun(current: number, message?: string), done_callback: fun(success: boolean, result?: any)) }
function M.with_progress(opts)
    local current = 0

    M.show({
        message = opts.message,
        progress = 0,
        total = opts.total,
    })

    local function progress_callback(new_current, new_message)
        current = new_current
        M.update({
            message = new_message or opts.message,
            progress = current,
            total = opts.total,
        })
    end

    local function done_callback(success, result)
        M.hide()
        if success then
            vim.notify("✅ " .. opts.message .. " done", vim.log.levels.INFO)
        else
            vim.notify("❌ " .. opts.message .. " failed: " .. (result or ""), vim.log.levels.ERROR)
        end
    end

    opts.operation(progress_callback, done_callback)
end

return M
