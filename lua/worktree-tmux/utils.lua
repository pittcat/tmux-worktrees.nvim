-- 工具函数模块

local M = {}

--- 格式化文件大小
---@param bytes number 字节数
---@return string 格式化后的字符串
function M.format_size(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    else
        return string.format("%.1f GB", bytes / (1024 * 1024 * 1024))
    end
end

--- 格式化持续时间
---@param ms number 毫秒数
---@return string 格式化后的字符串
function M.format_duration(ms)
    if ms < 1000 then
        return string.format("%d ms", ms)
    elseif ms < 60000 then
        return string.format("%.1f s", ms / 1000)
    else
        local minutes = math.floor(ms / 60000)
        local seconds = (ms % 60000) / 1000
        return string.format("%d m %.0f s", minutes, seconds)
    end
end

--- 安全地转义 shell 字符串
---@param str string
---@return string
function M.shell_escape(str)
    return vim.fn.shellescape(str)
end

--- 展开路径中的 ~ 和环境变量
---@param path string
---@return string
function M.expand_path(path)
    return vim.fn.expand(path)
end

--- 确保目录存在
---@param path string
---@return boolean success
function M.ensure_dir(path)
    if vim.fn.isdirectory(path) == 1 then
        return true
    end
    return vim.fn.mkdir(path, "p") == 1
end

--- 检查路径是否存在
---@param path string
---@return boolean
function M.path_exists(path)
    return vim.fn.isdirectory(path) == 1 or vim.fn.filereadable(path) == 1
end

--- 获取路径的父目录
---@param path string
---@return string
function M.dirname(path)
    return vim.fn.fnamemodify(path, ":h")
end

--- 获取路径的文件名
---@param path string
---@return string
function M.basename(path)
    return vim.fn.fnamemodify(path, ":t")
end

--- 合并路径
---@param ... string
---@return string
function M.join_path(...)
    local parts = { ... }
    return table.concat(parts, "/"):gsub("//+", "/")
end

--- 防抖函数
---@param fn function 要执行的函数
---@param ms number 延迟毫秒数
---@return function 防抖后的函数
function M.debounce(fn, ms)
    local timer = nil
    return function(...)
        local args = { ... }
        if timer then
            vim.fn.timer_stop(timer)
        end
        timer = vim.fn.timer_start(ms, function()
            fn(unpack(args))
        end)
    end
end

--- 节流函数
---@param fn function 要执行的函数
---@param ms number 节流间隔毫秒数
---@return function 节流后的函数
function M.throttle(fn, ms)
    local last_call = 0
    return function(...)
        local now = vim.loop.now()
        if now - last_call >= ms then
            last_call = now
            fn(...)
        end
    end
end

--- 深拷贝表
---@param tbl table
---@return table
function M.deep_copy(tbl)
    return vim.deepcopy(tbl)
end

--- 表是否为空
---@param tbl table
---@return boolean
function M.is_empty(tbl)
    return next(tbl) == nil
end

--- 安全获取嵌套表值
---@param tbl table
---@param ... string 键路径
---@return any
function M.get_nested(tbl, ...)
    local keys = { ... }
    local value = tbl

    for _, key in ipairs(keys) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[key]
    end

    return value
end

--- 生成唯一 ID
---@return string
function M.generate_id()
    return string.format("%x%x", os.time(), math.random(0, 0xFFFF))
end

return M
