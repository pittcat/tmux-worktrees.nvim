-- File sync module
-- Syncs .gitignore patterns to new worktrees

local log = require("worktree-tmux.log")

local M = {}

-- Parse .gitignore file
---@param gitignore_path string
---@return string[] patterns
function M.parse_gitignore(gitignore_path)
    if vim.fn.filereadable(gitignore_path) == 0 then
        return {}
    end

    local patterns = {}
    local file = io.open(gitignore_path, "r")
    if not file then
        return {}
    end

    for line in file:lines() do
        -- Skip empty lines and comments
        line = line:gsub("^%s+", ""):gsub("%s+$", "") -- trim
        if line ~= "" and not line:match("^#") then
            -- Skip negation patterns (starting with !)
            if not line:match("^!") then
                table.insert(patterns, line)
            end
        end
    end

    file:close()
    return patterns
end

-- Check path exists
---@param path string
---@return boolean is_dir
---@return boolean exists
local function check_path(path)
    local stat = vim.loop.fs_stat(path)
    if not stat then
        return false, false
    end
    return stat.type == "directory", true
end

-- Sync single pattern
---@param source_base string source directory
---@param target_base string target directory
---@param pattern string gitignore pattern
---@return boolean success
---@return string? error_msg
local function sync_pattern(source_base, target_base, pattern)
    -- Handle pattern (remove leading /)
    local clean_pattern = pattern:gsub("^/", "")

    -- Handle wildcard directories (e.g., **/node_modules)
    if clean_pattern:match("^%*%*/") then
        -- Use find to find all matching dirs/files
        local search_pattern = clean_pattern:gsub("^%*%*/", "")
        local cmd = string.format(
            "find %s -name %s -type d 2>/dev/null",
            vim.fn.shellescape(source_base),
            vim.fn.shellescape(search_pattern)
        )
        local output = vim.fn.system(cmd)

        if vim.v.shell_error == 0 then
            for source_path in output:gmatch("[^\r\n]+") do
                -- Calculate relative path
                local relative = source_path:sub(#source_base + 2)
                local target_path = target_base .. "/" .. relative

                -- Ensure parent dir exists
                local parent = vim.fn.fnamemodify(target_path, ":h")
                vim.fn.mkdir(parent, "p")

                -- Use rsync to sync
                local rsync_cmd = string.format(
                    "rsync -a --exclude='.git' %s/ %s/",
                    vim.fn.shellescape(source_path),
                    vim.fn.shellescape(target_path)
                )
                vim.fn.system(rsync_cmd)

                if vim.v.shell_error ~= 0 then
                    log.warn("Sync failed:", relative)
                else
                    log.debug("Sync success:", relative)
                end
            end
        end
        return true
    end

    -- Handle normal pattern
    local source_path = source_base .. "/" .. clean_pattern
    local target_path = target_base .. "/" .. clean_pattern

    local is_dir, exists = check_path(source_path)
    if not exists then
        log.debug("Source not exists, skip:", clean_pattern)
        return true
    end

    -- Ensure parent dir exists
    local parent = vim.fn.fnamemodify(target_path, ":h")
    vim.fn.mkdir(parent, "p")

    -- Build rsync command
    local rsync_cmd
    if is_dir then
        -- Directory sync
        rsync_cmd = string.format(
            "rsync -a --exclude='.git' %s/ %s/",
            vim.fn.shellescape(source_path),
            vim.fn.shellescape(target_path)
        )
    else
        -- File sync
        rsync_cmd = string.format(
            "rsync -a %s %s",
            vim.fn.shellescape(source_path),
            vim.fn.shellescape(target_path)
        )
    end

    log.debug("Execute rsync:", rsync_cmd)
    local output = vim.fn.system(rsync_cmd)

    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

-- Sync ignored files to new worktree (async version)
---@param source string source directory (current repo)
---@param target string target directory (new worktree)
---@param opts? { patterns?: string[], on_progress?: fun(pattern: string, current: number, total: number), on_sync_done?: fun(sync_ok: boolean, synced_count: number) }
function M.sync_ignored_files_async(source, target, opts)
    opts = opts or {}

    -- Get patterns
    local patterns = opts.patterns
    if not patterns then
        local gitignore_path = source .. "/.gitignore"
        patterns = M.parse_gitignore(gitignore_path)
    end

    if #patterns == 0 then
        log.info("No files to sync")
        if opts.on_sync_done then
            opts.on_sync_done(true, 0)
        end
        return
    end

    log.info("Start syncing ignore files, total", #patterns, "patterns")

    local synced = 0
    local failed = 0
    local async = require("worktree-tmux.async")
    local remaining = #patterns

    local function process_next(index)
        if index > #patterns then
            -- All done
            local success = failed == 0
            if failed > 0 then
                log.warn("Sync complete, success:", synced, "failed:", failed)
            else
                log.info("Sync complete, total", synced, "patterns")
            end
            if opts.on_sync_done then
                opts.on_sync_done(success, synced)
            end
            return
        end

        local pattern = patterns[index]
        if opts.on_progress then
            opts.on_progress(pattern, index, #patterns)
        end

        local clean_pattern = pattern:gsub("^/", "")
        local source_path = source .. "/" .. clean_pattern
        local target_path = target .. "/" .. clean_pattern

        local stat = vim.loop.fs_stat(source_path)
        if not stat then
            -- Source not exists, skip
            process_next(index + 1)
            return
        end

        -- Build rsync command
        local is_dir = stat.type == "directory"
        local rsync_cmd
        if is_dir then
            rsync_cmd = string.format(
                "rsync -a --exclude='.git' %s/ %s/",
                vim.fn.shellescape(source_path),
                vim.fn.shellescape(target_path)
            )
        else
            rsync_cmd = string.format(
                "rsync -a %s %s",
                vim.fn.shellescape(source_path),
                vim.fn.shellescape(target_path)
            )
        end

        log.debug("Execute rsync:", rsync_cmd)

        -- Execute rsync async
        async.run({
            cmd = "sh",
            args = { "-c", rsync_cmd },
            on_success = function()
                synced = synced + 1
                process_next(index + 1)
            end,
            on_error = function()
                failed = failed + 1
                log.warn("Sync failed:", pattern)
                process_next(index + 1)
            end,
        })
    end

    process_next(1)
end

-- Sync ignored files to new worktree (sync version, kept for compatibility)
---@param source string source directory (current repo)
---@param target string target directory (new worktree)
---@param opts? { patterns?: string[], on_progress?: fun(pattern: string, current: number, total: number), on_sync_done?: fun(sync_ok: boolean, synced_count: number) }
---@return boolean success
---@return number synced_count
function M.sync_ignored_files(source, target, opts)
    opts = opts or {}

    -- Get patterns
    local patterns = opts.patterns
    if not patterns then
        local gitignore_path = source .. "/.gitignore"
        patterns = M.parse_gitignore(gitignore_path)
    end

    if #patterns == 0 then
        log.info("No files to sync")
        if opts.on_sync_done then
            opts.on_sync_done(true, 0)
        end
        return true, 0
    end

    log.info("Start syncing ignore files, total", #patterns, "patterns")

    local synced = 0
    local failed = 0

    for i, pattern in ipairs(patterns) do
        if opts.on_progress then
            opts.on_progress(pattern, i, #patterns)
        end

        local success, err = sync_pattern(source, target, pattern)
        if success then
            synced = synced + 1
        else
            failed = failed + 1
            log.warn("Sync failed:", pattern, err or "")
        end
    end

    if failed > 0 then
        log.warn("Sync complete, success:", synced, "failed:", failed)
    else
        log.info("Sync complete, total", synced, "patterns")
    end

    if opts.on_sync_done then
        opts.on_sync_done(failed == 0, synced)
    end

    return failed == 0, synced
end

-- Get file list to sync (for preview)
---@param source string source directory
---@return table[] file list { pattern, path, type, size }
function M.get_sync_preview(source)
    local gitignore_path = source .. "/.gitignore"
    local patterns = M.parse_gitignore(gitignore_path)

    local files = {}
    for _, pattern in ipairs(patterns) do
        local clean_pattern = pattern:gsub("^/", "")
        local path = source .. "/" .. clean_pattern

        local stat = vim.loop.fs_stat(path)
        if stat then
            table.insert(files, {
                pattern = pattern,
                path = path,
                type = stat.type,
                size = stat.size,
            })
        end
    end

    return files
end

-- Calculate disk space needed for sync (estimate)
---@param source string source directory
---@return number bytes
function M.estimate_sync_size(source)
    local files = M.get_sync_preview(source)
    local total = 0

    for _, file in ipairs(files) do
        if file.type == "directory" then
            -- Use du to estimate dir size
            local cmd = string.format("du -sb %s 2>/dev/null | cut -f1", vim.fn.shellescape(file.path))
            local output = vim.fn.system(cmd)
            local size = tonumber(output) or 0
            total = total + size
        else
            total = total + (file.size or 0)
        end
    end

    return total
end

return M
