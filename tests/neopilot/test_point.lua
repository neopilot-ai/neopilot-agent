local helper = require("neopilot.test_helper")
local describe = helper.describe
local it = helper.it
local before_each = helper.before_each
local after_each = helper.after_each

-- Load the module
local Point = require("neopilot.geo").Point

describe("Point class tests", function()
    describe("Constructor", function()
        it("should create a point with valid coordinates", function()
            local p = Point:new(1, 1)
            assert(p.row == 1 and p.col == 1, "Point should have correct coordinates")
        end)

        it("should floor non-integer coordinates", function()
            local p = Point:new(1.9, 2.1)
            assert(p.row == 1 and p.col == 2, "Point should floor coordinates")
        end)

        it("should error with invalid row", function()
            helper.assert_error(function()
                Point:new(0, 1)
            end, "row must be a positive number")
        end)

        it("should error with invalid column", function()
            helper.assert_error(function()
                Point:new(1, -1)
            end, "col must be a positive number")
        end)
    end)

    describe("from_cursor", function()
        it("should create a point from cursor position", function()
            -- Mock the cursor position
            vim.api.nvim_win_set_cursor(0, {5, 10}) -- 1-based in Lua, but 0-based in Vim
            
            local p = Point.from_cursor()
            assert(p.row == 5 and p.col == 11, "Should convert from 0-based to 1-based")
        end)
    end)

    describe("Comparison methods", function()
        local p1, p2, p3

        before_each(function()
            p1 = Point:new(1, 1)
            p2 = Point:new(1, 2)
            p3 = Point:new(2, 1)
        end)

        it("should compare points correctly", function()
            assert(p1:before(p2), "p1 should be before p2")
            assert(p2:after(p1), "p2 should be after p1")
            assert(not p1:before(p1), "Point should not be before itself")
            assert(p1:equals(Point:new(1, 1)), "Points with same coordinates should be equal")
        end)

        it("should handle lte and gte comparisons", function()
            assert(p1:lte(p2), "p1 should be lte p2")
            assert(p2:gte(p1), "p2 should be gte p1")
            assert(p1:lte(p1), "Point should be lte itself")
            assert(p1:gte(p1), "Point should be gte itself")
        end)
    end)

    describe("Movement methods", function()
        it("should move point by offset", function()
            local p = Point:new(5, 5)
            p:move(1, 2)
            assert(p.row == 6 and p.col == 7, "Should move point by offset")
        end)

        it("should not move below 1,1", function()
            local p = Point:new(1, 1)
            p:move(-1, -1)
            assert(p.row == 1 and p.col == 1, "Should not move below 1,1")
        end)
    end)

    describe("Text operations", function()
        local buf_id
        
        before_each(function()
            buf_id = helper.create_mock_buffer({
                "line 1",
                "line 2",
                "line 3",
            })
        end)
        
        after_each(function()
            helper.cleanup_buffer(buf_id)
        end)
        
        it("should get text line", function()
            local p = Point:new(1, 1)
            local line = p:get_text_line(buf_id)
            assert(line == "line 1", "Should get correct line text")
        end)
        
        it("should set text line", function()
            local p = Point:new(2, 1)
            local success = p:set_text_line(buf_id, "new line 2")
            assert(success, "Should set line text successfully")
            
            local lines = vim.api.nvim_buf_get_lines(buf_id, 1, 2, false)
            assert(lines[1] == "new line 2", "Line text should be updated")
        end)
        
        it("should move to end of line", function()
            local p = Point:new(1, 1)
            p:update_to_end_of_line()
            assert(p.col == 7, "Should move to end of line (length + 1)")
        end)
        
        it("should insert new line below", function()
            local p = Point:new(1, 3)
            local success = p:insert_new_line_below(buf_id)
            assert(success, "Should insert new line successfully")
            
            local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
            assert(#lines == 4, "Should have 4 lines after insertion")
            assert(lines[2] == "  ", "New line should be indented")
            assert(p.row == 2 and p.col == 1, "Point should move to start of new line")
        end)
    end)
end)

print("\nAll Point tests completed")
