-- Minimal test environment configuration

-- Set runtime paths
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
local nui_path = vim.fn.stdpath("data") .. "/lazy/nui.nvim"

vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(plenary_path)
vim.opt.runtimepath:append(nui_path)

-- Set basic options
vim.cmd("runtime plugin/plenary.vim")
vim.o.swapfile = false
vim.bo.swapfile = false
