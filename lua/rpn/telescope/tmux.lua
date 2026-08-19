-- Vendored from telescope-tmux.nvim's sessions/windows pickers, which drop the
-- session/window you are currently in (`valid = false`). Here it is listed first
-- and marked with "*" instead.
local tutils = require("telescope.utils")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local transform_mod = require("telescope.actions.mt").transform_mod
local utils = require("telescope._extensions.tmux.utils")
local tmux_commands = require("telescope._extensions.tmux.tmux_commands")

-- The marker goes on `display` only: `value` stays the raw session name / window id
-- that the previewers and actions target.
local function mark_current(entries, is_current)
	local ordered, current = {}, nil
	for _, entry in ipairs(entries) do
		if is_current(entry) then
			entry.display = "* " .. entry.display
			current = entry
		else
			entry.display = "  " .. entry.display
			table.insert(ordered, entry)
		end
	end
	if current then
		table.insert(ordered, 1, current)
	end
	return ordered
end

local function identity(entry)
	return entry
end

local function sessions(opts)
	opts = utils.apply_default_layout(opts)
	local session_ids = tmux_commands.list_sessions({ format = tmux_commands.session_id_fmt })
	local session_names = tmux_commands.list_sessions({ format = opts.entry_format or tmux_commands.session_name_fmt })
	local formatted_to_real_session_map = {}
	for i, v in ipairs(session_names) do
		formatted_to_real_session_map[v] = session_ids[i]
	end

	local current_session =
		tutils.get_os_command_output({ "tmux", "display-message", "-p", tmux_commands.session_id_fmt })[1]
	local current_client = tutils.get_os_command_output({ "tmux", "display-message", "-p", "#{client_tty}" })[1]

	local entries = {}
	for _, name in ipairs(session_names) do
		table.insert(entries, { value = name, display = name, ordinal = name })
	end
	entries = mark_current(entries, function(entry)
		return formatted_to_real_session_map[entry.value] == current_session
	end)

	local custom_actions = transform_mod({
		create_new_session = function(prompt_bufnr)
			local new_session = action_state.get_current_line()
			local confirmation = vim.fn.input("Create session '" .. new_session .. "'? [Y/n] ")
			if string.lower(confirmation) ~= "y" then
				return
			end
			local new_session_id = tutils.get_os_command_output({
				"tmux",
				"new-session",
				"-dP",
				"-s",
				new_session,
				"-F",
				"#{session_id}",
			})[1]
			tutils.get_os_command_output({ "tmux", "switch-client", "-t", new_session_id, "-c", current_client })
			actions.close(prompt_bufnr)
		end,
		delete_session = function(prompt_bufnr)
			local entry = action_state.get_selected_entry()
			local session_id = entry.value
			local session_display = entry.display
			local confirmation = vim.fn.input("Kill session '" .. session_display .. "'? [Y/n] ")
			if string.lower(confirmation) ~= "y" then
				return
			end
			tutils.get_os_command_output({ "tmux", "kill-session", "-t", session_id })
			actions.close(prompt_bufnr)
		end,
		rename_session = function(prompt_bufnr)
			local session = action_state.get_selected_entry().value
			local new_session_name = vim.fn.input("Enter new session name: ")
			if string.lower(new_session_name) == "" then
				return
			end
			tutils.get_os_command_output({ "tmux", "rename-session", "-t", session, new_session_name })
			actions.close(prompt_bufnr)
		end,
	})

	pickers
		.new(opts, {
			prompt_title = "Tmux Sessions",
			finder = finders.new_table({
				results = entries,
				entry_maker = identity,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					return { "tmux", "attach-session", "-t", formatted_to_real_session_map[entry.value], "-r" }
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					vim.cmd(string.format('silent !tmux switchc -t "%s" -c "%s"', selection.value, current_client))
					actions.close(prompt_bufnr)
				end)

				actions.close:enhance({
					post = function()
						if opts.quit_on_select then
							vim.cmd("q!")
						end
					end,
				})

				map("i", "<c-a>", custom_actions.create_new_session)
				map("n", "<c-a>", custom_actions.create_new_session)
				map("i", "<c-d>", custom_actions.delete_session)
				map("n", "<c-d>", custom_actions.delete_session)
				map("i", "<c-r>", custom_actions.rename_session)
				map("n", "<c-r>", custom_actions.rename_session)

				return true
			end,
		})
		:find()
end

local custom_window_actions = transform_mod({
	delete_window = function(prompt_bufnr)
		local entry = action_state.get_selected_entry()
		local window_id = entry.value
		local window_display = entry.display
		local confirmation = vim.fn.input("Kill window '" .. window_display .. "'? [Y/n] ")
		if string.lower(confirmation) ~= "y" then
			return
		end
		tmux_commands.kill_window(window_id)
		actions.close(prompt_bufnr)
	end,
})

local function windows(opts)
	opts = utils.apply_default_layout(opts)

	local window_ids = tmux_commands.list_windows({ format = tmux_commands.window_id_fmt })
	local display_windows = tmux_commands.list_windows({ format = opts.entry_format or "#S: #W" })
	local current_window =
		tutils.get_os_command_output({ "tmux", "display-message", "-p", tmux_commands.window_id_fmt })[1]

	local entries = {}
	for i, v in ipairs(display_windows) do
		table.insert(entries, { value = window_ids[i], display = v, ordinal = v })
	end
	entries = mark_current(entries, function(entry)
		return entry.value == current_window
	end)

	local dummy_session_name = "telescope-tmux-previewer"
	local current_client = tutils.get_os_command_output({ "tmux", "display-message", "-p", "#{client_tty}" })[1]

	local base_index = tmux_commands.get_base_index_option()

	pickers
		.new(opts, {
			prompt_title = "Tmux Windows",
			finder = finders.new_table({
				results = entries,
				entry_maker = identity,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			previewer = previewers.new_buffer_previewer({
				setup = function()
					vim.api.nvim_command(string.format("silent !tmux new-session -s %s -d", dummy_session_name))
					return {}
				end,
				define_preview = function(self, entry)
					-- We have to set the window buf manually to avoid a race condition where we try to attach to
					-- the tmux sessions before the buffer has been set in the window. This is because Telescope
					-- calls nvim_win_set_buf inside vim.schedule()
					vim.api.nvim_win_set_buf(self.state.winid, self.state.bufnr)
					local window_id = entry.value
					vim.api.nvim_buf_call(self.state.bufnr, function()
						if tutils.job_is_running(self.state.termopen_id) then
							vim.fn.jobstop(self.state.termopen_id)
						end
						local target_window_id = dummy_session_name .. ":" .. base_index
						tmux_commands.link_window(window_id, target_window_id)
						-- Need -r here to prevent resizing the window which will distort the view on the real client
						self.state.termopen_id =
							vim.fn.termopen(string.format("tmux attach -t %s -r", dummy_session_name))
					end)
				end,
				teardown = function()
					vim.api.nvim_command(string.format("silent !tmux kill-session -t %s", dummy_session_name))
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					vim.cmd(string.format('silent !tmux switchc -t "%s" -c "%s"', selection.value, current_client))
					actions.close(prompt_bufnr)
				end)
				actions.close:enhance({
					post = function()
						if opts.quit_on_select then
							vim.cmd("q")
						end
					end,
				})
				map("i", "<c-d>", custom_window_actions.delete_window)
				map("n", "<c-d>", custom_window_actions.delete_window)
				return true
			end,
		})
		:find()
end

return {
	sessions = sessions,
	windows = windows,
}
