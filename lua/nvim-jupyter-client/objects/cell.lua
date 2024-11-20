local utils = require("nvim-jupyter-client.utils.utils")

-- @class CellObject
-- @field cell_type string
-- @field execution_count Union[integer, nil]
-- @field id string
-- @field metadata table
-- @field outputs table
-- @field source table
local Cell = {}

function Cell:new(cell)
    local c = {}
    if cell then
        c = {
            cell_type = cell.cell_type or cell["cell_type"],
            id = cell.id or cell["id"],
            execution_count = cell["execution_count"] or nil,
            metadata = cell["metadata"],
            outputs = cell["outputs"],
            source = cell["source"],
        }
    else
        c = {
            cell_type = "code",
            id = utils.uuid(),
            execution_count = nil,
            metadata = {},
            outputs = {},
            source = { "\n" },
        }
    end
    setmetatable(c["metadata"], { __jsontype = "object" }) -- ensure object when written back so it is not written as array
    setmetatable(c, self)
    self.__index = self
    return c
end

function Cell:reset_source(lines)
    local source = {}
    for _, line in ipairs(lines) do
        table.insert(source, line .. "\n")
    end
    self.source = source
end

return Cell
