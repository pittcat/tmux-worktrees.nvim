-- Core business logic module
-- Coordinates git, tmux, sync modules for create, delete, sync operations

local config = require("worktree-tmux.config")
local git = require("worktree-tmux.git")
local tmux = require("worktree-tmux.tmux")
local sync = require("worktree-tmux.sync")
local log = require("worktree-tmux.log")

local M = {}

--- Pre-check
---@return boolean ok
---@return string? error_msg
local function precondition_check()
    -- Check tmux environment
    if not tmux.in_tmux() then
        return false, "This plugin must be used in tmux environment"
    end

    -- Check git repository
    if not git.in_git_repo() then
        return false, "Current directory is not a git repository"
    end

    return true
end

--- Ensure worktrees session exists
---@return boolean success
---@return string? error_msg
---@return boolean is_new whether session was newly created
local function ensure_session()
    local session_name = config.get("session_name")

    if tmux.session_exists(session_name) then
        return true, nil, false
    end

    log.info("Create tmux session:", session_name)
    local ok, err = tmux.create_session(session_name)
    return ok, err, true
end

--- Resolve worktree path
---@param branch string branch name
---@return string path
local function resolve_worktree_path(branch)
    local base_dir = config.get_worktree_base_dir()
    local repo_name = git.get_repo_name()

    -- Replace / in branch name with -
    local safe_branch = branch:gsub("/", "-")

    return string.format("%s/%s-%s", base_dir, repo_name, safe_branch)
end

--- Create worktree + tmux window
---@param branch string branch name
---@param base? string base branch (default: current branch)
---@return boolean success
---@return string? error_msg
function M.create_worktree_window(branch, base)
    local dbg = log.get_debug()
    dbg.begin("create_worktree_window")

    -- Pre-check
    local ok, err = precondition_check()
    if not ok then
        dbg.done()
        return false, err
    end

    -- Validate branch name
    local valid, valid_err = git.validate_branch_name(branch)
    if not valid then
        dbg.done()
        return false, valid_err
    end

    -- Prepare variables
    local repo_name = git.get_repo_name()
    local session_name = config.get("session_name")
    local window_name = config.format_window_name(repo_name, branch, base)
    local worktree_path = resolve_worktree_path(branch)

    log.info("Create worktree:", branch, "->", worktree_path)
    dbg.checkpoint("variables_prepared", {
        repo = repo_name,
        branch = branch,
        window = window_name,
        path = worktree_path,
    })

    -- Ensure session exists
    ok, err = ensure_session()
    if not ok then
        dbg.done()
        return false, "Failed to create session: " .. (err or "")
    end

    -- Check if window already exists
    if tmux.window_exists(session_name, window_name) then
        local strategy = config.get("on_duplicate_window")
        log.debug("Window exists, strategy:", strategy)

        if strategy == "skip" then
            dbg.done()
            return false, "Window already exists: " .. window_name
        elseif strategy == "overwrite" then
            local del_ok, del_err = tmux.delete_window(session_name, window_name)
            if not del_ok then
                dbg.done()
                return false, "Failed to delete old window: " .. (del_err or "")
            end
        else
            -- "ask" strategy is handled by UI layer, return special error here
            dbg.done()
            return false, "WINDOW_EXISTS:" .. window_name
        end
    end

    -- Create worktree
    local source_dir = git.get_repo_root()
    local create_ok, create_err = git.create_worktree(worktree_path, branch, { base = base })
    if not create_ok then
        dbg.done()
        return false, "Failed to create worktree: " .. (create_err or "")
    end
    dbg.checkpoint("worktree_created")

    -- Sync ignore files
    if config.get("sync_ignored_files") then
        log.info("Syncing ignore files...")
        local sync_ok, synced = sync.sync_ignored_files(source_dir, worktree_path)
        if not sync_ok then
            log.warn("Some files sync failed, but worktree was created")
        else
            log.info("Sync complete,", synced, "patterns")
        end
        dbg.checkpoint("files_synced", { count = synced })
    end

    -- Create tmux window
    local win_ok, win_err = tmux.create_window({
        session = session_name,
        name = window_name,
        cwd = worktree_path,
        cmd = config.get("window_command"),
    })

    if not win_ok then
        -- Rollback: delete newly created worktree
        log.error("Failed to create window, rolling back worktree")
        git.delete_worktree(worktree_path, { force = true })
        dbg.done()
        return false, "Failed to create tmux window: " .. (win_err or "")
    end

    dbg.checkpoint("window_created")
    dbg.done()

    log.info("Created successfully:", window_name)
    return true
