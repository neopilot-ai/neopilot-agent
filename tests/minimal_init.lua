local root = vim.fn.fnamemodify('./.nvim', ':p')

-- Set up packpath
vim.opt.packpath:prepend(root .. '/site')
vim.opt.runtimepath:prepend('.')
vim.opt.runtimepath:prepend(root .. '/site/pack/*/start/*')

-- Install test dependencies
local function ensure_packer()
  local install_path = root .. '/site/pack/packer/start/packer.nvim'
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({
      'git', 'clone', '--depth=1',
      'https://github.com/wbthomason/packer.nvim',
      install_path
    })
  end
  vim.cmd('packadd packer.nvim')
  return require('packer')
end

local packer = ensure_packer()
packer.init({
  package_root = root .. '/site/pack/',
  compile_path = root .. '/plugin/packer_compiled.lua',
})

-- Install dependencies
packer.startup(function(use)
  use 'wbthomason/packer.nvim'
  use 'nvim-lua/plenary.nvim'
  use 'nvim-treesitter/nvim-treesitter'
  use './' -- This project
end)

-- Load test helpers
require('neopilot.test_helper').setup()
