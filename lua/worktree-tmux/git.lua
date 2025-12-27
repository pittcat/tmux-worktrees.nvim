-- Git 操作封装模块
-- 提供 git worktree 相关的 CLI 操作

local log = require("worktree-tmux.log")

local M = {}

--- 检查是否在 git 仓库中
---@return boolean
function M.in_git_repo()
    vim.fn.system("git rev-parse --git-dir 2>/dev/null")
    return vim.v.shell_error == 0
end

--- 获取 git 仓库根目录
---@return string|nil
function M.get_repo_root()
    local output = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- 获取 git 仓库名称
---@return string|nil
function M.get_repo_name()
    local root = M.get_repo_root()
    if not root then
        return nil
    end
    return vim.fn.fnamemodify(root, ":t")
end

--- 获取当前分支名
---@return string|nil
function M.get_current_branch()
    local output = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

--- 获取所有 worktrees
---@return WorktreeTmux.Worktree[]
function M.get_worktree_list()
    local output = vim.fn.system("git worktree list --porcelain 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return {}
    end

    local worktrees = {}
    local current = {}

    for line in output:gmatch("[^\r\n]+") do
        if line:match("^worktree ") then
            current.path = line:match("^worktree (.+)$")
        elseif line:match("^branch ") then
            current.branch = line:match("^branch refs/heads/(.+)$")
        elseif line:match("^bare") then
            current.bare = true
        elseif line:match("^detached") then
            current.detached = true
        elseif line == "" and current.path then
            table.insert(worktrees, current)
            current = {}
        end
    end

    -- 处理最后一个条目
    if current.path then
        table.insert(worktrees, current)
    end

    return worktrees
end

--- 检查分支是否存在
---@param branch string 分支名
---@return boolean
function M.branch_exists(branch)
    local cmd = string.format("git show-ref --verify --quiet refs/heads/%s", vim.fn.shellescape(branch))
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- 检查远程分支是否存在
---@param branch string 分支名
---@param remote? string 远程名（默认 origin）
---@return boolean
function M.remote_branch_exists(branch, remote)
    remote = remote or "origin"
    local cmd = string.format(
        "git show-ref --verify --quiet refs/remotes/%s/%s",
        vim.fn.shellescape(remote),
        vim.fn.shellescape(branch)
    )
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- 创建 worktree
---@param path string 目标路径
---@param branch string 分支名
---@param opts? { base?: string, create_branch?: boolean }
---@return boolean success
---@return string? error_msg
function M.create_worktree(path, branch, opts)
    opts = opts or {}
    local cmd_parts = { "git", "worktree", "add" }

    -- 如果需要创建新分支
    if opts.create_branch or not M.branch_exists(branch) then
        table.insert(cmd_parts, "-b")
        table.insert(cmd_parts, vim.fn.shellescape(branch))
    end

    table.insert(cmd_parts, vim.fn.shellescape(path))

    -- 如果不创建新分支，直接使用分支名
    if M.branch_exists(branch) and not opts.create_branch then
        table.insert(cmd_parts, vim.fn.shellescape(branch))
    elseif opts.base then
        -- 基于指定分支创建
        table.insert(cmd_parts, vim.fn.shellescape(opts.base))
    end

    local cmd = table.concat(cmd_parts, " ")
    log.debug("创建 worktree:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 删除 worktree
---@param path string worktree 路径
---@param opts? { force?: boolean }
---@return boolean success
---@return string? error_msg
function M.delete_worktree(path, opts)
    opts = opts or {}
    local cmd_parts = { "git", "worktree", "remove" }

    if opts.force then
        table.insert(cmd_parts, "--force")
    end

    table.insert(cmd_parts, vim.fn.shellescape(path))

    local cmd = table.concat(cmd_parts, " ")
    log.debug("删除 worktree:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 清理 worktree（移除无效的 worktree 记录）
---@return boolean success
---@return string? error_msg
function M.prune_worktrees()
    local cmd = "git worktree prune"
    log.debug("清理 worktrees:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 根据分支名获取 worktree 路径
---@param branch string 分支名
---@return string|nil
function M.get_worktree_path_by_branch(branch)
    local worktrees = M.get_worktree_list()
    for _, wt in ipairs(worktrees) do
        if wt.branch == branch then
            return wt.path
        end
    end
    return nil
end

--- 验证分支名是否合法
---@param branch string 分支名
---@return boolean valid
---@return string? error_msg
function M.validate_branch_name(branch)
    if not branch or branch == "" then
        return false, "分支名不能为空"
    end

    -- 检查非法字符
    if branch:match("%.%.") then
        return false, "分支名不能包含 '..'"
    end

    if branch:match("^/") or branch:match("/$") then
        return false, "分支名不能以 '/' 开头或结尾"
    end

    if branch:match("^%-") then
        return false, "分支名不能以 '-' 开头"
    end

    -- 使用 git check-ref-format 验证
    local cmd = string.format(
        "git check-ref-format --branch %s 2>/dev/null",
        vim.fn.shellescape(branch)
    )
    vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        return false, "分支名格式无效"
    end

    return true
end

--- 获取远程分支列表
---@param remote? string 远程名（默认 origin）
---@return string[]
function M.get_remote_branches(remote)
    remote = remote or "origin"
    local cmd = string.format("git branch -r --list '%s/*' --format='%%(refname:short)' 2>/dev/null", remote)
    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        return {}
    end

    local branches = {}
    for line in output:gmatch("[^\r\n]+") do
        -- 移除 origin/ 前缀
        local branch = line:match("^" .. remote .. "/(.+)$")
        if branch and branch ~= "HEAD" then
            table.insert(branches, branch)
        end
    end

    return branches
end

--- 获取本地分支列表
---@return string[]
function M.get_local_branches()
    local output = vim.fn.system("git branch --format='%(refname:short)' 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return {}
    end

    local branches = {}
    for line in output:gmatch("[^\r\n]+") do
        if line ~= "" then
            table.insert(branches, line)
        end
    end

    return branches
end

return M
