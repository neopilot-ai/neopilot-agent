local uv = vim.uv or vim.loop

-- Create the logger module table
local M = {}

-- Define log levels with metatable to prevent modification
local levels = setmetatable({
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5,
    FATAL = 6,
    NONE = 7
}, {
    __newindex = function(_, k, _)
        error(string.format("Cannot modify log level '%s'", tostring(k)), 2)
    end,
    __metatable = false
})

--- @class FileSink
local FileSink = {}
FileSink.__index = FileSink

--- Create a new FileSink
--- @param path string
--- @return FileSink
function FileSink:new(path)
    local fd, err = uv.fs_open(path, "w", 493) -- 0755 in decimal
    if not fd then
        error(string.format("Failed to open log file %s: %s", path, err))
    end

    return setmetatable({
        fd = fd,
        path = path,
        buffer = {},
        buffer_size = 0,
        max_buffer_size = 8192, -- 8KB buffer
    }, self)
end

--- Write a line to the buffer, flushing if needed
--- @param str string
function FileSink:write_line(str)
    table.insert(self.buffer, str)
    self.buffer_size = self.buffer_size + #str + 1 -- +1 for newline
    
    if self.buffer_size >= self.max_buffer_size then
        self:flush()
    end
end

--- Flush the buffer to disk
function FileSink:flush()
    if #self.buffer == 0 then return end
    
    local success, err = uv.fs_write(
        self.fd, 
        table.concat(self.buffer, "\n") .. "\n"
    )
    
    if not success then
        error(string.format("Failed to write to log file %s: %s", self.path, err))
    end
    
    -- Reset buffer
    self.buffer = {}
    self.buffer_size = 0
end

--- Close the file handle
function FileSink:close()
    self:flush()
    if self.fd then
        local success, err = uv.fs_close(self.fd)
        if not success then
            error(string.format("Failed to close log file %s: %s", self.path, err))
        end
        self.fd = nil
    end
end

-- Add finalizer for automatic cleanup
FileSink.__gc = function(self)
    if self.fd then
        self:close()
    end
end

--- @class PrintSink
local PrintSink = {}
PrintSink.__index = PrintSink

function PrintSink:new()
    return setmetatable({}, self)
end

function PrintSink:write_line(str)
    print(str)
end

function PrintSink:close()
    -- No cleanup needed for print sink
end

--- @class Logger
local Logger = setmetatable({}, {
    __newindex = function(_, k, _)
        error(string.format("Cannot modify Logger.%s", tostring(k)), 2)
    end,
    __metatable = false
})
Logger.__index = Logger

-- Expose log levels through the Logger class
for k, v in pairs(levels) do
    rawset(Logger, k, v)
end

--- Create a new Logger instance
--- @param level number?
--- @return Logger
function Logger:new(level)
    level = level or levels.INFO
    local sink = PrintSink:new()
    return setmetatable({
        sink = sink,
        level = level,
    }, self)
end

--- Set the log level
--- @param level number
function Logger:set_level(level)
    self.level = level
end

--- Set a file sink for logging
--- @param path string
function Logger:file_sink(path)
    if self.sink and self.sink.close then
        self.sink:close()
    end
    self.sink = FileSink:new(path)
end

--- Log a message at TRACE level
--- @param message string
--- @param ... any
function Logger:trace(message, ...)
    self:log(levels.TRACE, message, ...)
end

--- Log a message at DEBUG level
--- @param message string
--- @param ... any
function Logger:debug(message, ...)
    self:log(levels.DEBUG, message, ...)
end

--- Log a message at INFO level
--- @param message string
--- @param ... any
function Logger:info(message, ...)
    self:log(levels.INFO, message, ...)
end

--- Log a message at WARN level
--- @param message string
--- @param ... any
function Logger:warn(message, ...)
    self:log(levels.WARN, message, ...)
end

--- Log a message at ERROR level
--- @param message string
--- @param ... any
function Logger:error(message, ...)
    self:log(levels.ERROR, message, ...)
end

--- Log a message at FATAL level
--- @param message string
--- @param ... any
function Logger:fatal(message, ...)
    self:log(levels.FATAL, message, ...)
end

--- Internal log method
--- @param level number
--- @param message string
--- @param ... any
function Logger:log(level, message, ...)
    if level < self.level then return end
    
    local level_name = "UNKNOWN"
    for name, lvl in pairs(levels) do
        if lvl == level then
            level_name = name
            break
        end
    end
    
    local formatted_msg = string.format("[%s] %s", level_name, message)
    if select('#', ...) > 0 then
        formatted_msg = string.format(formatted_msg, ...)
    end
    
    self.sink:write_line(formatted_msg)
end

--- Close the logger and release resources
function Logger:close()
    if self.sink and self.sink.close then
        self.sink:close()
    end
end

-- Module exports
local M = setmetatable({}, {
    __index = function(_, k)
        return levels[k]
    end,
    __newindex = function()
        error("Cannot modify log levels")
    end,
})

-- Create default logger instance
local default_logger = Logger:new(levels.INFO)

-- Export logger methods
for name, method in pairs(Logger) do
    if type(method) == "function" and name ~= "new" then
        M[name] = function(...)
            return method(default_logger, ...)
        end
    end
end

-- Export FileSink and PrintSink for testing
M.FileSink = FileSink
M.PrintSink = PrintSink

return M
