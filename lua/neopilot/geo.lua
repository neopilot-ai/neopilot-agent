-- Projection factor for converting 2D coordinates to 1D for efficient comparison
local project_row = 100000000

--- Project a point or row/col to a 1D coordinate for comparison
--- @param point_or_row Point | number
--- @param col number | nil
--- @return number
local function project(point_or_row, col)
    if type(point_or_row) == "number" then
        assert(type(col) == "number", "col must be a number when point_or_row is a number")
        assert(col >= 1, "col must be a positive number")
        return point_or_row * project_row + col
    end
    return point_or_row.row * project_row + point_or_row.col
end

--- @class Point
--- @field row number 1-based row number
--- @field col number 1-based column number
local Point = {}
Point.__index = Point

--- Create a new Point instance
--- @param row number 1-based row number
--- @param col number 1-based column number
--- @return Point
function Point:new(row, col)
    -- Input validation with test-expected error messages
    if type(row) ~= "number" or row < 1 then
        error("row must be a positive number", 2)
    end
    if type(col) ~= "number" or col < 1 then
        error("col must be a positive number", 2)
    end
    
    -- Floor the values to ensure they're integers
    return setmetatable({
        row = math.floor(row),
        col = math.floor(col),
    }, self)
end

--- Create a Point from the current cursor position
--- @return Point
function Point.from_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return Point:new(cursor[1], cursor[2] + 1) -- Convert from 0-based to 1-based
end

--- Convert to string representation
--- @return string
function Point:to_string()
    return string.format("Point(row=%d, col=%d)", self.row, self.col)
end

--- Get the text line at this point's row
--- @param buffer number Buffer handle
--- @return string | nil content of the line, or nil if out of range
function Point:get_text_line(buffer)
    assert(buffer and vim.api.nvim_buf_is_valid(buffer), "Invalid buffer handle")
    
    local lines = vim.api.nvim_buf_get_lines(buffer, self.row - 1, self.row, false)
    return lines[1]
end

--- Set the text line at this point's row
--- @param buffer number Buffer handle
--- @param text string Text to set
--- @return boolean success
function Point:set_text_line(buffer, text)
    assert(buffer and vim.api.nvim_buf_is_valid(buffer), "Invalid buffer handle")
    assert(type(text) == "string", "Text must be a string")
    
    local ok, _ = pcall(vim.api.nvim_buf_set_lines, buffer, self.row - 1, self.row, false, {text})
    return ok
end

--- Move the cursor to the end of the current line
function Point:update_to_end_of_line()
    local line_length = vim.fn.col("$")
    self.col = math.max(1, line_length + 1)
    vim.api.nvim_win_set_cursor(0, {self.row, self.col - 1}) -- Convert to 0-based for nvim_win_set_cursor
end

--- Insert a new line below the current point
--- @param buffer number Buffer handle
--- @return boolean success
function Point:insert_new_line_below(buffer)
    assert(buffer and vim.api.nvim_buf_is_valid(buffer), "Invalid buffer handle")
    
    local lines = vim.api.nvim_buf_get_lines(buffer, self.row - 1, self.row, false)
    local ok, _ = pcall(vim.api.nvim_buf_set_lines, buffer, self.row, self.row, false, {
        string.rep(" ", self.col - 1)
    })
    
    if ok then
        self.row = self.row + 1
        self.col = 1
    end
    
    return ok
end

--- Convert to Vim's 0-based row/col format
--- @return number row 0-based row
--- @return number col 0-based column
function Point:to_vim()
    return self.row - 1, self.col - 1
end

--- Convert to 0-based index for API calls
--- @return number row 0-based row
--- @return number col 0-based column
function Point:to_zero_based()
    return self.row - 1, self.col - 1
end

--- Check if this point is before another point
--- @param other Point
--- @return boolean
function Point:before(other)
    assert(getmetatable(other) == Point, "Argument must be a Point")
    return project(self) < project(other)
end

--- Check if this point is after another point
--- @param other Point
--- @return boolean
function Point:after(other)
    assert(getmetatable(other) == Point, "Argument must be a Point")
    return project(self) > project(other)
end

--- Check if this point is equal to another point
--- @param other Point
--- @return boolean
function Point:equals(other)
    if getmetatable(other) ~= Point then return false end
    return self.row == other.row and self.col == other.col
end

--- Move the point by the given row and column offsets
--- @param row_offset number
--- @param col_offset number
--- @return Point self for chaining
function Point:move(row_offset, col_offset)
    self.row = math.max(1, self.row + (row_offset or 0))
    self.col = math.max(1, self.col + (col_offset or 0))
    return self
end

--- @class Range
--- @field start Point
--- @field end_ Point
--- @field buffer number
local Range = {}
Range.__index = Range

---@param buffer number
--- @param start Point
---@param end_ Point
function Range:new(buffer, start, end_)
    return setmetatable({
        start = start,
        end_ = end_,
        buffer = buffer,
    }, self)
end

---@param node TSNode
---@param buffer number
---@return Range
function Range:from_ts_node(node, buffer)
    -- ts is zero based
    local start_row, start_col, _ = node:start()
    local end_row, end_col, _ = node:end_()
    local range = {
        start = Point:from_ts_point(start_row, start_col),
        end_ = Point:from_ts_point(end_row, end_col),
        buffer = buffer,
    }

    return setmetatable(range, self)
end

--- @param point Point
--- @return boolean
function Range:contains(point)
    local start = project(self.start)
    local stop = project(self.end_)
    local p = project(point)
    return start <= p and p <= stop
end

