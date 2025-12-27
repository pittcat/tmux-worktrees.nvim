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

    -- 执行创建
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
    local ui = get_ui()
    local tmux = require("worktree-tmux.tmux")
    local notify = get_notify()

    if not tmux.in_tmux() then
        notify.error("必须在 tmux 环境中使用此命令")
        return
    end

    ui.worktree_picker()
end

--- 删除 worktree + tmux window
---@param path? string worktree 路径
function M.delete(path)
    local ui = get_ui()
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

    -- 如果没有指定路径，显示选择器
    if not path or path == "" then
        ui.get_picker().show_delete_picker({
            on_select = function(worktree)
                -- 确认删除
                ui.get_confirm().confirm_delete(worktree.path, {
                    on_yes = function()
                        local ok, err = core.delete_worktree_window(worktree.path)
                        if ok then
                            notify.success("删除成功")
                        else
                            notify.error(err or "删除失败")
                        end
                    end,
                })
            end,
        })
        return
    end

    -- 直接删除指定路径
    local ok, err = core.delete_worktree_window(path)
    if ok then
        notify.success("删除成功")
    else
        notify.error(err or "删除失败")
    end
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

--- 列出所有 worktrees
function M.list()
    local core = get_core()
    local notify = get_notify()
    local git = require("worktree-tmux.git")

    if not git.in_git_repo() then
        notify.error("当前目录不是 git 仓库")
        return
    end

    local worktrees = core.get_worktree_list()

    if #worktrees == 0 then
        notify.info("没有 worktrees")
        return
    end

    -- 构建列表显示
    local lines = { "Worktrees:" }
    for _, wt in ipairs(worktrees) do
        local status = wt.has_window and "✓" or "✗"
        table.insert(lines, string.format("  %s %s (%s)", status, wt.branch, wt.path))
    end

    -- 使用 echo 显示（多行）
    vim.api.nvim_echo(vim.tbl_map(function(line)
        return { line .. "\n", "Normal" }
    end, lines), true, {})
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
