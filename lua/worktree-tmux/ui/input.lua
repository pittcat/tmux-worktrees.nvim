-- nui.nvim 输入框组件

local config = require("worktree-tmux.config")

local M = {}

-- 检查 nui.nvim 是否可用
local has_nui, Input = pcall(require, "nui.input")
local has_event, event = pcall(require, "nui.utils.autocmd")
if has_event then
    event = event.event
end

--- 显示分支名输入框
---@param opts { prompt?: string, default?: string, on_submit: fun(value: string), on_close?: fun() }
function M.branch_input(opts)
    if not has_nui then
        -- 回退到 vim.ui.input
        vim.ui.input({
            prompt = opts.prompt or "输入分支名: ",
            default = opts.default or "",
        }, function(value)
            if value and value ~= "" then
                opts.on_submit(value)
            elseif opts.on_close then
                opts.on_close()
            end
        end)
        return
    end

    local ui_config = config.get("ui.input") or {}

    local input = Input({
        position = ui_config.position or "50%",
        size = {
            width = ui_config.width or 60,
        },
        relative = {
            type = "editor",
        },
        border = {
            style = ui_config.border or "rounded",
            text = {
                top = opts.prompt or " 输入分支名 ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
    }, {
        prompt = "  ",
        default_value = opts.default or "",
        on_submit = function(value)
            if value and value ~= "" then
                opts.on_submit(value)
            end
        end,
        on_close = function()
            if opts.on_close then
                opts.on_close()
            end
        end,
    })

    -- 挂载并设置快捷键
    input:mount()

    -- ESC 关闭
    input:map("n", "<Esc>", function()
        input:unmount()
    end, { noremap = true })

    -- Ctrl-C 关闭
    input:map("i", "<C-c>", function()
        input:unmount()
    end, { noremap = true })

    -- 自动关闭
    if has_event then
        input:on(event.BufLeave, function()
            input:unmount()
        end)
    end
end

--- 显示基础分支选择输入框
---@param opts { prompt?: string, branches: string[], on_submit: fun(value: string), on_close?: fun() }
function M.base_branch_input(opts)
    if not has_nui then
        -- 回退到 vim.ui.select
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "选择基础分支:",
        }, function(choice)
            if choice then
                opts.on_submit(choice)
            elseif opts.on_close then
                opts.on_close()
            end
        end)
        return
    end

    -- 使用 nui.menu 实现
    local has_menu, Menu = pcall(require, "nui.menu")
    if not has_menu then
        -- 回退
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "选择基础分支:",
        }, function(choice)
            if choice then
                opts.on_submit(choice)
            elseif opts.on_close then
                opts.on_close()
            end
        end)
        return
    end

    local ui_config = config.get("ui.input") or {}
    local lines = {}
    for _, branch in ipairs(opts.branches) do
        table.insert(lines, Menu.item("  " .. branch, { value = branch }))
    end

    local menu = Menu({
        position = ui_config.position or "50%",
        size = {
            width = ui_config.width or 60,
            height = math.min(#lines, 10),
        },
        relative = {
            type = "editor",
        },
        border = {
            style = ui_config.border or "rounded",
            text = {
                top = opts.prompt or " 选择基础分支 ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
    }, {
        lines = lines,
        max_width = 60,
        keymap = {
            focus_next = { "j", "<Down>", "<Tab>" },
            focus_prev = { "k", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "q" },
            submit = { "<CR>", "<Space>" },
        },
        on_submit = function(item)
            opts.on_submit(item.value)
        end,
        on_close = function()
            if opts.on_close then
                opts.on_close()
            end
        end,
    })

    menu:mount()

    if has_event then
        menu:on(event.BufLeave, function()
            menu:unmount()
        end)
    end
end

return M
