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

--- 显示 worktree 列表选择器（支持多操作）
--- Enter: 跳转到 worktree
--- Ctrl-D: 删除 worktree
--- Ctrl-N: 新建 worktree
---@param opts? { on_jump?: fun(worktree: table), on_delete?: fun(worktree: table), on_create?: fun() }
function M.show_list_picker(opts)
    opts = opts or {}

    -- 创建调试上下文
    local dbg = log.get_debug()
    local request_id = dbg.begin("ui.show_list_picker")

    -- 记录环境和版本信息
    local version = vim.version()
    dbg.log_raw("INFO", string.format(
        "环境: %s | 版本: v0.1.0 | Neovim: %s.%s.%s | RequestID: %s",
        vim.env.WORKTREE_ENV or "dev",
        version.major,
        version.minor,
        version.patch,
        request_id
    ))

    -- 记录调用栈
    local call_stack = {}
    for i = 3, 7 do
        local info = debug.getinfo(i, "nSl")
        if not info then break end
        table.insert(call_stack, string.format("%s() line %d", info.name or "anonymous", info.currentline or 0))
    end
    dbg.log_raw("DEBUG", string.format("调用栈: %s", table.concat(call_stack, " → ")))

    -- 获取 worktree 列表
    dbg.log_raw("INFO", "调用 core.get_worktree_list() 获取工作列表")
    local worktrees = core.get_worktree_list()
    dbg.log_raw("INFO", string.format("获取到 %d 个 worktrees", #worktrees))

    -- 记录从 core 获取的列表详情
    for i, wt in ipairs(worktrees) do
        dbg.log_raw("DEBUG", string.format(
            "UI Worktree[%d]: 路径=%s, 分支=%s, window=%s, has_window=%s",
            i,
            wt.path or "nil",
            wt.branch or "nil",
            wt.window_name or "nil",
            wt.has_window and "✓" or "✗"
        ))
    end

    if #worktrees == 0 then
        dbg.log_raw("WARN", "没有可用的 worktrees，显示警告消息")
        vim.notify("没有可用的 worktrees", vim.log.levels.WARN)
        dbg.done()
        return
    end

    -- 格式化为 fzf 选项
    dbg.log_raw("INFO", "格式化 UI 显示选项")
    local items = {}
    local worktree_map = {}
    for _, wt in ipairs(worktrees) do
        local status = wt.has_window and " ✓" or " ✗"
        local display = string.format("%s%s | %s", wt.window_name, status, wt.branch)
        table.insert(items, display)
        worktree_map[display] = wt
        dbg.log_raw("DEBUG", string.format(
            "格式化选项: 显示='%s', 对应 worktree: %s",
            display,
            wt.path
        ))
    end

    -- 记录数据流
    dbg.log_raw("INFO", string.format(
        "数据流: core.get_worktree_list(%d) → 格式化 → %d 个 UI 选项",
        #worktrees,
        #items
    ))

    local fzf_opts = config.get("fzf_opts") or {}

    if not has_fzf then
        -- 回退到 vim.ui.select（单操作）
        dbg.log_raw("INFO", "使用 vim.ui.select 回退模式")
        vim.ui.select(items, {
            prompt = "选择 Worktree (Enter=跳转, Ctrl-D=删除):",
        }, function(choice)
            if choice and worktree_map[choice] then
                local wt = worktree_map[choice]
                dbg.log_raw("INFO", string.format(
                    "用户选择: %s, 执行 on_jump",
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

    dbg.log_raw("INFO", "使用 fzf-lua 模式")
    fzf.fzf_exec(items, {
        prompt = "Worktree List> ",
        header = string.format("%s  |  [Enter] 跳转  |  [Ctrl-D] 删除  |  [Ctrl-N] 新建  |  [Ctrl-C] 取消\n", string.rep("─", 28)),
        header_lines = 1,
        fzf_opts = {
            ["--layout"] = "reverse",
        },
        actions = {
            -- Enter: 跳转
            ["default"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local wt = worktree_map[selected[1]]
                if wt then
                    dbg.log_raw("INFO", string.format(
                        "用户按 Enter: 跳转到 %s (路径: %s)",
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
            -- Ctrl-D: 删除
            ["ctrl-d"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local wt = worktree_map[selected[1]]
                if wt then
                    dbg.log_raw("INFO", string.format(
                        "用户按 Ctrl-D: 删除 %s (路径: %s)",
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
            -- Ctrl-N: 新建
            ["ctrl-n"] = function(selected)
                dbg.log_raw("INFO", "用户按 Ctrl-N: 新建 worktree")
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

    dbg.log_raw("INFO", "Fzf 选择器已显示，等待用户操作")
    dbg.done()
end

return M
