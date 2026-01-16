--- @class _neopilot.window.Module
--- @field active_windows _neopilot.window.Window[]
local M = {
  active_windows = {},
}
local nsid = vim.api.nvim_create_namespace("neopilot.window.error")
local nvim_win_is_valid = vim.api.nvim_win_is_valid

--- @class _neopilot.window.Config
--- @field width number
--- @field height number
--- @field row number?
--- @field col number?
--- @field anchor string?

--- @class _neopilot.window.Window
--- @field config _neopilot.window.Config
--- @field win_id number
--- @field buf_id number

--- @param lines string[]
--- @return string[]
local function ensure_no_new_lines(lines)
  local display_lines = {}
  for _, line in ipairs(lines) do
    local split_lines = vim.split(line, "\n")
    for _, clean_line in ipairs(split_lines) do
      table.insert(display_lines, clean_line)
    end
  end
  return display_lines
end

--- @return number
--- @return number
local function get_ui_dimensions()
  local ui = vim.api.nvim_list_uis()[1]
  return ui.width, ui.height
end

--- @return _neopilot.window.Config
local function create_window_top_config()
  local width, _ = get_ui_dimensions()
  return {
    width = width - 2,
    height = 3,
    anchor = "NE",
  }
end

--- @return _neopilot.window.Config
local function create_window_top_left_config()
  local width, _ = get_ui_dimensions()
  return {
    width = math.floor(width / 3),
    height = 3,
    anchor = "NE",
  }
end

--- @return _neopilot.window.Config
local function create_window_full_screen()
  local width, height = get_ui_dimensions()
  return {
    width = width - 2,
    height = height - 2,
    anchor = "NE",
  }
end

--- @param config _neopilot.window.Config
---@param offset_bottom number | nil
--- @return _neopilot.window.Config
local function create_window_inside(config, offset_bottom)
  offset_bottom = offset_bottom or 0
  return {
    width = config.width - 2,
    height = 1,
    row = config.row + config.height - offset_bottom,
    col = config.col + 1,
    anchor = config.anchor,
  }
end

--- @return _neopilot.window.Config
local function create_centered_window()
  local width, height = get_ui_dimensions()
  local win_width = math.floor(width * 2 / 3)
  local win_height = math.floor(height / 3)
  return {
    width = win_width,
    height = win_height,
    row = math.floor((height - win_height) / 2),
    col = math.floor((width - win_width) / 2),
  }
end

--- @param config _neopilot.window.Config
--- @param win_config vim.api.keyset.win_config
--- @return _neopilot.window.Window
local function create_floating_window(config, win_config)
  local buf_id = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = "editor",
    width = config.width,
    height = config.height,
    row = config.row or 0,
    col = config.col or 0,
    anchor = config.anchor,
    style = "minimal",
    border = win_config.border,
    title = win_config.title,
    title_pos = "center",
    zindex = win_config.zindex,
  })
  local window = {
    config = config,
    win_id = win_id,
    buf_id = buf_id,
  }
  vim.wo[win_id].wrap = true

  table.insert(M.active_windows, window)
  return window
end

--- @param window _neopilot.window.Window
local function highlight_error(window)
  local line_count = vim.api.nvim_buf_line_count(window.buf_id)

  if line_count > 0 then
    vim.api.nvim_buf_set_extmark(window.buf_id, nsid, 0, 0, {
      end_row = 1,
      hl_group = "Normal",
      hl_eol = true,
    })
  end

  if line_count > 1 then
    vim.api.nvim_buf_set_extmark(window.buf_id, nsid, 1, 0, {
      end_row = line_count,
      hl_group = "ErrorMsg",
      hl_eol = true,
    })
  end
end

--- @param error_text string
--- @return _neopilot.window.Window
function M.display_error(error_text)
  local window = create_floating_window(create_window_top_config(), {
    title = " neopilot Error ",
    border = "rounded",
  })
  local lines = vim.split(error_text, "\n")

  table.insert(lines, 1, "")
  table.insert(
    lines,
    1,
    "neopilot: Fatal operational error encountered (error logs may have more in-depth information)"
  )

  vim.api.nvim_buf_set_lines(window.buf_id, 0, -1, false, lines)
  highlight_error(window)
  return window
end

--- @param window _neopilot.window.Window
local function window_close(window)
  if nvim_win_is_valid(window.win_id) then
    vim.api.nvim_win_close(window.win_id, true)
  end
  if vim.api.nvim_buf_is_valid(window.buf_id) then
    vim.api.nvim_buf_delete(window.buf_id, { force = true })
  end
