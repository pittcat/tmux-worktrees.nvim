-- 文件同步模块
-- 负责同步 .gitignore 中的文件到新 worktree

local log = require("worktree-tmux.log")

local M = {}

--- 解析 .gitignore 文件
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
        -- 忽略空行和注释
        line = line:gsub("^%s+", ""):gsub("%s+$", "") -- trim
        if line ~= "" and not line:match("^#") then
            -- 忽略否定模式（以 ! 开头）
            if not line:match("^!") then
                table.insert(patterns, line)
            end
        end
    end

    file:close()
    return patterns
end

--- 检查路径是否存在
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

--- 同步单个 pattern 对应的文件/目录
---@param source_base string 源目录
---@param target_base string 目标目录
---@param pattern string gitignore pattern
---@return boolean success
---@return string? error_msg
local function sync_pattern(source_base, target_base, pattern)
    -- 处理 pattern（移除开头的 /）
    local clean_pattern = pattern:gsub("^/", "")

    -- 处理通配符目录（如 **/node_modules）
    if clean_pattern:match("^%*%*/") then
        -- 使用 find 查找所有匹配的目录/文件
        local search_pattern = clean_pattern:gsub("^%*%*/", "")
        local cmd = string.format(
            "find %s -name %s -type d 2>/dev/null",
            vim.fn.shellescape(source_base),
            vim.fn.shellescape(search_pattern)
        )
        local output = vim.fn.system(cmd)

        if vim.v.shell_error == 0 then
            for source_path in output:gmatch("[^\r\n]+") do
                -- 计算相对路径
                local relative = source_path:sub(#source_base + 2)
                local target_path = target_base .. "/" .. relative

                -- 确保父目录存在
                local parent = vim.fn.fnamemodify(target_path, ":h")
                vim.fn.mkdir(parent, "p")

                -- 使用 rsync 同步
                local rsync_cmd = string.format(
                    "rsync -a --exclude='.git' %s/ %s/",
                    vim.fn.shellescape(source_path),
                    vim.fn.shellescape(target_path)
                )
                vim.fn.system(rsync_cmd)

                if vim.v.shell_error ~= 0 then
                    log.warn("同步失败:", relative)
                else
                    log.debug("同步成功:", relative)
                end
            end
        end
        return true
    end

    -- 处理普通 pattern
    local source_path = source_base .. "/" .. clean_pattern
    local target_path = target_base .. "/" .. clean_pattern

    local is_dir, exists = check_path(source_path)
    if not exists then
        log.debug("源不存在，跳过:", clean_pattern)
        return true
    end

    -- 确保父目录存在
    local parent = vim.fn.fnamemodify(target_path, ":h")
    vim.fn.mkdir(parent, "p")

    -- 构建 rsync 命令
    local rsync_cmd
    if is_dir then
        -- 目录同步
        rsync_cmd = string.format(
            "rsync -a --exclude='.git' %s/ %s/",
            vim.fn.shellescape(source_path),
            vim.fn.shellescape(target_path)
        )
    else
        -- 文件同步
        rsync_cmd = string.format(
            "rsync -a %s %s",
            vim.fn.shellescape(source_path),
            vim.fn.shellescape(target_path)
        )
    end

    log.debug("执行 rsync:", rsync_cmd)
    local output = vim.fn.system(rsync_cmd)

    if vim.v.shell_error ~= 0 then
        return false, output
    end

    return true
end

--- 同步 ignored 文件到新 worktree
---@param source string 源目录（当前仓库）
---@param target string 目标目录（新 worktree）
---@param opts? { patterns?: string[], on_progress?: fun(pattern: string, current: number, total: number) }
---@return boolean success
---@return number synced_count
function M.sync_ignored_files(source, target, opts)
    opts = opts or {}

    -- 获取 patterns
    local patterns = opts.patterns
    if not patterns then
        local gitignore_path = source .. "/.gitignore"
        patterns = M.parse_gitignore(gitignore_path)
    end

    if #patterns == 0 then
        log.info("没有需要同步的文件")
        return true, 0
    end

    log.info("开始同步 ignore 文件，共", #patterns, "个 patterns")

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
            log.warn("同步失败:", pattern, err or "")
        end
    end

    if failed > 0 then
        log.warn("同步完成，成功:", synced, "失败:", failed)
    else
        log.info("同步完成，共", synced, "个 patterns")
    end

    return failed == 0, synced
end

--- 获取需要同步的文件列表（用于预览）
---@param source string 源目录
---@return table[] 文件列表 { pattern, path, type, size }
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

--- 计算同步所需的磁盘空间（估算）
---@param source string 源目录
---@return number bytes
function M.estimate_sync_size(source)
    local files = M.get_sync_preview(source)
    local total = 0

    for _, file in ipairs(files) do
        if file.type == "directory" then
            -- 使用 du 估算目录大小
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