end

--- Create worktree + tmux window (async background execution)
---@param branch string branch name
---@param base? string base branch (default: current branch)
---@param callbacks { on_success?: fun(), on_error?: fun(msg: string) }
function M.create_worktree_window_async(branch, base, callbacks)
    local notify = require("worktree-tmux.notify")

    -- Pre-check
    local tmux = require("worktree-tmux.tmux")
    local async = require("worktree-tmux.async")

    local ok, err = precondition_check()
    if not ok then
        if callbacks.on_error then
            callbacks.on_error(err)
        end
        return
    end

    local valid, valid_err = git.validate_branch_name(branch)
    if not valid then
        if callbacks.on_error then
            callbacks.on_error(valid_err)
        end
        return
    end

    -- Prepare variables
    local repo_name = git.get_repo_name()
    local session_name = config.get("session_name")
    local window_name = config.format_window_name(repo_name, branch, base)
    local worktree_path = resolve_worktree_path(branch)
    local source_dir = git.get_repo_root()

    notify.info(string.format("Creating worktree: %s", branch))

    -- Ensure session exists
    ok, err = ensure_session()
    if not ok then
        notify.error("Failed to create session: " .. (err or ""))
        if callbacks.on_error then
            callbacks.on_error("Failed to create session")
        end
        return
    end

    -- Check if window already exists
    if tmux.window_exists(session_name, window_name) then
        local strategy = config.get("on_duplicate_window")
        if strategy == "skip" then
            notify.warn("Window already exists: " .. window_name)
            if callbacks.on_error then
                callbacks.on_error("Window already exists")
            end
            return
        elseif strategy == "overwrite" then
            tmux.delete_window(session_name, window_name)
        else
            -- "ask" strategy
            notify.warn("Window already exists: " .. window_name)
            if callbacks.on_error then
                callbacks.on_error("Window already exists")
            end
            return
        end
    end

    -- Build git worktree command args (keep sync with sync version)
    local git_args = { "worktree", "add" }

    -- Check if branch exists
    local branch_exists = git.branch_exists(branch)
    if not branch_exists then
        -- Need to create new branch
        table.insert(git_args, "-b")
        table.insert(git_args, branch)
        table.insert(git_args, worktree_path)
        -- If base specified, create from base
        if base then
            table.insert(git_args, base)
        end
    else
        -- Branch exists, create worktree from existing branch
        table.insert(git_args, worktree_path)
        table.insert(git_args, branch)
    end

    -- Async create worktree
    async.git(git_args, {
        on_success = function()
            -- worktree created successfully
            notify.info(string.format("Starting file sync..."))

            -- Async sync ignore files
            sync.sync_ignored_files_async(source_dir, worktree_path, {
                on_sync_done = function(sync_ok, synced_count)
                    if sync_ok then
                        notify.info(string.format("Files synced (%d), creating window...", synced_count or 0))
                    else
                        notify.warn("Some files sync failed, continuing to create window...")
                    end

                    -- Create tmux window
                    async.run({
                        cmd = "tmux",
                        args = {
                            "new-window",
                            "-t", session_name,
                            "-n", window_name,
                            "-c", worktree_path,
                        },
                        on_success = function()
                            -- Success
                            notify.success(string.format("Created: %s", window_name))
                            if callbacks.on_success then
                                callbacks.on_success()
                            end
                        end,
                        on_error = function(_, code)
                            -- Failed, rollback worktree
                            git.delete_worktree(worktree_path, { force = true })
                            notify.error(string.format("Create window failed, rolled back (error code: %d)", code))
                            if callbacks.on_error then
                                callbacks.on_error("Create window failed")
                            end
                        end,
                    })
                end,
            })
        end,
        on_error = function(stderr, code)
            notify.error(string.format("Create worktree failed (error code: %d)", code))
            if callbacks.on_error then
                callbacks.on_error("Create worktree failed")
            end
        end,
    })
