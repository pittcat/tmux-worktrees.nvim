# worktree-tmux.nvim

Git Worktree + Tmux Window 自动化管理 Neovim 插件。

在 Neovim 中创建 git worktree 时，自动在固定的 tmux session 中创建对应的 window，实现统一管理。

## 功能特性

- **一键创建**：创建 worktree 时自动创建对应 tmux window
- **统一管理**：所有 worktrees 集中在固定的 `worktrees` session
- **快速切换**：通过 fzf-lua 模糊搜索快速跳转
- **完整同步**：自动同步所有文件（包括 .gitignore 内容）
- **自动清理**：删除 worktree 时自动删除 tmux window

## 安装

### lazy.nvim

```lua
{
  "yourusername/worktree-tmux.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",   -- 必选：异步执行
    "MunifTanjim/nui.nvim",    -- 必选：UI 组件
    "ibhagwan/fzf-lua",        -- 可选：模糊搜索
    "folke/snacks.nvim",       -- 可选：通知系统
  },
  config = function()
    require("worktree-tmux").setup({
      -- 配置选项
    })
  end,
  keys = {
    { "<leader>wc", "<cmd>WorktreeCreate<cr>", desc = "创建 Worktree" },
    { "<leader>wj", "<cmd>WorktreeJump<cr>", desc = "跳转 Worktree" },
    { "<leader>wd", "<cmd>WorktreeDelete<cr>", desc = "删除 Worktree" },
    { "<leader>ws", "<cmd>WorktreeSync<cr>", desc = "同步 Worktrees" },
    { "<leader>wl", "<cmd>WorktreeList<cr>", desc = "列出 Worktrees" },
  },
}
```

## 命令

| 命令 | 描述 |
|------|------|
| `:WorktreeCreate [branch] [base]` | 创建 worktree 并打开 tmux window |
| `:WorktreeJump` | 使用 fzf-lua 选择并跳转到 worktree |
| `:WorktreeDelete [path]` | 删除 worktree 及对应 tmux window |
| `:WorktreeSync` | 同步 worktrees 和 windows 状态 |
| `:WorktreeList` | 列出所有 worktrees |

## 配置

```lua
require("worktree-tmux").setup({
  -- Tmux session 名称
  session_name = "worktrees",

  -- Worktree 基础目录
  worktree_base_dir = "~/worktrees",

  -- Window 启动命令（nil = 空 shell）
  window_command = nil,

  -- Window 命名模板
  window_name_template = "wt-{repo}-{branch}",

  -- 是否同步 .gitignore 文件
  sync_ignored_files = true,

  -- 重名 window 处理："ask" | "overwrite" | "skip"
  on_duplicate_window = "ask",

  -- 是否异步执行（后台运行，不阻塞当前 Neovim 操作）
  async = true,

  -- UI 配置
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

  -- fzf-lua 配置
  fzf_opts = {
    prompt = "Worktree Jump> ",
    winopts = {
      height = 0.4,
      width = 0.6,
    },
  },

  -- 日志配置
  log = {
    level = "info",  -- trace, debug, info, warn, error
    use_console = true,
    use_file = true,
  },
})
```

## 健康检查

```vim
:checkhealth worktree-tmux
```

## 依赖

### 必选

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - 异步执行
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI 组件

### 可选

- [fzf-lua](https://github.com/ibhagwan/fzf-lua) - 模糊搜索（推荐）
- [snacks.nvim](https://github.com/folke/snacks.nvim) - 通知系统

### 系统依赖

- `tmux` - Tmux 终端复用器
- `git` - Git 版本控制
- `rsync` - 文件同步（用于同步 .gitignore 文件）

## License

MIT
