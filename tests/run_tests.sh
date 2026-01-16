#!/bin/bash
cd "$(dirname "$0")"  # Change to tests directory

# Create a minimal init.lua
cat > minimal_init.lua << 'EOF'
-- Minimal Neovim configuration for testing
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- Set up package path
local project_root = vim.fn.fnamemodify(vim.fn.getcwd(), ':h')
package.path = string.format(
  "%s;%s/lua/?.lua;%s/lua/?/init.lua;%s",
  package.path or "",
  project_root,
  project_root,
  "/usr/share/nvim/runtime/lua/?.lua"
)
EOF

# Run tests with minimal configuration
nvim --headless \
  -u minimal_init.lua \
  -c "lua dofile('run_isolated_tests.lua')" \
  -c "q"

# Clean up
rm -f minimal_init.lua