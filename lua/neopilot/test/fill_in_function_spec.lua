-- luacheck: globals describe it assert
local _neopilot = require("neopilot")
local test_utils = require("neopilot.test.test_utils")
local eq = assert.are.same
local Levels = require("neopilot.logger.level")

--- @param content string[]
--- @param row number
--- @param col number
--- @param lang string?
--- @return _neopilot.test.Provider, number
local function setup(content, row, col, lang)
  lang = lang or "lua"
  local p = test_utils.TestProvider.new()
  _neopilot.setup({
    provider = p,
    logger = {
      error_cache_level = Levels.ERROR,
      type = "print",
    },
  })

  local buffer = test_utils.create_file(content, lang, row, col)
  return p, buffer
end

--- @param buffer number
--- @return string[]
local function r(buffer)
  return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
end

local content = {
  "",
  "local foo = function() end",
}
describe("fill_in_function", function()
  it("replace function contents", function()
    local p, buffer = setup(content, 2, 12)
    local state = _neopilot.__get_state()

    _neopilot.fill_in_function()

    eq(1, state:active_request_count())
    eq(content, r(buffer))

    p:resolve("success", "function()\n    return 42\nend")
    test_utils.next_frame()

    local expected_state = {
      "",
      "local foo = function()",
      "    return 42",
      "end",
    }
    eq(expected_state, r(buffer))
    eq(0, state:active_request_count())
  end)

  it("should test a typescript file", function()
    local ts_content = {
      "",
      "const foo = function() {}",
    }
    local p, buffer = setup(ts_content, 2, 12, "typescript")
    local state = _neopilot.__get_state()

    _neopilot.fill_in_function()

    eq(1, state:active_request_count())
    eq(ts_content, r(buffer))

    p:resolve("success", "function() {\n    return 42;\n}")
    test_utils.next_frame()

    local expected_state = {
      "",
      "const foo = function() {",
      "    return 42;",
      "}",
    }
    eq(expected_state, r(buffer))
    eq(0, state:active_request_count())
  end)

  it("should cancel request when stop_all_requests is called", function()
    local p, buffer = setup(content, 2, 12)
    _neopilot.fill_in_function()

    eq(content, r(buffer))

    assert.is_false(p.request.request:is_cancelled())
    assert.is_not_nil(p.request)
    assert.is_not_nil(p.request.request)

    _neopilot.stop_all_requests()
    test_utils.next_frame()

    assert.is_true(p.request.request:is_cancelled())

    p:resolve("success", "function foo()\n    return 42\nend")
    test_utils.next_frame()

    eq(content, r(buffer))
  end)

  it("should handle error cases with graceful failures", function()
    local p, buffer = setup(content, 2, 12)
    _neopilot.fill_in_function()

    eq(content, r(buffer))

    p:resolve("failed", "Something went wrong")
    test_utils.next_frame()

    eq(content, r(buffer))
  end)
end)
