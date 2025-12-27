-- UI module entry point
-- Unified export of UI functionality

local M = {}

-- Lazy load submodules
local _input = nil
local _confirm = nil
local _picker = nil
local _progress = nil

--- Get input module
---@return table
function M.get_input()
    if not _input then
        _input = require("worktree-tmux.ui.input")
    end
    return _input
end

--- Get confirm dialog module
---@return table
function M.get_confirm()
    if not _confirm then
        _confirm = require("worktree-tmux.ui.confirm")
    end
    return _confirm
end

--- Get picker module
---@return table
function M.get_picker()
    if not _picker then
        _picker = require("worktree-tmux.ui.picker")
    end
    return _picker
end

--- Get progress module
---@return table
function M.get_progress()
    if not _progress then
        _progress = require("worktree-tmux.ui.progress")
    end
    return _progress
end

--- Show branch name input
---@param opts { prompt?: string, default?: string, on_submit: fun(value: string), on_close?: fun() }
function M.branch_input(opts)
    M.get_input().branch_input(opts)
end

--- Show confirm dialog
---@param opts { title?: string, message: string, on_yes: fun(), on_no?: fun() }
function M.confirm(opts)
    M.get_confirm().show(opts)
end

--- Show worktree picker
---@param opts? { on_select?: fun(item: table) }
function M.worktree_picker(opts)
    M.get_picker().show_worktree_picker(opts)
end

--- Show progress
---@param opts { message: string, progress?: number, total?: number }
function M.show_progress(opts)
    M.get_progress().show(opts)
end

--- Hide progress
function M.hide_progress()
    M.get_progress().hide()
end

return M
