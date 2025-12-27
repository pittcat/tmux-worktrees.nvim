-- LuaCATS 类型定义
-- 提供 IDE 智能补全和类型检查支持

---@class WorktreeTmux.Config
---@field session_name string Tmux session 名称（默认 "worktrees"）
---@field worktree_base_dir string|fun():string Worktree 基础目录
---@field window_command? string Window 启动命令
---@field window_name_template string Window 命名模板
---@field sync_ignored_files boolean 是否同步 ignore 文件
---@field on_duplicate_window "ask"|"overwrite"|"skip" 重名 window 处理策略
---@field ui WorktreeTmux.UIConfig UI 配置
---@field fzf_opts WorktreeTmux.FzfConfig fzf-lua 配置
---@field notify WorktreeTmux.NotifyConfig 通知配置
---@field async WorktreeTmux.AsyncConfig 异步执行配置
---@field log WorktreeTmux.LogConfig 日志配置

---@class WorktreeTmux.UIConfig
---@field input WorktreeTmux.InputConfig 输入框配置
---@field confirm WorktreeTmux.ConfirmConfig 确认对话框配置

---@class WorktreeTmux.InputConfig
---@field border string 边框样式
---@field width number 宽度
---@field position string|table 位置

---@class WorktreeTmux.ConfirmConfig
---@field border string 边框样式
---@field width number 宽度

---@class WorktreeTmux.FzfConfig
---@field prompt string 提示符
---@field winopts? table 窗口选项

---@class WorktreeTmux.NotifyConfig
---@field use_snacks boolean 是否使用 snacks.nvim
---@field timeout number 通知显示时间（毫秒）

---@class WorktreeTmux.AsyncConfig
---@field show_progress boolean 是否显示进度通知
---@field rsync_timeout number rsync 超时时间（秒）

---@class WorktreeTmux.LogConfig
---@field level "trace"|"debug"|"info"|"warn"|"error"|"fatal" 日志级别
---@field use_console boolean 输出到控制台
---@field use_file boolean 输出到文件
---@field debug_mode boolean 启用调试模式
---@field debug_file? string 调试日志文件路径
---@field highlights boolean 是否高亮

---@class WorktreeTmux.Worktree
---@field path string Worktree 路径
---@field branch? string 分支名
---@field bare? boolean 是否为裸仓库

---@class WorktreeTmux.TmuxWindow
---@field index number Window 索引
---@field name string Window 名称
---@field active boolean 是否为当前活动窗口

---@class WorktreeTmux.CreateWindowOpts
---@field session string Session 名称
---@field name string Window 名称
---@field cwd string 工作目录
---@field cmd? string 启动命令

---@class WorktreeTmux.SyncResult
---@field created number 创建的 window 数量
---@field skipped number 跳过的数量

---@class WorktreeTmux.DebugContext
---@field request_id string 请求 ID
---@field start_time number 开始时间
---@field logs table 日志列表
---@field data_flow table 数据流记录

return {}
