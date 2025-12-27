# worktree-tmux.nvim

Git Worktree + Tmux Window Automation Management Neovim Plugin.

Automatically create corresponding tmux windows in a dedicated tmux session when creating git worktrees in Neovim, enabling unified management.

## Features

- **One-click Create**: Automatically create tmux window when creating worktree
- **Unified Management**: All worktrees centralized in dedicated `worktrees` session
- **Quick Switch**: Fast jump via fzf-lua fuzzy search
- **Complete Sync**: Automatically sync all files (including .gitignore content)
- **Auto Cleanup**: Automatically delete tmux window when deleting worktree

## Installation

### lazy.nvim

```lua
{
  "pittcat/worktree-tmux.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",   -- Required: async execution
    "MunifTanjim/nui.nvim",    -- Required: UI components
    "ibhagwan/fzf-lua",        -- Optional: fuzzy search
    "folke/snacks.nvim",       -- Optional: notification system
  },
  config = function()
    require("worktree-tmux").setup({
      -- Configuration options
    })
  end,
  keys = {
    { "<leader>wc", "<cmd>WorktreeCreate<cr>", desc = "Create Worktree" },
    { "<leader>wj", "<cmd>WorktreeJump<cr>", desc = "Jump to Worktree" },
    { "<leader>wd", "<cmd>WorktreeDelete<cr>", desc = "Delete Worktree" },
    { "<leader>ws", "<cmd>WorktreeSync<cr>", desc = "Sync Worktrees" },
    { "<leader>wl", "<cmd>WorktreeList<cr>", desc = "List Worktrees" },
  },
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:WorktreeCreate [branch] [base]` | Create worktree and open tmux window |
| `:WorktreeJump` | Use fzf-lua to select and jump to worktree |
| `:WorktreeDelete [path]` | Delete worktree and corresponding tmux window |
| `:WorktreeSync` | Sync worktrees and windows status |
| `:WorktreeList` | List all worktrees |

## Configuration

```lua
require("worktree-tmux").setup({
  -- Tmux session name
  session_name = "worktrees",

  -- Worktree base directory
  worktree_base_dir = "~/worktrees",

  -- Window startup command (nil = empty shell)
  window_command = nil,

  -- Window name template
  window_name_template = "wt-{repo}-{branch}",

  -- Whether to sync .gitignore files
  sync_ignored_files = true,

  -- Duplicate window handling: "ask" | "overwrite" | "skip"
  on_duplicate_window = "ask",

  -- Whether to execute asynchronously (run in background, doesn't block Neovim)
  async = true,

  -- UI configuration
  ui = {
    input = {
      border = "rounded",
      width = 60,
    },
    confirm = {
      border = "rounded",
      width = 40,
    },
  },

  -- fzf-lua configuration
  fzf_opts = {
    prompt = "Worktree Jump> ",
    winopts = {
      height = 0.4,
      width = 0.6,
    },
  },

  -- Log configuration
  log = {
    level = "info",  -- trace, debug, info, warn, error
    use_console = false,
    use_file = true,
  },
})
```

## Health Check

```vim
:checkhealth worktree-tmux
```

## Dependencies

### Required

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Async execution
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI components

### Optional

- [fzf-lua](https://github.com/ibhagwan/fzf-lua) - Fuzzy search (recommended)
- [snacks.nvim](https://github.com/folke/snacks.nvim) - Notification system

### System Dependencies

- `tmux` - Tmux terminal multiplexer
- `git` - Git version control
- `rsync` - File sync (for syncing .gitignore files)

## License

MIT
