-- worktree-tmux.nvim
-- Git Worktree + Tmux Window automation

local M = {}

-- Version
M.version = "0.1.0"

-- Lazy load modules
local _config = nil
local _core = nil
local _ui = nil
local _notify = nil

-- Get config module
---@return table
local function get_config()
    if not _config then
        _config = require("worktree-tmux.config")
    end
    return _config
end

-- Get core module
---@return table
local function get_core()
    if not _core then
        _core = require("worktree-tmux.core")
    end
    return _core
end

-- Get UI module
---@return table
local function get_ui()
    if not _ui then
        _ui = require("worktree-tmux.ui")
    end
    return _ui
end

-- Get notify module
---@return table
local function get_notify()
    if not _notify then
        _notify = require("worktree-tmux.notify")
    end
    return _notify
end

-- Initialize plugin
---@param user_config? table user config
function M.setup(user_config)
    get_config().setup(user_config)
end

-- Create worktree + tmux window
---@param branch? string branch name (show input if empty)
---@param base? string base branch
function M.create(branch, base)
    local ui = get_ui()
    local core = get_core()
    local notify = get_notify()
    local git = require("worktree-tmux.git")

    -- Pre-check
    local tmux = require("worktree-tmux.tmux")
    if not tmux.in_tmux() then
        notify.error("Must be run in tmux environment")
        return
    end

    if not git.in_git_repo() then
        notify.error("Current directory is not a git repository")
        return
    end

    -- If no branch provided, show input
    if not branch or branch == "" then
        ui.branch_input({
            prompt = " Enter new branch name ",
            on_submit = function(value)
                M.create(value, base)
            end,
        })
        return
    end

    -- Check if async mode enabled
    local config = get_config()
    local use_async = config.get("async")

    if use_async then
        -- Async execution (background, non-blocking)
        core.create_worktree_window_async(branch, base, {
            on_success = function()
                -- Optional: switch to new window
                -- local tmux = require("worktree-tmux.tmux")
                -- tmux.switch_to_window(config.get("session_name"), window_name)
            end,
            on_error = function(msg)
                -- Error handled in callback via notify
            end,
        })
        return
    end

    -- Sync execution
    local ok, err = core.create_worktree_window(branch, base)

    if not ok then
        -- Handle special errors
        if err and err:match("^WINDOW_EXISTS:") then
            local window_name = err:match("^WINDOW_EXISTS:(.+)$")
            ui.get_confirm().confirm_overwrite(window_name, {
                on_yes = function()
                    -- Set strategy to overwrite and retry
                    local config = get_config()
                    local old_strategy = config.get("on_duplicate_window")
                    config.options.on_duplicate_window = "overwrite"

                    local retry_ok, retry_err = core.create_worktree_window(branch, base)

                    -- Restore strategy
                    config.options.on_duplicate_window = old_strategy

                    if retry_ok then
                        notify.success("Created: " .. branch)
                    else
                        notify.error("Create failed: " .. (retry_err or ""))
                    end
                end,
            })
        else
            notify.error(err or "Create failed")
        end
    else
        notify.success("Created: " .. branch)
    end
end

-- Jump to worktree window
function M.jump()
    -- Create debug context
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.jump")

    -- Record environment and version info
    local version = vim.version()
    dbg.log_raw("INFO", string.format(
        "Env: %s | Version: v0.1.0 | Neovim: %s.%s.%s | RequestID: %s",
        vim.env.WORKTREE_ENV or "dev",
        version.major,
        version.minor,
        version.patch,
        request_id
    ))

    -- Record call stack
    local call_stack = {}
    for i = 3, 7 do
        local info = debug.getinfo(i, "nSl")
        if not info then break end
        table.insert(call_stack, string.format("%s() line %d", info.name or "anonymous", info.currentline or 0))
    end
    dbg.log_raw("DEBUG", string.format("Call stack: %s", table.concat(call_stack, " -> ")))

    local ui = get_ui()
    local tmux = require("worktree-tmux.tmux")
    local notify = get_notify()

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "Not in tmux environment")
        notify.error("Must be run in tmux environment")
        dbg.done()
        return
    end

    dbg.log_raw("INFO", "Environment check passed, showing worktree picker")
    ui.worktree_picker()
    dbg.done()
end

