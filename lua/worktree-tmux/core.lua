-- 核心业务逻辑模块
-- 协调 git, tmux, sync 模块完成创建、删除、同步等操作

local config = require("worktree-tmux.config")
local git = require("worktree-tmux.git")
local tmux = require("worktree-tmux.tmux")
local sync = require("worktree-tmux.sync")
local log = require("worktree-tmux.log")

local M = {}

--- 前置检查
---@return boolean ok
---@return string? error_msg
local function precondition_check()
    -- 检查 tmux 环境
    if not tmux.in_tmux() then
        return false, "必须在 tmux 环境中使用此插件"
    end

    -- 检查 git 仓库
    if not git.in_git_repo() then
        return false, "当前目录不是 git 仓库"
    end

    return true
end

--- 确保 worktrees session 存在
---@return boolean success
---@return string? error_msg
---@return boolean is_new 是否新建的 session
local function ensure_session()
    local session_name = config.get("session_name")

    if tmux.session_exists(session_name) then
        return true, nil, false
    end

    log.info("创建 tmux session:", session_name)
    local ok, err = tmux.create_session(session_name)
    return ok, err, true
end

--- 解析 worktree 路径
---@param branch string 分支名
---@return string path
local function resolve_worktree_path(branch)
    local base_dir = config.get_worktree_base_dir()
    local repo_name = git.get_repo_name()

    -- 将分支名中的 / 替换为 -
    local safe_branch = branch:gsub("/", "-")

    return string.format("%s/%s-%s", base_dir, repo_name, safe_branch)
end

--- 创建 worktree + tmux window
---@param branch string 分支名
---@param base? string 基于哪个分支（默认当前分支）
---@return boolean success
---@return string? error_msg
function M.create_worktree_window(branch, base)
    local dbg = log.get_debug()
    dbg.begin("create_worktree_window")

    -- 前置检查
    local ok, err = precondition_check()
    if not ok then
        dbg.done()
        return false, err
    end

    -- 验证分支名
    local valid, valid_err = git.validate_branch_name(branch)
    if not valid then
        dbg.done()
        return false, valid_err
    end

    -- 准备变量
    local repo_name = git.get_repo_name()
    local session_name = config.get("session_name")
    local window_name = config.format_window_name(repo_name, branch, base)
    local worktree_path = resolve_worktree_path(branch)

    log.info("创建 worktree:", branch, "->", worktree_path)
    dbg.checkpoint("variables_prepared", {
        repo = repo_name,
        branch = branch,
        window = window_name,
        path = worktree_path,
    })

    -- 确保 session 存在
    ok, err = ensure_session()
    if not ok then
        dbg.done()
        return false, "创建 session 失败: " .. (err or "")
    end

    -- 检查 window 是否已存在
    if tmux.window_exists(session_name, window_name) then
        local strategy = config.get("on_duplicate_window")
        log.debug("window 已存在，策略:", strategy)

        if strategy == "skip" then
            dbg.done()
            return false, "Window 已存在: " .. window_name
        elseif strategy == "overwrite" then
            local del_ok, del_err = tmux.delete_window(session_name, window_name)
            if not del_ok then
                dbg.done()
                return false, "删除旧 window 失败: " .. (del_err or "")
            end
        else
            -- "ask" 策略由 UI 层处理，这里返回特殊错误
            dbg.done()
            return false, "WINDOW_EXISTS:" .. window_name
        end
    end

    -- 创建 worktree
    local source_dir = git.get_repo_root()
    local create_ok, create_err = git.create_worktree(worktree_path, branch, { base = base })
    if not create_ok then
        dbg.done()
        return false, "创建 worktree 失败: " .. (create_err or "")
    end
    dbg.checkpoint("worktree_created")

    -- 同步 ignore 文件
    if config.get("sync_ignored_files") then
        log.info("同步 ignore 文件...")
        local sync_ok, synced = sync.sync_ignored_files(source_dir, worktree_path)
        if not sync_ok then
            log.warn("部分文件同步失败，但 worktree 已创建")
        else
            log.info("同步完成，共", synced, "个 patterns")
        end
        dbg.checkpoint("files_synced", { count = synced })
    end

    -- 创建 tmux window
    local win_ok, win_err = tmux.create_window({
        session = session_name,
        name = window_name,
        cwd = worktree_path,
        cmd = config.get("window_command"),
    })

    if not win_ok then
        -- 回滚：删除刚创建的 worktree
        log.error("创建 window 失败，回滚 worktree")
        git.delete_worktree(worktree_path, { force = true })
        dbg.done()
        return false, "创建 tmux window 失败: " .. (win_err or "")
    end

    dbg.checkpoint("window_created")
    dbg.done()

    log.info("✅ 创建成功:", window_name)
    return true
