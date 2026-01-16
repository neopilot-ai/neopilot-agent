local helper = require("neopilot.test_helper")
local describe = helper.describe
local it = helper.it
local before_each = helper.before_each
local after_each = helper.after_each

-- Load the module
local neopilot = require("neopilot")

describe("NeoPilot Initialization Tests", function()
    local original_instance
    
    before_each(function()
        -- Save original instance if it exists
        original_instance = neopilot._instance
        -- Reset the module
        package.loaded["neopilot"] = nil
        neopilot = require("neopilot")
    end)
    
    after_each(function()
        -- Cleanup and restore
        if neopilot.cleanup then
            pcall(neopilot.cleanup)
        end
        if original_instance then
            neopilot._instance = original_instance
        end
    end)
    
    describe("Module Setup", function()
        it("should expose setup function", function()
            assert(type(neopilot.setup) == "function", "setup should be a function")
        end)
        
        it("should expose cleanup function", function()
            assert(type(neopilot.cleanup) == "function", "cleanup should be a function")
        end)
        
        it("should expose fill_in_function", function()
            assert(type(neopilot.fill_in_function) == "function", "fill_in_function should be available")
        end)
    end)
    
    describe("Setup Functionality", function()
        it("should initialize with default options", function()
            local instance = neopilot.setup()
            assert(neopilot._instance ~= nil, "Should create an instance")
            assert(instance == neopilot._instance, "Should return the instance")
        end)
        
        it("should return same instance on multiple calls", function()
            local instance1 = neopilot.setup()
            local instance2 = neopilot.setup()
            assert(instance1 == instance2, "Should return same instance")
        end)
        
        it("should initialize with custom logger options", function()
            local log_file = "/tmp/neopilot_test.log"
            local instance = neopilot.setup({
                logger = {
                    level = 2, -- DEBUG
                    path = log_file
                }
            })
            
            -- Verify logger was configured
            -- This is a simple check; in a real test, you might want to verify the file was created
            assert(instance.logger ~= nil, "Should have a logger instance")
            
            -- Clean up test file
            os.remove(log_file)
        end)
    end)
    
    describe("Cleanup Functionality", function()
        it("should clean up resources", function()
            neopilot.setup()
            assert(neopilot._instance ~= nil, "Instance should exist before cleanup")
            
            neopilot.cleanup()
            assert(neopilot._instance == nil, "Instance should be nil after cleanup")
        end)
        
        it("should be safe to call multiple times", function()
            neopilot.setup()
            neopilot.cleanup()
            local status, err = pcall(neopilot.cleanup)
            assert(status, "Cleanup should be safe to call multiple times")
        end)
    end)
    
    describe("Fill In Function", function()
        it("should require initialization", function()
            -- Reset the module to uninitialized state
            neopilot.cleanup()
            
            local status, err = pcall(neopilot.fill_in_function)
            assert(not status, "Should fail when not initialized")
            assert(string.find(err, "not initialized"), "Should indicate not initialized")
        end)
        
        it("should call instance method", function()
            -- Setup a mock instance
            local called = false
            neopilot._instance = {
                fill_in_function = function()
                    called = true
                    return true, "success"
                end
            }
            
            local success, result = neopilot.fill_in_function()
            assert(called, "Should call instance method")
            assert(success == true, "Should return success status")
            assert(result == "success", "Should return result from instance")
        end)
    end)
    
    describe("Auto Cleanup on Vim Exit", function()
        it("should set up VimLeavePre autocommand", function()
            local mock_vim = {
                api = {
                    nvim_create_autocmd = function(event, opts)
                        assert(event == "VimLeavePre", "Should set up VimLeavePre autocommand")
                        assert(type(opts.callback) == "function", "Should provide callback function")
                    end
                }
            }
            
            -- Temporarily replace vim global
            local original_vim = _G.vim
            _G.vim = mock_vim
            
            -- Reload the module to trigger setup
            package.loaded["neopilot"] = nil
            require("neopilot")
            
            -- Restore vim global
            _G.vim = original_vim
        end)
    end)
end)

print("\nAll Initialization tests completed")
