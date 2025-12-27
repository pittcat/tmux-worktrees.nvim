-- 第三层：高级调试工具
-- 提供调用栈追踪、数据流追踪、上下文管理、函数装饰器

local log = require("worktree-tmux.log.logger")

local M = {}

-- 调试上下文管理
local debug_contexts = {}
local current_context = nil
local request_id_counter = 0

--- 生成请求 ID
---@return string
local function generate_request_id()
    request_id_counter = request_id_counter + 1
    return string.format(
        "wt_%s_%d",
        os.date("%Y%m%d_%H%M%S"),
        request_id_counter
    )
end

--- 获取调用栈信息
---@param depth number 调用深度
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

--- 获取毫秒级时间戳
---@return string
local function get_timestamp()
    local time = vim.loop.hrtime() / 1e6
    local ms = math.floor(time % 1000)
    return os.date("%Y-%m-%d %H:%M:%S") .. string.format(".%03d", ms)
end

--- 开始调试上下文
---@param context string 上下文名称
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

    M.log_raw("START", string.format("========== %s 开始 ==========", context))

    -- 记录环境信息
    local version = vim.version()
    M.log_raw("INFO", string.format(
        "环境: %s | 版本: %s | Neovim: %s.%s.%s",
        vim.env.WORKTREE_ENV or "dev",
        "v0.1.0",
        version.major,
        version.minor,
        version.patch
    ))

    return request_id
end

--- 结束调试上下文
function M.done()
    if not current_context then
        log.warn("No active debug context")
        return
    end

    local ctx = debug_contexts[current_context]
    if ctx then
        local duration = (vim.loop.hrtime() - ctx.start_time) / 1e6
        M.log_raw("END", string.format(
            "========== %s 完成 | 总耗时: %.0fms ==========",
            current_context,
            duration
        ))
    end

    current_context = nil
end

--- 原始日志记录（带完整格式）
---@param level string 日志级别
---@param msg string 消息
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

    -- 输出到控制台和文件
    log.info(formatted)

    -- 记录到上下文
    if ctx then
        table.insert(ctx.logs, formatted)
    end
end

--- 记录调用栈
---@param fn_name string 函数名
---@param ... any 参数
function M.fn_call(fn_name, ...)
    local args = { ... }
    local args_str = {}

    for _, a in ipairs(args) do
        if type(a) == "table" then
            table.insert(args_str, vim.inspect(a))
        else
            table.insert(args_str, tostring(a))
        end
    end

    local call_stack = get_call_stack(3)
    M.log_raw("DEBUG", string.format(
        "调用栈: %s | 参数: %s",
        call_stack,
        table.concat(args_str, ", ")
    ))
end

--- 记录函数返回
---@param fn_name string 函数名
---@param ... any 返回值
function M.fn_return(fn_name, ...)
    local returns = { ... }
    local ret_str = {}

    for _, r in ipairs(returns) do
        if type(r) == "table" then
            table.insert(ret_str, vim.inspect(r))
        else
            table.insert(ret_str, tostring(r))
        end
    end

    M.log_raw("DEBUG", string.format(
        "返回: %s() → %s",
        fn_name,
        table.concat(ret_str, ", ")
    ))
end

--- 记录数据流
---@param input any 输入数据
---@param output any 输出数据
---@param operation string 操作描述
function M.data_flow(input, output, operation)
    local input_str
    if type(input) == "table" then
        input_str = string.format("%d 条记录", #input)
    else
        input_str = tostring(input)
    end

    local output_str
    if type(output) == "table" then
        output_str = string.format("%d 条记录", #output)
    else
        output_str = tostring(output)
    end

    M.log_raw("DEBUG", string.format(
        "数据流: 输入 %s → %s → 输出 %s",
        input_str,
        operation,
        output_str
    ))

    -- 记录到上下文
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

--- 检查点
---@param name string 检查点名称
---@param data? table 额外数据
function M.checkpoint(name, data)
    local data_str = data and string.format(" | 数据: %s", vim.inspect(data)) or ""
    M.log_raw("INFO", string.format("✓ 检查点: %s%s", name, data_str))
end

--- 函数装饰器：自动记录调用和返回
---@param fn function 要装饰的函数
---@param name string 函数名称
---@return function
function M.wrap(fn, name)
    return function(...)
        M.fn_call(name, ...)
        local start = vim.loop.hrtime()
        local results = { fn(...) }
        local duration = (vim.loop.hrtime() - start) / 1e6
        M.fn_return(name, unpack(results))
        M.log_raw("DEBUG", string.format("%s() 耗时: %.2fms", name, duration))
        return unpack(results)
    end
end

--- 带作用域的调试
---@param context string 上下文名称
---@param fn function 要执行的函数
---@return any
function M.scope(context, fn)
    M.begin(context)
    local ok, result = pcall(fn)
    M.done()

    if not ok then
        M.log_raw("ERROR", string.format("作用域 '%s' 出错: %s", context, result))
        error(result)
    end

    return result
end

--- 获取调试报告
---@param context? string 上下文名称
---@return table
function M.report(context)
    if context then
        return debug_contexts[context]
    end
    return debug_contexts
end

--- 清空调试上下文
function M.clear()
    debug_contexts = {}
    current_context = nil
    request_id_counter = 0
end

-- 导出快捷方法
function M.trace(msg, data)
    log.trace(data and string.format("%s: %s", msg, vim.inspect(data)) or msg)
end

function M.debug(msg, data)
    log.debug(data and string.format("%s: %s", msg, vim.inspect(data)) or msg)
end

function M.info(msg, data)
    log.info(data and string.format("%s: %s", msg, vim.inspect(data)) or msg)
end

function M.warn(msg, data)
    log.warn(data and string.format("%s: %s", msg, vim.inspect(data)) or msg)
end

function M.error(msg, data)
    log.error(data and string.format("%s: %s", msg, vim.inspect(data)) or msg)
end

return M