end

--- 创建 worktree + tmux window（异步后台执行）
---@param branch string 分支名
---@param base? string 基于哪个分支（默认当前分支）
---@param callbacks { on_success?: fun(), on_error?: fun(msg: string) }
function M.create_worktree_window_async(branch, base, callbacks)
    local notify = require("worktree-tmux.notify")

    -- 前置检查
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

    -- 准备变量
    local repo_name = git.get_repo_name()
    local session_name = config.get("session_name")
    local window_name = config.format_window_name(repo_name, branch, base)
    local worktree_path = resolve_worktree_path(branch)
    local source_dir = git.get_repo_root()

    notify.info(string.format("🚀 后台创建 worktree: %s", branch))

    -- 确保 session 存在
    ok, err = ensure_session()
    if not ok then
        notify.error("创建 session 失败: " .. (err or ""))
        if callbacks.on_error then
            callbacks.on_error("创建 session 失败")
        end
        return
    end

    -- 检查 window 是否已存在
    if tmux.window_exists(session_name, window_name) then
        local strategy = config.get("on_duplicate_window")
        if strategy == "skip" then
            notify.warn("Window 已存在: " .. window_name)
            if callbacks.on_error then
                callbacks.on_error("Window 已存在")
            end
            return
        elseif strategy == "overwrite" then
            tmux.delete_window(session_name, window_name)
        else
            -- "ask" 策略
            notify.warn("Window 已存在: " .. window_name)
            if callbacks.on_error then
                callbacks.on_error("Window 已存在")
            end
            return
        end
    end

    -- 构建 git worktree 命令参数（与同步版本保持一致）
    local git_args = { "worktree", "add" }

    -- 检查分支是否已存在
    local branch_exists = git.branch_exists(branch)
    if not branch_exists then
        -- 需要创建新分支
        table.insert(git_args, "-b")
        table.insert(git_args, branch)
        table.insert(git_args, worktree_path)
        -- 如果指定了 base，基于 base 创建
        if base then
            table.insert(git_args, base)
        end
    else
        -- 分支已存在，直接从该分支创建 worktree
        table.insert(git_args, worktree_path)
        table.insert(git_args, branch)
    end

    -- 异步创建 worktree
    async.git(git_args, {
        on_success = function()
            -- worktree 创建成功
            notify.info(string.format("🚀 开始同步文件..."))

            -- 异步同步 ignore 文件
            sync.sync_ignored_files_async(source_dir, worktree_path, {
                on_sync_done = function(sync_ok, synced_count)
                    if sync_ok then
                        notify.info(string.format("📦 文件同步完成 (%d)，创建 Window...", synced_count or 0))
                    else
                        notify.warn("部分文件同步失败，继续创建 Window...")
                    end

                    -- 创建 tmux window
                    async.run({
                        cmd = "tmux",
                        args = {
                            "new-window",
                            "-t", session_name,
                            "-n", window_name,
                            "-c", worktree_path,
                        },
                        on_success = function()
                            -- 成功
                            notify.success(string.format("✅ 创建成功: %s", window_name))
                            if callbacks.on_success then
                                callbacks.on_success()
                            end
                        end,
                        on_error = function(_, code)
                            -- 失败，回滚 worktree
                            git.delete_worktree(worktree_path, { force = true })
                            notify.error(string.format("创建 Window 失败，已回滚 (错误码: %d)", code))
                            if callbacks.on_error then
                                callbacks.on_error("创建 Window 失败")
                            end
                        end,
                    })
                end,
            })
        end,
        on_error = function(stderr, code)
            notify.error(string.format("创建 worktree 失败 (错误码: %d)", code))
            if callbacks.on_error then
                callbacks.on_error("创建 worktree 失败")
            end
        end,
    })
