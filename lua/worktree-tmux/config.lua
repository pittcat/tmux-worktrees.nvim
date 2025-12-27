-- 配置管理模块
-- 负责配置的深度合并、验证和访问

---@class WorktreeTmux.ConfigModule
---@field options WorktreeTmux.Config
local M = {}

---@type WorktreeTmux.Config
local defaults = {
    -- Tmux session 名称（固定）
    session_name = "worktrees",

    -- Worktree 基础目录
    worktree_base_dir = "~/worktrees",

    -- Window 启动命令（nil = 空 shell）
    window_command = nil,

    -- Window 命名模板：{repo}, {branch}, {base}
    window_name_template = "wt-{repo}-{branch}",

    -- 是否同步 ignore 文件
    sync_ignored_files = true,

    -- 重名 window 处理策略
    on_duplicate_window = "ask",

    -- 是否异步执行（后台运行，不阻塞 Neovim）
    async = true,

    -- UI 配置
    ui = {
        input = {
            border = "rounded",
            width = 60,
            position = "50%",
        },
        confirm = {
            border = "rounded",
            width = 40,
        },
    },

    -- fzf-lua 配置
    fzf_opts = {
        prompt = "Worktree Jump> ",
        winopts = {
            height = 0.4,
            width = 0.6,
            row = 0.5,
            col = 0.5,
        },
    },

    -- 通知配置
    notify = {
        use_snacks = true,
        timeout = 3000,
    },

    -- 日志配置
    log = {
        level = "info",
        use_console = true,
        use_file = true,
        debug_mode = false,
        debug_file = nil,
        highlights = true,
    },
}

---@type WorktreeTmux.Config
M.options = vim.deepcopy(defaults)

--- 深度合并配置
---@param user_config? table 用户配置
---@return WorktreeTmux.Config
function M.setup(user_config)
    user_config = user_config or {}

    -- 深度合并配置
    M.options = vim.tbl_deep_extend("force", defaults, user_config)

    -- 验证配置
    M.validate()

    -- 应用环境变量覆盖
    M.apply_env_overrides()

    return M.options
end

--- 验证配置
function M.validate()
    local opts = M.options

    -- 验证 session_name
    if type(opts.session_name) ~= "string" or opts.session_name == "" then
        vim.notify(
            "[worktree-tmux] session_name 必须是非空字符串，使用默认值",
            vim.log.levels.WARN
        )
        opts.session_name = defaults.session_name
    end

    -- 验证 worktree_base_dir
    if type(opts.worktree_base_dir) ~= "string" and type(opts.worktree_base_dir) ~= "function" then
        vim.notify(
            "[worktree-tmux] worktree_base_dir 必须是字符串或函数，使用默认值",
            vim.log.levels.WARN
        )
        opts.worktree_base_dir = defaults.worktree_base_dir
    end

    -- 验证 on_duplicate_window
    local valid_strategies = { ask = true, overwrite = true, skip = true }
    if not valid_strategies[opts.on_duplicate_window] then
        vim.notify(
            "[worktree-tmux] on_duplicate_window 无效，使用 'ask'",
            vim.log.levels.WARN
        )
        opts.on_duplicate_window = "ask"
    end

    -- 验证 log.level
    local valid_levels = { trace = true, debug = true, info = true, warn = true, error = true, fatal = true }
    if not valid_levels[opts.log.level] then
        vim.notify(
            "[worktree-tmux] log.level 无效，使用 'info'",
            vim.log.levels.WARN
        )
        opts.log.level = "info"
    end
end

--- 应用环境变量覆盖
function M.apply_env_overrides()
    local opts = M.options

    -- WORKTREE_LOG_LEVEL 覆盖日志级别
    if vim.env.WORKTREE_LOG_LEVEL then
        opts.log.level = vim.env.WORKTREE_LOG_LEVEL
    end

    -- WORKTREE_ENV=production 禁用调试输出
    if vim.env.WORKTREE_ENV == "production" then
        opts.log.debug_mode = false
        if opts.log.level == "trace" or opts.log.level == "debug" then
            opts.log.level = "info"
        end
    end
end

--- 获取配置项
---@param key string 配置键（支持点号分隔，如 "ui.input.width"）
---@return any
function M.get(key)
    local keys = vim.split(key, ".", { plain = true })
    local value = M.options

    for _, k in ipairs(keys) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[k]
    end

    return value
end

--- 解析 worktree 基础目录
---@return string
function M.get_worktree_base_dir()
    local base = M.options.worktree_base_dir

    if type(base) == "function" then
        base = base()
    end

    -- 展开 ~ 和环境变量
    return vim.fn.expand(base)
end

--- 格式化 window 名称
---@param repo_name string 仓库名
---@param branch_name string 分支名
---@param base_branch? string 基础分支名
---@return string
function M.format_window_name(repo_name, branch_name, base_branch)
    local template = M.options.window_name_template

    -- 将分支名中的 / 替换为 -（tmux window 名称不支持 /）
    local safe_branch = branch_name:gsub("/", "-")

    local result = template
        :gsub("{repo}", repo_name)
        :gsub("{branch}", safe_branch)
        :gsub("{base}", base_branch or "")

    -- 移除末尾可能的 -（如果 base 为空）
    result = result:gsub("%-+$", "")

    return result
end

--- 获取默认配置（用于 health check）
---@return WorktreeTmux.Config
function M.get_defaults()
    return vim.deepcopy(defaults)
end

--- 重置为默认配置
function M.reset()
    M.options = vim.deepcopy(defaults)
end

return M
