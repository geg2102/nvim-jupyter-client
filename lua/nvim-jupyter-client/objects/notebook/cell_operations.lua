local M = {}
local Cell = require("nvim-jupyter-client.objects.cell")
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")
local navigation = require("nvim-jupyter-client.objects.notebook.navigation")
local utils = require("nvim-jupyter-client.utils.utils")

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

function M.merge_visual_selection(notebook)
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")

    -- Get all cells that intersect with the visual selection
    local cells_to_merge = {}
    local current_line = 1

    for _, cell in ipairs(notebook.cells) do
        local cell_start = current_line
        local cell_end = current_line + #cell.source - 1

        if not (cell_end < start_line or cell_start > end_line) then
            table.insert(cells_to_merge, cell)
        end

        current_line = cell_end + 2 -- +2 for the cell separator
    end

    if #cells_to_merge >= 2 then
        M.merge_cells(notebook, cells_to_merge)
    else
        vim.notify("Select at least 2 cells to merge", vim.log.levels.WARN)
    end
end

function M.remove_cell_with_register(notebook, cell_id, operator_opts)
    cell_id = cell_id or navigation.get_under_cursor_cell_id(0)

    for index, cell in ipairs(notebook.cells) do
        if cell.id == cell_id then
            -- Convert cell content to string
            local cell_content = table.concat(cell.source, "") .. "\n"

            -- Store cell type and content in register
            local cell_data = string.format("\n# %%%% %s []\n%s\n", cell_id, cell_content)

            -- Handle register selection like native Vim
            if operator_opts and operator_opts.register then
                -- If a specific register was given (like "ay to delete into register a)
                vim.fn.setreg(operator_opts.register, cell_data)
            else
                -- Default behavior: store in unnamed register and small delete register
                vim.fn.setreg('"', cell_data)
                -- If the cell is less than one line, store in small delete register
                if #cell.source <= 1 then
                    vim.fn.setreg('-', cell_data)
                else
                    -- For multiline deletes, store in numbered registers
                    -- Shift numbered registers
                    for i = 9, 2, -1 do
                        local content = vim.fn.getreg(tostring(i - 1))
                        vim.fn.setreg(tostring(i), content)
                    end
                    vim.fn.setreg('1', cell_data)
                end
            end

            table.remove(notebook.cells, index)
            break
        end
    end
    notebook:render_py(0)
end

function M.convert_type(notebook)
    buffer_ops.update_cells_from_buffer(notebook, 0)
    local cursor_id = navigation.get_under_cursor_cell_id(0)
    local cell = M.find_cell_by_id(notebook.cells, cursor_id)
    if not cell then
        vim.notify("No cell found under cursor", vim.log.levels.ERROR)
        return
    end

    -- Remove triple quotes if converting from markdown to code
    if cell.cell_type == "markdown" then
        cell.source = utils.remove_triple_quotes(cell.source)
    end

    cell.cell_type = cell.cell_type == "code" and "markdown" or "code"

    notebook:render_py(0)
end

return M
