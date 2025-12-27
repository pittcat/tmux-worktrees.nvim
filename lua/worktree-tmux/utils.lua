-- Utility functions module

local M = {}

--- Format file size
---@param bytes number Bytes
---@return string Formatted string
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

--- Format duration
---@param ms number Milliseconds
---@return string Formatted string
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

--- Safely escape shell string
---@param str string
---@return string
function M.shell_escape(str)
    return vim.fn.shellescape(str)
end

--- Expand ~ and environment variables in path
---@param path string
---@return string
function M.expand_path(path)
    return vim.fn.expand(path)
end

--- Ensure directory exists
---@param path string
---@return boolean success
function M.ensure_dir(path)
    if vim.fn.isdirectory(path) == 1 then
        return true
    end
    return vim.fn.mkdir(path, "p") == 1
end

--- Check if path exists
---@param path string
---@return boolean
function M.path_exists(path)
    return vim.fn.isdirectory(path) == 1 or vim.fn.filereadable(path) == 1
end

--- Get parent directory of path
---@param path string
---@return string
function M.dirname(path)
    return vim.fn.fnamemodify(path, ":h")
end

--- Get filename from path
---@param path string
---@return string
function M.basename(path)
    return vim.fn.fnamemodify(path, ":t")
end

--- Join path parts
---@param ... string
---@return string
function M.join_path(...)
    local parts = { ... }
    return table.concat(parts, "/"):gsub("//+", "/")
end

--- Debounce function
---@param fn function Function to execute
---@param ms number Delay in milliseconds
---@return function Debounced function
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

--- Throttle function
---@param fn function Function to execute
---@param ms number Throttle interval in milliseconds
---@return function Throttled function
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

--- Deep copy table
---@param tbl table
---@return table
function M.deep_copy(tbl)
    return vim.deepcopy(tbl)
end

--- Check if table is empty
---@param tbl table
---@return boolean
function M.is_empty(tbl)
    return next(tbl) == nil
end

--- Safely get nested table value
---@param tbl table
---@param ... string Key path
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

--- Generate unique ID
---@return string
function M.generate_id()
    return string.format("%x%x", os.time(), math.random(0, 0xFFFF))
end

return M
