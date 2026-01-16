local Logger = require("neopilot.logger.logger")
local Level = require("neopilot.logger.level")
local ops = require("neopilot.ops")
local Languages = require("neopilot.language")
local Window = require("neopilot.window")
local get_id = require("neopilot.id")
local RequestContext = require("neopilot.request-context")
local Range = require("neopilot.geo").Range
local Extensions = require("neopilot.extensions")
local Agents = require("neopilot.extensions.agents")

---@param path_or_rule string | _neopilot.Agents.Rule
---@return _neopilot.Agents.Rule | string
local function expand(path_or_rule)
  if type(path_or_rule) == "string" then
    return vim.fn.expand(path_or_rule)
  end
  return {
    name = path_or_rule.name,
    path = vim.fn.expand(path_or_rule.path),
  }
end

--- @param opts _neopilot.ops.Opts?
--- @return _neopilot.ops.Opts
local function process_opts(opts)
  opts = opts or {}
  for i, rule in ipairs(opts.additional_rules or {}) do
    opts.additional_rules[i] = expand(rule)
  end
  return opts
end

--- @alias _neopilot.Cleanup fun(): nil

--- @class _neopilot.StateProps
--- @field model string
--- @field md_files string[]
--- @field prompts _neopilot.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _neopilot.Provider?
--- @field __active_requests _neopilot.Cleanup[]
--- @field __view_log_idx number

--- @return _neopilot.StateProps
local function create_neopilot_state()
  return {
    model = "opencode/claude-sonnet-4-5",
    md_files = {},
    prompts = require("neopilot.prompt-settings"),
    ai_stdout_rows = 3,
    languages = { "lua", "go", "java", "cpp" },
    display_errors = false,
    __active_requests = {},
    __view_log_idx = 1,
  }
end

--- @class _neopilot.Completion
--- @field source "cmp" | nil
--- @field custom_rules string[]
--- @field cursor_rules string | nil defaults to .cursor/rules

--- @class _neopilot.Options
--- @field logger _neopilot.Logger.Options?
--- @field model string?
--- @field md_files string[]?
--- @field provider _neopilot.Provider?
--- @field debug_log_prefix string?
--- @field display_errors? boolean
--- @field completion _neopilot.Completion?

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _neopilot.State
--- @field completion _neopilot.Completion
--- @field model string
--- @field md_files string[]
--- @field prompts _neopilot.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _neopilot.Provider?
--- @field rules _neopilot.Agents.Rules
--- @field __active_requests _neopilot.Cleanup[]
--- @field __view_log_idx number
local _neopilot_State = {}
_neopilot_State.__index = _neopilot_State

--- @return _neopilot.State
function _neopilot_State.new()
  local props = create_neopilot_state()
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable(props, _neopilot_State)
end

--- TODO: This is something to understand.  I bet that this is going to need
--- a lot of performance tuning.  I am just reading every file, and this could
--- take a decent amount of time if there are lots of rules.
---
--- Simple perfs:
--- 1. read 4096 bytes at a tiem instead of whole file and parse out lines
--- 2. don't show the docs
--- 3. do the operation once at setup instead of every time.
---    likely not needed to do this all the time.
function _neopilot_State:refresh_rules()
  self.rules = Agents.rules(self)
  Extensions.refresh(self)
end

local _active_request_id = 0
---@param clean_up _neopilot.Cleanup
---@return number
function _neopilot_State:add_active_request(clean_up)
  _active_request_id = _active_request_id + 1
  Logger:debug("adding active request", "id", _active_request_id)
  self.__active_requests[_active_request_id] = clean_up
  return _active_request_id
end

function _neopilot_State:active_request_count()
  local count = 0
  for _ in pairs(self.__active_requests) do
    count = count + 1
  end
  return count
end

---@param id number
function _neopilot_State:remove_active_request(id)
  local logger = Logger:set_id(id)
  local r = self.__active_requests[id]
  logger:assert(r, "there is no active request for id.  implementation broken")
  logger:debug("removing active request")
  self.__active_requests[id] = nil
end

local _neopilot_state = _neopilot_State.new()

--- @class _neopilot
local _neopilot = {
  DEBUG = Level.DEBUG,
  INFO = Level.INFO,
  WARN = Level.WARN,
  ERROR = Level.ERROR,
  FATAL = Level.FATAL,
}

--- you can only set those marks after the visual selection is removed
local function set_selection_marks()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "x",
    false
  )
end

--- @param operation_name string
--- @return _neopilot.RequestContext
local function get_context(operation_name)
  _neopilot_state:refresh_rules()
  local trace_id = get_id()
  local context = RequestContext.from_current_buffer(_neopilot_state, trace_id)
  context.logger:debug("neopilot Request", "method", operation_name)
  return context
end

function _neopilot.info()
  local info = {}
  table.insert(
    info,
    string.format(
      "Agent Files: %s",
      table.concat(_neopilot_state.md_files, ", ")
    )
  )
  table.insert(info, string.format("Model: %s", _neopilot_state.model))
  table.insert(
    info,
    string.format("AI Stdout Rows: %d", _neopilot_state.ai_stdout_rows)
  )
  table.insert(
    info,
    string.format(
      "Display Errors: %s",
      tostring(_neopilot_state.display_errors)
    )
  )
  table.insert(
    info,
    string.format("Active Requests: %d", _neopilot_state:active_request_count())
  )
  Window.display_centered_message(info)
end

