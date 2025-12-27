-- worktree-tmux.nvim
-- Git Worktree + Tmux Window 自动化管理

local M = {}

-- 版本信息
M.version = "0.1.0"

-- 模块懒加载
local _config = nil
local _core = nil
local _ui = nil
local _notify = nil

--- 获取配置模块
---@return table
local function get_config()
    if not _config then
        _config = require("worktree-tmux.config")
    end
    return _config
end

--- 获取核心模块
---@return table
local function get_core()
    if not _core then
        _core = require("worktree-tmux.core")
    end
    return _core
end

--- 获取 UI 模块
---@return table
local function get_ui()
    if not _ui then
        _ui = require("worktree-tmux.ui")
    end
    return _ui
end

--- 获取通知模块
---@return table
local function get_notify()
    if not _notify then
        _notify = require("worktree-tmux.notify")
    end
    return _notify
end

--- 初始化插件
---@param user_config? table 用户配置
function M.setup(user_config)
    get_config().setup(user_config)
end

--- 创建 worktree + tmux window
---@param branch? string 分支名（如果为空，弹出输入框）
---@param base? string 基于哪个分支
function M.create(branch, base)
    local ui = get_ui()
    local core = get_core()
    local notify = get_notify()
    local git = require("worktree-tmux.git")

    -- 前置检查
    local tmux = require("worktree-tmux.tmux")
    if not tmux.in_tmux() then
        notify.error("必须在 tmux 环境中使用此命令")
        return
    end

    if not git.in_git_repo() then
        notify.error("当前目录不是 git 仓库")
        return
    end

    -- 如果没有提供分支名，弹出输入框
    if not branch or branch == "" then
        ui.branch_input({
            prompt = " 输入新分支名 ",
            on_submit = function(value)
                M.create(value, base)
            end,
        })
        return
    end

    -- 检查是否启用异步模式
    local config = get_config()
    local use_async = config.get("async")

    if use_async then
        -- 异步执行（后台运行，不阻塞 Neovim）
        core.create_worktree_window_async(branch, base, {
            on_success = function()
                -- 可选：自动切换到新 window
                -- local tmux = require("worktree-tmux.tmux")
                -- tmux.switch_to_window(config.get("session_name"), window_name)
            end,
            on_error = function(msg)
                -- 错误已在回调中通过 notify 处理
            end,
        })
        return
    end

    -- 同步执行
    local ok, err = core.create_worktree_window(branch, base)

    if not ok then
        -- 处理特殊错误
        if err and err:match("^WINDOW_EXISTS:") then
            local window_name = err:match("^WINDOW_EXISTS:(.+)$")
            ui.get_confirm().confirm_overwrite(window_name, {
                on_yes = function()
                    -- 设置策略为 overwrite 后重试
                    local config = get_config()
                    local old_strategy = config.get("on_duplicate_window")
                    config.options.on_duplicate_window = "overwrite"

                    local retry_ok, retry_err = core.create_worktree_window(branch, base)

                    -- 恢复策略
                    config.options.on_duplicate_window = old_strategy

                    if retry_ok then
                        notify.success("创建成功: " .. branch)
                    else
                        notify.error("创建失败: " .. (retry_err or ""))
                    end
                end,
            })
        else
            notify.error(err or "创建失败")
        end
    else
        notify.success("创建成功: " .. branch)
    end
end

--- 跳转到 worktree window
function M.jump()
    -- 创建调试上下文
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.jump")

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

    local ui = get_ui()
    local tmux = require("worktree-tmux.tmux")
    local notify = get_notify()

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "不在 tmux 环境中")
        notify.error("必须在 tmux 环境中使用此命令")
        dbg.done()
        return
    end

    dbg.log_raw("INFO", "环境检查通过，显示 worktree 选择器")
    ui.worktree_picker()
    dbg.done()
end

