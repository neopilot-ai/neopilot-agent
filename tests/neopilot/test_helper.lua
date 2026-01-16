local M = {}

-- Test utilities
local test_hooks = {}

--- Register a before_each hook
function M.before_each(fn)
    table.insert(test_hooks, { type = "before_each", fn = fn })
end

--- Register an after_each hook
function M.after_each(fn)
    table.insert(test_hooks, { type = "after_each", fn = fn })
end

--- Run all hooks of a specific type
function M.run_hooks(hook_type)
    for _, hook in ipairs(test_hooks) do
        if hook.type == hook_type then
            hook.fn()
        end
    end
end

--- Assert that a function throws an error
--- @param func function
--- @param expected_error string|nil
function M.assert_error(func, expected_error)
    local success, err = pcall(func)
    if success then
        error("Expected an error but none was thrown")
    end
    
    if expected_error and not string.find(tostring(err), expected_error, 1, true) then
        error(string.format("Expected error to contain '%s' but got: %s", expected_error, tostring(err)))
    end
    
    return err
end

--- Create a mock buffer for testing
--- @param lines string[]
--- @return number buffer_id
function M.create_mock_buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    if lines and #lines > 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end
    return buf
end

--- Clean up a mock buffer
--- @param buf_id number
function M.cleanup_buffer(buf_id)
    if vim.api.nvim_buf_is_valid(buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
    end
end

-- Simple test framework
function M.describe(desc, fn)
    print("\n" .. desc)
    fn()
end

function M.it(desc, fn)
    M.run_hooks("before_each")
    
    local success, err = pcall(function()
        fn()
        M.run_hooks("after_each")
    end)
    
    if success then
        print("  ✓ " .. desc)
    else
        print("  ✗ " .. desc .. "\n    " .. tostring(err))
    end
    
    return success
end

return M
