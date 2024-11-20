local M = {}
local json = require("dkjson")
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")

function M.read(fname, template)
    local file_exists = vim.fn.filereadable(fname) == 1
    if not file_exists then
        vim.notify("File does not exist, creating new notebook from template", vim.log.levels.DEBUG)
        return template or require("nvim-jupyter-client.template")
    end

    local ipynb_file, err = io.open(fname, "r")
    if not ipynb_file then
        vim.notify("Could not open file " .. fname .. ": " .. err, vim.log.levels.ERROR)
        return nil
    end

    local content = ipynb_file:read("*a")
    ipynb_file:close()
    if content == "" then
        vim.notify("File is empty, loading template", vim.log.levels.DEBUG)
        return template or require("nvim-jupyter-client.template")
    end

    return json.decode(content)
end

function M.save(self)
    if not self.filename then
        vim.notify("No filename specified for notebook", vim.log.levels.ERROR)
        return
    end

    buffer_ops.update_cells_from_buffer(self, 0)
    local output_data = {
        cells = self.cells,
        metadata = self.metadata,
        nbformat = self.nbformat,
        nbformat_minor = self.nbformat_minor
    }

    for _, cell in ipairs(output_data.cells) do
        setmetatable(cell.metadata, { __jsontype = "object" })
        setmetatable(cell.outputs, { __jsontype = "array" })
        if cell.execution_count == nil then
            cell.execution_count = 0
        end
    end

    local ipynb_json = json.encode(output_data, { indent = true })
    local file, err = io.open(self.filename, "w")
    if not file then
        vim.notify("Failed to open file for writing: " .. err, vim.log.levels.ERROR)
        return
    end
    file:write(ipynb_json)
    file:close()
end

return M
