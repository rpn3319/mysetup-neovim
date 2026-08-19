# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a Neovim configuration written in Lua, organized under the `rpn` namespace. The configuration follows a modular structure:

- **Entry Point**: `init.lua` loads core config and lazy.nvim plugin manager
- **Core Configuration**: `lua/rpn/core/` contains options, keymaps, and initialization
- **Plugin Management**: Uses lazy.nvim with lazy-loading. Plugins are auto-imported from `lua/rpn/plugins/` and `lua/rpn/plugins/lsp/`
- **Custom Plugins**: `lua/augment_apply/` is a local plugin for applying code blocks from AI assistants

### Configuration Flow

1. `init.lua` → loads `rpn.core` and `rpn.lazy`
2. `rpn.core` → loads options and keymaps from `lua/rpn/core/`
3. `rpn.lazy` → bootstraps lazy.nvim and imports all plugin specs from `lua/rpn/plugins/` and `lua/rpn/plugins/lsp/`
4. Each plugin file in those directories returns a lazy.nvim plugin spec table

### LSP Architecture (CRITICAL)

**This config uses the NEW `vim.lsp.config` API (0.11+), NOT `lspconfig.setup()`**

- ESLint is configured using `vim.lsp.config()` and enabled with `vim.lsp.enable()` in `lua/rpn/plugins/lsp/lspconfig.lua`
- Mason auto-installs LSP servers defined in `lua/rpn/plugins/lsp/mason.lua`
- LSP keymaps are set via `LspAttach` autocmd in lspconfig.lua
- Uses UTF-16 encoding with a monkey-patch for `make_position_params()`
- ESLint has auto-fix on save via `BufWritePre` autocmd

### Treesitter Architecture (CRITICAL)

**This config uses `romus204/tree-sitter-manager.nvim`, NOT `nvim-treesitter`.**

The old `nvim-treesitter` (master branch) was archived and breaks on Neovim 0.12+
(`require("nvim-treesitter.configs")` no longer exists). We migrated to
tree-sitter-manager, a lightweight 0.12+ parser manager.

- Config in `lua/rpn/plugins/treesitter.lua` via `require("tree-sitter-manager").setup()`
- Requires the **`tree-sitter` CLI** (install with `brew install tree-sitter-cli` — NOT
  `brew install tree-sitter`, which is the library only) plus git and a C compiler
- Parsers compile to `~/.local/share/nvim/site/parser/*.dylib` (the native runtimepath);
  highlight queries copy to `~/.local/share/nvim/site/queries/<lang>/`
