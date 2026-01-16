-- luacheck: globals describe it assert
local Agents = require("neopilot.extensions.agents")
local eq = assert.are.same

local function c(t, item)
  return vim.tbl_contains(t, function(v)
    return vim.deep_equal(v, item)
  end, { predicate = true })
end

local function a(p)
  return vim.fs.joinpath(vim.uv.cwd(), p)
end

local cursor_mds = {
  { name = "database", path = a("scratch/cursor/rules/database.mdc") },
  { name = "my-proj", path = a("scratch/cursor/rules/my-proj.mdc") },
}
local custom_mds = {
  { name = "back-end", path = a("scratch/custom_rules/back-end.md") },
  { name = "foo", path = a("scratch/custom_rules/foo.md") },
  { name = "front-end", path = a("scratch/custom_rules/front-end.md") },
  { name = "vim.lsp", path = a("scratch/custom_rules/vim.lsp.md") },
  { name = "vim", path = a("scratch/custom_rules/vim.md") },
  {
    name = "vim.treesitter",
    path = a("scratch/custom_rules/vim.treesitter.md"),
  },
}

--- @return _neopilot.State
local function r(cursor, custom)
  return {
    completion = {
      cursor_rules = cursor,
      custom_rules = { custom },
    },
  }
end

local function string_rules()
  return string.format(
    [[
    Here is a long sentense with @%s these types of rules @%s that should be parsed in the correct order
    and it should be awesome @%s
    ]],
    cursor_mds[1].path,
    custom_mds[2].path,
    custom_mds[4].path
  ),
    {
      cursor_mds[1],
      custom_mds[2],
      custom_mds[4],
    }
end

--- @param rules _neopilot.Agents.Rules
local function test_cursor(rules)
  for _, cursor in ipairs(cursor_mds) do
    eq(true, c(rules.cursor, cursor))
    eq(false, c(rules.custom, cursor))
  end
end

--- @param rules _neopilot.Agents.Rules
local function test_custom(rules)
  for _, custom in ipairs(custom_mds) do
    eq(true, c(rules.custom, custom))
    eq(false, c(rules.cursor, custom))
  end
end
describe("neopilot.agents.helpers", function()
  it(
    "should generate rules from _neopilot state with completion rules",
    function()
      local _neopilot = r("scratch/cursor/rules", "scratch/custom_rules/")
      local rules = Agents.rules(_neopilot)
      test_cursor(rules)
      test_custom(rules)
    end
  )

  it("generate without cursor", function()
    local _neopilot = r("foo/bar/bazz", "scratch/custom_rules/")
    local rules = Agents.rules(_neopilot)
    test_custom(rules)
  end)

  it("generate without custom", function()
    local _neopilot = r("scratch/cursor/rules")
    local rules = Agents.rules(_neopilot)
    test_cursor(rules)
  end)

  it(
    "should validate that tokens exist, in both custom and cursor, and incorrect tokens",
    function()
      local _neopilot = r("scratch/cursor/rules", "scratch/custom_rules/")
      local rules = Agents.rules(_neopilot)

      eq(true, Agents.is_rule(rules, a("scratch/cursor/rules/database.mdc")))
      eq(true, Agents.is_rule(rules, a("scratch/cursor/rules/my-proj.mdc")))
      eq(true, Agents.is_rule(rules, a("scratch/custom_rules/back-end.md")))
      eq(true, Agents.is_rule(rules, a("scratch/custom_rules/foo.md")))
      eq(true, Agents.is_rule(rules, a("scratch/custom_rules/front-end.md")))
      eq(true, Agents.is_rule(rules, a("scratch/custom_rules/vim.lsp.md")))
      eq(true, Agents.is_rule(rules, a("scratch/custom_rules/vim.md")))
      eq(
        true,
        Agents.is_rule(rules, a("scratch/custom_rules/vim.treesitter.md"))
      )
      eq(false, Agents.is_rule(rules, "nonexistent"))
      eq(false, Agents.is_rule(rules, "invalid-token"))
      eq(false, Agents.is_rule(rules, ""))
    end
  )

  it("find all the existing rules", function()
    local _neopilot = r("scratch/cursor/rules", "scratch/custom_rules/")
    local rules = Agents.rules(_neopilot)
    local prompt, expected_rules = string_rules()
    local found_rules = Agents.find_rules(rules, prompt)

    eq(expected_rules, found_rules)
  end)
end)
