-- Async execution module
-- Async operations wrapper based on plenary.job

local log = require("worktree-tmux.log")

local M = {}

-- Check if plenary is available
local has_plenary, Job = pcall(require, "plenary.job")

--- Execute command asynchronously
---@param opts { cmd: string, args?: string[], cwd?: string, on_success?: fun(result: string[]), on_error?: fun(stderr: string[], code: number), on_progress?: fun(data: string) }
---@return table|nil job
function M.run(opts)
    if not has_plenary then
        log.error("plenary.nvim not installed, async feature unavailable")
        -- Fallback to sync execution
        local cmd = opts.cmd
        if opts.args then
            cmd = cmd .. " " .. table.concat(opts.args, " ")
        end

        local output = vim.fn.system(cmd)
        if vim.v.shell_error == 0 then
            if opts.on_success then
                opts.on_success(vim.split(output, "\n"))
            end
        else
            if opts.on_error then
                opts.on_error(vim.split(output, "\n"), vim.v.shell_error)
            end
        end
        return nil
    end

    local job = Job:new({
        command = opts.cmd,
        args = opts.args or {},
        cwd = opts.cwd,
        on_stdout = function(_, data)
            if opts.on_progress and data then
                vim.schedule(function()
                    opts.on_progress(data)
                end)
            end
        end,
        on_stderr = function(_, data)
            if opts.on_progress and data then
                vim.schedule(function()
                    opts.on_progress(data)
                end)
            end
        end,
        on_exit = function(j, return_val)
            vim.schedule(function()
                if return_val == 0 then
                    if opts.on_success then
                        opts.on_success(j:result())
                    end
                else
                    if opts.on_error then
                        opts.on_error(j:stderr_result(), return_val)
                    else
                        log.error("Command failed:", opts.cmd, "exit code:", return_val)
                    end
                end
            end)
        end,
    })

    job:start()
    return job
end

--- Execute git command asynchronously
---@param args string[] git command arguments
---@param callbacks { on_success?: fun(result: string[]), on_error?: fun(stderr: string[], code: number) }
---@return table|nil job
function M.git(args, callbacks)
    return M.run({
        cmd = "git",
        args = args,
        on_success = callbacks.on_success,
        on_error = callbacks.on_error,
    })
end

--- Execute tmux command asynchronously
---@param args string[] tmux command arguments
---@param callbacks { on_success?: fun(result: string[]), on_error?: fun(stderr: string[], code: number) }
---@return table|nil job
function M.tmux(args, callbacks)
    return M.run({
        cmd = "tmux",
        args = args,
        on_success = callbacks.on_success,
        on_error = callbacks.on_error,
    })
end

--- Execute rsync command asynchronously
---@param source string source path
---@param target string target path
---@param callbacks { on_success?: fun(result: string[]), on_error?: fun(stderr: string[], code: number), on_progress?: fun(data: string) }
---@return table|nil job
function M.rsync(source, target, callbacks)
    return M.run({
        cmd = "rsync",
        args = { "-a", "--exclude=.git", "--progress", source, target },
        on_success = callbacks.on_success,
        on_error = callbacks.on_error,
        on_progress = callbacks.on_progress,
    })
end

--- Wait for job completion (sync blocking)
---@param job table plenary.job
---@param timeout? number Timeout in milliseconds
---@return boolean completed
function M.wait(job, timeout)
    if not job then
        return true
    end

    if not has_plenary then
        return true
    end

    timeout = timeout or 30000
    local result = job:wait(timeout)
    return result ~= nil
end

--- Create Promise-style async operation
---@param opts { cmd: string, args?: string[], cwd?: string }
---@return table promise { then_: fun(on_success: fun(result: string[])), catch: fun(on_error: fun(err: string)), await: fun(): string[] }
function M.promise(opts)
    local promise = {
        _pending = true,
        _result = nil,
        _error = nil,
        _success_callbacks = {},
        _error_callbacks = {},
    }

    local job = M.run({
        cmd = opts.cmd,
        args = opts.args,
        cwd = opts.cwd,
        on_success = function(result)
            promise._pending = false
            promise._result = result
            for _, cb in ipairs(promise._success_callbacks) do
                cb(result)
            end
        end,
        on_error = function(stderr, code)
            promise._pending = false
            promise._error = table.concat(stderr, "\n")
            for _, cb in ipairs(promise._error_callbacks) do
                cb(promise._error)
            end
        end,
    })

    function promise.then_(on_success)
        if promise._pending then
            table.insert(promise._success_callbacks, on_success)
        elseif promise._result then
            on_success(promise._result)
        end
        return promise
    end

    function promise.catch(on_error)
        if promise._pending then
            table.insert(promise._error_callbacks, on_error)
        elseif promise._error then
            on_error(promise._error)
        end
        return promise
    end

    function promise.await()
        if job then
            M.wait(job)
        end
        if promise._error then
            error(promise._error)
        end
        return promise._result
    end

    return promise
end

--- Execute multiple commands in parallel
---@param commands { cmd: string, args?: string[] }[]
---@param callback fun(results: { success: boolean, result?: string[], error?: string }[])
function M.parallel(commands, callback)
    local results = {}
    local completed = 0
    local total = #commands

    for i, cmd_opts in ipairs(commands) do
        M.run({
            cmd = cmd_opts.cmd,
            args = cmd_opts.args,
            on_success = function(result)
                results[i] = { success = true, result = result }
                completed = completed + 1
                if completed == total then
                    callback(results)
                end
            end,
            on_error = function(stderr, code)
                results[i] = { success = false, error = table.concat(stderr, "\n") }
                completed = completed + 1
                if completed == total then
                    callback(results)
                end
            end,
        })
    end
end

--- Check if plenary is available
---@return boolean
function M.is_available()
    return has_plenary
end

return M