end

--- Delete worktree + tmux window
---@param worktree_path? string worktree path (if empty, use selector)
---@return boolean success
---@return string? error_msg
function M.delete_worktree_window(worktree_path)
    local dbg = log.get_debug()
    dbg.begin("delete_worktree_window")

    -- Pre-check
    local ok, err = precondition_check()
    if not ok then
        dbg.done()
        return false, err
    end

    -- If no path specified, need UI to provide selection
    if not worktree_path then
        dbg.done()
        return false, "NEED_SELECT_WORKTREE"
    end

    -- Get worktree info
    local worktrees = git.get_worktree_list()
    local target = nil
    for _, wt in ipairs(worktrees) do
        if wt.path == worktree_path then
            target = wt
            break
        end
    end

    if not target then
        dbg.done()
        return false, "Worktree not found: " .. worktree_path
    end

    if target.bare then
        dbg.done()
        return false, "Cannot delete main repository"
    end

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()
    local window_name = config.format_window_name(repo_name, target.branch or "unknown")

    log.info("Delete worktree:", worktree_path)

    -- Delete worktree
    local del_ok, del_err = git.delete_worktree(worktree_path)
    if not del_ok then
        dbg.done()
        return false, "Failed to delete worktree: " .. (del_err or "")
    end
    dbg.checkpoint("worktree_deleted")

    -- Ensure directory is also deleted (git worktree remove may not delete dir in old versions)
    local function delete_directory(path)
        local cmd = string.format("rm -rf %s", vim.fn.shellescape(path))
        log.debug("Delete directory:", cmd)
        vim.fn.system(cmd)
    end

    -- Check if directory still exists, force delete if so
    if vim.fn.isdirectory(worktree_path) == 1 then
        log.debug("Directory still exists, force delete:", worktree_path)
        delete_directory(worktree_path)
    end

    -- Delete corresponding tmux window
    if tmux.window_exists(session_name, window_name) then
        local win_ok, win_err = tmux.delete_window(session_name, window_name)
        if not win_ok then
            log.warn("Failed to delete window:", win_err)
        else
            dbg.checkpoint("window_deleted")
        end
    else
        log.debug("Window does not exist, skip:", window_name)
    end

    dbg.done()
    log.info("Delete success")
    return true
end

--- Sync worktrees and tmux windows
---@return WorktreeTmux.SyncResult
function M.sync_worktrees()
    local dbg = log.get_debug()
    dbg.begin("sync_worktrees")

    local result = { created = 0, skipped = 0 }

    -- Pre-check
    local ok, err = precondition_check()
    if not ok then
        log.error(err)
        dbg.done()
        return result
    end

    -- Ensure session exists
    local ok, err, is_new_session = ensure_session()
    if not ok then
        log.error("Failed to create session:", err)
        dbg.done()
        return result
    end

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()

    -- Get all worktrees
    local worktrees = git.get_worktree_list()

    -- Get all windows
    local windows = tmux.list_windows(session_name)
    local window_names = {}
    for _, win in ipairs(windows) do
        window_names[win.name] = true
    end

    log.info("Syncing worktrees...")
    dbg.data_flow(worktrees, windows, "compare")

    -- Check each worktree for corresponding window
    for _, wt in ipairs(worktrees) do
        -- Skip main/master branches (typically worked in main window)
        if wt.branch == "main" or wt.branch == "master" then
            log.debug("Skip main/master branch:", wt.branch)
            -- Not counted in any counter (notify display excludes these)
        elseif not wt.bare and wt.branch then
            local window_name = config.format_window_name(repo_name, wt.branch)

            if not window_names[window_name] then
                log.info("Create missing window:", window_name)

                local win_ok = tmux.create_window({
                    session = session_name,
                    name = window_name,
                    cwd = wt.path,
                    cmd = config.get("window_command"),
                })

                if win_ok then
                    result.created = result.created + 1
                else
                    log.warn("Failed to create window:", window_name)
                end
            else
                result.skipped = result.skipped + 1
            end
        end
    end

    -- If new session, delete auto-created window 0
    if is_new_session then
        log.debug("Delete default window 0 of new session")
        tmux.delete_window(session_name, "0")
    end

    dbg.done()
    log.info("Sync complete: created", result.created, ", skipped", result.skipped)
    return result