--- 删除 worktree + tmux window
---@param path? string worktree 路径
function M.delete(path)
    -- 创建调试上下文
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.delete")

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

    local ui = get_ui()
    local core = get_core()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "不在 tmux 环境中")
        notify.error("必须在 tmux 环境中使用此命令")
        dbg.done()
        return
    end

    if not git.in_git_repo() then
        dbg.log_raw("ERROR", "不在 git 仓库中")
        notify.error("当前目录不是 git 仓库")
        dbg.done()
        return
    end

    -- 如果没有指定路径，显示选择器
    if not path or path == "" then
        dbg.log_raw("INFO", "未指定路径，显示删除选择器")
        ui.get_picker().show_delete_picker({
            on_select = function(worktree)
                dbg.log_raw("INFO", string.format(
                    "用户选择删除: %s (路径: %s)",
                    worktree.window_name,
                    worktree.path
                ))
                -- 确认删除
                ui.get_confirm().confirm_delete(worktree, {
                    on_yes = function()
                        dbg.log_raw("INFO", "用户确认删除，执行删除操作")
                        local ok, err = core.delete_worktree_window(worktree.path)
                        if ok then
                            notify.success("删除成功: " .. worktree.branch)
                        else
                            notify.error(err or "删除失败")
                        end
                    end,
                })
            end,
        })
        dbg.done()
        return
    end

    -- 直接删除指定路径
    dbg.log_raw("INFO", string.format("直接删除指定路径: %s", path))
    local ok, err = core.delete_worktree_window(path)
    if ok then
        dbg.log_raw("INFO", "删除成功")
        notify.success("删除成功")
    else
        dbg.log_raw("ERROR", string.format("删除失败: %s", err or "未知错误"))
        notify.error(err or "删除失败")
    end
    dbg.done()
end

--- 同步 worktrees 和 tmux windows
function M.sync()
    local core = get_core()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        notify.error("必须在 tmux 环境中使用此命令")
        return
    end

    if not git.in_git_repo() then
        notify.error("当前目录不是 git 仓库")
        return
    end

    local result = core.sync_worktrees()
    notify.success(string.format("同步完成: 创建 %d 个，跳过 %d 个", result.created, result.skipped))
end

--- 列出所有 worktrees（可交互选择操作）
function M.list()
    -- 创建调试上下文
    local log = require("worktree-tmux.log")
    local dbg = log.get_debug()
    local request_id = dbg.begin("init.list")

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

    local ui = get_ui()
    local notify = get_notify()
    local tmux = require("worktree-tmux.tmux")
    local git = require("worktree-tmux.git")

    if not tmux.in_tmux() then
        dbg.log_raw("ERROR", "不在 tmux 环境中")
        notify.error("必须在 tmux 环境中使用此命令")
        dbg.done()
        return
    end

    if not git.in_git_repo() then
        dbg.log_raw("ERROR", "不在 git 仓库中")
        notify.error("当前目录不是 git 仓库")
        dbg.done()
        return
    end

    dbg.log_raw("INFO", "环境检查通过，开始显示 worktree 列表选择器")
    -- 使用新的多操作选择器
    ui.get_picker().show_list_picker({
        on_jump = function(worktree)
            dbg.log_raw("INFO", string.format(
                "用户选择跳转: %s (路径: %s)",
                worktree.window_name,
                worktree.path
            ))
            local core = get_core()
            local ok, err = core.jump_to_window(worktree.window_name)
            if ok then
                notify.success("已切换到: " .. worktree.window_name)
            else
                notify.error(err or "跳转失败")
            end
        end,
        on_delete = function(worktree)
            dbg.log_raw("INFO", string.format(
                "用户选择删除: %s (路径: %s)",
                worktree.window_name,
                worktree.path
            ))
            -- 显示确认对话框
            ui.get_confirm().confirm_delete(worktree, {
                on_yes = function()
                    dbg.log_raw("INFO", "用户确认删除，执行删除操作")
                    local core = get_core()
                    local ok, err = core.delete_worktree_window(worktree.path)
                    if ok then
                        notify.success("删除成功: " .. worktree.branch)
                    else
                        notify.error(err or "删除失败")
                    end
                end,
            })
        end,
        on_create = function()
            dbg.log_raw("INFO", "用户选择创建新 worktree")
            -- 弹出输入框创建新 worktree
            ui.branch_input({
                prompt = " 输入新分支名 ",
                on_submit = function(branch)
                    dbg.log_raw("INFO", string.format("用户输入新分支名: %s", branch))
                    M.create(branch)
                end,
            })
        end,
    })

    dbg.done()
end

-- 导出模块（供高级用户使用）
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
