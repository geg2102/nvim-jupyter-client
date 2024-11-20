local M = {}
local api = vim.api
local ID_PATTERN = "^#%s%%%%%s(.-)%s%[.-%]"

function M.get_under_cursor_cell_id(winnr)
    winnr = winnr or 0
    local bufnr = api.nvim_win_get_buf(winnr)
    local cursor = api.nvim_win_get_cursor(winnr)
    local line_num = cursor[1]
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i = line_num, 1, -1 do
        local line = lines[i]
        local match = string.match(line, ID_PATTERN)
        if match ~= nil then
            return match
        end
    end
end

function M.get_id_index(notebook, cell_id)
    for index, cell in ipairs(notebook.cells) do
        if cell.id == cell_id then
            return index
        end
    end
    return nil
end

function M.get_all_ids_in_buffer(bufnr)
    bufnr = bufnr or 0
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ids = {}
    for _, line in ipairs(lines) do
        local id = string.match(line, ID_PATTERN)
        if id ~= nil then
            table.insert(ids, id)
        end
    end
    return ids
end

function M.get_lineno_of_id(cell_id)
    local buf = api.nvim_get_current_buf()
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for lineno, line in ipairs(lines) do
        if string.match(line, ID_PATTERN) == cell_id then
            return lineno
        end
    end
end

function M.get_above_cell_id(notebook, cell_id)
    local cell_id_index = M.get_id_index(notebook, cell_id)
    if not cell_id_index then
        vim.notify("Current cell ID not found in notebook cells", vim.log.levels.ERROR)
        return nil
    end
    if cell_id_index == 1 then
        return nil
    else
        return notebook.cells[cell_id_index - 1].id
    end
end

function M.get_below_cell_id(notebook, cell_id)
    local cell_id_index = M.get_id_index(notebook, cell_id)
    if not cell_id_index then
        vim.notify("Current cell ID not found in notebook cells", vim.log.levels.ERROR)
        return nil
    end
    if cell_id_index == #notebook.cells then
        return nil
    else
        return notebook.cells[cell_id_index + 1].id
    end
end

function M.reset_cursor(self, movement_type)
    local current_id = self:get_under_cursor_cell_id(0)
    local new_id = nil
    local new_lineno = nil
    if movement_type == "below" then
        new_id = self:get_below_cell_id(current_id)
    elseif movement_type == "above" then
        new_id = current_id
    end

    if new_id then
        new_lineno = self:get_lineno_of_id(new_id)
        if new_lineno then
            api.nvim_win_set_cursor(0, { new_lineno + 1, 0 })
        end
    else
        vim.notify("No adjacent cell found for cursor movement", vim.log.levels.ERROR)
    end
end

return M
