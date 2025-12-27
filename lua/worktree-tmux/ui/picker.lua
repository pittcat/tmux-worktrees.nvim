-- fzf-lua picker component

local config = require("worktree-tmux.config")
local core = require("worktree-tmux.core")
local log = require("worktree-tmux.log")

local M = {}

-- Check if fzf-lua is available
local has_fzf, fzf = pcall(require, "fzf-lua")

--- Show worktree picker and jump
---@param opts? { on_select?: fun(item: table) }
function M.show_worktree_picker(opts)
    opts = opts or {}

    -- Get worktree list
    local worktrees = core.get_worktree_list()

    if #worktrees == 0 then
        vim.notify("No available worktree windows", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        -- Fallback to vim.ui.select
        local items = {}
        for _, wt in ipairs(worktrees) do
            local status = wt.has_window and " ✓" or " ✗"
            table.insert(items, wt.window_name .. status)
        end

        vim.ui.select(items, {
            prompt = "Select Worktree:",
        }, function(choice)
            if choice then
                -- Extract window name (remove status marker)
                local window_name = choice:match("^(.+) [✓✗]$")
                if window_name then
                    local ok, err = core.jump_to_window(window_name)
                    if not ok then
                        vim.notify(err, vim.log.levels.ERROR)
                    end
                end
            end
        end)
        return
    end

    -- Format as fzf options
    local items = {}
    for _, wt in ipairs(worktrees) do
        local status = wt.has_window and " ✓" or " ✗"
        table.insert(items, wt.window_name .. status .. " | " .. wt.branch)
    end

    local fzf_opts = config.get("fzf_opts") or {}

    fzf.fzf_exec(items, {
        prompt = fzf_opts.prompt or "Worktree Jump> ",
        actions = {
            ["default"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                -- Extract window name
                local window_name = selected[1]:match("^([^%s]+)")

                if opts.on_select then
                    -- Find corresponding worktree
                    for _, wt in ipairs(worktrees) do
                        if wt.window_name == window_name then
                            opts.on_select(wt)
                            return
                        end
                    end
                else
                    -- Default jump
                    local ok, err = core.jump_to_window(window_name)
                    if ok then
                        vim.notify("Switched to: " .. window_name, vim.log.levels.INFO)
                    else
                        vim.notify(err, vim.log.levels.ERROR)
                    end
                end
            end,
        },
        winopts = fzf_opts.winopts or {
            height = 0.4,
            width = 0.6,
            row = 0.5,
            col = 0.5,
        },
    })
end

--- Show worktree picker for deletion
---@param opts { on_select: fun(worktree: table) }
function M.show_delete_picker(opts)
    local worktrees = core.get_worktree_list()

    if #worktrees == 0 then
        vim.notify("No deletable worktrees", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        -- Fallback to vim.ui.select
        local items = {}
        local item_map = {}
        for _, wt in ipairs(worktrees) do
            local display = wt.branch .. " | " .. wt.path
            table.insert(items, display)
            item_map[display] = wt
        end

        vim.ui.select(items, {
            prompt = "Select Worktree to delete:",
        }, function(choice)
            if choice and item_map[choice] then
                opts.on_select(item_map[choice])
            end
        end)
        return
    end

    local items = {}
    for _, wt in ipairs(worktrees) do
        table.insert(items, wt.branch .. " | " .. wt.path)
    end

    local fzf_opts = config.get("fzf_opts") or {}

    fzf.fzf_exec(items, {
        prompt = "Delete Worktree> ",
        actions = {
            ["default"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                -- Extract branch name
                local branch = selected[1]:match("^([^%s]+)")

                for _, wt in ipairs(worktrees) do
                    if wt.branch == branch then
                        opts.on_select(wt)
                        return
                    end
                end
            end,
        },
        winopts = fzf_opts.winopts or {
            height = 0.4,
            width = 0.6,
            row = 0.5,
            col = 0.5,
        },
    })
end

--- Show branch picker
---@param opts { branches: string[], prompt?: string, on_select: fun(branch: string) }
function M.show_branch_picker(opts)
    if #opts.branches == 0 then
        vim.notify("No available branches", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "Select branch:",
        }, function(choice)
            if choice then
                opts.on_select(choice)
            end
        end)
        return
    end

    local fzf_opts = config.get("fzf_opts") or {}

    fzf.fzf_exec(opts.branches, {
        prompt = opts.prompt or "Select Branch> ",
        actions = {
            ["default"] = function(selected)
                if selected and #selected > 0 then
                    opts.on_select(selected[1])
                end
            end,
        },
        winopts = fzf_opts.winopts or {
            height = 0.4,
            width = 0.6,
            row = 0.5,
            col = 0.5,
        },
    })
end

--- Show worktree list picker (multi-operation support)
--- Enter: Jump to worktree
--- Ctrl-D: Delete worktree
--- Ctrl-N: Create worktree
---@param opts? { on_jump?: fun(worktree: table), on_delete?: fun(worktree: table), on_create?: fun() }
function M.show_list_picker(opts)
    opts = opts or {}

    -- Create debug context
    local dbg = log.get_debug()
    local request_id = dbg.begin("ui.show_list_picker")

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
    dbg.log_raw("DEBUG", string.format("Call stack: %s", table.concat(call_stack, " → ")))

    -- Get worktree list
    dbg.log_raw("INFO", "Calling core.get_worktree_list()")
    local worktrees = core.get_worktree_list()
    dbg.log_raw("INFO", string.format("Retrieved %d worktrees", #worktrees))

    -- Record list details from core
    for i, wt in ipairs(worktrees) do
        dbg.log_raw("DEBUG", string.format(
            "UI Worktree[%d]: path=%s, branch=%s, window=%s, has_window=%s",
            i,
            wt.path or "nil",
            wt.branch or "nil",
            wt.window_name or "nil",
            wt.has_window and "✓" or "✗"
        ))
    end

    if #worktrees == 0 then
        dbg.log_raw("WARN", "No available worktrees, showing warning")
        vim.notify("No available worktrees", vim.log.levels.WARN)
        dbg.done()
        return
    end

    -- Format as fzf options
    dbg.log_raw("INFO", "Formatting UI display options")
    local items = {}
    local worktree_map = {}
    for _, wt in ipairs(worktrees) do
        local status = wt.has_window and " ✓" or " ✗"
        local display = string.format("%s%s | %s", wt.window_name, status, wt.branch)
        table.insert(items, display)
        worktree_map[display] = wt
        dbg.log_raw("DEBUG", string.format(
            "Formatted option: display='%s', worktree: %s",
            display,
            wt.path
        ))
    end

    -- Record data flow
    dbg.log_raw("INFO", string.format(
        "Data flow: core.get_worktree_list(%d) → formatted → %d UI options",
        #worktrees,
        #items
    ))

    local fzf_opts = config.get("fzf_opts") or {}

    if not has_fzf then
        -- Fallback to vim.ui.select (single operation)
        dbg.log_raw("INFO", "Using vim.ui.select fallback mode")
        vim.ui.select(items, {
            prompt = "Select Worktree (Enter=jump, Ctrl-D=delete):",
        }, function(choice)
            if choice and worktree_map[choice] then
                local wt = worktree_map[choice]
                dbg.log_raw("INFO", string.format(
                    "User selected: %s, executing on_jump",
                    wt.window_name
                ))
                if opts.on_jump then
                    opts.on_jump(wt)
                else
                    core.jump_to_window(wt.window_name)
                end
            end
        end)
        dbg.done()
        return
    end

    dbg.log_raw("INFO", "Using fzf-lua mode")
    fzf.fzf_exec(items, {
        prompt = "Worktree List> ",
        header = string.format("%s  |  [Enter] Jump  |  [Ctrl-D] Delete  |  [Ctrl-N] Create  |  [Ctrl-C] Cancel\n", string.rep("─", 28)),
        header_lines = 1,
        fzf_opts = {
            ["--layout"] = "reverse",
        },
        actions = {
            -- Enter: Jump
            ["default"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local wt = worktree_map[selected[1]]
                if wt then
                    dbg.log_raw("INFO", string.format(
                        "User pressed Enter: jump to %s (path: %s)",
                        wt.window_name,
                        wt.path
                    ))
                    if opts.on_jump then
                        opts.on_jump(wt)
                    else
                        core.jump_to_window(wt.window_name)
                    end
                end
            end,
            -- Ctrl-D: Delete
            ["ctrl-d"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local wt = worktree_map[selected[1]]
                if wt then
                    dbg.log_raw("INFO", string.format(
                        "User pressed Ctrl-D: delete %s (path: %s)",
                        wt.window_name,
                        wt.path
                    ))
                    if opts.on_delete then
                        opts.on_delete(wt)
                    else
                        local delete_func = require("worktree-tmux.init")
                        delete_func.delete(wt.path)
                    end
                end
            end,
            -- Ctrl-N: Create
            ["ctrl-n"] = function(selected)
                dbg.log_raw("INFO", "User pressed Ctrl-N: create worktree")
                if opts.on_create then
                    opts.on_create()
                end
            end,
        },
        winopts = vim.tbl_deep_extend("force", fzf_opts.winopts or {}, {
            relative = "editor",
            height = 0.5,
            width = 0.7,
            row = 0.5,
            col = 0.5,
        }),
    })

    dbg.log_raw("INFO", "Fzf picker displayed, waiting for user action")
    dbg.done()
end

return M
