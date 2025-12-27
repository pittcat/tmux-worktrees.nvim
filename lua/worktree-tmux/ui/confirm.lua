-- nui.nvim confirm dialog component

local config = require("worktree-tmux.config")

local M = {}

-- Check if nui.nvim is available
local has_nui, Menu = pcall(require, "nui.menu")
local has_event, event = pcall(require, "nui.utils.autocmd")
if has_event then
    event = event.event
end

--- Show confirm dialog
---@param opts { title?: string, message?: string, on_yes: fun(), on_no?: fun() }
function M.show(opts)
    if not has_nui then
        -- Fallback to vim.fn.confirm
        local choice = vim.fn.confirm(
            opts.message or "Confirm action?",
            "&Yes\n&No",
            2
        )
        if choice == 1 then
            opts.on_yes()
        elseif opts.on_no then
            opts.on_no()
        end
        return
    end

    local ui_config = config.get("ui.confirm") or {}

    local menu = Menu({
        position = "50%",
        size = {
            width = ui_config.width or 40,
            height = 2,
        },
        relative = {
            type = "editor",
        },
        border = {
            style = ui_config.border or "rounded",
            text = {
                top = opts.title or " Confirm ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
    }, {
        lines = {
            Menu.item("  Yes ", { action = "yes" }),
            Menu.item("  No ", { action = "no" }),
        },
        max_width = 40,
        keymap = {
            focus_next = { "j", "<Down>", "<Tab>" },
            focus_prev = { "k", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "q" },
            submit = { "<CR>", "<Space>" },
        },
        on_submit = function(item)
            if item.action == "yes" then
                opts.on_yes()
            elseif opts.on_no then
                opts.on_no()
            end
        end,
        on_close = function()
            if opts.on_no then
                opts.on_no()
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

--- Ask user whether to overwrite existing window
---@param window_name string
---@param callbacks { on_yes: fun(), on_no?: fun() }
function M.confirm_overwrite(window_name, callbacks)
    M.show({
        title = " ⚠️  Window Exists ",
        message = string.format("'%s' already exists, overwrite?", window_name),
        on_yes = callbacks.on_yes,
        on_no = callbacks.on_no,
    })
end

--- Ask user whether to delete worktree
---@param worktree_info table { path: string, branch: string, window_name?: string }
---@param callbacks { on_yes: fun(), on_no?: fun() }
function M.confirm_delete(worktree_info, callbacks)
    local message = string.format(
        "Branch: %s\nPath: %s\n\nWill also delete:\n• Tmux Window: %s\n• Working directory\n\nConfirm delete?",
        worktree_info.branch,
        worktree_info.path,
        worktree_info.window_name or "none"
    )

    M.show({
        title = " ⚠️  Confirm Delete ",
        message = message,
        on_yes = callbacks.on_yes,
        on_no = callbacks.on_no,
    })
end

return M
