local api = vim.api
local utils = require("nvim-jupyter-client.utils.utils")

local NotebookMeta = {}

function NotebookMeta:new(json_data)
    local t = {
        metadata = json_data["metadata"],
        nbformat = json_data["nbformat"],
        nbformat_minor = json_data["nbformat_minor"]
    }
    setmetatable(t, self)
    self.__index = self
    return t
end

return NotebookMeta
