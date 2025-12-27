-- UI 模块入口
-- 统一导出 UI 功能

local M = {}

-- 懒加载子模块
local _input = nil
local _confirm = nil
local _picker = nil
local _progress = nil

--- 获取输入框模块
---@return table
function M.get_input()
    if not _input then
        _input = require("worktree-tmux.ui.input")
    end
    return _input
end

--- 获取确认对话框模块
---@return table
function M.get_confirm()
    if not _confirm then
        _confirm = require("worktree-tmux.ui.confirm")
    end
    return _confirm
end

--- 获取选择器模块
---@return table
function M.get_picker()
    if not _picker then
        _picker = require("worktree-tmux.ui.picker")
    end
    return _picker
end

--- 获取进度模块
---@return table
function M.get_progress()
    if not _progress then
        _progress = require("worktree-tmux.ui.progress")
    end
    return _progress
end

--- 显示分支名输入框
---@param opts { prompt?: string, default?: string, on_submit: fun(value: string), on_close?: fun() }
function M.branch_input(opts)
    M.get_input().branch_input(opts)
end

--- 显示确认对话框
---@param opts { title?: string, message: string, on_yes: fun(), on_no?: fun() }
function M.confirm(opts)
    M.get_confirm().show(opts)
end

--- 显示 worktree 选择器
---@param opts? { on_select?: fun(item: table) }
function M.worktree_picker(opts)
    M.get_picker().show_worktree_picker(opts)
end

--- 显示进度
---@param opts { message: string, progress?: number, total?: number }
function M.show_progress(opts)
    M.get_progress().show(opts)
end

--- 隐藏进度
function M.hide_progress()
    M.get_progress().hide()
end

return M
