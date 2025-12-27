-- 健康检查模块
-- 用于 :checkhealth worktree-tmux

local M = {}

-- 获取 vim.health 模块（兼容不同版本）
local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

--- 检查命令是否可用
---@param cmd string
---@return boolean available
---@return string? version
local function check_command(cmd)
    local output = vim.fn.system(cmd .. " --version 2>/dev/null")
    if vim.v.shell_error == 0 then
        local version = output:match("[%d%.]+")
        return true, version
    end
    return false, nil
end

--- 检查 Lua 模块是否可用
---@param module_name string
---@return boolean
local function check_module(module_name)
    local has_module = pcall(require, module_name)
    return has_module
end

--- 执行健康检查
function M.check()
    start("worktree-tmux.nvim")

    -- 检查 Neovim 版本
    local nvim_version = vim.version()
    if nvim_version.major >= 0 and nvim_version.minor >= 9 then
        ok(string.format("Neovim 版本: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch))
    else
        warn("Neovim 版本过低，建议 >= 0.9.0")
    end

    -- 检查 tmux 环境
    start("Tmux 环境")
    if vim.env.TMUX then
        ok("在 tmux 环境中运行")
        local tmux_available, tmux_version = check_command("tmux")
        if tmux_available then
            ok("tmux 版本: " .. (tmux_version or "unknown"))
        end
    else
        warn("当前不在 tmux 环境中，部分功能不可用")
    end

    -- 检查 git
    start("Git 环境")
    local git_available, git_version = check_command("git")
    if git_available then
        ok("git 版本: " .. (git_version or "unknown"))

        -- 检查是否在 git 仓库中
        vim.fn.system("git rev-parse --git-dir 2>/dev/null")
        if vim.v.shell_error == 0 then
            ok("当前目录是 git 仓库")
        else
            info("当前目录不是 git 仓库")
        end

        -- 检查 git worktree 支持
        vim.fn.system("git worktree list 2>/dev/null")
        if vim.v.shell_error == 0 then
            ok("git worktree 功能可用")
        end
    else
        error("未找到 git 命令")
    end

    -- 检查 rsync
    start("文件同步")
    local rsync_available, rsync_version = check_command("rsync")
    if rsync_available then
        ok("rsync 版本: " .. (rsync_version or "unknown"))
    else
        warn("未找到 rsync，文件同步功能不可用")
    end

    -- 检查必选依赖
    start("必选依赖")

    if check_module("plenary") then
        ok("plenary.nvim 已安装")
    else
        error("plenary.nvim 未安装，异步功能不可用")
    end

    if check_module("nui.input") then
        ok("nui.nvim 已安装")
    else
        warn("nui.nvim 未安装，将使用 vim.ui 替代")
    end

    -- 检查可选依赖
    start("可选依赖")

    if check_module("fzf-lua") then
        ok("fzf-lua 已安装")
    else
        info("fzf-lua 未安装，将使用 vim.ui.select 替代")
    end

    if check_module("snacks") then
        ok("snacks.nvim 已安装")
    else
        info("snacks.nvim 未安装，将使用 vim.notify 替代")
    end

    -- 检查配置
    start("配置检查")

    local config_ok, config = pcall(require, "worktree-tmux.config")
    if config_ok then
        local opts = config.options

        info("session_name: " .. (opts.session_name or "worktrees"))
        info("worktree_base_dir: " .. (type(opts.worktree_base_dir) == "string" and opts.worktree_base_dir or "<function>"))
        info("sync_ignored_files: " .. tostring(opts.sync_ignored_files))
        info("on_duplicate_window: " .. (opts.on_duplicate_window or "ask"))

        -- 检查 worktree_base_dir 是否可写
        local base_dir = config.get_worktree_base_dir()
        if vim.fn.isdirectory(base_dir) == 1 then
            ok("worktree_base_dir 目录存在: " .. base_dir)
        else
            local parent = vim.fn.fnamemodify(base_dir, ":h")
            if vim.fn.isdirectory(parent) == 1 then
                info("worktree_base_dir 目录不存在，将在首次使用时创建: " .. base_dir)
            else
                warn("worktree_base_dir 父目录不存在: " .. parent)
            end
        end

        ok("配置加载成功")
    else
        warn("配置未初始化，请调用 require('worktree-tmux').setup()")
    end
end

return M
