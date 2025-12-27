-- 第一层：核心日志引擎
-- 基于 tjdevries/vlog.nvim 设计，提供基础日志功能

local M = {}

---@class VlogConfig
---@field plugin string 插件名称
---@field use_console boolean 输出到控制台
---@field use_file boolean 输出到文件
---@field highlights boolean 启用高亮
---@field level string 日志级别
---@field modes table 日志模式定义
---@field float_precision number 浮点数精度

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

--- 创建新的日志实例
---@param config? VlogConfig 日志配置
---@return table 日志实例
function M.new(config)
    config = vim.tbl_deep_extend("force", default_config, config or {})

    -- 日志文件路径: ~/.local/share/nvim/worktree-tmux.nvim.log
    local outfile = string.format(
        "%s/%s.log",
        vim.fn.stdpath("data"),
        config.plugin
    )

    local obj = {}
    local levels = {}

    -- 构建级别映射
    for i, v in ipairs(config.modes) do
        levels[v.name] = i
    end

    --- 格式化值（处理表和特殊类型）
    ---@param ... any
    ---@return string
    local function format_values(...)
        local args = { ... }
        local result = {}

        for _, v in ipairs(args) do
            if type(v) == "table" then
                table.insert(result, vim.inspect(v))
            elseif type(v) == "number" then
                -- 处理浮点数精度
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

    --- 在指定级别记录日志
    ---@param level number 级别索引
    ---@param level_config table 级别配置
    ---@param ... any 日志参数
    local function log_at_level(level, level_config, ...)
        -- 级别过滤
        if level < levels[config.level] then
            return
        end

        local nameupper = level_config.name:upper()
        local msg = format_values(...)

        -- 获取调用位置
        local info = debug.getinfo(3, "Sl")
        local lineinfo = ""
        if info then
            lineinfo = info.short_src .. ":" .. info.currentline
        end

        -- 输出到控制台
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

        -- 输出到文件
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

    -- 创建各级别方法
    for i, mode in ipairs(config.modes) do
        obj[mode.name] = function(...)
            return log_at_level(i, mode, ...)
        end
    end

    --- 格式化日志（带占位符）
    ---@param level string 日志级别
    ---@param fmt string 格式字符串
    ---@param ... any 参数
    function obj.fmt(level, fmt, ...)
        if obj[level] then
            obj[level](string.format(fmt, ...))
        end
    end

    --- 获取日志文件路径
    ---@return string
    function obj.get_log_file()
        return outfile
    end

    --- 清空日志文件
    function obj.clear()
        local fp = io.open(outfile, "w")
        if fp then
            fp:close()
        end
    end

    return obj
end

return M
