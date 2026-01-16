local helpers = require("neopilot.extensions.agents.helpers")
local M = {}

--- @class _neopilot.Agents.Rule
--- @field name string
--- @field path string

--- @class _neopilot.Agents.Rules
--- @field cursor _neopilot.Agents.Rule[]
--- @field custom _neopilot.Agents.Rule[]

--- @class _neopilot.Agents.Agent
--- @field rules _neopilot.Agents.Rules

---@param _neopilot _neopilot.State
---@return _neopilot.Agents.Rules
function M.rules(_neopilot)
  local cursor = helpers.ls(_neopilot.completion.cursor_rules)
  local custom = {}
  for _, path in ipairs(_neopilot.completion.custom_rules or {}) do
    local custom_rule = helpers.ls(path)
    for _, c in ipairs(custom_rule) do
      table.insert(custom, c)
    end
  end
  return {
    cursor = cursor,
    custom = custom,
  }
end

--- @param rules _neopilot.Agents.Rules
--- @return _neopilot.Agents.Rule[]
function M.rules_to_items(rules)
  local items = {}
  for _, rule in ipairs(rules.cursor or {}) do
    table.insert(items, rule)
  end
  for _, rule in ipairs(rules.custom or {}) do
    table.insert(items, rule)
  end
  return items
end

--- @param rules _neopilot.Agents.Rules
---@param path string
---@return _neopilot.Agents.Rule | nil
function M.get_rule_by_path(rules, path)
  for _, rule in ipairs(rules.cursor or {}) do
    if rule.path == path then
      return rule
    end
  end
  for _, rule in ipairs(rules.custom or {}) do
    if rule.path == path then
      return rule
    end
  end
  return nil
end

--- @param rules _neopilot.Agents.Rules
---@param token string
---@return boolean
function M.is_rule(rules, token)
  for _, rule in ipairs(rules.cursor or {}) do
    if rule.path == token then
      return true
    end
  end
  for _, rule in ipairs(rules.custom or {}) do
    if rule.path == token then
      return true
    end
  end
  return false
end

--- @param rules _neopilot.Agents.Rules
--- @param haystack string
--- @return _neopilot.Agents.Rule[]
function M.find_rules(rules, haystack)
  --- @type _neopilot.Agents.Rule[]
  local out = {}

  for word in haystack:gmatch("@%S+") do
    local rule_string = word:sub(2)
    local rule = M.get_rule_by_path(rules, rule_string)
    if rule then
      table.insert(out, rule)
    end
  end

  return out
end

return M
