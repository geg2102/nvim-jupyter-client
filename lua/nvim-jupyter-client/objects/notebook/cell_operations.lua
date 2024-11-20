local M = {}
local Cell = require("nvim-jupyter-client.objects.cell")
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")
local navigation = require("nvim-jupyter-client.objects.notebook.navigation")

function M.find_cell_by_id(cells, cell_id)
    for _, cell in ipairs(cells) do
        if cell.id == cell_id then
            return cell
        end
    end
    return nil
end

function M.add_cell(notebook, above)
    -- Update self.cells from buffer before modifying
    buffer_ops.update_cells_from_buffer(notebook, 0)
    local win = vim.api.nvim_get_current_win()
    local id = navigation.get_under_cursor_cell_id(win)
    local index = navigation.get_id_index(notebook, id)
    local cell = Cell:new()

    if index == nil then
        index = above and 1 or #notebook.cells + 1
    else
        if not above then
            index = index + 1
        end
    end

    table.insert(notebook.cells, index, cell)
    notebook:render_py(0)
end

function M.remove_cell(notebook, cell_id)
    cell_id = cell_id or navigation.get_under_cursor_cell_id(0)
    for index, cell in ipairs(notebook.cells) do
        if cell.id == cell_id then
            table.remove(notebook.cells, index)
            break
        end
    end
    notebook:render_py(0)
end

function M.merge_cells(notebook, cells)
    local new_source = {}
    for i, cell in ipairs(cells) do
        for _, line in ipairs(cell.source) do
            table.insert(new_source, line)
        end
        if i < #cells then
            table.insert(new_source, "\n")
        end
    end

    local target_cell = cells[1]
    target_cell.source = new_source

    for i = 2, #cells do
        M.remove_cell(notebook, cells[i].id)
    end

    notebook:render_py(0)
end

function M.convert_type(notebook)
    buffer_ops.update_cells_from_buffer(notebook, 0)
    local cursor_id = navigation.get_under_cursor_cell_id(0)
    local cell = M.find_cell_by_id(notebook.cells, cursor_id)
    cell.cell_type = cell.cell_type == "code" and "markdown" or "code"
    notebook:render_py(0)
end

return M
