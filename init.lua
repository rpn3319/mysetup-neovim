require("rpn.core")
require("rpn.lazy")

-- small cleanup command to your init.lua/vimrc so that on startup it purges old temp files automatically
local s = vim.fn.stdpath("state") .. "/shada"
if vim.fn.isdirectory(s) == 1 then
	for _, f in ipairs(vim.fn.globpath(s, "main.shada.tmp.*", false, true)) do
		vim.loop.fs_unlink(f)
	end
end

vim.o.termguicolors = true

vim.cmd("colorscheme bamboo")

-- Make background transparent
-- vim.cmd([[
--   hi Normal       guibg=NONE ctermbg=NONE
--   hi NormalNC     guibg=NONE ctermbg=NONE
--   hi Pmenu        guibg=NONE ctermbg=NONE
--   hi SignColumn   guibg=NONE ctermbg=NONE
--   hi VertSplit    guibg=NONE ctermbg=NONE
--   hi StatusLineNC guibg=NONE ctermbg=NONE
-- ]])
