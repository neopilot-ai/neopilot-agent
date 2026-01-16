R("neopilot")
local _neopilot = require("neopilot")
_neopilot.setup({
  completion = {
    custom_rules = {
      "~/.behaviors/",
    },
    source = "cmp",
  },
})
local Ext = require("neopilot.extensions")
local Agents = require("neopilot.extensions.agents")
local Helpers = require("neopilot.extensions.agents.helpers")

print(vim.inspect(Agents.rules(_neopilot.__get_state())))
print(vim.inspect(Helpers.ls("/home/neopilot-ai/.behaviors")))

--- @class Config
--- @field width number
--- @field height number
--- @field offset_row number
--- @field offset_col number
--- @field border string
function create_window(config)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Configure the floating window
  local win_config = {
    relative = 'editor',
    width = config.width,
    height = config.height,
    row = config.offset_row,
    col = config.offset_col,
    style = 'minimal',
    border = 'rounded'
  }

  -- Open the floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end
