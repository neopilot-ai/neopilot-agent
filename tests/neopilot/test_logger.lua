local helper = require("neopilot.test_helper")
local describe = helper.describe
local it = helper.it
local before_each = helper.before_each
local after_each = helper.after_each

-- Load the module
local Logger = require("neopilot.logger")
local uv = vim.uv or vim.loop

describe("Logger Tests", function()
    local temp_file = "/tmp/neopilot_test_logger.log"
    
    before_each(function()
        -- Clean up any existing test file
        pcall(os.remove, temp_file)
    end)
    
    after_each(function()
        -- Clean up test file
        pcall(os.remove, temp_file)
    end)
    
    describe("Basic Logging", function()
        it("should log messages at or above the current level", function()
            local messages = {}
            local test_logger = Logger:new(Logger.INFO)
            
            -- Mock the sink
            test_logger.sink = {
                write_line = function(_, msg)
                    table.insert(messages, msg)
                end,
                close = function() end
            }
            
            test_logger:debug("This should not appear")
            test_logger:info("Info message")
            test_logger:warn("Warning message")
            test_logger:error("Error message")
            
            assert(#messages == 3, "Should log 3 messages (info, warn, error)")
            assert(string.find(messages[1], "INFO") and string.find(messages[1], "Info message"), 
                "Should log info message")
        end)
        
        it("should respect log levels", function()
            local messages = {}
            local test_logger = Logger:new(Logger.ERROR)
            
            -- Mock the sink
            test_logger.sink = {
                write_line = function(_, msg)
                    table.insert(messages, msg)
                end,
                close = function() end
            }
            
            test_logger:info("This should not appear")
            test_logger:warn("This should not appear")
            test_logger:error("This should appear")
            
            assert(#messages == 1, "Should only log ERROR level messages")
            assert(string.find(messages[1], "ERROR"), "Should log error message")
        end)
    end)
    
    describe("File Sink", function()
        it("should write logs to a file", function()
            local file_sink = Logger.FileSink:new(temp_file)
            
            -- Write test messages
            file_sink:write_line("[INFO] Test message 1")
            file_sink:write_line("[WARN] Test message 2")
            file_sink:flush()
            
            -- Read the file back
            local fd = uv.fs_open(temp_file, "r", 438) -- 438 = 0666 in decimal
            assert(fd, "Failed to open log file for reading")
            
            local stat = uv.fs_fstat(fd)
            local data = uv.fs_read(fd, stat.size, 0)
            uv.fs_close(fd)
            
            assert(string.find(data, "Test message 1"), "Should contain first message")
            assert(string.find(data, "Test message 2"), "Should contain second message")
            
            -- Clean up
            file_sink:close()
        end)
        
        it("should handle file write errors", function()
            local status, err = pcall(function()
                local sink = Logger.FileSink:new("/invalid/path/to/log/file.log")
            end)
            
            assert(not status, "Should fail to open invalid file path")
            assert(string.find(tostring(err), "Failed to open log file"), "Should indicate file open error")
        end)
    end)
    
    describe("Print Sink", function()
        it("should write to standard output", function()
            local captured = {}
            local original_print = print
            
            -- Mock print function
            _G.print = function(...)
                table.insert(captured, table.concat({...}, "\t"))
            end
            
            local print_sink = Logger.PrintSink:new()
            print_sink:write_line("Test message")
            
            -- Restore print
            _G.print = original_print
            
            assert(#captured == 1, "Should call print once")
            assert(captured[1] == "Test message", "Should print the correct message")
        end)
    end)
    
    describe("Module Interface", function()
        it("should provide log level constants", function()
            local levels = {
                TRACE = 1,
                DEBUG = 2,
                INFO = 3,
                WARN = 4,
                ERROR = 5,
                FATAL = 6,
                NONE = 7
            }
            
            for name, value in pairs(levels) do
                assert(Logger[name] == value, string.format("Should provide %s level", name))
            end
        end)
    end)
    
    describe("Cleanup", function()
        it("should close file handles on garbage collection", function()
            local file_sink = Logger.FileSink:new(temp_file)
            file_sink:write_line("Test message")
            
            -- Force garbage collection
            file_sink = nil
            collectgarbage()
            
            -- Verify file was closed by checking if we can delete it
            local ok = os.remove(temp_file)
            assert(ok, "Should be able to delete file after GC")
        end)
    end)
end)

print("\nAll Logger tests completed")
