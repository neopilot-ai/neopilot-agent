-- Set up package path to include project's lua directory
local project_root = vim.fn.fnamemodify(vim.fn.getcwd(), ':h')
package.path = string.format(
    "%s;%s/?.lua;%s/?/init.lua;%s",
    package.path,
    project_root .. "/lua",
    project_root .. "/lua",
    package.path
)

print("Project root: " .. project_root)
print("Package path: " .. package.path)

print("\nStarting Neopilot Test Suite" .. string.rep("=", 40))

-- Track test statistics
local stats = {
    total = 0,
    passed = 0,
    failed = 0,
    start_time = os.clock()
}

-- Simple test runner
local function run_test_suite(name, test_fn)
    print("\n" .. string.upper(name) .. " TESTS")
    print(string.rep("-", #name + 7))
    
    local success, err = pcall(test_fn)
    if not success then
        print("\nERROR in " .. name .. " suite: " .. tostring(err))
        stats.failed = stats.failed + 1
    end
    
    print("\n" .. string.rep("-", #name + 7))
    print("COMPLETED " .. string.upper(name) .. " TESTS")
end

-- Run test suites
local test_suites = {
    ["Point"] = function()
        dofile("neopilot/test_point.lua")
    end,
    ["Range"] = function()
        dofile("neopilot/test_range.lua")
    end,
    ["Logger"] = function()
        dofile("neopilot/test_logger.lua")
    end,
    ["Initialization"] = function()
        dofile("neopilot/test_init.lua")
    end
}

-- Run all test suites
for name, test_fn in pairs(test_suites) do
    stats.total = stats.total + 1
    run_test_suite(name, test_fn)
end

-- Calculate and display summary
local elapsed = os.clock() - stats.start_time
local passed = stats.total - stats.failed

print("\n" .. string.rep("=", 40))
print(string.format("TEST SUMMARY"))
print(string.rep("-", 20))
print(string.format("Total:  %d", stats.total))
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", stats.failed))
print(string.format("Time:   %.3f seconds", elapsed))
print(string.rep("=", 40) .. "\n")

-- Exit with appropriate status code
if stats.failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
