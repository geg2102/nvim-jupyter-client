local M = {}
local api = vim.api
local buffer_ops = require("nvim-jupyter-client.objects.notebook.buffer_operations")

local CELL_HEADER = "# %%%% %s [%s]\n"

function M.render_py(notebook, bufnr)
    if bufnr == nil then
        vim.cmd('tabnew')
    end
    local win = api.nvim_get_current_win()
    local buf = bufnr or api.nvim_win_get_buf(win)
    vim.bo[buf].buflisted = true
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "python"
    vim.bo[buf].autoread = false

    local lines = M._get_lines(notebook.cells)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    buffer_ops.reset_extmarks(0)
    vim.wo.foldenable = false
    vim.bo[buf].modified = false
    buffer_ops.update_cells_from_buffer(notebook, buf)
end

function M.render_ipynb(notebook, bufnr)
    local buf = bufnr or api.nvim_get_current_buf()
    notebook:_update_cells_from_buffer(0)
    local output_data = {
        cells = notebook.cells,
        metadata = notebook.metadata,
        nbformat = notebook.nbformat,
        nbformat_minor = notebook.nbformat_minor
    }

    for _, cell in ipairs(output_data.cells) do
        setmetatable(cell.metadata, { __jsontype = "object" })
        setmetatable(cell.outputs, { __jsontype = "array" })
        if cell.execution_count == nil then
            cell.execution_count = 0
        end
    end

    local ipynb_json = json.encode(output_data, { indent = true })
    local lines = {}
    for line in string.gmatch(ipynb_json, "([^\n]+)") do
        table.insert(lines, line)
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "json"
end

function M._get_lines(cells)
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
            local source_content = table.concat(cell.source, "")
            -- Check if content is already wrapped in """
            local content_str
            if source_content:match('^""".*"""$') then
                content_str = source_content
            else
                content_str = string.format('"""\n%s\n"""', source_content)
            end
            local markdown_str = string.format('%s%s',
                string.format(CELL_HEADER, cell.id, "MARKDOWN"),
                content_str)
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

return M
