-- Git operations wrapper module
-- Provides git worktree related CLI operations

local log = require("worktree-tmux.log")

local M = {}

-- Check if in git repository
---@return boolean
function M.in_git_repo()
    vim.fn.system("git rev-parse --git-dir 2>/dev/null")
    return vim.v.shell_error == 0
end

-- Get git repository root directory
---@return string|nil
function M.get_repo_root()
    local output = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

-- Get git repository name
---@return string|nil
function M.get_repo_name()
    local root = M.get_repo_root()
    if not root then
        return nil
    end
    return vim.fn.fnamemodify(root, ":t")
end

-- Get current branch name
---@return string|nil
function M.get_current_branch()
    local output = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return output:gsub("%s+$", "")
end

-- Get all worktrees
---@return WorktreeTmux.Worktree[]
function M.get_worktree_list()
    -- Create debug context
    local dbg = log.get_debug()
    local request_id = dbg.begin("git.get_worktree_list")

    -- Record environment and version info
    local version = vim.version()
    dbg.log_raw("INFO", string.format(
        "Env: %s | Version: v0.1.0 | Neovim: %s.%s.%s | RequestID: %s",
        vim.env.WORKTREE_ENV or "dev",
        version.major,
        version.minor,
        version.patch,
        request_id
    ))

    -- Record call stack
    local call_stack = {}
    for i = 3, 7 do
        local info = debug.getinfo(i, "nSl")
        if not info then break end
        table.insert(call_stack, string.format("%s() line %d", info.name or "anonymous", info.currentline or 0))
    end
    dbg.log_raw("DEBUG", string.format("Call stack: %s", table.concat(call_stack, " -> ")))

    -- Execute git command
    dbg.log_raw("INFO", "Execute git worktree list --porcelain command")
    local output = vim.fn.system("git worktree list --porcelain 2>/dev/null")

    -- Record command result
    if vim.v.shell_error ~= 0 then
        dbg.log_raw("ERROR", string.format("git command failed, error code: %d", vim.v.shell_error))
        dbg.log_raw("ERROR", string.format("Output: %s", output))
        dbg.done()
        return {}
    end

    -- Record raw output (escape special chars to avoid vim errors)
    dbg.log_raw("INFO", string.format("Raw output length: %d chars", #output))
    -- Only show first 200 chars to avoid output too long
    local preview = output:gsub("\n", "\\n"):sub(1, 200)
    if #output > 200 then
        preview = preview .. "... (truncated)"
    end
    dbg.log_raw("DEBUG", string.format("Raw output content (first 200 chars): %s", preview))

    -- Parse output
    dbg.log_raw("INFO", "Start parsing worktree list")
    local worktrees = {}
    local current = {}
    local line_count = 0

    for line in output:gmatch("[^\r\n]+") do
        line_count = line_count + 1
        dbg.log_raw("TRACE", string.format("Parse line %d: %s", line_count, line))

        if line:match("^worktree ") then
            local path = line:match("^worktree (.+)$")
            -- Exclude git internally managed worktrees (.git/.git/worktrees/)
            if not path:match("/%.git/%.git/worktrees/") then
                -- If we already have a complete worktree, save it first
                if current.path and current.branch then
                    dbg.log_raw("DEBUG", string.format("Save previous worktree: %s", current.path))
                    table.insert(worktrees, current)
                    dbg.log_raw("DEBUG", string.format("After save, worktrees count: %d", #worktrees))
                end
                -- Start new worktree
                dbg.log_raw("DEBUG", string.format("Found worktree path: %s", path))
                current = { path = path }  -- New table
            else
                dbg.log_raw("DEBUG", "Skip internal worktree path")
                current = {} -- Skip internal worktree
            end
        elseif line:match("^branch ") then
            local branch = line:match("^branch refs/heads/(.+)$")
            dbg.log_raw("DEBUG", string.format("Found branch: %s", branch))
            current.branch = branch
        elseif line:match("^bare") then
            dbg.log_raw("DEBUG", "Mark as bare")
            current.bare = true
        elseif line:match("^detached") then
            dbg.log_raw("DEBUG", "Mark as detached")
            current.detached = true
        elseif line == "" and current.path and current.branch then
            local current_info = string.format("path=%s, branch=%s, bare=%s",
                current.path or "nil", current.branch or "nil", tostring(current.bare or false))
            dbg.log_raw("DEBUG", string.format("Encountered empty line, current worktree: %s", current_info))
            table.insert(worktrees, current)
            dbg.log_raw("DEBUG", string.format("After add, worktrees count: %d", #worktrees))
            for i, wt in ipairs(worktrees) do
                dbg.log_raw("DEBUG", string.format("  Worktrees[%d]: %s", i, wt.path))
            end
            current = {}
            dbg.log_raw("DEBUG", "Reset current")
        end
    end

    -- Handle last entry
    local current_info = current.path and string.format("path=%s, branch=%s, bare=%s",
        current.path or "nil", current.branch or "nil", tostring(current.bare or false)) or "empty"
    dbg.log_raw("DEBUG", string.format("Loop ended, current: %s", current_info))
    if current.path then
        dbg.log_raw("DEBUG", string.format("Complete last worktree parsing: %s", current_info))
        table.insert(worktrees, current)
        dbg.log_raw("DEBUG", string.format("Final worktrees count: %d", #worktrees))
        for i, wt in ipairs(worktrees) do
            dbg.log_raw("DEBUG", string.format("  Worktrees[%d]: %s", i, wt.path))
        end
    end

    -- Record data flow
    dbg.log_raw("INFO", string.format(
        "Data flow: git worktree list --porcelain -> parse -> %d worktrees",
        #worktrees
    ))

    -- Record final result
    if #worktrees > 0 then
        for i, wt in ipairs(worktrees) do
            dbg.log_raw("INFO", string.format(
                "Worktree[%d]: path=%s, branch=%s, bare=%s, detached=%s",
                i,
                wt.path or "nil",
                wt.branch or "nil",
                tostring(wt.bare or false),
                tostring(wt.detached or false)
            ))
        end
    else
        dbg.log_raw("WARN", "No worktrees found")
    end

    dbg.done()
    return worktrees
end

-- Check if branch exists
---@param branch string branch name
---@return boolean
function M.branch_exists(branch)
    local cmd = string.format("git show-ref --verify --quiet refs/heads/%s", vim.fn.shellescape(branch))
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

-- Check if remote branch exists
---@param branch string branch name
---@param remote? string remote name (default origin)
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

-- Create worktree
---@param path string target path
---@param branch string branch name
---@param opts? { base?: string, create_branch?: boolean }
---@return boolean success
---@return string? error_msg
function M.create_worktree(path, branch, opts)
    opts = opts or {}
    local cmd_parts = { "git", "worktree", "add" }

    -- If need to create new branch
    if opts.create_branch or not M.branch_exists(branch) then
        table.insert(cmd_parts, "-b")
        table.insert(cmd_parts, vim.fn.shellescape(branch))
    end

    table.insert(cmd_parts, vim.fn.shellescape(path))

    -- If not creating new branch, use branch name directly
    if M.branch_exists(branch) and not opts.create_branch then
        table.insert(cmd_parts, vim.fn.shellescape(branch))
    elseif opts.base then
        -- Create from specified base
        table.insert(cmd_parts, vim.fn.shellescape(opts.base))
    end

    local cmd = table.concat(cmd_parts, " ")
    log.debug("Create worktree:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

-- Delete worktree
---@param path string worktree path
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
    log.debug("Delete worktree:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

-- Cleanup worktree (remove invalid worktree records)
---@return boolean success
---@return string? error_msg
function M.prune_worktrees()
    local cmd = "git worktree prune"
    log.debug("Prune worktrees:", cmd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

-- Get worktree path by branch name
---@param branch string branch name
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

-- Validate branch name
---@param branch string branch name
---@return boolean valid
---@return string? error_msg
function M.validate_branch_name(branch)
    if not branch or branch == "" then
        return false, "Branch name cannot be empty"
    end

    -- Check illegal characters
    if branch:match("%.%.") then
        return false, "Branch name cannot contain '..'"
    end

    if branch:match("^/") or branch:match("/$") then
        return false, "Branch name cannot start or end with '/'"
    end

    if branch:match("^%-") then
        return false, "Branch name cannot start with '-'"
    end

    -- Validate using git check-ref-format
    local cmd = string.format(
        "git check-ref-format --branch %s 2>/dev/null",
        vim.fn.shellescape(branch)
    )
    vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        return false, "Invalid branch name format"
    end

    return true
end

-- Get remote branches list
---@param remote? string remote name (default origin)
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
        -- Remove origin/ prefix
        local branch = line:match("^" .. remote .. "/(.+)$")
        if branch and branch ~= "HEAD" then
            table.insert(branches, branch)
        end
    end

    return branches
end

-- Get local branches list
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
