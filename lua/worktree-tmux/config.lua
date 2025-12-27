-- Configuration management module
-- Handles deep merging, validation, and access of configurations

---@class WorktreeTmux.ConfigModule
---@field options WorktreeTmux.Config
local M = {}

---@type WorktreeTmux.Config
local defaults = {
    -- Tmux session name (fixed)
    session_name = "worktrees",

    -- Worktree base directory
    worktree_base_dir = "~/worktrees",

    -- Window startup command (nil = empty shell)
    window_command = nil,

    -- Window naming template: {repo}, {branch}, {base}
    window_name_template = "wt-{repo}-{branch}",

    -- Whether to sync ignore files
    sync_ignored_files = true,

    -- Duplicate window handling strategy
    on_duplicate_window = "ask",

    -- Whether to async execute (run in background, non-blocking Neovim)
    async = true,

    -- UI config
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

    -- fzf-lua config
    fzf_opts = {
        prompt = "Worktree Jump> ",
        winopts = {
            height = 0.4,
            width = 0.6,
            row = 0.5,
            col = 0.5,
        },
    },

    -- Notification config
    notify = {
        use_snacks = true,
        timeout = 3000,
    },

    -- Log config
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

--- Deep merge configuration
---@param user_config? table User configuration
---@return WorktreeTmux.Config
function M.setup(user_config)
    user_config = user_config or {}

    -- Deep merge configuration
    M.options = vim.tbl_deep_extend("force", defaults, user_config)

    -- Validate configuration
    M.validate()

    -- Apply environment variable overrides
    M.apply_env_overrides()

    return M.options
end

--- Validate configuration
function M.validate()
    local opts = M.options

    -- Validate session_name
    if type(opts.session_name) ~= "string" or opts.session_name == "" then
        vim.notify(
            "[worktree-tmux] session_name must be a non-empty string, using default value",
            vim.log.levels.WARN
        )
        opts.session_name = defaults.session_name
    end

    -- Validate worktree_base_dir
    if type(opts.worktree_base_dir) ~= "string" and type(opts.worktree_base_dir) ~= "function" then
        vim.notify(
            "[worktree-tmux] worktree_base_dir must be a string or function, using default value",
            vim.log.levels.WARN
        )
        opts.worktree_base_dir = defaults.worktree_base_dir
    end

    -- Validate on_duplicate_window
    local valid_strategies = { ask = true, overwrite = true, skip = true }
    if not valid_strategies[opts.on_duplicate_window] then
        vim.notify(
            "[worktree-tmux] on_duplicate_window invalid, using 'ask'",
            vim.log.levels.WARN
        )
        opts.on_duplicate_window = "ask"
    end

    -- Validate log.level
    local valid_levels = { trace = true, debug = true, info = true, warn = true, error = true, fatal = true }
    if not valid_levels[opts.log.level] then
        vim.notify(
            "[worktree-tmux] log.level invalid, using 'info'",
            vim.log.levels.WARN
        )
        opts.log.level = "info"
    end
end

--- Apply environment variable overrides
function M.apply_env_overrides()
    local opts = M.options

    -- WORKTREE_LOG_LEVEL overrides log level
    if vim.env.WORKTREE_LOG_LEVEL then
        opts.log.level = vim.env.WORKTREE_LOG_LEVEL
    end

    -- WORKTREE_ENV=production disables debug output
    if vim.env.WORKTREE_ENV == "production" then
        opts.log.debug_mode = false
        if opts.log.level == "trace" or opts.log.level == "debug" then
            opts.log.level = "info"
        end
    end
end

--- Get configuration value
---@param key string Config key (supports dot notation, e.g. "ui.input.width")
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

--- Parse worktree base directory
---@return string
function M.get_worktree_base_dir()
    local base = M.options.worktree_base_dir

    if type(base) == "function" then
        base = base()
    end

    -- Expand ~ and environment variables
    return vim.fn.expand(base)
end

--- Format window name
---@param repo_name string Repository name
---@param branch_name string Branch name
---@param base_branch? string Base branch name
---@return string
function M.format_window_name(repo_name, branch_name, base_branch)
    local template = M.options.window_name_template

    -- Replace / with - in branch name (tmux window name doesn't support /)
    local safe_branch = branch_name:gsub("/", "-")

    local result = template
        :gsub("{repo}", repo_name)
        :gsub("{branch}", safe_branch)
        :gsub("{base}", base_branch or "")

    -- Remove trailing - if base is empty
    result = result:gsub("%-+$", "")

    return result
end

--- Get default config (for health check)
---@return WorktreeTmux.Config
function M.get_defaults()
    return vim.deepcopy(defaults)
end

--- Reset to default config
function M.reset()
    M.options = vim.deepcopy(defaults)
end

return M
