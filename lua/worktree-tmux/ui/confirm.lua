-- nui.nvim 确认对话框组件

local config = require("worktree-tmux.config")

local M = {}

-- 检查 nui.nvim 是否可用
local has_nui, Menu = pcall(require, "nui.menu")
local has_event, event = pcall(require, "nui.utils.autocmd")
if has_event then
    event = event.event
end

--- 显示确认对话框
---@param opts { title?: string, message?: string, on_yes: fun(), on_no?: fun() }
function M.show(opts)
    if not has_nui then
        -- 回退到 vim.fn.confirm
        local choice = vim.fn.confirm(
            opts.message or "确认操作？",
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
        border = {
            style = ui_config.border or "rounded",
            text = {
                top = opts.title or " 确认 ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
    }, {
        lines = {
            Menu.item("  是 (Yes)", { action = "yes" }),
            Menu.item("  否 (No)", { action = "no" }),
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

--- 询问用户是否覆盖已存在的 window
---@param window_name string
---@param callbacks { on_yes: fun(), on_no?: fun() }
function M.confirm_overwrite(window_name, callbacks)
    M.show({
        title = " ⚠️  Window 已存在 ",
        message = string.format("'%s' 已存在，是否覆盖？", window_name),
        on_yes = callbacks.on_yes,
        on_no = callbacks.on_no,
    })
end

--- 询问用户是否删除 worktree
---@param worktree_info table { path: string, branch: string, window_name?: string }
---@param callbacks { on_yes: fun(), on_no?: fun() }
function M.confirm_delete(worktree_info, callbacks)
    local message = string.format(
        "分支: %s\n路径: %s\n\n将同时删除:\n• Tmux Window: %s\n• 工作目录\n\n确认删除？",
        worktree_info.branch,
        worktree_info.path,
        worktree_info.window_name or "无"
    )

    M.show({
        title = " ⚠️  确认删除 ",
        message = message,
        on_yes = callbacks.on_yes,
        on_no = callbacks.on_no,
    })
end

return M
