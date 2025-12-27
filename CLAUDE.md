# CLAUDE.md - 开发指南

## 项目概述

worktree-tmux.nvim 是一个 Neovim 插件，用于管理 Git Worktree 和 Tmux Window 的自动化关联。

## 项目结构

```
worktree-tmux.nvim/
├── plugin/worktree-tmux.lua     # 插件入口，定义 Vim 命令
├── lua/worktree-tmux/
│   ├── init.lua                 # 主模块入口
│   ├── config.lua               # 配置管理
│   ├── types.lua                # 类型定义
│   ├── core.lua                 # 核心业务逻辑
│   ├── tmux.lua                 # Tmux 操作封装
│   ├── git.lua                  # Git 操作封装
│   ├── sync.lua                 # 文件同步
│   ├── async.lua                # 异步执行
│   ├── notify.lua               # 通知封装
│   ├── health.lua               # 健康检查
│   ├── utils.lua                # 工具函数
│   ├── log/                     # 日志系统
│   │   ├── init.lua
│   │   ├── vlog.lua
│   │   ├── logger.lua
│   │   ├── debug.lua
│   │   └── file_logger.lua
│   └── ui/                      # UI 组件
│       ├── init.lua
│       ├── input.lua
│       ├── confirm.lua
│       ├── picker.lua
│       └── progress.lua
├── spec/                        # 测试文件
└── doc/                         # 帮助文档
```

## 开发规范

### Lua 代码风格

- 使用 4 空格缩进
- 函数使用 `function M.name()` 风格
- 使用 LuaCATS 注解提供类型信息
- 模块使用 `local M = {}` + `return M` 模式

### 测试

运行测试：
```bash
nvim --headless -c "PlenaryBustedDirectory spec/"
```

### 日志

```lua
local log = require("worktree-tmux.log")
log.info("message")
log.debug("debug info", { data = "value" })
```

环境变量：
- `WORKTREE_LOG_LEVEL` - 日志级别 (trace/debug/info/warn/error)
- `WORKTREE_ENV=production` - 生产模式

## 核心模块说明

### config.lua
管理配置的深度合并和验证。使用 `config.get("key.subkey")` 访问配置。

### core.lua
核心业务逻辑，协调 git, tmux, sync 模块。主要函数：
- `create_worktree_window(branch, base)`
- `delete_worktree_window(path)`
- `sync_worktrees()`

### tmux.lua
Tmux CLI 封装。所有函数返回 `(success, error_msg)` 元组。

### git.lua
Git CLI 封装。包含 worktree 操作和分支管理。

### ui/
UI 组件，支持 nui.nvim 和 vim.ui fallback。

## 常用命令

```vim
:WorktreeCreate feature/auth main   " 创建 worktree
:WorktreeJump                       " 跳转
:WorktreeDelete                     " 删除
:WorktreeSync                       " 同步
:checkhealth worktree-tmux          " 健康检查
```
