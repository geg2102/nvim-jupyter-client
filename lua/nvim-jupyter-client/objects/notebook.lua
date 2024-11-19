local api = vim.api
local Cell = require("nvim-jupyter-client.objects.cell")
local Meta = require("nvim-jupyter-client.objects.notebook_meta")
local json = require("dkjson")
local utils = require("nvim-jupyter-client.utils.utils")

local CELL_HEADER = "# %%%% %s [%s]\n"
local ID_PATTERN = "^#%s%%%%%s(.-)%s%[.-%]"
local EXECUTION_PATTERN = "^#%s%%%%%s.-%s(%[.-%])"

local decor_ns = api.nvim_create_namespace('rendered_jupyter')
api.nvim_set_hl(decor_ns, 'jupyterhl', { ctermfg = 'red', ctermbg = 'yellow', cterm = { bold = true } })

local function find_cell_by_id(cells, cellId)
    for _, cell in ipairs(cells) do
        if cell.id == cellId then
            return cell
        end
    end
    return nil
end

local Notebook = {}

function Notebook:new(filename, template)
    local fname = filename or nil
    local ipynb_json = nil
    if fname then
        ipynb_json = self:_read(fname)
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

function Notebook:save()
    if not self.filename then
        vim.notify("No filename specified for notebook", vim.log.levels.ERROR)
        return
    end

    -- Prepare the JSON content
    local output_data = {}
    output_data["cells"] = self.cells

    -- Ensure proper JSON serialization
    for _, cell in ipairs(output_data["cells"]) do
        setmetatable(cell["metadata"], { __jsontype = "object" })
        setmetatable(cell["outputs"], { __jsontype = "array" })
        if cell["execution_count"] == nil then
            cell["execution_count"] = 0
        end
    end

    output_data["metadata"] = self.metadata
    output_data["nbformat"] = self.nbformat
    output_data["nbformat_minor"] = self.nbformat_minor

    local ipynb_json = json.encode(output_data, { indent = true })

    -- Write the JSON content to the file
    local file, err = io.open(self.filename, "w")
    if not file then
        vim.notify("Failed to open file for writing: " .. err, vim.log.levels.ERROR)
        return
    end
    file:write(ipynb_json)
    file:close()
end

function Notebook:render_py(bufnr)
    if bufnr == nil then
        vim.cmd('tabnew')
    end
    local win = api.nvim_get_current_win()
    local buf = bufnr or api.nvim_win_get_buf(win)
    vim.bo[buf].buflisted = true
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "python"
    vim.bo[buf].autoread = false -- Disable autoread for this buffer

    local lines = self:_get_lines(self.cells)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- Remove or adjust cursor movement here if needed
    -- api.nvim_win_set_cursor(win, { 2, 0 })  -- Consider commenting this out
    self:reset_extmarks(0)
    vim.wo.foldenable = false
    vim.bo[buf].modified = false
end

function Notebook:render_ipynb(bufnr)
    local buf = bufnr or api.nvim_get_current_buf()
    -- local notebook = api.nvim_buf_get_var(0, "notebook")
    self:_update_cells_from_buffer(0)
    local output_data = {}
    output_data["cells"] = self.cells
    -- Make sure empty tables are written as objects, not arrays
    for _, cell in ipairs(output_data["cells"]) do
        -- if cell["metadata"] == nil then
        --     cell["metadata"] = {}
        -- end
        setmetatable(cell["metadata"], { __jsontype = "object" })
        setmetatable(cell["outputs"], { __jsontype = "array" })
        if cell["execution_count"] == nil then
            cell["execution_count"] = 0
        end
    end

    output_data["metadata"] = self.metadata
    output_data["nbformat"] = self.nbformat
    output_data["nbformat_minor"] = self.nbformat_minor
    local ipynb_json = json.encode(output_data,
        {
            indent = true
        })
    local lines = {}
    for line in string.gmatch(ipynb_json, "([^\n]+)") do
        table.insert(lines, line)
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "json"
end

function Notebook:remove_cell(cell_id)
    cell_id = cell_id or self:_get_under_cursor_cell_id(0)
    for index, cell in ipairs(self.cells) do
        if cell.id == cell_id then
            table.remove(self.cells, index)
            break
        end
    end
    self:render_py(0)
end

function Notebook:add_cell_above()
    -- Update self.cells from buffer before modifying
    self:_update_cells_from_buffer(0)
    self:_add_cell(true)
    self:_reset_cursor("above")
end

function Notebook:add_cell_below()
    -- Update self.cells from buffer before modifying
    self:_update_cells_from_buffer(0)
    self:_add_cell(false)
    self:_reset_cursor("below")
end

function Notebook:merge_cells(cells)
    local new_source = {}
    -- Combine source lines from each cell into a single table
    for i, cell in ipairs(cells) do
        for _, line in ipairs(cell.source) do
            table.insert(new_source, line)
        end
        -- Optionally, add a newline between merged cells
        if i < #cells then
            table.insert(new_source, "\n") -- This represents a newline
        end
    end

    -- Update the source of the cell under the cursor
    local target_cell = cells[1]
    target_cell.source = new_source

    -- Remove other cells from the notebook
    for i = 2, #cells do
        self:remove_cell(cells[i].id)
    end

    -- Render the notebook to update the buffer
    self:render_py(0)
