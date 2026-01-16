local Agents = require("neopilot.extensions.agents")
local Helpers = require("neopilot.extensions.agents.helpers")
local SOURCE = "neopilot"

--- @class _neopilot.Extensions.CmpItem
--- @field rule _neopilot.Agents.Rule
--- @field docs string

--- @param _neopilot _neopilot.State
--- @return _neopilot.Extensions.CmpItem[]
local function rules(_neopilot)
  local agent_rules = Agents.rules_to_items(_neopilot.rules)
  local out = {}
  for _, rule in ipairs(agent_rules) do
    table.insert(out, {
      rule = rule,
      docs = Helpers.head(rule.path),
    })
  end
  return out
end

--- @class CmpSource
--- @field _neopilot _neopilot.State
--- @field items _neopilot.Extensions.CmpItem[]
local CmpSource = {}
CmpSource.__index = CmpSource

--- @param _neopilot _neopilot.State
function CmpSource.new(_neopilot)
  return setmetatable({
    _neopilot = _neopilot,
    items = rules(_neopilot),
  }, CmpSource)
end

function CmpSource.is_available()
  return true
end

function CmpSource.get_debug_name()
  return SOURCE
end

function CmpSource.get_keyword_pattern()
  return [[@\k\+]]
end

function CmpSource.get_trigger_characters()
  return { "@" }
end

--- @class CompletionItem
--- @field label string
--- @field kind number kind is optional but gives icons / categories
--- @field documentation string can be a string or markdown table
--- @field detail string detail shows a right-side hint

--- @class Completion
--- @field items CompletionItem[]
--- @field isIncomplete boolean -
-- true: I might return more if user types more
-- false: this result set is complete
function CmpSource:complete(params, callback)
  local before = params.context.cursor_before_line or ""
  local items = {} --[[ @as CompletionItem[] ]]

  if #before > 1 and before:sub(#before - 1) ~= " @" then
    callback({
      items = {},
      isIncomplete = false,
    })
    return
  end

  for _, item in ipairs(self.items) do
    table.insert(items, {
      label = item.rule.name,
      insertText = item.rule.path,
      filterText = item.rule.name,
      kind = 17, -- file
      documentation = {
        kind = "markdown",
        value = item.docs,
      },
      detail = item.rule.path,
    })
  end

  callback({
    items = items,
    isIncomplete = false,
  })
end

--- TODO: Look into what this could be
function CmpSource.resolve(completion_item, callback)
  callback(completion_item)
end

function CmpSource.execute(completion_item, callback)
  callback(completion_item)
end

--- @type CmpSource | nil
local source = nil

--- @param _ _neopilot.State
local function init_for_buffer(_)
  local cmp = require("cmp")
  cmp.setup.buffer({
    sources = {
      { name = SOURCE },
    },
    window = {
      completion = {
        zindex = 1001,
      },
      documentation = {
        zindex = 1001,
      },
    },
  })
end

--- @param _neopilot _neopilot.State
local function init(_neopilot)
  assert(
    source == nil,
    "the source must be nil when calling init on an completer"
  )

  local cmp = require("cmp")
  source = CmpSource.new(_neopilot)
  source.items = rules(_neopilot)
  cmp.register_source(SOURCE, source)
end

--- @param _neopilot _neopilot.State
local function refresh_state(_neopilot)
  if not source then
    return
  end
  source.items = rules(_neopilot)
end

--- @type _neopilot.Extensions.Source
local source_wrapper = {
  init_for_buffer = init_for_buffer,
  init = init,
  refresh_state = refresh_state,
}
return source_wrapper
