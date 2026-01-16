std = luajit
cache = true
codes = true
ignore = {
    "111", -- Setting an undefined global variable. (for ok, _ = pcall...)
    "211", -- Unused local variable.
    "214", -- Unused variable with unused hint (handling _neopilot)
    "411", -- Redefining a local variable.
    "122", -- Setting read-only field of global vim
    "631", -- Line too long (handled by formatter)
}

read_globals = { 
    "vim", "describe", "it", "bit", "assert", "before_each", "after_each",
    "_neopilot" -- Add _neopilot as a global to avoid unused variable warnings
}

top_blocks = true
allow_defined = true

-- Ignore specific files or patterns if needed
-- exclude_files = {
--     "lua/neopilot/window/init.lua",
-- }
