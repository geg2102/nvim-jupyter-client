local M = {}
local json = require("dkjson")
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")
local utils = require("nvim-jupyter-client.utils.utils")

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
    local notebook = json.decode(content)

    for _, cell in ipairs(notebook.cells) do
        if not cell.id then
            cell.id = utils.uuid()
        end
    end

    notebook.nbformat_minor = 5

    return notebook
end

function M.save(self)
    if not self.filename then
        vim.notify("No filename specified for notebook", vim.log.levels.ERROR)
        return
    end

    buffer_ops.update_cells_from_buffer(self, 0)
    local output_data = {
        -- Make a deep copy of the cells
        cells = vim.deepcopy(self.cells),
        metadata = self.metadata,
        nbformat = self.nbformat,
        nbformat_minor = self.nbformat_minor
    }

    for _, cell in ipairs(output_data.cells) do
        cell.metadata = cell.metadata or {}
        cell.outputs = cell.outputs or {}

        setmetatable(cell.metadata, { __jsontype = "object" })
        setmetatable(cell.outputs, { __jsontype = "array" })

        for _, output in ipairs(cell.outputs or {}) do
            if output.metadata then
                setmetatable(output.metadata, { __jsontype = "object" })
            end
        end


        if cell.execution_count == nil then
            cell.execution_count = 0
        end

        -- Remove leading and trailing triple quotes from markdown cells
        if cell.cell_type == "markdown" and type(cell.source) == "table" then
            cell.source = utils.remove_triple_quotes(cell.source)
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