-- Delete worktree + tmux window
---@param path? string worktree path
function M.delete(path)
    -- Create debug context
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.delete")

    -- Record environment and version info
    local version = vim.version()
    dbg.log_raw("INFO", string.format(
        "Env: %s | Version: v0.1.0 | Neovim: %s.%s.%s | RequestID: %s",
        vim.env.WORKTREE_ENV or "dev",
        version.major,
        version.minor,
        version.patch,
        request_id
    ))

    -- Record call stack
    local call_stack = {}
    for i = 3, 7 do
        local info = debug.getinfo(i, "nSl")
        if not info then break end
        table.insert(call_stack, string.format("%s() line %d", info.name or "anonymous", info.currentline or 0))
    end
    dbg.log_raw("DEBUG", string.format("Call stack: %s", table.concat(call_stack, " -> ")))

    local ui = get_ui()
    local core = get_core()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "Not in tmux environment")
        notify.error("Must be run in tmux environment")
        dbg.done()
        return
    end

    if not git.in_git_repo() then
        dbg.log_raw("ERROR", "Not in git repository")
        notify.error("Current directory is not a git repository")
        dbg.done()
        return
    end

    -- If no path specified, show picker
    if not path or path == "" then
        dbg.log_raw("INFO", "No path specified, showing delete picker")
        ui.get_picker().show_delete_picker({
            on_select = function(worktree)
                dbg.log_raw("INFO", string.format(
                    "User selected delete: %s (path: %s)",
                    worktree.window_name,
                    worktree.path
                ))
                -- Confirm delete
                ui.get_confirm().confirm_delete(worktree, {
                    on_yes = function()
                        dbg.log_raw("INFO", "User confirmed delete, executing")
                        local ok, err = core.delete_worktree_window(worktree.path)
                        if ok then
                            notify.success("Deleted: " .. worktree.branch)
                        else
                            notify.error(err or "Delete failed")
                        end
                    end,
                })
            end,
        })
        dbg.done()
        return
    end

    -- Delete specified path directly
    dbg.log_raw("INFO", string.format("Delete specified path: %s", path))
    local ok, err = core.delete_worktree_window(path)
    if ok then
        dbg.log_raw("INFO", "Delete success")
        notify.success("Deleted")
    else
        dbg.log_raw("ERROR", string.format("Delete failed: %s", err or "unknown error"))
        notify.error(err or "Delete failed")
    end
    dbg.done()
end

-- Sync worktrees and tmux windows
function M.sync()
    local core = get_core()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        notify.error("Must be run in tmux environment")
        return
    end

    if not git.in_git_repo() then
        notify.error("Current directory is not a git repository")
        return
    end

    local result = core.sync_worktrees()
    notify.success(string.format("Sync complete: created %d, skipped %d", result.created, result.skipped))
end

-- List all worktrees (interactive selection)
function M.list()
    -- Create debug context
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.list")

    -- Record environment and version info
    local version = vim.version()
    dbg.log_raw("INFO", string.format(
        "Env: %s | Version: v0.1.0 | Neovim: %s.%s.%s | RequestID: %s",
        vim.env.WORKTREE_ENV or "dev",
        version.major,
        version.minor,
        version.patch,
        request_id
    ))

    -- Record call stack
    local call_stack = {}
    for i = 3, 7 do
        local info = debug.getinfo(i, "nSl")
        if not info then break end
        table.insert(call_stack, string.format("%s() line %d", info.name or "anonymous", info.currentline or 0))
    end
    dbg.log_raw("DEBUG", string.format("Call stack: %s", table.concat(call_stack, " -> ")))

    local ui = get_ui()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "Not in tmux environment")
        notify.error("Must be run in tmux environment")
        dbg.done()
        return
    end

    if not git.in_git_repo() then
        dbg.log_raw("ERROR", "Not in git repository")
        notify.error("Current directory is not a git repository")
        dbg.done()
        return
    end

    dbg.log_raw("INFO", "Environment check passed, showing worktree list picker")
    -- Use multi-action picker
    ui.get_picker().show_list_picker({
        on_jump = function(worktree)
            dbg.log_raw("INFO", string.format(
                "User selected jump: %s (path: %s)",
                worktree.window_name,
                worktree.path
            ))
            local core = get_core()
            local ok, err = core.jump_to_window(worktree.window_name)
            if ok then
                notify.success("Switched to: " .. worktree.window_name)
            else
                notify.error(err or "Jump failed")
            end
        end,
        on_delete = function(worktree)
            dbg.log_raw("INFO", string.format(
                "User selected delete: %s (path: %s)",
                worktree.window_name,
                worktree.path
            ))
            -- Show confirm dialog
            ui.get_confirm().confirm_delete(worktree, {
                on_yes = function()
                    dbg.log_raw("INFO", "User confirmed delete, executing")
                    local core = get_core()
                    local ok, err = core.delete_worktree_window(worktree.path)
                    if ok then
                        notify.success("Deleted: " .. worktree.branch)
                    else
                        notify.error(err or "Delete failed")
                    end
                end,
            })
        end,
        on_create = function()
            dbg.log_raw("INFO", "User selected create new worktree")
            -- Delay to allow fzf-lua window to close before showing nui.input
            vim.defer_fn(function()
                ui.branch_input({
                    prompt = " Enter new branch name ",
                    on_submit = function(branch)
                        dbg.log_raw("INFO", string.format("User entered branch name: %s", branch))
                        M.create(branch)
                    end,
                })
            end, 50)
        end,
    })

    dbg.done()
end

-- Export modules (for advanced users)
M.config = get_config
M.core = get_core
M.ui = get_ui
M.notify = get_notify
M.tmux = function()
    return require("worktree-tmux.tmux")
end
M.git = function()
    return require("worktree-tmux.git")
end
M.sync_module = function()
    return require("worktree-tmux.sync")
end
M.async = function()
    return require("worktree-tmux.async")
end
M.log = function()
    return require("worktree-tmux.log")
end

return M
