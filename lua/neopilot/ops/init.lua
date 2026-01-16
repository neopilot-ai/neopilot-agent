--- @class _neopilot.ops.Opts
--- @field additional_prompt? string
--- @field additional_rules? _neopilot.Agents.Rule[]
return {
  fill_in_function = require("neopilot.ops.fill-in-function"),
  implement_fn = require("neopilot.ops.implement-fn"),
  over_range = require("neopilot.ops.over-range"),
}
