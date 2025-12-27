-- Layer 1: Core logging engine
-- Based on tjdevries/vlog.nvim design, provides basic logging functionality

local M = {}

---@class VlogConfig
---@field plugin string Plugin name
---@field use_console boolean Output to console
---@field use_file boolean Output to file
---@field highlights boolean Enable highlights
---@field level string Log level
---@field modes table Log mode definitions
---@field float_precision number Float precision

---@type VlogConfig
local default_config = {
    plugin = "worktree-tmux.nvim",
    use_console = true,
    use_file = true,
    highlights = true,
    level = "info",
    modes = {
        { name = "trace", hl = "Comment" },
        { name = "debug", hl = "Comment" },
        { name = "info", hl = "Directory" },
        { name = "warn", hl = "WarningMsg" },
        { name = "error", hl = "ErrorMsg" },
        { name = "fatal", hl = "ErrorMsg" },
    },
    float_precision = 0.01,
}

--- Create new logger instance
---@param config? VlogConfig Logger configuration
---@return table Logger instance
function M.new(config)
    config = vim.tbl_deep_extend("force", default_config, config or {})

    -- Log file path: ~/.local/share/nvim/worktree-tmux.nvim.log
    local outfile = string.format(
        "%s/%s.log",
        vim.fn.stdpath("data"),
        config.plugin
    )

    local obj = {}
    local levels = {}

    -- Build level mapping
    for i, v in ipairs(config.modes) do
        levels[v.name] = i
    end

    --- Format values (handle tables and special types)
    ---@param ... any
    ---@return string
    local function format_values(...)
        local args = { ... }
        local result = {}

        for _, v in ipairs(args) do
            if type(v) == "table" then
                table.insert(result, vim.inspect(v))
            elseif type(v) == "number" then
                -- Handle float precision
                if v ~= math.floor(v) then
                    table.insert(result, string.format("%.2f", v))
                else
                    table.insert(result, tostring(v))
                end
            else
                table.insert(result, tostring(v))
            end
        end

        return table.concat(result, " ")
    end

    --- Log at specified level
    ---@param level number Level index
    ---@param level_config table Level config
    ---@param ... any Log arguments
    local function log_at_level(level, level_config, ...)
        -- Level filter
        if level < levels[config.level] then
            return
        end

        local nameupper = level_config.name:upper()
        local msg = format_values(...)

        -- Get caller location
        local info = debug.getinfo(3, "Sl")
        local lineinfo = ""
        if info then
            lineinfo = info.short_src .. ":" .. info.currentline
        end

        -- Output to console
        if config.use_console then
            local console_str = string.format(
                "[%-6s%s] %s: %s",
                nameupper,
                os.date("%H:%M:%S"),
                lineinfo,
                msg
            )

            if config.highlights and level_config.hl then
                vim.schedule(function()
                    vim.cmd(string.format("echohl %s", level_config.hl))
                    local escaped = vim.fn.escape(console_str, '"\\')
                    vim.cmd(string.format([[echom "[%s] %s"]], config.plugin, escaped))
                    vim.cmd("echohl NONE")
                end)
            else
                vim.schedule(function()
                    local escaped = vim.fn.escape(console_str, '"\\')
                    vim.cmd(string.format([[echom "[%s] %s"]], config.plugin, escaped))
                end)
            end
        end

        -- Output to file
        if config.use_file then
            local fp = io.open(outfile, "a")
            if fp then
                local str = string.format(
                    "[%-6s%s] %s: %s\n",
                    nameupper,
                    os.date(),
                    lineinfo,
                    msg
                )
                fp:write(str)
                fp:close()
            end
        end
    end

    -- Create level methods
    for i, mode in ipairs(config.modes) do
        obj[mode.name] = function(...)
            return log_at_level(i, mode, ...)
        end
    end

    --- Format log (with placeholders)
    ---@param level string Log level
    ---@param fmt string Format string
    ---@param ... any Arguments
    function obj.fmt(level, fmt, ...)
        if obj[level] then
            obj[level](string.format(fmt, ...))
        end
    end

    --- Get log file path
    ---@return string
    function obj.get_log_file()
        return outfile
    end

    --- Clear log file
    function obj.clear()
        local fp = io.open(outfile, "w")
        if fp then
            fp:close()
        end
    end

    return obj
end

return M