end

function Notebook:convert_type()
    -- Update self.cells from buffer before modifying
    self:_update_cells_from_buffer(0)

    local cursor_id = self:_get_under_cursor_cell_id(0)
    local cell = find_cell_by_id(self.cells, cursor_id)
    if cell.cell_type == "code" then
        cell.cell_type = "markdown"
    elseif cell.cell_type == "markdown" then
        cell.cell_type = "code"
    end
    self:render_py(0)
end

function Notebook:_simple_merge(type)
    -- Update self.cells from buffer before modifying
    self:_update_cells_from_buffer(0)

    local cursor_id = self:_get_under_cursor_cell_id(0)
    if not cursor_id then
        vim.notify("No cell found under cursor", vim.log.levels.ERROR)
        return
    end

    local other_id
    if type == "above" then
        other_id = self:_get_above_cell_id(cursor_id)
    else
        other_id = self:_get_below_cell_id(cursor_id)
    end

    if not other_id then
        vim.notify("No adjacent cell to merge with", vim.log.levels.ERROR)
        return
    end

    -- Fetch the actual cell objects
    local cell_under_cursor = find_cell_by_id(self.cells, cursor_id)
    local adjacent_cell = find_cell_by_id(self.cells, other_id)

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

    self:merge_cells(cells_to_merge)
end

function Notebook:merge_below()
    self:_simple_merge("below")
end

function Notebook:merge_above()
    self:_simple_merge("above")
end

function Notebook:reset_extmarks(bufnr)
    local buf = bufnr or 0
    api.nvim_buf_clear_namespace(buf, decor_ns, 0, -1)
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    for index, line in ipairs(lines) do
        local execution_pattern = string.match(line, EXECUTION_PATTERN)
        if execution_pattern ~= nil then
            api.nvim_buf_set_extmark(0, decor_ns, index - 1, 0,
                {
                    id = index,
                    virt_text = { { "In: " .. execution_pattern .. string.rep(" ", 10000), "CurSearch" } },
                    virt_text_pos = "overlay",
                    virt_text_win_col = 0
                })
        end
    end
    return api.nvim_buf_get_extmarks(buf, decor_ns, 0, -1, {})
end

function Notebook:get_cell_line_numbers(bufnr)
    local marks = self:reset_extmarks(bufnr)
    local line = nil
    local cell_boundaries = {}
    for _, mark in ipairs(marks) do
        line = mark[2] + 1 -- 0 indexed lines
        table.insert(cell_boundaries, line)
    end
    return cell_boundaries
end

function Notebook:_read(fname, template)
    -- Check if the file exists
    local file_exists = vim.fn.filereadable(fname) == 1
    if not file_exists then
        vim.notify("File does not exist, creating new notebook from template", vim.log.levels.DEBUG)
        return template or require("nvim-jupyter-client.template")
    end

    -- Attempt to open the file
    local ipynb_file, err = io.open(fname, "r")
    if not ipynb_file then
        -- This means the file exists but couldn't be opened (e.g., due to permissions)
        vim.notify("Could not open file " .. fname .. ": " .. err, vim.log.levels.ERROR)
        return nil -- Return nil to indicate an unrecoverable error
    end

    -- Read the file content
    local content = ipynb_file:read("*a")
    ipynb_file:close()
    if content == "" then
        vim.notify("File is empty, loading template", vim.log.levels.DEBUG)
        return template or require("nvim-jupyter-client.template")
    end

    -- Decode the JSON content
    local ipynb_json = json.decode(content)
    return ipynb_json
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

function Notebook:_get_lines(cells)
    local unescaped_lines = {} -- store a table of strings
    local lines = {}           -- split on \n to make each line explicit
    local code_str = ""
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
            -- Handle or skip other cell types like 'raw'
            -- You can decide to process them differently or skip
            vim.notify("Skipping unhandled cell type: " .. tostring(cell.cell_type), vim.log.levels.WARN)
        end
    end

    -- Safely concatenate to the last element if it exists
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

