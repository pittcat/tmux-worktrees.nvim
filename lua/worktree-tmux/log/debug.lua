-- Layer 3: Advanced debugging tools
-- Provides call stack tracing, data flow tracing, context management, function decorators

local log = require("worktree-tmux.log.logger")

local M = {}

--- Safely format data for log output
---@param data any Data to format
---@param max_length? number Max length (default 200)
---@return string
local function safe_inspect(data, max_length)
    max_length = max_length or 200
    if data == nil then
        return "nil"
    end

    local inspected = vim.inspect(data, {
        newline = "",
        indent = "",
        depth = 3,  -- Limit depth to avoid deep nesting
    })

    -- Limit length
    if #inspected > max_length then
        inspected = inspected:sub(1, max_length) .. "... (truncated)"
    end

    -- Escape quotes to avoid echomsg errors
    inspected = inspected:gsub('"', "'")

    return inspected
end

-- Debug context management
local debug_contexts = {}
local current_context = nil
local request_id_counter = 0

--- Generate request ID
---@return string
local function generate_request_id()
    request_id_counter = request_id_counter + 1
    return string.format(
        "wt_%s_%d",
        os.date("%Y%m%d_%H%M%S"),
        request_id_counter
    )
end

--- Get call stack info
---@param depth number Call depth
---@return string
local function get_call_stack(depth)
    local stack = {}
    for i = depth, depth + 5 do
        local info = debug.getinfo(i, "nSl")
        if not info then
            break
        end
        local name = info.name or "anonymous"
        local line = info.currentline or 0
        table.insert(stack, string.format("%s() line %d", name, line))
    end
    return table.concat(stack, " → ")
end

--- Get millisecond timestamp
---@return string
local function get_timestamp()
    local time = vim.loop.hrtime() / 1e6
    local ms = math.floor(time % 1000)
    return os.date("%Y-%m-%d %H:%M:%S") .. string.format(".%03d", ms)
end

--- Start debug context
---@param context string Context name
---@return string request_id
function M.begin(context)
    local request_id = generate_request_id()
    current_context = context
    debug_contexts[context] = {
        request_id = request_id,
        start_time = vim.loop.hrtime(),
        logs = {},
        data_flow = {},
    }

    M.log_raw("START", string.format("========== %s begins ==========", context))

    -- Record environment info
    local version = vim.version()
    M.log_raw("INFO", string.format(
        "Env: %s | Version: %s | Neovim: %s.%s.%s",
        vim.env.WORKTREE_ENV or "dev",
        "v0.1.0",
        version.major,
        version.minor,
        version.patch
    ))

    return request_id
end

--- End debug context
function M.done()
    if not current_context then
        log.warn("No active debug context")
        return
    end

    local ctx = debug_contexts[current_context]
    if ctx then
        local duration = (vim.loop.hrtime() - ctx.start_time) / 1e6
        M.log_raw("END", string.format(
            "========== %s completed | total time: %.0fms ==========",
            current_context,
            duration
        ))
    end

    current_context = nil
end

--- Raw log (with full format)
---@param level string Log level
---@param msg string Message
function M.log_raw(level, msg)
    local ctx = current_context and debug_contexts[current_context]
    local request_id = ctx and ctx.request_id or ""
    local id_part = request_id ~= "" and string.format("[%s] ", request_id) or ""

    local formatted = string.format(
        "[%s] [%s] %s%s",
        get_timestamp(),
        level,
        id_part,
        msg
    )

    -- Output to console and file
    log.info(formatted)

    -- Record to context
    if ctx then
        table.insert(ctx.logs, formatted)
    end
end

--- Record function call
---@param fn_name string Function name
---@param ... any Arguments
function M.fn_call(fn_name, ...)
    local args = { ... }
    local args_str = {}

    for _, a in ipairs(args) do
        if type(a) == "table" then
            table.insert(args_str, safe_inspect(a, 100))
        else
            table.insert(args_str, tostring(a))
        end
    end

    local call_stack = get_call_stack(3)
    M.log_raw("DEBUG", string.format(
        "Call stack: %s | Args: %s",
        call_stack,
        table.concat(args_str, ", ")
    ))
end

--- Record function return
---@param fn_name string Function name
---@param ... any Return values
function M.fn_return(fn_name, ...)
    local returns = { ... }
    local ret_str = {}

    for _, r in ipairs(returns) do
        if type(r) == "table" then
            table.insert(ret_str, safe_inspect(r, 100))
        else
            table.insert(ret_str, tostring(r))
        end
    end

    M.log_raw("DEBUG", string.format(
        "Return: %s() → %s",
        fn_name,
        table.concat(ret_str, ", ")
    ))
end

--- Record data flow
---@param input any Input data
---@param output any Output data
---@param operation string Operation description
function M.data_flow(input, output, operation)
    local input_str
    if type(input) == "table" then
        input_str = string.format("%d records", #input)
    else
        input_str = tostring(input)
    end

    local output_str
    if type(output) == "table" then
        output_str = string.format("%d records", #output)
    else
        output_str = tostring(output)
    end

    M.log_raw("DEBUG", string.format(
        "Data flow: input %s → %s → output %s",
        input_str,
        operation,
        output_str
    ))

    -- Record to context
    local ctx = current_context and debug_contexts[current_context]
    if ctx then
        table.insert(ctx.data_flow, {
            input = input,
            output = output,
            operation = operation,
            timestamp = get_timestamp(),
        })
    end
end

--- Checkpoint
---@param name string Checkpoint name
---@param data? table Extra data
function M.checkpoint(name, data)
    if data then
        M.log_raw("INFO", string.format("✓ Checkpoint: %s | Data: %s", name, safe_inspect(data)))
    else
        M.log_raw("INFO", string.format("✓ Checkpoint: %s", name))
    end
end

--- Function decorator: auto record call and return
---@param fn function Function to decorate
---@param name string Function name
---@return function
function M.wrap(fn, name)
    return function(...)
        M.fn_call(name, ...)
        local start = vim.loop.hrtime()
        local results = { fn(...) }
        local duration = (vim.loop.hrtime() - start) / 1e6
        M.fn_return(name, unpack(results))
        M.log_raw("DEBUG", string.format("%s() duration: %.2fms", name, duration))
        return unpack(results)
    end
end

--- Scoped debugging
---@param context string Context name
---@param fn function Function to execute
---@return any
function M.scope(context, fn)
    M.begin(context)
    local ok, result = pcall(fn)
    M.done()

    if not ok then
        M.log_raw("ERROR", string.format("Scope '%s' error: %s", context, result))
        error(result)
    end

    return result
end

--- Get debug report
---@param context? string Context name
---@return table
function M.report(context)
    if context then
        return debug_contexts[context]
    end
    return debug_contexts
end

--- Clear debug contexts
function M.clear()
    debug_contexts = {}
    current_context = nil
    request_id_counter = 0
end

-- Export shortcut methods
function M.trace(msg, data)
    log.trace(data and string.format("%s: %s", msg, safe_inspect(data, 200)) or msg)
end

function M.debug(msg, data)
    log.debug(data and string.format("%s: %s", msg, safe_inspect(data, 200)) or msg)
end

function M.info(msg, data)
    log.info(data and string.format("%s: %s", msg, safe_inspect(data, 200)) or msg)
end

function M.warn(msg, data)
    log.warn(data and string.format("%s: %s", msg, safe_inspect(data, 200)) or msg)
end

function M.error(msg, data)
    log.error(data and string.format("%s: %s", msg, safe_inspect(data, 200)) or msg)
end

return M
