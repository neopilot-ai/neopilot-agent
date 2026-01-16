local Logger = require("neopilot.logger")
local editor = require("neopilot.editor")
local Point = require("neopilot.geo").Point

--- @class LoggerOptions
--- @field level number?
--- @field path string?

--- @class _neopilotOptions
--- @field logger LoggerOptions?

--- @class _neopilot
local _neopilot = {}
_neopilot.__index = _neopilot

--- @param opts _neopilotOptions
--- @return _neopilot
function _neopilot:new(opts)
    opts = opts or {}
    local instance = setmetatable({
        logger = Logger:new(opts.logger and opts.logger.level),
        _initialized = false,
    }, self)
    
    -- Set up file sink if path is provided
    if opts.logger and opts.logger.path then
        instance.logger:file_sink(opts.logger.path)
    end
    
    return instance
end

--- Fill in function implementation
--- @return boolean success
--- @return string? error_message
function _neopilot:fill_in_function()
    if not self._initialized then
        return false, "NeoPilot not initialized"
    end
    
    self.logger:debug("fill_in_function called")
    
    local success, ts = pcall(require, "neopilot.editor.treesitter")
    if not success then
        self.logger:error("Failed to load treesitter module: %s", ts)
        return false, "Failed to load treesitter module"
    end
    
    local cursor = Point:from_cursor()
    local scopes, err = ts.scopes(cursor)
    
    if not scopes then
        self.logger:error("Failed to get scopes: %s", err or "unknown error")
        return false, err or "Failed to get scopes"
    end
    
    self.logger:debug("Scopes: %s", vim.inspect(scopes))
    return true, scopes
end

--- Initialize the NeoPilot instance
--- @param opts _neopilotOptions?
--- @return _neopilot
local function init(opts)
    opts = opts or {}
    
    -- Create new instance
    local instance = _neopilot:new(opts)
    instance._initialized = true
    
    instance.logger:info("NeoPilot initialized with options: %s", vim.inspect(opts))
    
    return instance
end

-- Module table
local M = {
    _instance = nil,
    _initialized = false
}

--- Setup NeoPilot with the given options
--- @param opts _neopilotOptions?
--- @return _neopilot
function M.setup(opts)
    if M._instance then
        M.logger:warn("NeoPilot already initialized, returning existing instance")
        return M._instance
    end
    
    M._instance = init(opts)
    M._initialized = true
    
    -- Set up autocommands
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            M.cleanup()
        end,
    })
    
    return M._instance
end

--- Cleanup resources
function M.cleanup()
    if M._instance then
        if M._instance.logger then
            M._instance.logger:debug("Cleaning up NeoPilot")
            M._instance.logger:close()
        end
        M._instance = nil
    end
    M._initialized = false
end

-- For backward compatibility
local function _fill_in_function()
    if not M._instance then
        vim.notify("NeoPilot not initialized. Call require('neopilot').setup() first", vim.log.levels.ERROR)
        return
    end
    return M._instance:fill_in_function()
end

-- Set up the module
M.setup()

-- Return the module
return setmetatable(M, {
    __index = function(_, k)
        if k == "fill_in_function" then
            return _fill_in_function
        end
        return M._instance and M._instance[k]
    end,
})