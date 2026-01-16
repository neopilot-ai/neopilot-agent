local helper = require("neopilot.test_helper")
local describe = helper.describe
local it = helper.it
local before_each = helper.before_each
local after_each = helper.after_each

-- Load the modules
local geo = require("neopilot.geo")
local Point = geo.Point
local Range = geo.Range

describe("Range class tests", function()
    local buf_id
    
    before_each(function()
        buf_id = helper.create_mock_buffer({
            "line 1",
            "line 2 with some text",
            "line 3",
            "line 4 with more text",
        })
    end)
    
    after_each(function()
        helper.cleanup_buffer(buf_id)
    end)
    
    describe("Constructor", function()
        it("should create a range with valid points", function()
            local start_p = Point:new(1, 1)
            local end_p = Point:new(3, 5)
            local range = Range:new(buf_id, start_p, end_p)
            
            assert(range.start:equals(start_p), "Should set start point")
            assert(range.end_:equals(end_p), "Should set end point")
            assert(range.buffer == buf_id, "Should set buffer ID")
        end)
        
        it("should error with invalid points", function()
            local start_p = Point:new(1, 1)
            local end_p = Point:new(1, 0) -- Invalid point
            
            helper.assert_error(function()
                Range:new(buf_id, start_p, end_p)
            end, "col must be a positive number")
        end)
    end)
    
    describe("from_ts_node", function()
        it("should create a range from a Tree-sitter node", function()
            -- Mock a Tree-sitter node
            local mock_node = {
                start = function() return 1, 2, 0 end,  -- 0-based
                end_ = function() return 3, 4, 0 end,   -- 0-based
            }
            
            local range = Range:from_ts_node(mock_node, buf_id)
            
            assert(range.start.row == 2, "Should convert 0-based row to 1-based")
            assert(range.start.col == 3, "Should convert 0-based col to 1-based")
            assert(range.end_.row == 4, "Should convert 0-based row to 1-based")
            assert(range.end_.col == 5, "Should convert 0-based col to 1-based")
            assert(range.buffer == buf_id, "Should set buffer ID")
        end)
    end)
    
    describe("contains", function()
        local range
        
        before_each(function()
            range = Range:new(buf_id, Point:new(2, 1), Point:new(4, 5))
        end)
        
        it("should contain points within range", function()
            assert(range:contains(Point:new(2, 1)), "Should contain start point")
            assert(range:contains(Point:new(3, 1)), "Should contain middle point")
            assert(range:contains(Point:new(4, 5)), "Should contain end point")
        end)
        
        it("should not contain points outside range", function()
            assert(not range:contains(Point:new(1, 1)), "Should not contain before start")
            assert(not range:contains(Point:new(5, 1)), "Should not contain after end")
            assert(not range:contains(Point:new(4, 6)), "Should not contain after end column")
        end)
    end)
    
    describe("to_text", function()
        it("should extract text from single line range", function()
            local range = Range:new(buf_id, Point:new(2, 1), Point:new(2, 5))
            local text = range:to_text()
            assert(text == "line", "Should extract correct text from single line")
        end)
        
        it("should extract text from multi-line range", function()
            local range = Range:new(buf_id, Point:new(2, 6), Point:new(3, 3))
            local text = range:to_text()
            assert(text == "2 with some text\nlin", "Should extract correct text from multiple lines")
        end)
        
        it("should handle empty range", function()
            local range = Range:new(buf_id, Point:new(2, 1), Point:new(2, 1))
            local text = range:to_text()
            assert(text == "", "Should return empty string for zero-length range")
        end)
    end)
    
    describe("contains_range", function()
        local range
        
        before_each(function()
            range = Range:new(buf_id, Point:new(2, 1), Point:new(4, 5))
        end)
        
        it("should contain smaller range", function()
            local subrange = Range:new(buf_id, Point:new(2, 2), Point:new(3, 3))
            assert(range:contains_range(subrange), "Should contain smaller range")
        end)
        
        it("should contain same range", function()
            assert(range:contains_range(range), "Should contain itself")
        end)
        
        it("should not contain larger range", function()
            local larger = Range:new(buf_id, Point:new(1, 1), Point:new(5, 5))
            assert(not range:contains_range(larger), "Should not contain larger range")
        end)
        
        it("should not contain overlapping range", function()
            local overlapping = Range:new(buf_id, Point:new(1, 1), Point:new(3, 3))
            assert(not range:contains_range(overlapping), "Should not contain overlapping range")
        end)
    end)
    
    describe("to_string", function()
        it("should return string representation", function()
            local range = Range:new(buf_id, Point:new(1, 1), Point:new(3, 5))
            local str = range:to_string()
            assert(string.find(str, "range%(Point%(row=1, col=1%), Point%(row=3, col=5%)"), 
                "Should return correct string representation")
        end)
    end)
end)

print("\nAll Range tests completed")
