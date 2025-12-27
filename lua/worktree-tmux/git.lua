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
    -- 创建调试上下文
    local dbg = log.get_debug()
    local request_id = dbg.begin("git.get_worktree_list")

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

    -- 执行 git 命令
    dbg.log_raw("INFO", "执行 git worktree list --porcelain 命令")
    local output = vim.fn.system("git worktree list --porcelain 2>/dev/null")

    -- 记录命令执行结果
    if vim.v.shell_error ~= 0 then
        dbg.log_raw("ERROR", string.format("git 命令执行失败，错误码: %d", vim.v.shell_error))
        dbg.log_raw("ERROR", string.format("输出: %s", output))
        dbg.done()
        return {}
    end

    -- 记录原始输出（转义特殊字符避免 vim 错误）
    dbg.log_raw("INFO", string.format("原始输出长度: %d 字符", #output))
    -- 只显示前200个字符，避免输出过长
    local preview = output:gsub("\n", "\\n"):sub(1, 200)
    if #output > 200 then
        preview = preview .. "... (截断)"
    end
    dbg.log_raw("DEBUG", string.format("原始输出内容（前200字符）: %s", preview))

    -- 解析输出
    dbg.log_raw("INFO", "开始解析 worktree 列表")
    local worktrees = {}
    local current = {}
    local line_count = 0

    for line in output:gmatch("[^\r\n]+") do
        line_count = line_count + 1
        dbg.log_raw("TRACE", string.format("解析第 %d 行: %s", line_count, line))

        if line:match("^worktree ") then
            local path = line:match("^worktree (.+)$")
            -- 排除 git 内部管理的 worktree（.git/.git/worktrees/）
            if not path:match("/%.git/%.git/worktrees/") then
                -- 如果当前已经有完整的 worktree，先保存它
                if current.path and current.branch then
                    dbg.log_raw("DEBUG", string.format("保存前一个 worktree: %s", current.path))
                    table.insert(worktrees, current)
                    dbg.log_raw("DEBUG", string.format("保存后 worktrees 数量: %d", #worktrees))
                end
                -- 开始新的 worktree
                dbg.log_raw("DEBUG", string.format("找到 worktree 路径: %s", path))
                current = { path = path }  -- 新建 table
            else
                dbg.log_raw("DEBUG", "跳过内部 worktree 路径")
                current = {} -- 跳过内部 worktree
            end
        elseif line:match("^branch ") then
            local branch = line:match("^branch refs/heads/(.+)$")
            dbg.log_raw("DEBUG", string.format("找到分支: %s", branch))
            current.branch = branch
        elseif line:match("^bare") then
            dbg.log_raw("DEBUG", "标记为 bare")
            current.bare = true
        elseif line:match("^detached") then
            dbg.log_raw("DEBUG", "标记为 detached")
            current.detached = true
        elseif line == "" and current.path and current.branch then
            local current_info = string.format("path=%s, branch=%s, bare=%s",
                current.path or "nil", current.branch or "nil", tostring(current.bare or false))
            dbg.log_raw("DEBUG", string.format("遇到空行，当前 worktree: %s", current_info))
            table.insert(worktrees, current)
            dbg.log_raw("DEBUG", string.format("添加后 worktrees 数量: %d", #worktrees))
            for i, wt in ipairs(worktrees) do
                dbg.log_raw("DEBUG", string.format("  Worktrees[%d]: %s", i, wt.path))
            end
            current = {}
            dbg.log_raw("DEBUG", "已重置 current")
        end
    end

    -- 处理最后一个条目
    local current_info = current.path and string.format("path=%s, branch=%s, bare=%s",
        current.path or "nil", current.branch or "nil", tostring(current.bare or false)) or "空"
    dbg.log_raw("DEBUG", string.format("循环结束，current: %s", current_info))
    if current.path then
        dbg.log_raw("DEBUG", string.format("完成最后一个 worktree 解析: %s", current_info))
        table.insert(worktrees, current)
        dbg.log_raw("DEBUG", string.format("最终 worktrees 数量: %d", #worktrees))
        for i, wt in ipairs(worktrees) do
            dbg.log_raw("DEBUG", string.format("  Worktrees[%d]: %s", i, wt.path))
        end
    end

    -- 记录数据流
    dbg.log_raw("INFO", string.format(
        "数据流: git worktree list --porcelain → 解析 → %d 个 worktrees",
        #worktrees
    ))

    -- 记录最终结果
    if #worktrees > 0 then
        for i, wt in ipairs(worktrees) do
            dbg.log_raw("INFO", string.format(
                "Worktree[%d]: 路径=%s, 分支=%s, bare=%s, detached=%s",
                i,
                wt.path or "nil",
                wt.branch or "nil",
                tostring(wt.bare or false),
                tostring(wt.detached or false)
            ))
        end
    else
        dbg.log_raw("WARN", "没有找到任何 worktrees")
    end

    dbg.done()
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