--- @return string
function Range:to_text()
    local sr, sc = self.start:to_vim()
    local er, ec = self.end_:to_vim()

    -- note
    -- this api is 0 index end exclusive for _only_ column
    if ec == 0 then
        ec = -1
        er = er - 1
    end

    local text = vim.api.nvim_buf_get_text(self.buffer, sr, sc, er, ec, {})
    return table.concat(text, "\n")
end

--- @param range Range
--- @return boolean
function Range:contains_range(range)
    return self.start:lte(range.start) and self.end_:gte(range.end_)
end

function Range:to_string()
    return string.format(
        "range(%s,%s)",
        self.start:to_string(),
        self.end_:to_string()
    )
end

-- Add the missing from_ts_point method to Point class
--- Create a Point from a Tree-sitter point (0-based)
--- @param row number 0-based row
--- @param col number 0-based column
--- @return Point
function Point.from_ts_point(row, col)
    return Point:new(row + 1, col + 1)
end

-- Add comparison methods to Point class
--- Check if this point is less than or equal to another point
--- @param other Point
--- @return boolean
function Point:lte(other)
    return self:before(other) or self:equals(other)
end

--- Check if this point is greater than or equal to another point
--- @param other Point
--- @return boolean
function Point:gte(other)
    return self:after(other) or self:equals(other)
end

--- @param buffer number
--- @return string
function Point:get_text_line(buffer)
    local r, _ = self:to_vim()
    return vim.api.nvim_buf_get_lines(buffer, r, r + 1, true)[1]
end

--- @param buffer number
--- @param text string
function Point:set_text_line(buffer, text)
    local r, _ = self:to_vim()
    vim.api.nvim_buf_set_lines(buffer, r, r + 1, false, { text })
end

function Point:update_to_end_of_line()
    self.col = vim.fn.col("$") + 1
    local r, c = self:to_one_zero_index()
    vim.api.nvim_win_set_cursor(0, { r, c })
end

--- @param buffer number
function Point:insert_new_line_below(buffer)
    vim.api.nvim_input("<esc>o")
end

--- 1 based point
--- @param row number
--- @param col number
--- @return Point
function Point:new(row, col)
    return setmetatable({
        row = row,
        col = col,
    }, self)
end

function Point:from_cursor()
    local point = setmetatable({
        row = 0,
        col = 0,
    }, self)

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_row, cursor_col = cursor[1], cursor[2]
    point.row = cursor_row
    point.col = cursor_col + 1
    return point
end

--- @param row number
---@param col number
--- @return Point
function Point:from_ts_point(row, col)
    return setmetatable({
        row = row + 1,
        col = col + 1,
    }, self)
end

--- stores all 2 points
--- @param range Range
--- @return boolean
function Point:in_ts_range(range)
    return range:contains(self)
end

--- vim.api.nvim_buf_get_text uses 0 based row and col
--- @return number, number
function Point:to_lua()
    return self.row, self.col
end

--- @return number, number
function Point:to_lsp()
    return self.row - 1, self.col - 1
end

--- vim.api.nvim_buf_get_text uses 0 based row and col
--- @return number, number
function Point:to_vim()
    return self.row - 1, self.col - 1
end

function Point:to_one_zero_index()
    return self.row, self.col - 1
end

--- treesitter uses 0 based row and col
--- @return number, number
function Point:to_ts()
    return self.row - 1, self.col - 1
end

--- @param point Point
--- @return boolean
function Point:gt(point)
    return project(self) > project(point)
end

--- @param point Point
--- @return boolean
function Point:lt(point)
    return project(self) < project(point)
end

--- @param point Point
--- @return boolean
function Point:lte(point)
    return project(self) <= project(point)
end

--- @param point Point
--- @return boolean
function Point:gte(point)
    return project(self) >= project(point)
end

--- @param point Point
--- @return boolean
function Point:eq(point)
    return project(self) == project(point)
end

--- @class Range
--- @field start Point
--- @field end_ Point
--- @field buffer number
local Range = {}
Range.__index = Range

---@param buffer number
--- @param start Point
---@param end_ Point
function Range:new(buffer, start, end_)
    return setmetatable({
        start = start,
        end_ = end_,
        buffer = buffer,
    }, self)
end

---@param node TSNode
---@param buffer number
---@return Range
function Range:from_ts_node(node, buffer)
    -- ts is zero based
    local start_row, start_col, _ = node:start()
    local end_row, end_col, _ = node:end_()
    local range = {
        start = Point:from_ts_point(start_row, start_col),
        end_ = Point:from_ts_point(end_row, end_col),
        buffer = buffer,
    }

    return setmetatable(range, self)
end

--- @param point Point
--- @return boolean
function Range:contains(point)
    local start = project(self.start)
    local stop = project(self.end_)
    local p = project(point)
    return start <= p and p <= stop
end

--- @return string
function Range:to_text()
    local sr, sc = self.start:to_vim()
    local er, ec = self.end_:to_vim()

    -- note
    -- this api is 0 index end exclusive for _only_ column
    if ec == 0 then
        ec = -1
        er = er - 1
    end

    local text = vim.api.nvim_buf_get_text(self.buffer, sr, sc, er, ec, {})
    return table.concat(text, "\n")
end

--- @param range Range
--- @return boolean
function Range:contains_range(range)
    return self.start:lte(range.start) and self.end_:gte(range.end_)
end

function Range:to_string()
    return string.format(
        "range(%s,%s)",
        self.start:to_string(),
        self.end_:to_string()
    )
end

return {
    Point = Point,
    Range = Range,
}