--- @param path string
--- @return _neopilot.Agents.Rule?
function _neopilot.rule_from_path(_, path)
  path = expand(path) --[[ @as string]]
  return Agents.get_rule_by_path(_neopilot_state.rules, path)
end

--- @param opts? _neopilot.ops.Opts
function _neopilot.fill_in_function_prompt(opts)
  opts = process_opts(opts)
  local context = get_context("fill-in-function-with-prompt")

  context.logger:debug("start")
  Window.capture_input({
    cb = function(success, response)
      context.logger:debug(
        "capture_prompt",
        "success",
        success,
        "response",
        response
      )
      if success then
        opts.additional_prompt = response
        ops.fill_in_function(context, opts)
      end
    end,
    on_load = function()
      Extensions.setup_buffer(_neopilot_state)
    end,
  })
end

--- @param opts? _neopilot.ops.Opts
function _neopilot.fill_in_function(opts)
  opts = process_opts(opts)
  ops.fill_in_function(get_context("fill_in_function"), opts)
end

--- @param opts _neopilot.ops.Opts
function _neopilot.visual_prompt(opts)
  opts = process_opts(opts)
  local context = get_context("over-range-with-prompt")
  context.logger:debug("start")
  Window.capture_input({
    cb = function(success, response)
      context.logger:debug(
        "capture_prompt",
        "success",
        success,
        "response",
        response
      )
      if success then
        opts.additional_prompt = response
        _neopilot.visual(context, opts)
      end
    end,
    on_load = function()
      Extensions.setup_buffer(_neopilot_state)
    end,
  })
end

--- @param context _neopilot.RequestContext?
--- @param opts _neopilot.ops.Opts?
function _neopilot.visual(context, opts)
  opts = process_opts(opts)
  --- TODO: Talk to teej about this.
  --- Visual selection marks are only set in place post visual selection.
  --- that means for this function to work i must escape out of visual mode
  --- which i dislike very much.  because maybe you dont want this
  set_selection_marks()

  context = context or get_context("over-range")
  local range = Range.from_visual_selection()
  ops.over_range(context, range, opts)
end

--- View all the logs that are currently cached.  Cached log count is determined
--- by _neopilot.Logger.Options that are passed in.
function _neopilot.view_logs()
  _neopilot_state.__view_log_idx = 1
  local logs = Logger.logs()
  if #logs == 0 then
    print("no logs to display")
    return
  end
  Window.display_full_screen_message(logs[1])
end

function _neopilot.prev_request_logs()
  local logs = Logger.logs()
  if #logs == 0 then
    print("no logs to display")
    return
  end
  _neopilot_state.__view_log_idx =
    math.min(_neopilot_state.__view_log_idx + 1, #logs)
  Window.display_full_screen_message(logs[_neopilot_state.__view_log_idx])
end

function _neopilot.next_request_logs()
  local logs = Logger.logs()
  if #logs == 0 then
    print("no logs to display")
    return
  end
  _neopilot_state.__view_log_idx =
    math.max(_neopilot_state.__view_log_idx - 1, 1)
  Window.display_full_screen_message(logs[_neopilot_state.__view_log_idx])
end

function _neopilot.stop_all_requests()
  for _, clean_up in pairs(_neopilot_state.__active_requests) do
    clean_up()
  end
  _neopilot_state.__active_requests = {}
end

--- if you touch this function you will be fired
--- @return _neopilot.State
function _neopilot.__get_state()
  return _neopilot_state
end

--- @param opts _neopilot.Options?
function _neopilot.setup(opts)
  opts = opts or {}
  _neopilot_state = _neopilot_State.new()
  _neopilot_state.provider_override = opts.provider
  _neopilot_state.completion = opts.completion
    or {
      source = nil,
      custom_rules = {},
    }
  _neopilot_state.completion.cursor_rules = _neopilot_state.completion.cursor_rules
    or ".cursor/rules/"
  _neopilot_state.completion.custom_rules = _neopilot_state.completion.custom_rules
    or {}

  local crules = _neopilot_state.completion.custom_rules
  for i, rule in ipairs(crules) do
    crules[i] = expand(rule)
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      _neopilot.stop_all_requests()
    end,
  })

  Logger:configure(opts.logger)

  if opts.model then
    assert(type(opts.model) == "string", "opts.model is not a string")
    _neopilot_state.model = opts.model
  end

  if opts.md_files then
    assert(type(opts.md_files) == "table", "opts.md_files is not a table")
    for _, md in ipairs(opts.md_files) do
      _neopilot.add_md_file(md)
    end
  end

  _neopilot_state.display_errors = opts.display_errors or false

  _neopilot_state:refresh_rules()
  Languages.initialize(_neopilot_state)
  Extensions.init(_neopilot_state)
end

--- @param md string
--- @return _neopilot
function _neopilot.add_md_file(md)
  table.insert(_neopilot_state.md_files, md)
  return _neopilot
end

--- @param md string
--- @return _neopilot
function _neopilot.rm_md_file(md)
  for i, name in ipairs(_neopilot_state.md_files) do
    if name == md then
      table.remove(_neopilot_state.md_files, i)
      break
    end
  end
  return _neopilot
end

--- @param model string
--- @return _neopilot
function _neopilot.set_model(model)
  _neopilot_state.model = model
  return _neopilot
end

function _neopilot.__debug()
  Logger:configure({
    path = nil,
    level = Level.DEBUG,
  })
end

return _neopilot
