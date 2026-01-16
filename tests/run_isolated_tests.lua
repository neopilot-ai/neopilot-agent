-- Minimal test environment setup
local M = {}

-- Set up minimal vim global
_G.vim = _G.vim or {}
if not _G.vim.api then
    _G.vim.api = {
        nvim_buf_get_lines = function(_, start, end_, _)
            return {string.format("Test line %d to %d", start + 1, end_)}
        end,
        nvim_buf_set_lines = function(_, start, end_, _, lines)
            return true
        end,
        nvim_win_get_cursor = function()
            return {1, 0} -- 1-based line, 0-based column
        end,
        nvim_win_set_cursor = function(_, _) end,
        nvim_buf_is_valid = function() return true end,
        nvim_buf_delete = function() end,
        nvim_create_buf = function() return 1 end,
        nvim_buf_set_name = function() end,
        nvim_create_autocmd = function(_, _) end,
        nvim_err_writeln = function(msg) print("ERROR: " .. msg) end,
    }
end

-- Set up uv if not available
if not _G.vim.loop then
    _G.vim.loop = {
        fs_open = function(_, _, _) return 1 end,
        fs_write = function() return true end,
        fs_close = function() return true end,
        fs_fstat = function() return {size = 100} end,
        fs_read = function(_, size) return string.rep("x", size) end,
    }
end

-- Set up package path
local project_root = vim.fn.fnamemodify(vim.fn.getcwd(), ':h')
package.path = string.format(
    "%s;%s/lua/?.lua;%s/lua/?/init.lua;%s",
    package.path or "",
    project_root,
    project_root,
    "/usr/share/nvim/runtime/lua/?.lua"
)

-- Load test files
local test_files = {
    "neopilot/test_point",
    "neopilot/test_range",
    "neopilot/test_logger",
    "neopilot/test_init"
}

-- Run tests
local passed = 0
local failed = 0

for _, test_file in ipairs(test_files) do
    local ok, err = pcall(dofile, test_file .. ".lua")
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("\nError in %s: %s", test_file, tostring(err)))
    end
end

-- Print summary
print("\n" .. string.rep("=", 40))
print(string.format("TEST SUMMARY"))
print(string.rep("-", 20))
print(string.format("Total:  %d", passed + failed))
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
print(string.rep("=", 40) .. "\n")

-- Exit with appropriate status
os.exit(failed > 0 and 1 or 0)