end

--- Get worktree list (for UI display)
---@return table[] list { path, branch, window_name, has_window }
function M.get_worktree_list()
    -- Create debug context
    local dbg = log.get_debug()
    local request_id = dbg.begin("core.get_worktree_list")

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

    -- Get git worktrees
    dbg.log_raw("INFO", "Call git.get_worktree_list() to get raw worktree list")
    local worktrees = git.get_worktree_list()
    dbg.log_raw("INFO", string.format("Got %d worktrees from git", #worktrees))

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()

    dbg.log_raw("INFO", string.format("Session: %s, Repo: %s", session_name, repo_name or "nil"))

    -- Record list from git
    for i, wt in ipairs(worktrees) do
        dbg.log_raw("DEBUG", string.format(
            "Git Worktree[%d]: path=%s, branch=%s, bare=%s",
            i,
            wt.path or "nil",
            wt.branch or "nil",
            tostring(wt.bare or false)
        ))
    end

    -- Process worktrees, add tmux window info
    dbg.log_raw("INFO", "Start checking tmux window for each worktree")
    local result = {}
    local repo_root = git.get_repo_root()

    for _, wt in ipairs(worktrees) do
        -- Exclude main repo (path equals git repo root)
        if wt.path == repo_root then
            dbg.log_raw("DEBUG", string.format("Skip main repo: %s", wt.path))
        elseif not wt.bare then
            local window_name = config.format_window_name(repo_name, wt.branch or "unknown")
            dbg.log_raw("DEBUG", string.format(
                "Process worktree: branch=%s, window_name=%s",
                wt.branch or "nil",
                window_name
            ))

            -- Check if tmux window exists
            local has_window = tmux.window_exists(session_name, window_name)
            dbg.log_raw("INFO", string.format(
                "Check window '%s' exists: %s",
                window_name,
                has_window and "yes" or "no"
            ))

            table.insert(result, {
                path = wt.path,
                branch = wt.branch,
                window_name = window_name,
                has_window = has_window,
            })
        else
            dbg.log_raw("DEBUG", string.format("Skip bare worktree: %s", wt.path or "nil"))
        end
    end

    -- Record data flow
    dbg.log_raw("INFO", string.format(
        "Data flow: git.get_worktree_list(%d) -> process -> final result(%d)",
        #worktrees,
        #result
    ))

    -- Record final result
    if #result > 0 then
        for i, wt in ipairs(result) do
            dbg.log_raw("INFO", string.format(
                "Final result[%d]: path=%s, branch=%s, window=%s, has_window=%s",
                i,
                wt.path,
                wt.branch or "nil",
                wt.window_name,
                wt.has_window and "yes" or "no"
            ))
        end
    else
        dbg.log_raw("WARN", "Final result empty, no available worktrees")
    end

    dbg.done()
    return result
end

-- Jump to worktree window
---@param window_name string window name
---@return boolean success
---@return string? error_msg
function M.jump_to_window(window_name)
    local session_name = config.get("session_name")

    -- First switch to worktrees session
    local switch_ok, switch_err = tmux.switch_session(session_name)
    if not switch_ok then
        return false, "Failed to switch session: " .. (switch_err or "")
    end

    -- Then select target window
    local select_ok, select_err = tmux.select_window(session_name, window_name)
    if not select_ok then
        return false, "Failed to select window: " .. (select_err or "")
    end

    log.info("Jump to:", window_name)
    return true
end

return M
