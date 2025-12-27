-- fzf-lua 选择器组件

local config = require("worktree-tmux.config")
local core = require("worktree-tmux.core")
local log = require("worktree-tmux.log")

local M = {}

-- 检查 fzf-lua 是否可用
local has_fzf, fzf = pcall(require, "fzf-lua")

--- 显示 worktree 选择器并跳转
---@param opts? { on_select?: fun(item: table) }
function M.show_worktree_picker(opts)
    opts = opts or {}

    -- 获取 worktree 列表
    local worktrees = core.get_worktree_list()

    if #worktrees == 0 then
        vim.notify("没有可用的 worktree windows", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        -- 回退到 vim.ui.select
        local items = {}
        for _, wt in ipairs(worktrees) do
            local status = wt.has_window and " ✓" or " ✗"
            table.insert(items, wt.window_name .. status)
        end

        vim.ui.select(items, {
            prompt = "选择 Worktree:",
        }, function(choice)
            if choice then
                -- 提取 window 名（移除状态标记）
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

    -- 格式化为 fzf 选项
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

                -- 提取 window 名
                local window_name = selected[1]:match("^([^%s]+)")

                if opts.on_select then
                    -- 查找对应的 worktree
                    for _, wt in ipairs(worktrees) do
                        if wt.window_name == window_name then
                            opts.on_select(wt)
                            return
                        end
                    end
                else
                    -- 默认跳转
                    local ok, err = core.jump_to_window(window_name)
                    if ok then
                        vim.notify("切换到: " .. window_name, vim.log.levels.INFO)
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

--- 显示 worktree 选择器用于删除
---@param opts { on_select: fun(worktree: table) }
function M.show_delete_picker(opts)
    local worktrees = core.get_worktree_list()

    if #worktrees == 0 then
        vim.notify("没有可删除的 worktrees", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        -- 回退到 vim.ui.select
        local items = {}
        local item_map = {}
        for _, wt in ipairs(worktrees) do
            local display = wt.branch .. " | " .. wt.path
            table.insert(items, display)
            item_map[display] = wt
        end

        vim.ui.select(items, {
            prompt = "选择要删除的 Worktree:",
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

                -- 提取分支名
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

--- 显示分支选择器
---@param opts { branches: string[], prompt?: string, on_select: fun(branch: string) }
function M.show_branch_picker(opts)
    if #opts.branches == 0 then
        vim.notify("没有可用的分支", vim.log.levels.WARN)
        return
    end

    if not has_fzf then
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "选择分支:",
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

return M
