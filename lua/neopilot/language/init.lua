local Logger = require("neopilot.logger.logger")

--- @class _neopilot.LanguageOps
--- @field log_item fun(item_name: string): string
--- @field names table<string, string>

--- @class _neopilot.Langauges
--- @field languages table<string, _neopilot.LanguageOps>
local M = {
  languages = {},
}

--- @alias _neopilot.langauge.GetLangParam _neopilot.Location | number?

--- @param bufferOrLoc _neopilot.langauge.GetLangParam
--- @return _neopilot.LanguageOps
--- @return string
--- @return number
local function get_langauge(bufferOrLoc)
  if type(bufferOrLoc) == "number" or not bufferOrLoc then
    local buffer = bufferOrLoc or vim.api.nvim_get_current_buf()
    local file_type =
      vim.api.nvim_get_option_value("filetype", { buf = buffer })
    local lang = M.languages[file_type]
    if not lang then
      Logger:fatal("language currently not supported", "lang", file_type)
    end
    return lang, file_type, buffer
  end

  local file_type = bufferOrLoc.file_type
  local lang = M.languages[file_type]
  if not lang then
    Logger:fatal("language currently not supported", "lang", file_type)
  end
  return lang, file_type, bufferOrLoc.buffer
end

local function validate_function(fn, file_type)
  if type(fn) ~= "function" then
    Logger:fatal("language does not support log_item", "lang", file_type)
  end
end

--- @param _neopilot _neopilot.State
function M.initialize(_neopilot)
  M.languages = {}
  for _, lang in ipairs(_neopilot.languages) do
    M.languages[lang] = require("neopilot.language." .. lang)
  end
end

--- @param _ _neopilot.State
--- @param item_name string
--- @param buffer number?
--- @return string
function M.log_item(_, item_name, buffer)
  local lang, file_type = get_langauge(buffer)
  validate_function(lang.log_item, file_type)

  return lang.log_item(item_name)
end

--[[
-- i wrote this but now i dont know why i did...
-- i must have had a good reason but christmas break made me forget..
--- @param function_node any
---@param body_name string
function M.find_body(function_node, body_name)
    for child in function_node:iter_children() do
        print("test", child:type())
        if child:type() == body_name then
            return child
        else
            M.find_body(child, body_name)
        end
    end
    return nil
end

--- @param function_node _neopilot.treesitter.TSNode
--- @param buffer number
function M.get_body(function_node, buffer)
    local lang, file_type = get_langauge(buffer)
    local body = lang.names.body
    assert(body, "body is not defined in language", "language", file_type)
end
--]]

return M
