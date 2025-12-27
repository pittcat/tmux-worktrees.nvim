-- nui.nvim input component

local config = require("worktree-tmux.config")

local M = {}

-- Check if nui.nvim is available
local has_nui, Input = pcall(require, "nui.input")
local has_event, event = pcall(require, "nui.utils.autocmd")
if has_event then
    event = event.event
end

--- Show branch name input
---@param opts { prompt?: string, default?: string, on_submit: fun(value: string), on_close?: fun() }
function M.branch_input(opts)
    if not has_nui then
        -- Fallback to vim.ui.input
        vim.ui.input({
            prompt = opts.prompt or "Enter branch name: ",
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
                top = opts.prompt or " Enter Branch Name ",
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

    -- Mount and set shortcuts
    input:mount()

    -- ESC to close
    input:map("n", "<Esc>", function()
        input:unmount()
    end, { noremap = true })

    -- Ctrl-C to close
    input:map("i", "<C-c>", function()
        input:unmount()
    end, { noremap = true })

    -- Auto close
    if has_event then
        input:on(event.BufLeave, function()
            input:unmount()
        end)
    end
end

--- Show base branch selection input
---@param opts { prompt?: string, branches: string[], on_submit: fun(value: string), on_close?: fun() }
function M.base_branch_input(opts)
    if not has_nui then
        -- Fallback to vim.ui.select
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "Select base branch:",
        }, function(choice)
            if choice then
                opts.on_submit(choice)
            elseif opts.on_close then
                opts.on_close()
            end
        end)
        return
    end

    -- Use nui.menu implementation
    local has_menu, Menu = pcall(require, "nui.menu")
    if not has_menu then
        -- Fallback
        vim.ui.select(opts.branches, {
            prompt = opts.prompt or "Select base branch:",
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
                top = opts.prompt or " Select Base Branch ",
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
