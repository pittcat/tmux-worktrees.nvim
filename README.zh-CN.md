# worktree-tmux.nvim

Git Worktree + Tmux 窗口自动化管理 Neovim 插件。

在 Neovim 中创建 Git Worktree 时，自动在专用 tmux 会话中创建对应的 tmux 窗口，实现统一管理。

## 功能特性

- **一键创建**: 创建 worktree 时自动创建 tmux 窗口
- **统一管理**: 所有 worktree 集中在专用的 `worktrees` 会话中
- **快速跳转**: 通过 fzf-lua 模糊搜索快速跳转
- **完整同步**: 自动同步所有文件（包括 .gitignore 内容）
- **自动清理**: 删除 worktree 时自动删除对应的 tmux 窗口

## 安装

### lazy.nvim

```lua
{
  "pittcat/worktree-tmux.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",   -- 必选: 异步执行
    "MunifTanjim/nui.nvim",    -- 必选: UI 组件
    "ibhagwan/fzf-lua",        -- 可选: 模糊搜索
    "folke/snacks.nvim",       -- 可选: 通知系统
  },
  config = function()
    require("worktree-tmux").setup({
      -- 配置选项
    })
  end,
  keys = {
    { "<leader>wc", "<cmd>WorktreeCreate<cr>", desc = "创建 Worktree" },
    { "<leader>wj", "<cmd>WorktreeJump<cr>", desc = "跳转到 Worktree" },
    { "<leader>wd", "<cmd>WorktreeDelete<cr>", desc = "删除 Worktree" },
    { "<leader>ws", "<cmd>WorktreeSync<cr>", desc = "同步 Worktrees" },
    { "<leader>wl", "<cmd>WorktreeList<cr>", desc = "列出 Worktrees" },
  },
}
```

## 命令说明

| 命令 | 描述 |
|------|------|
| `:WorktreeCreate [分支] [基准]` | 创建 worktree 并打开 tmux 窗口 |
| `:WorktreeJump` | 使用 fzf-lua 选择并跳转到 worktree |
| `:WorktreeDelete [路径]` | 删除 worktree 及对应的 tmux 窗口 |
| `:WorktreeSync` | 同步 worktree 和窗口状态 |
| `:WorktreeList` | 列出所有 worktree |

## 配置选项

```lua
require("worktree-tmux").setup({
  -- Tmux 会话名称
  session_name = "worktrees",

  -- Worktree 基础目录
  worktree_base_dir = "~/worktrees",

  -- 窗口启动命令 (nil = 空 shell)
  window_command = nil,

  -- 窗口名称模板
  window_name_template = "wt-{repo}-{branch}",

  -- 是否同步 .gitignore 文件
  sync_ignored_files = true,

  -- 重复窗口处理: "ask" | "overwrite" | "skip"
  on_duplicate_window = "ask",

  -- 是否异步执行（在后台运行，不阻塞 Neovim）
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
    prompt = "Worktree 跳转> ",
    winopts = {
      height = 0.4,
      width = 0.6,
    },
  },

  -- 日志配置
  log = {
    level = "info",  -- trace, debug, info, warn, error
    use_console = false,
    use_file = true,
  },
})
```

## 健康检查

```vim
:checkhealth worktree-tmux
```

## 依赖说明

### 必选依赖

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - 异步执行
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI 组件

### 可选依赖

- [fzf-lua](https://github.com/ibhagwan/fzf-lua) - 模糊搜索（推荐）
- [snacks.nvim](https://github.com/folke/snacks.nvim) - 通知系统

### 系统依赖

- `tmux` - Tmux 终端复用器
- `git` - Git 版本控制
- `rsync` - 文件同步（用于同步 .gitignore 文件）

## 开源协议

MIT
