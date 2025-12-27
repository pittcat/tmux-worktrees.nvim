-- worktree-tmux.nvim - Git Worktree + Tmux Window Automation Management
-- Plugin entry point: defines Vim commands, loads core module on first execution

if vim.g.loaded_worktree_tmux then
    return
end
vim.g.loaded_worktree_tmux = true

-- Lazy load core module
local function get_core()
    return require("worktree-tmux")
end

-- Define user commands
local function create_commands()
    -- :WorktreeCreate [branch] [base] - Create worktree + tmux window
    vim.api.nvim_create_user_command("WorktreeCreate", function(opts)
        local args = opts.fargs
        local branch = args[1]
        local base = args[2]
        get_core().create(branch, base)
    end, {
        nargs = "*",
        desc = "Create Git Worktree and open corresponding window in tmux",
        complete = function(_, _, _)
            -- TODO: Branch name completion
            return {}
        end,
    })

    -- :WorktreeJump - Use fzf-lua to select and jump to worktree
    vim.api.nvim_create_user_command("WorktreeJump", function()
        get_core().jump()
    end, {
        desc = "Use fzf-lua fuzzy search to jump to worktree window",
    })

    -- :WorktreeDelete [path] - Delete worktree + tmux window
    vim.api.nvim_create_user_command("WorktreeDelete", function(opts)
        local path = opts.fargs[1]
        get_core().delete(path)
    end, {
        nargs = "?",
        desc = "Delete Git Worktree and close corresponding tmux window",
        complete = function(_, _, _)
            -- TODO: Worktree path completion
            return {}
        end,
    })

    -- :WorktreeSync - Sync worktrees and tmux windows
    vim.api.nvim_create_user_command("WorktreeSync", function()
        get_core().sync()
    end, {
        desc = "Sync worktrees status, create windows for missing worktrees",
    })

    -- :WorktreeList - List all worktrees
    vim.api.nvim_create_user_command("WorktreeList", function()
        get_core().list()
    end, {
        desc = "List all Git Worktrees and their corresponding tmux windows",
    })
end

create_commands()
