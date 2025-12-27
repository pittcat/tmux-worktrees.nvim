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
local function ensure_session()
    local session_name = config.get("session_name")

    if tmux.session_exists(session_name) then
        return true
    end

    log.info("创建 tmux session:", session_name)
    return tmux.create_session(session_name)
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
    ok, err = ensure_session()
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
        if not wt.bare and wt.branch then
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

    dbg.done()
    log.info("同步完成: 创建", result.created, "个，跳过", result.skipped, "个")
    return result
end

--- 获取 worktree 列表（用于 UI 展示）
---@return table[] 列表 { path, branch, window_name, has_window }
function M.get_worktree_list()
    local worktrees = git.get_worktree_list()
    local session_name = config.get("session_name")
    local repo_name = git.get_repo_name()

    local result = {}
    for _, wt in ipairs(worktrees) do
        if not wt.bare then
            local window_name = config.format_window_name(repo_name, wt.branch or "unknown")
            table.insert(result, {
                path = wt.path,
                branch = wt.branch,
                window_name = window_name,
                has_window = tmux.window_exists(session_name, window_name),
            })
        end
    end

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