- Provides **parser management + highlighting only**. It does NOT provide treesitter
  indentation or incremental selection — those were dropped from the plugin during the
  migration (Neovim's native filetype indent is used instead). Incremental selection was
  later re-added as a **native standalone module** built directly on `vim.treesitter`
  (`lua/rpn/core/treesitter-incsel.lua`), NOT through tree-sitter-manager — see
  "Incremental Selection (native)" below
- Auto-tagging is handled by `nvim-ts-autotag`, set up standalone via its own
  `require("nvim-ts-autotag").setup()` in `treesitter.lua` (NOT via a nvim-treesitter option)
- Commands: `:TSManager` (TUI), `:TSInstall <lang>`, `:TSUninstall <lang>`, `:TSUpdate`
- Add parsers by appending to `ensure_installed` in `treesitter.lua`

**Gotcha — missing highlight queries:** `tree-sitter-manager` installs each parser as an
async chain (compile → copy queries). If that chain is interrupted, you can end up with a
compiled parser but NO highlight queries, so the language parses but renders with no colors.
Because the plugin's `is_installed` check only looks for the compiled parser, plain
`:TSInstall <lang>` will NOT fix this (it skips already-compiled parsers). To recover, force a
clean reinstall: `:TSUninstall <lang>` then `:TSInstall <lang>`. Languages Neovim bundles
queries for (c, lua, markdown, query, vim, vimdoc) still highlight even when the plugin's copy
is missing — JS/TS/yaml/bash/etc. do not, so they're where this bug shows up. To diagnose,
compare `~/.local/share/nvim/site/parser/` against `~/.local/share/nvim/site/queries/`.

**Incremental Selection (native):** Implemented in `lua/rpn/core/treesitter-incsel.lua`,
loaded eagerly from `lua/rpn/core/init.lua`. It is built **directly on the core
`vim.treesitter` API** (NOT tree-sitter-manager, NOT nvim-treesitter) and keeps a
per-buffer stack of selected ranges. Keymaps: `<C-Space>` in normal mode starts a
selection on the node under the cursor; `<C-Space>` in visual mode expands to the
enclosing parent node; `<BS>` in visual mode shrinks back to the previous range
(`<BS>` and `<C-@>`/`<Nul>` aliases are mapped for terminal Ctrl+Space compatibility).
Safe in non-parsed buffers (no-op when there's no node).

### Formatting vs LSP

- **Formatting**: Uses conform.nvim (`lua/rpn/plugins/formatting.lua`)
- **Format on save**: `lsp_fallback = false` - only uses configured formatters, NOT LSP
- **Manual format**: `<leader>mp` or `:Format` with `lsp_fallback = true`
- Prettier is the main formatter for JS/TS/web files
- ESLint fixes on save are separate (via LSP autocmd in lspconfig.lua)

### AI Assistant System

This config supports multiple AI assistants via environment variables:

- `NVIM_AI_ASSISTANT_COMPLETIONS`: Controls inline completions (`github_copilot` or `augment`)
- `NVIM_AI_ASSISTANT_CHAT`: Controls chat interface (`github_copilot`, `augment`, or `claude`)
- Configuration in `lua/rpn/plugins/ai-assistant.lua`
- The `augment_apply` plugin (`<leader>aa` in visual mode) applies code blocks with metadata headers like:
  ```
  path=/path/to/file mode=EDIT
  code content here
  ```
  Modes: `EDIT` (replace), `APPEND`, `PREPEND`

## Common Commands

### Plugin Management

```bash
# Update all plugins
nvim -c "Lazy update"

# Install/update LSP servers and tools
nvim -c "Mason"
```

### Treesitter Parsers

```vim
:TSManager           " Open the parser manager TUI
:TSInstall <lang>    " Install a parser (skips if already compiled)
:TSUninstall <lang>  " Remove a parser AND its queries (use before reinstalling)
:TSUpdate            " Update parsers
```

### Formatting & Linting

```vim
:Format              " Format current file/selection
:FormatDisable       " Disable format-on-save globally
:FormatDisable!      " Disable format-on-save for current buffer
:FormatEnable        " Re-enable format-on-save
<leader>mp           " Manual format (normal/visual mode)
<leader>ll           " Trigger linting for current file
```

### LSP Commands

```vim
:LspRestart          " Restart LSP server
:ESLintDebug         " Debug ESLint configuration
<leader>rs           " Restart LSP (keymap)
```

### Diagnostics

```vim
:checkhealth         " Check Neovim health (dependencies, LSP, etc.)
```

## Key Configuration Details

### Plugin Spec Structure

Each file in `lua/rpn/plugins/` returns a table (or array of tables) for lazy.nvim:

```lua
return {
  "author/plugin-name",
  dependencies = { "other/plugin" },
  event = { "BufReadPre", "BufNewFile" }, -- lazy-load trigger
  config = function()
    -- Plugin setup here
  end,
}
```

### Adding New Plugins

1. Create a new `.lua` file in `lua/rpn/plugins/` (or `lua/rpn/plugins/lsp/` for LSP-related)
2. Return a lazy.nvim spec table
3. Lazy.nvim will auto-import it on next launch

### Custom Keymaps

Core keymaps are in `lua/rpn/core/keymaps.lua`. Plugin-specific keymaps are typically in their respective plugin config files.

Leader key: `<Space>`

### Colorscheme

- Uses `melange` colorscheme with transparent background
- Background transparency set in `init.lua` (lines 16-24)

### Autocommands

Plugin-specific autocommands are in their respective config files. The main ones:

- **Format on save**: In `lua/rpn/plugins/formatting.lua` via conform.nvim
- **ESLint fix on save**: In `lua/rpn/plugins/lsp/lspconfig.lua` (line 117-122)
- **LSP keymaps**: Attached via `LspAttach` autocmd in lspconfig.lua
- **Linting triggers**: In `lua/rpn/plugins/linting.lua` on `BufEnter`, `BufWritePost`, `InsertLeave`
- **Treesitter highlight**: tree-sitter-manager registers a `FileType` autocmd that calls `vim.treesitter.start` (set up inside `require("tree-sitter-manager").setup()` in `treesitter.lua`)

## File Organization Patterns

- Options: Modify `lua/rpn/core/options.lua`
- Global keymaps: Modify `lua/rpn/core/keymaps.lua`
- New plugin: Add file to `lua/rpn/plugins/` or `lua/rpn/plugins/lsp/`
- LSP servers: Add to `ensure_installed` in `lua/rpn/plugins/lsp/mason.lua`
- Formatters: Add to `formatters_by_ft` in `lua/rpn/plugins/formatting.lua`
- Linters: Add to `linters_by_ft` in `lua/rpn/plugins/linting.lua`

## Important Notes for Modifications

1. **Never use `lspconfig.setup()`** - This config uses the new `vim.lsp.config()` API
2. **Format on save only uses formatters** - `lsp_fallback = false` is intentional
3. **Lazy.nvim auto-imports** - Just create files in plugin directories, no need to manually require
4. **Plugin configs are lazy-loaded** - Use appropriate `event`, `cmd`, `keys`, or `ft` triggers
5. **The `rpn` namespace** - All custom Lua modules are under `lua/rpn/`
6. **Archived plugins** - Check `lua/_archived_plugins/` before adding similar functionality
7. **Never use `nvim-treesitter`** - This config uses `tree-sitter-manager.nvim` (see Treesitter Architecture). Don't reintroduce `nvim-treesitter` or `require("nvim-treesitter.configs")` — it's broken on 0.12+
8. **No treesitter indent via tree-sitter-manager** - it doesn't provide indent; don't try to re-add it through the plugin. Incremental selection IS available, but as a native module on `vim.treesitter` (`lua/rpn/core/treesitter-incsel.lua`) — never re-add it through tree-sitter-manager
9. **Treesitter "no colors" bug** - A parser without copied queries highlights nothing. Fix with `:TSUninstall <lang>` then `:TSInstall <lang>`, NOT a plain `:TSInstall` (see Treesitter Architecture gotcha)
10. **Tmux pickers are overridden locally** - `camgraff/telescope-tmux.nvim` hardcodes `valid = false` on the current session/window, so Telescope hides it. `lua/rpn/telescope/tmux.lua` vendors both pickers with that filter removed (current entry marked `*` and listed first) and `lua/rpn/plugins/telescope.lua` assigns them over `telescope.extensions.tmux` after `load_extension("tmux")`. `~/.tmux.conf` (`prefix+s` / `prefix+w`) still calls `:Telescope tmux sessions|windows`, so keep those export names
