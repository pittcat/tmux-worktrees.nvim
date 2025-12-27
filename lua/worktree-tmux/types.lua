-- LuaCATS type definitions
-- Provides IDE autocomplete and type checking support

---@class WorktreeTmux.Config
---@field session_name string Tmux session name (default "worktrees")
---@field worktree_base_dir string|fun():string Worktree base directory
---@field window_command? string Window startup command
---@field window_name_template string Window naming template
---@field sync_ignored_files boolean Whether to sync ignore files
---@field on_duplicate_window "ask"|"overwrite"|"skip" Duplicate window handling strategy
---@field ui WorktreeTmux.UIConfig UI config
---@field fzf_opts WorktreeTmux.FzfConfig fzf-lua config
---@field notify WorktreeTmux.NotifyConfig Notification config
---@field async WorktreeTmux.AsyncConfig Async execution config
---@field log WorktreeTmux.LogConfig Log config

---@class WorktreeTmux.UIConfig
---@field input WorktreeTmux.InputConfig Input config
---@field confirm WorktreeTmux.ConfirmConfig Confirm dialog config

---@class WorktreeTmux.InputConfig
---@field border string Border style
---@field width number Width
---@field position string|table Position

---@class WorktreeTmux.ConfirmConfig
---@field border string Border style
---@field width number Width

---@class WorktreeTmux.FzfConfig
---@field prompt string Prompt
---@field winopts? table Window options

---@class WorktreeTmux.NotifyConfig
---@field use_snacks boolean Whether to use snacks.nvim
---@field timeout number Notification display time (ms)

---@class WorktreeTmux.AsyncConfig
---@field show_progress boolean Whether to show progress notification
---@field rsync_timeout number Rsync timeout (seconds)

---@class WorktreeTmux.LogConfig
---@field level "trace"|"debug"|"info"|"warn"|"error"|"fatal" Log level
---@field use_console boolean Output to console
---@field use_file boolean Output to file
---@field debug_mode boolean Enable debug mode
---@field debug_file? string Debug log file path
---@field highlights boolean Enable highlights

---@class WorktreeTmux.Worktree
---@field path string Worktree path
---@field branch? string Branch name
---@field bare? boolean Whether it's a bare repository

---@class WorktreeTmux.TmuxWindow
---@field index number Window index
---@field name string Window name
---@field active boolean Whether it's the current active window

---@class WorktreeTmux.CreateWindowOpts
---@field session string Session name
---@field name string Window name
---@field cwd string Working directory
---@field cmd? string Startup command

---@class WorktreeTmux.SyncResult
---@field created number Number of created windows
---@field skipped number Number of skipped

---@class WorktreeTmux.DebugContext
---@field request_id string Request ID
---@field start_time number Start time
---@field logs table Log list
---@field data_flow table Data flow records

return {}
