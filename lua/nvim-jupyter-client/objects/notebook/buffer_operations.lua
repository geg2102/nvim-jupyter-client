local api = vim.api
local utils = require("nvim-jupyter-client.utils.utils")
local Cell = require("nvim-jupyter-client.objects.cell")
local navigation = require("nvim-jupyter-client.objects.notebook.navigation")

local M = {}

local CELL_HEADER = "# %%%% %s [%s]\n"
local ID_PATTERN = "^#%s%%%%%s(.-)%s%[.-%]"
local EXECUTION_PATTERN = "^#%s%%%%%s.-%s(%[.-%])"
local CELL_TYPE_PATTERN = "^#%s*%%%%%s*.-%s*%[(.-)%]"

function M.find_cell_by_id(cells, cell_id)
    for _, cell in ipairs(cells) do
        if cell.id == cell_id then
            return cell
        end
    end
    return nil
end

function M.get_lines(cells)
    local unescaped_lines = {} -- store a table of strings
    local lines = {}           -- split on \n to make each line explicit

    for _, cell in ipairs(cells) do
        -- Ensure cell.source is a table
        if type(cell.source) == "string" then
            cell.source = { cell.source }
        elseif type(cell.source) ~= "table" then
            cell.source = { "" }
        end

        -- Clean source content - ensure it's valid UTF-8
        local clean_source = {}
        for _, line in ipairs(cell.source) do
            if type(line) == "string" then
                -- Remove any invalid UTF-8 sequences
                local cleaned = line:gsub("[\192-\255][\128-\191]*", "")
                table.insert(clean_source, cleaned)
            end
        end
        cell.source = clean_source

        if cell.cell_type == "markdown" then
            -- Process markdown cells
            local markdown_str = string.format('%s"""\n%s\n"""',
                string.format(CELL_HEADER, cell.id, "MARKDOWN"),
                table.concat(cell.source, ""))
            table.insert(unescaped_lines, markdown_str)
        elseif cell.cell_type == "code" then
            -- Process code cells
            local exec_count = cell.execution_count or " "
            local code_str = string.format("%s%s",
                string.format(CELL_HEADER, cell.id, exec_count),
                table.concat(cell.source, ""))
            table.insert(unescaped_lines, code_str)
        else
            vim.notify("Skipping unhandled cell type: " .. tostring(cell.cell_type), vim.log.levels.WARN)
        end
    end

    if #unescaped_lines > 0 then
        unescaped_lines[#unescaped_lines] = unescaped_lines[#unescaped_lines] .. "\n"
    end

    local result_str = table.concat(unescaped_lines, "\n\n")
    for s in result_str:gmatch("(.-)\n") do
        table.insert(lines, s)
    end
    table.insert(lines, "")
    return lines
end

function M.update_cells_from_buffer(notebook, bufnr)
    local buf = bufnr or api.nvim_get_current_buf()
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local temp_cells = {}
    local i = 1
    local num_lines = #lines

    while i <= num_lines do
        local line = lines[i]
        local trimmed_line = line:gsub("^%s*(.-)%s*$", "%1")

        if string.match(trimmed_line, "^#%s*%%%%") then
            local cell_id = string.match(trimmed_line, ID_PATTERN)
            if not cell_id or cell_id == "" then
                cell_id = utils.uuid()
                local new_header = string.format(CELL_HEADER, cell_id, " ")
                api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_header })
                -- Update lines and line variables after modifying the buffer
                lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
                num_lines = #lines
                line = lines[i]
                trimmed_line = line:gsub("^%s*(.-)%s*$", "%1")
            end

            -- Extract cell type from header
            local cell_type_in_header = string.match(trimmed_line, CELL_TYPE_PATTERN)
            if cell_type_in_header then
                cell_type_in_header = string.lower(cell_type_in_header)
                if cell_type_in_header == "markdown" then
                    cell_type_in_header = "markdown"
                else
                    cell_type_in_header = "code"
                end
            else
                cell_type_in_header = "code"
            end

            local cell_lines = {}
            i = i + 1
            while i <= num_lines do
                local content_line = lines[i]
                if string.match(content_line, "^#%s*%%%%") then
                    break
                else
                    table.insert(cell_lines, content_line)
                    i = i + 1
                end
            end

            -- Remove trailing empty lines
            while #cell_lines > 0 and cell_lines[#cell_lines]:match("^%s*$") do
                table.remove(cell_lines)
            end
            for j = 1, #cell_lines - 1 do
                cell_lines[j] = cell_lines[j] .. "\n"
            end

            local existing_cell = M.find_cell_by_id(notebook.cells, cell_id)
            if existing_cell then
                existing_cell.source = cell_lines
                existing_cell.cell_type = cell_type_in_header -- Update cell_type here
                setmetatable(existing_cell, { __index = Cell })
                table.insert(temp_cells, existing_cell)
            else
                local newCell = Cell:new()
                newCell.id = cell_id
                newCell.source = cell_lines
                newCell.cell_type = cell_type_in_header
                table.insert(temp_cells, newCell)
            end
        else
            i = i + 1
        end
    end
    notebook.cells = temp_cells
    M.reset_extmarks(0)
    return temp_cells
end

function M.reset_extmarks(bufnr)
    local jupyter_client = require("nvim-jupyter-client")

    local decor_ns = api.nvim_create_namespace('rendered_jupyter')
    local highlight_group = jupyter_client.config.cell_highlight_group or "CurSearch"

    if not pcall(vim.api.nvim_get_hl_by_name, highlight_group, true) then
        vim.notify(string.format("Highlight group '%s' not found, falling back to CurSearch", highlight_group),
            vim.log.levels.WARN)
        highlight_group = "CurSearch"
    end

    if highlight_group ~= "CurSearch" then
        api.nvim_set_hl(0, highlight_group, jupyter_client.config.highlights.cell_title)
    end

    local buf = bufnr or 0
    api.nvim_buf_clear_namespace(buf, decor_ns, 0, -1)
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    for index, line in ipairs(lines) do
        local execution_pattern = string.match(line, EXECUTION_PATTERN)
        if execution_pattern ~= nil then
            api.nvim_buf_set_extmark(0, decor_ns, index - 1, 0,
                {
                    id = index,
                    virt_text = { { "In: " .. execution_pattern .. string.rep(" ", 10000), highlight_group } },
                    virt_text_pos = "overlay",
                    virt_text_win_col = 0
                })
        end
    end
    return api.nvim_buf_get_extmarks(buf, decor_ns, 0, -1, {})
end

function M.get_cell_line_numbers(notebook, bufnr)
    local marks = M.reset_extmarks(bufnr)
    local line = nil
    local cell_boundaries = {}
    for _, mark in ipairs(marks) do
        line = mark[2] + 1 -- 0 indexed lines
        table.insert(cell_boundaries, line)
    end
    return cell_boundaries
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

function M.reset_cursor(notebook, movement_type)
    local current_id = navigation.get_under_cursor_cell_id(0)
    local new_id = nil
    local new_lineno = nil
    if movement_type == "below" then
        new_id = navigation.get_below_cell_id(notebook, current_id)
    elseif movement_type == "above" then
        -- Move to the current cell (newly added cell) instead of the one above
        new_id = current_id
    end

    if new_id then
        new_lineno = M.get_lineno_of_id(new_id)
        if new_lineno then
            api.nvim_win_set_cursor(0, { new_lineno + 1, 0 })
        end
    else
        vim.notify("No adjacent cell found for cursor movement", vim.log.levels.ERROR)
    end
end

return M
