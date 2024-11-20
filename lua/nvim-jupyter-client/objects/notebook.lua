local api = vim.api
local Cell = require("nvim-jupyter-client.objects.cell")
local Meta = require("nvim-jupyter-client.objects.notebook_meta")
local render_ops = require("nvim-jupyter-client.objects.notebook.render_operations")
local cell_ops = require("nvim-jupyter-client.objects.notebook.cell_operations")
local file_ops = require("nvim-jupyter-client.objects.notebook.file_operations")
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")
local navigation = require("nvim-jupyter-client.objects.notebook.navigation")

local decor_ns = api.nvim_create_namespace('rendered_jupyter')
api.nvim_set_hl(decor_ns, 'jupyterhl', { ctermfg = 'red', ctermbg = 'yellow', cterm = { bold = true } })

local Notebook = {}

-- File Operations

function Notebook:new(filename, template)
    local fname = filename or nil
    local ipynb_json = nil
    if fname then
        ipynb_json = file_ops.read(fname, template)
        -- Use the current buffer; do not create a new one
    else
        -- No filename provided, create a new buffer
        local buf = api.nvim_create_buf(true, false)
        local win = api.nvim_get_current_win()
        api.nvim_win_set_buf(win, buf)
        local empty_name = "Untitled.ipynb"
        local i = 1
        while vim.fn.filereadable(empty_name) == 1 do
            empty_name = "Untitled" .. i .. ".ipynb"
            i = i + 1
        end
        api.nvim_buf_set_name(buf, empty_name)
        fname = empty_name -- Ensure fname is set for new notebooks
        ipynb_json = template or require("nvim-jupyter-client.template")
    end
    local meta = Meta:new(ipynb_json)
    local t = {
        filename = fname,
        cells = self:_get_cells_as_objects(ipynb_json),
        metadata = meta["metadata"],
        nbformat = meta["nbformat"],
        nbformat_minor = meta["nbformat_minor"]
    }
    setmetatable(t, self)
    self.__index = self
    return t
end

function Notebook:_get_cells_as_objects(ipynb_json)
    local cell_objects = {}
    local cells = ipynb_json["cells"]
    for _, cell in ipairs(cells) do
        local c = Cell:new(cell)
        cell_objects[#cell_objects + 1] = c
    end
    return cell_objects
end

function Notebook:save()
    file_ops.save(self)
end

function Notebook:render_py(bufnr)
    render_ops.render_py(self, bufnr)
end

function Notebook:render_ipynb(bufnr)
    render_ops.render_ipynb(self, bufnr)
end

-- Cell Operations
function Notebook:remove_cell(cell_id)
    cell_ops.remove_cell(self, cell_id)
end

function Notebook:convert_type()
    cell_ops.convert_type(self)
end

function Notebook:add_cell_above()
    -- Update self.cells from buffer before modifying
    buffer_ops.update_cells_from_buffer(self, 0)
    cell_ops.add_cell(self, true)
    buffer_ops.reset_cursor(self, "above")
end

function Notebook:add_cell_below()
    -- Update self.cells from buffer before modifying
    buffer_ops.update_cells_from_buffer(self, 0)
    cell_ops.add_cell(self, false)
    buffer_ops.reset_cursor(self, "below")
end

function Notebook:_simple_merge(type)
    -- Update self.cells from buffer before modifying
    buffer_ops.update_cells_from_buffer(self, 0)

    local cursor_id = navigation.get_under_cursor_cell_id(0)
    if not cursor_id then
        vim.notify("No cell found under cursor", vim.log.levels.ERROR)
        return
    end

    local other_id
    if type == "above" then
        other_id = navigation.get_above_cell_id(self, cursor_id)
    else
        other_id = navigation.get_below_cell_id(self, cursor_id)
    end

    if not other_id then
        vim.notify("No adjacent cell to merge with", vim.log.levels.ERROR)
        return
    end

    -- Fetch the actual cell objects
    local cell_under_cursor = cell_ops.find_cell_by_id(self.cells, cursor_id)
    local adjacent_cell = cell_ops.find_cell_by_id(self.cells, other_id)

    if not cell_under_cursor or not adjacent_cell then
        vim.notify("Could not find cells to merge", vim.log.levels.ERROR)
        return
    end

    -- Ensure the cell under the cursor is first
    if type == "above" then -- Merge above
        local temp = cell_under_cursor
        cell_under_cursor = adjacent_cell
        adjacent_cell = temp
    end
    local cells_to_merge = { cell_under_cursor, adjacent_cell }

    cell_ops.merge_cells(self, cells_to_merge)
end

function Notebook:merge_below()
    self:_simple_merge("below")
    buffer_ops.reset_cursor(self, "below")
end

function Notebook:merge_above()
    self:_simple_merge("above")
    buffer_ops.reset_cursor(self, "above")
end

return Notebook
