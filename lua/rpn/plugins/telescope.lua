return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
		"folke/todo-comments.nvim",
		"nvim-telescope/telescope-live-grep-args.nvim",
		"camgraff/telescope-tmux.nvim",
	},
	config = function()
		local telescope = require("telescope")

		telescope.setup({
			defaults = {
				preview = true,

				-- Use default config is better than "smart"
				-- path_display = { "smart" },

				-- Customize the width for the window
				layout_strategy = "horizontal",
				layout_config = {
					horizontal = { width = 0.8 },
				},
			},
		})

		-- Loading extensions
		telescope.load_extension("fzf")
		telescope.load_extension("live_grep_args")
		telescope.load_extension("tmux")

		-- Upstream telescope-tmux hides the current session/window; list them instead
		local tmux = require("rpn.telescope.tmux")
		telescope.extensions.tmux.sessions = tmux.sessions
		telescope.extensions.tmux.windows = tmux.windows

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		-- Keymaps
		keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Find keymaps" })

		-- Files
		local fuzzyhiddencmd = "<cmd>Telescope find_files find_command=rg,--ignore,--hidden,--files,-u<cr>"
		local fuzzyfindcmd = "<cmd>Telescope find_files hidden=true find_command=rg,--files,--hidden,--glob,!.git<cr>"
		keymap.set("n", "<leader>ff", fuzzyfindcmd, { desc = "Fuzzy find files in cwd (respects .gitignore only)" })
		keymap.set("n", "<leader>fu", fuzzyhiddencmd, { desc = "Fuzzy incl. hidden and ignore" })
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy recent files" })

		-- Jump
		keymap.set("n", "<leader>fj", "<cmd>Telescope jumplist<cr>", { desc = "Find jump list" })

		-- Quickfix list
		keymap.set("n", "<leader>fqq", "<cmd>Telescope quickfix<cr>", { desc = "Find quickfix" })
		keymap.set("n", "<leader>fqh", "<cmd>Telescope quickfixhistory<cr>", { desc = "Find quickfix history" })

		-- Grep
		local grep_extra_args = function()
			return { "--hidden", "--glob", "!.git" }
		end
		keymap.set("n", "<leader>fgg", function()
			require("telescope.builtin").live_grep({ additional_args = grep_extra_args })
		end, { desc = "Find string in cwd (respects .gitignore only)" })
		keymap.set("n", "<leader>fga", function()
			require("telescope").extensions.live_grep_args.live_grep_args({ additional_args = grep_extra_args })
		end, { desc = "live_grep_args (respects .gitignore only)" })

		-- Git
		keymap.set("n", "<leader>fgs", "<cmd>Telescope git_status<cr>", { desc = "Telescope git_status" })
		keymap.set("n", "<leader>fgb", "<cmd>Telescope git_bcommits<cr>", { desc = "Telescope git_bcommits" })

		-- Buffer
		local fuzzycurrbuf = "<cmd>Telescope current_buffer_fuzzy_find<cr>"
		keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Telescope buffers" })
		keymap.set("n", "<leader>fc", fuzzycurrbuf, { desc = "Fuzzy current buffer" })

		-- Todo
		keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
	end,
}

---
