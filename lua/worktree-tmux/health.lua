-- Health check module
-- For :checkhealth worktree-tmux

local M = {}

-- Get vim.health module (compatible with different versions)
local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

-- Check if command is available
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

-- Check if Lua module is available
---@param module_name string
---@return boolean
local function check_module(module_name)
    local has_module = pcall(require, module_name)
    return has_module
end

-- Execute health check
function M.check()
    start("worktree-tmux.nvim")

    -- Check Neovim version
    local nvim_version = vim.version()
    if nvim_version.major >= 0 and nvim_version.minor >= 9 then
        ok(string.format("Neovim version: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch))
    else
        warn("Neovim version too old, recommended >= 0.9.0")
    end

    -- Check tmux environment
    start("Tmux Environment")
    if vim.env.TMUX then
        ok("Running in tmux environment")
        local tmux_available, tmux_version = check_command("tmux")
        if tmux_available then
            ok("tmux version: " .. (tmux_version or "unknown"))
        end
    else
        warn("Not in tmux environment, some features unavailable")
    end

    -- Check git
    start("Git Environment")
    local git_available, git_version = check_command("git")
    if git_available then
        ok("git version: " .. (git_version or "unknown"))

        -- Check if in git repo
        vim.fn.system("git rev-parse --git-dir 2>/dev/null")
        if vim.v.shell_error == 0 then
            ok("Current directory is git repository")
        else
            info("Current directory is not git repository")
        end

        -- Check git worktree support
        vim.fn.system("git worktree list 2>/dev/null")
        if vim.v.shell_error == 0 then
            ok("git worktree feature available")
        end
    else
        error("git command not found")
    end

    -- Check rsync
    start("File Sync")
    local rsync_available, rsync_version = check_command("rsync")
    if rsync_available then
        ok("rsync version: " .. (rsync_version or "unknown"))
    else
        warn("rsync not found, file sync feature unavailable")
    end

    -- Check required dependencies
    start("Required Dependencies")

    if check_module("plenary") then
        ok("plenary.nvim installed")
    else
        error("plenary.nvim not installed, async feature unavailable")
    end

    if check_module("nui.input") then
        ok("nui.nvim installed")
    else
        warn("nui.nvim not installed, will use vim.ui instead")
    end

    -- Check optional dependencies
    start("Optional Dependencies")

    if check_module("fzf-lua") then
        ok("fzf-lua installed")
    else
        info("fzf-lua not installed, will use vim.ui.select instead")
    end

    if check_module("snacks") then
        ok("snacks.nvim installed")
    else
        info("snacks.nvim not installed, will use vim.notify instead")
    end

    -- Check configuration
    start("Configuration Check")

    local config_ok, config = pcall(require, "worktree-tmux.config")
    if config_ok then
        local opts = config.options

        info("session_name: " .. (opts.session_name or "worktrees"))
        info("worktree_base_dir: " .. (type(opts.worktree_base_dir) == "string" and opts.worktree_base_dir or "<function>"))
        info("sync_ignored_files: " .. tostring(opts.sync_ignored_files))
        info("on_duplicate_window: " .. (opts.on_duplicate_window or "ask"))

        -- Check if worktree_base_dir is writable
        local base_dir = config.get_worktree_base_dir()
        if vim.fn.isdirectory(base_dir) == 1 then
            ok("worktree_base_dir exists: " .. base_dir)
        else
            local parent = vim.fn.fnamemodify(base_dir, ":h")
            if vim.fn.isdirectory(parent) == 1 then
                info("worktree_base_dir not exists, will be created on first use: " .. base_dir)
            else
                warn("worktree_base_dir parent not exists: " .. parent)
            end
        end

        ok("Configuration loaded successfully")
    else
        warn("Configuration not initialized, please call require('worktree-tmux').setup()")
    end
end

return M