end

--- 删除 worktree + tmux window
---@param worktree_path? string worktree 路径（如果为空，使用当前目录或选择器）
---@return boolean success
---@return string? error_msg
function M.delete_worktree_window(worktree_path)
    local dbg = log.get_debug()
    dbg.begin("delete_worktree_window")

    -- 前置检查
    local ok, err = precondition_check()
    if not ok then
        dbg.done()
        return false, err
    end

    -- 如果没有指定路径，需要 UI 层提供选择
    if not worktree_path then
        dbg.done()
        return false, "NEED_SELECT_WORKTREE"
    end

    -- 获取 worktree 信息
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
        return false, "未找到 worktree: " .. worktree_path
    end

    if target.bare then
        dbg.done()
        return false, "不能删除主仓库"
    end

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()
    local window_name = config.format_window_name(repo_name, target.branch or "unknown")

    log.info("删除 worktree:", worktree_path)

    -- 删除 worktree
    local del_ok, del_err = git.delete_worktree(worktree_path)
    if not del_ok then
        dbg.done()
        return false, "删除 worktree 失败: " .. (del_err or "")
    end
    dbg.checkpoint("worktree_deleted")

    -- 确保目录也被删除（git worktree remove 在旧版本可能不删除目录）
    local function delete_directory(path)
        local cmd = string.format("rm -rf %s", vim.fn.shellescape(path))
        log.debug("删除目录:", cmd)
        vim.fn.system(cmd)
    end

    -- 检查目录是否还存在，如果存在则强制删除
    if vim.fn.isdirectory(worktree_path) == 1 then
        log.debug("目录仍存在，强制删除:", worktree_path)
        delete_directory(worktree_path)
    end

    -- 删除对应的 tmux window
    if tmux.window_exists(session_name, window_name) then
        local win_ok, win_err = tmux.delete_window(session_name, window_name)
        if not win_ok then
            log.warn("删除 window 失败:", win_err)
        else
            dbg.checkpoint("window_deleted")
        end
    else
        log.debug("window 不存在，跳过:", window_name)
    end

    dbg.done()
    log.info("✅ 删除成功")
    return true
end

--- 同步 worktrees 和 tmux windows
---@return WorktreeTmux.SyncResult
function M.sync_worktrees()
    local dbg = log.get_debug()
    dbg.begin("sync_worktrees")

    local result = { created = 0, skipped = 0 }

    -- 前置检查
    local ok, err = precondition_check()
    if not ok then
        log.error(err)
        dbg.done()
        return result
    end

    -- 确保 session 存在
    local ok, err, is_new_session = ensure_session()
    if not ok then
        log.error("创建 session 失败:", err)
        dbg.done()
        return result
    end

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()

    -- 获取所有 worktrees
    local worktrees = git.get_worktree_list()

    -- 获取所有 windows
    local windows = tmux.list_windows(session_name)
    local window_names = {}
    for _, win in ipairs(windows) do
        window_names[win.name] = true
    end

    log.info("同步 worktrees...")
    dbg.data_flow(worktrees, windows, "比较")

    -- 为每个 worktree 检查是否有对应的 window
    for _, wt in ipairs(worktrees) do
        -- 跳过 main/master 分支（这些分支通常在主窗口中工作）
        if wt.branch == "main" or wt.branch == "master" then
            log.debug("跳过 main/master 分支:", wt.branch)
            -- 不计入任何计数器（notify 中显示的数量不包含这些）
        elseif not wt.bare and wt.branch then
            local window_name = config.format_window_name(repo_name, wt.branch)

            if not window_names[window_name] then
                log.info("创建缺失的 window:", window_name)

                local win_ok = tmux.create_window({
                    session = session_name,
                    name = window_name,
                    cwd = wt.path,
                    cmd = config.get("window_command"),
                })

                if win_ok then
                    result.created = result.created + 1
                else
                    log.warn("创建 window 失败:", window_name)
                end
            else
                result.skipped = result.skipped + 1
            end
        end
    end

    -- 如果是新建的 session，删除自动创建的 window 0
    if is_new_session then
        log.debug("删除新建 session 的默认 window 0")
        tmux.delete_window(session_name, "0")
    end

    dbg.done()
    log.info("同步完成: 创建", result.created, "个，跳过", result.skipped, "个")
    return result
