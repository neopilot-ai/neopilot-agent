local cmp = require("neopilot.extensions.cmp")

--- @class _neopilot.Extensions.Source
--- @field init_for_buffer fun(_neopilot: _neopilot.State): nil
--- @field init fun(_neopilot: _neopilot.State): nil
--- @field refresh_state fun(_neopilot: _neopilot.State): nil

--- @param completion _neopilot.Completion | nil
--- @return _neopilot.Extensions.Source | nil
local function get_source(completion)
  if not completion or not completion.source then
    return
  end
  local source = completion.source
  if source == "cmp" then
    return cmp
  end
end

return {
  --- @param _neopilot _neopilot.State
  init = function(_neopilot)
    local source = get_source(_neopilot.completion)
    if not source then
      return
    end
    source.init(_neopilot)
  end,

  --- @param _neopilot _neopilot.State
  setup_buffer = function(_neopilot)
    local source = get_source(_neopilot.completion)
    if not source then
      return
    end
    source.init_for_buffer(_neopilot)
  end,

  --- @param _neopilot _neopilot.State
  refresh = function(_neopilot)
    local source = get_source(_neopilot.completion)
    if not source then
      return
    end
    source.refresh_state(_neopilot)
  end,
}
