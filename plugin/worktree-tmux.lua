-- worktree-tmux.nvim - Git Worktree + Tmux Window 自动化管理
-- 插件入口：定义 Vim 命令，首次执行才加载核心模块

if vim.g.loaded_worktree_tmux then
    return
end
vim.g.loaded_worktree_tmux = true

-- 延迟加载核心模块
local function get_core()
    return require("worktree-tmux")
end

-- 定义用户命令
local function create_commands()
    -- :WorktreeCreate [branch] [base] - 创建 worktree + tmux window
    vim.api.nvim_create_user_command("WorktreeCreate", function(opts)
        local args = opts.fargs
        local branch = args[1]
        local base = args[2]
        get_core().create(branch, base)
    end, {
        nargs = "*",
        desc = "创建 Git Worktree 并在 tmux 中打开对应 window",
        complete = function(_, _, _)
            -- TODO: 分支名补全
            return {}
        end,
    })

    -- :WorktreeJump - 使用 fzf-lua 选择并跳转到 worktree
    vim.api.nvim_create_user_command("WorktreeJump", function()
        get_core().jump()
    end, {
        desc = "使用 fzf-lua 模糊搜索并跳转到 worktree window",
    })

    -- :WorktreeDelete [path] - 删除 worktree + tmux window
    vim.api.nvim_create_user_command("WorktreeDelete", function(opts)
        local path = opts.fargs[1]
        get_core().delete(path)
    end, {
        nargs = "?",
        desc = "删除 Git Worktree 并关闭对应 tmux window",
        complete = function(_, _, _)
            -- TODO: worktree 路径补全
            return {}
        end,
    })

    -- :WorktreeSync - 同步 worktrees 和 tmux windows
    vim.api.nvim_create_user_command("WorktreeSync", function()
        get_core().sync()
    end, {
        desc = "同步 worktrees 状态，为缺失的 worktree 创建 window",
    })

    -- :WorktreeList - 列出所有 worktrees
    vim.api.nvim_create_user_command("WorktreeList", function()
        get_core().list()
    end, {
        desc = "列出所有 Git Worktrees 及其对应的 tmux windows",
    })
end

create_commands()