function Notebook:_update_cells_from_buffer(bufnr)
    local buf = bufnr or api.nvim_get_current_buf()
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local temp_cells = {}
    local i = 1
    local num_lines = #lines

    while i <= num_lines do
        local line = lines[i]
        -- Trim leading and trailing whitespace
        local trimmed_line = line:gsub("^%s*(.-)%s*$", "%1")
        -- Check if the line is a cell header
        if string.match(trimmed_line, "^#%s*%%%%") then
            -- Extract cell ID
            local cell_id = string.match(trimmed_line, ID_PATTERN)
            if not cell_id then
                -- No ID found, generate a new one
                cell_id = utils.uuid()
                -- Update the line in the buffer to include the new ID
                local new_header = string.format(CELL_HEADER, cell_id, " ")
                api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_header })
                -- Update lines to reflect changes
                lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
                num_lines = #lines
                line = new_header
            end
            -- Initialize cell lines
            local cell_lines = {}
            i = i + 1
            -- Collect the cell content until the next cell header or end of buffer
            while i <= num_lines do
                local content_line = lines[i]
                if string.match(content_line, "^#%s*%%%%") then
                    -- Next cell header found, break out to process it
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
            -- Add newline characters to all lines except the last
            for j = 1, #cell_lines - 1 do
                cell_lines[j] = cell_lines[j] .. "\n"
            end
            -- Find existing cell or create a new one
            local existing_cell = find_cell_by_id(self.cells, cell_id)
            if existing_cell then
                existing_cell.source = cell_lines
                table.insert(temp_cells, existing_cell)
            else
                local newCell = Cell:new()
                newCell.id = cell_id
                newCell.source = cell_lines
                -- Determine cell type based on header
                if string.find(line, "MARKDOWN") then
                    newCell.cell_type = "markdown"
                else
                    newCell.cell_type = "code"
                end
                table.insert(temp_cells, newCell)
            end
        else
            -- Not a cell header, move to the next line
            i = i + 1
        end
    end
    -- Replace self.cells with temp_cells
    self.cells = temp_cells
    self:reset_extmarks(0)
end

function Notebook:_get_under_cursor_cell_id(winnr)
    winnr = winnr or 0
    local bufnr = api.nvim_win_get_buf(winnr)
    local cursor = api.nvim_win_get_cursor(winnr) -- Row, column
    local line_num = cursor[1]
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i = line_num, 1, -1 do
        local line = lines[i]
        local match = string.match(line, ID_PATTERN)
        if match ~= nil then
            return match
        end
    end
    -- for i = line_num, 1, -1 do
    --     local match = string.match(lines[i], ID_PATTERN)
    --     if match ~= nil then
    --         return match
    --     end
    -- end
end

function Notebook:_get_id_index(cell_id)
    local cell_id_index = nil
    for index, cell in ipairs(self.cells) do
        if cell["id"] == cell_id then
            cell_id_index = index
        end
    end
    return cell_id_index
end

function Notebook:_add_cell(above)
    -- Update self.cells from buffer before modifying
    self:_update_cells_from_buffer(0)
    local win = api.nvim_get_current_win()
    local id = self:_get_under_cursor_cell_id(win)
    local index = self:_get_id_index(id)
    local cell = Cell:new()

    if index == nil then
        -- If there is no cell under the cursor
        if above then
            -- Insert at the start of the notebook
            index = 1
        else
            -- Insert at the end of the notebook
            index = #self.cells + 1
        end
    else
        if not above then
            -- Insert after the current cell
            index = index + 1
        end
        -- If above is true, we keep index as is to insert before the current cell
    end

    -- Insert the new cell at the calculated index
    table.insert(self.cells, index, cell)

    -- Render the notebook (writes self.cells to the buffer)
    self:render_py(0)

    -- Do not call _update_cells_from_buffer here
    -- self:_update_cells_from_buffer(0)
end

function Notebook:_reset_cursor(movement_type)
    local current_id = self:_get_under_cursor_cell_id(0)
    local new_id = nil
    local new_lineno = nil
    if movement_type == "below" then
        new_id = self:_get_below_cell_id(current_id)
    elseif movement_type == "above" then
        -- Move to the current cell (newly added cell) instead of the one above
        new_id = current_id
    end

    if new_id then
        new_lineno = self:_get_lineno_of_id(new_id)
        if new_lineno then
            api.nvim_win_set_cursor(0, { new_lineno + 1, 0 })
        end
    else
        vim.notify("No adjacent cell found for cursor movement", vim.log.levels.ERROR)
    end
end

function Notebook:_get_all_ids_in_buffer(bufnr)
    bufnr = bufnr or 0
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ids = {}
    -- TODO: fix bug with split function that counts splits at beginning and end
    for _, line in ipairs(lines) do
        local id = string.match(line, ID_PATTERN)
        if id ~= nil then
            table.insert(ids, id)
        end
    end
    return ids
end

function Notebook:_get_lineno_of_id(cell_id)
    local buf = api.nvim_get_current_buf()
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for lineno, line in ipairs(lines) do
        if string.match(line, ID_PATTERN) == cell_id then
            return lineno
        end
    end
end

function Notebook:_get_above_cell_id(cell_id)
    local cell_id_index = self:_get_id_index(cell_id)
    if not cell_id_index then
        vim.notify("Current cell ID not found in notebook cells", vim.log.levels.ERROR)
        return nil
    end
    if cell_id_index == 1 then
        return nil -- There is no cell above
    else
        return self.cells[cell_id_index - 1].id
    end
end

function Notebook:_get_below_cell_id(cell_id)
    local cell_id_index = self:_get_id_index(cell_id)
    if not cell_id_index then
        vim.notify("Current cell ID not found in notebook cells", vim.log.levels.ERROR)
        return nil
    end
    if cell_id_index == #self.cells then
        return nil -- There is no cell below
    else
        return self.cells[cell_id_index + 1].id
    end
end

return Notebook