end

--- @param text string
function M.display_cancellation_message(text)
  local config = create_window_top_left_config()
  local window = create_floating_window(config, {
    title = " neopilot Cancelled ",
    border = "rounded",
  })
  local lines = vim.split(text, "\n")

  vim.api.nvim_buf_set_lines(window.buf_id, 0, -1, false, lines)

  vim.api.nvim_buf_set_extmark(window.buf_id, nsid, 0, 0, {
    end_row = vim.api.nvim_buf_line_count(window.buf_id),
    hl_group = "WarningMsg",
    hl_eol = true,
  })

  vim.defer_fn(function()
    if nvim_win_is_valid(window.win_id) then
      M.clear_active_popups()
    end
  end, 5000)

  return window
end

--- TODO: i dont like how the other interfaces have text being passed in
--- but this one is lines.  probably need to revisit this
--- @param lines string[]
function M.display_full_screen_message(lines)
  --- TODO: i really dislike that i am closing and opening windows
  --- i think it would be better to perserve the one that is already open
  --- but i just want this to work and then later... ohh much later, ill fix
  --- this basic nonsense
  M.clear_active_popups()
  local window = create_floating_window(create_window_full_screen(), {
    title = " neopilot ",
    border = "rounded",
  })
  local display_lines = ensure_no_new_lines(lines)
  vim.api.nvim_buf_set_lines(window.buf_id, 0, -1, false, display_lines)
end

--- @return _neopilot.window.Window
--- @return _neopilot.window.Config
function M.create_centered_window()
  M.clear_active_popups()
  local config = create_centered_window()
  local window = create_floating_window(config, {
    title = " neopilot ",
    border = "rounded",
  })
  return window, config
end

--- @param message string[]
function M.display_centered_message(message)
  M.clear_active_popups()
  local config = create_centered_window()
  local window = create_floating_window(config, {
    title = " neopilot ",
    border = "rounded",
  })
  local display_lines = ensure_no_new_lines(message)

  vim.api.nvim_buf_set_lines(window.buf_id, 0, -1, false, display_lines)

  return window
end

--- @param win _neopilot.window.Window
--- @param name string
local function set_defaul_win_options(win, name)
  vim.api.nvim_buf_set_name(win.buf_id, name)
  vim.wo[win.win_id].number = true
  vim.bo[win.buf_id].filetype = "neopilot"
  vim.bo[win.buf_id].buftype = "acwrite"
  vim.bo[win.buf_id].bufhidden = "wipe"
  vim.bo[win.buf_id].swapfile = false
end

--- @class _neopilot.window.CaptureInputOpts
--- @field cb fun(success: boolean, result: string): nil
--- @field on_load? fun(): nil

--- @param _opts _neopilot.window.CaptureInputOpts
function M.capture_input(_opts)
  M.clear_active_popups()

  local config = create_centered_window()
  local win = create_floating_window(config, {
    title = " neopilot Prompt ",
    border = "rounded",
  })

  set_defaul_win_options(win, "neopilot-prompt")
  vim.api.nvim_set_current_win(win.win_id)

  local group = vim.api.nvim_create_augroup(
    "neopilot_present_prompt_" .. win.buf_id,
    { clear = true }
  )

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = win.buf_id,
    callback = function()
      if nvim_win_is_valid(win.win_id) then
        vim.api.nvim_set_current_win(win.win_id)
      else
        M.clear_active_popups()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    buffer = win.buf_id,
    callback = function()
      if not nvim_win_is_valid(win.win_id) then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(win.buf_id, 0, -1, false)
      local result = table.concat(lines, "\n")
      M.clear_active_popups()
      _opts.cb(true, result)
    end,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    buffer = win.buf_id,
    callback = function()
      if not nvim_win_is_valid(win.win_id) then
        return
      end
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win.win_id),
    callback = function()
      if not nvim_win_is_valid(win.win_id) then
        return
      end
      M.clear_active_popups()
      _opts.cb(false, "")
    end,
  })

  vim.keymap.set("n", "q", function()
    M.clear_active_popups()
    _opts.cb(false, "")
  end, { buffer = win.buf_id, nowait = true })

  if _opts.on_load then
    vim.schedule(_opts.on_load)
  end
end

function M.clear_active_popups()
  for _, window in ipairs(M.active_windows) do
    window_close(window)
  end
  M.active_windows = {}
end

return M