end

--- 获取 worktree 列表（用于 UI 展示）
---@return table[] 列表 { path, branch, window_name, has_window }
function M.get_worktree_list()
    -- 创建调试上下文
    local dbg = log.get_debug()
    local request_id = dbg.begin("core.get_worktree_list")

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

    -- 获取 git worktrees
    dbg.log_raw("INFO", "调用 git.get_worktree_list() 获取原始 worktree 列表")
    local worktrees = git.get_worktree_list()
    dbg.log_raw("INFO", string.format("从 git 获取到 %d 个 worktrees", #worktrees))

    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()

    dbg.log_raw("INFO", string.format("Session: %s, Repo: %s", session_name, repo_name or "nil"))

    -- 记录从 git 获取的列表
    for i, wt in ipairs(worktrees) do
        dbg.log_raw("DEBUG", string.format(
            "Git Worktree[%d]: 路径=%s, 分支=%s, bare=%s",
            i,
            wt.path or "nil",
            wt.branch or "nil",
            tostring(wt.bare or false)
        ))
    end

    -- 处理 worktrees，添加 tmux window 信息
    dbg.log_raw("INFO", "开始检查每个 worktree 对应的 tmux window")
    local result = {}
    local repo_root = git.get_repo_root()

    for _, wt in ipairs(worktrees) do
        -- 排除主仓库（路径等于 git 仓库根目录的）
        if wt.path == repo_root then
            dbg.log_raw("DEBUG", string.format("跳过主仓库: %s", wt.path))
        elseif not wt.bare then
            local window_name = config.format_window_name(repo_name, wt.branch or "unknown")
            dbg.log_raw("DEBUG", string.format(
                "处理 worktree: 分支=%s, window_name=%s",
                wt.branch or "nil",
                window_name
            ))

            -- 检查 tmux window 是否存在
            local has_window = tmux.window_exists(session_name, window_name)
            dbg.log_raw("INFO", string.format(
                "检查 window '%s' 是否存在: %s",
                window_name,
                has_window and "✓ 存在" or "✗ 不存在"
            ))

            table.insert(result, {
                path = wt.path,
                branch = wt.branch,
                window_name = window_name,
                has_window = has_window,
            })
        else
            dbg.log_raw("DEBUG", string.format("跳过 bare worktree: %s", wt.path or "nil"))
        end
    end

    -- 记录数据流
    dbg.log_raw("INFO", string.format(
        "数据流: git.get_worktree_list(%d) → 处理 → 最终结果(%d)",
        #worktrees,
        #result
    ))

    -- 记录最终结果
    if #result > 0 then
        for i, wt in ipairs(result) do
            dbg.log_raw("INFO", string.format(
                "最终结果[%d]: 路径=%s, 分支=%s, window=%s, has_window=%s",
                i,
                wt.path,
                wt.branch or "nil",
                wt.window_name,
                wt.has_window and "✓" or "✗"
            ))
        end
    else
        dbg.log_raw("WARN", "最终结果为空，没有可用的 worktrees")
    end

    dbg.done()
    return result
end

--- 跳转到 worktree window
---@param window_name string window 名称
---@return boolean success
---@return string? error_msg
function M.jump_to_window(window_name)
    local session_name = config.get("session_name")

    -- 先切换到 worktrees session
    local switch_ok, switch_err = tmux.switch_session(session_name)
    if not switch_ok then
        return false, "切换 session 失败: " .. (switch_err or "")
    end

    -- 然后选择目标 window
    local select_ok, select_err = tmux.select_window(session_name, window_name)
    if not select_ok then
        return false, "选择 window 失败: " .. (select_err or "")
    end

    log.info("跳转到:", window_name)
    return true
end

return M
