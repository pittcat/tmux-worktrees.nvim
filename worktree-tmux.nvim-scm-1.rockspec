local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "worktree-tmux.nvim"
version = MODREV .. SPECREV

description = {
    summary = "Git Worktree + Tmux Window automation for Neovim",
    detailed = [[
        Automatically create and manage tmux windows when creating git worktrees.
        Provides unified management of worktrees in a dedicated tmux session.
    ]],
    labels = { "neovim", "git", "worktree", "tmux" },
    homepage = "https://github.com/yourusername/worktree-tmux.nvim",
    license = "MIT",
}

dependencies = {
    "lua >= 5.1",
    "plenary.nvim",
}

source = {
    url = "git://github.com/yourusername/worktree-tmux.nvim",
}

build = {
    type = "builtin",
    copy_directories = {
        "plugin",
        "doc",
    },
}
