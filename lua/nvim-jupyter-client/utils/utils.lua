local random = math.random
local M = {}

-- A method to combine two tables into a a new table of key, value pair
-- @param a table. This is the keys in the resulting table.
-- @param b table. This is the values in the resulting table.
function M.zip(a, b)
    local zipped = {}
    for i = 1, math.min(#a, #b) do
        zipped[a[i]] = b[i]
    end
    return zipped
end

-- Pairs each item in a table iwth the next item in the table
-- @param t table.
function M.pair_with_next(t)
    local result = {}
    for i = 1, #t do
        result[t[i]] = t[i + 1]
    end
    return result
end

function M.uuid()
    math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function M.remove_triple_quotes(source_lines)
    -- Remove leading and trailing empty lines
    while #source_lines > 0 and source_lines[1]:match("^%s*$") do
        table.remove(source_lines, 1)
    end
    while #source_lines > 0 and source_lines[#source_lines]:match("^%s*$") do
        table.remove(source_lines, #source_lines)
    end

    -- Remove leading triple quotes
    if #source_lines > 0 and source_lines[1]:match('^%s*"""%s*$') then
        table.remove(source_lines, 1)
    end
    -- Remove trailing triple quotes
    if #source_lines > 0 and source_lines[#source_lines]:match('^%s*"""%s*$') then
        table.remove(source_lines, #source_lines)
    end

    -- Remove any leading or trailing empty lines again
    while #source_lines > 0 and source_lines[1]:match("^%s*$") do
        table.remove(source_lines, 1)
    end
    while #source_lines > 0 and source_lines[#source_lines]:match("^%s*$") do
        table.remove(source_lines, #source_lines)
    end

    return source_lines
end

return M
