-- 最小化测试环境配置

-- 设置运行时路径
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
local nui_path = vim.fn.stdpath("data") .. "/lazy/nui.nvim"

vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(plenary_path)
vim.opt.runtimepath:append(nui_path)

-- 设置基本选项
vim.cmd("runtime plugin/plenary.vim")
vim.o.swapfile = false
vim.bo.swapfile = false
