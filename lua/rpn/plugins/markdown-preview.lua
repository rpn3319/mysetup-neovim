return {
	"iamcco/markdown-preview.nvim",
	ft = { "markdown" },
	-- npm install rewrites the repo's tracked app/yarn.lock, which makes every
	-- subsequent `Lazy update` abort on local changes. The installer fetches a
	-- prebuilt binary instead and leaves the worktree clean.
	build = function()
		vim.cmd([[Lazy load markdown-preview.nvim]])
		vim.fn["mkdp#util#install_sync"](true)
	end,
	init = function()
		vim.g.mkdp_filetypes = { "markdown" }
	end,
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
}
