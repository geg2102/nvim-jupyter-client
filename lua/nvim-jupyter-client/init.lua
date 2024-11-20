local api = vim.api
local Notebook = require("nvim-jupyter-client.objects.notebook")

local M = {}

M.config = {
    -- Users can provide their own template or a function returning a template
    template = nil,
    get_template = function()
        return require("nvim-jupyter-client.template")
    end
}

-- Get notebook instance for current buffer
function M.get_notebook()
    local notebook = vim.b.notebook
    if notebook then
        -- Only set metatable if it's not already set
        if not getmetatable(notebook) then
            setmetatable(notebook, Notebook)
        end
    end
    return notebook
end

-- Iniitialize notebook for current buffer
function M.init_notebook()
    local buf = api.nvim_get_current_buf()
    local filename = api.nvim_buf_get_name(buf)
    local notebook = nil

    vim.notify("Initializing notebook for: " .. filename, vim.log.levels.DEBUG)

    local template = M.config.template or M.config.get_template()

    -- Always call Notebook:new with filename
    notebook = Notebook:new(filename, template)
    if notebook then
        notebook:render_py(buf)
    else
        vim.notify("Failed to load notebook from file", vim.log.levels.ERROR)
        return nil
    end

    -- Store notebook instance directly in buffer variable
    if notebook then
        vim.b.notebook = notebook
        return notebook
    end
    return nil
end

-- Setup autocommands for a buffer
local function setup_autocommands(buf)
    -- Only set up autocommands if this is a notebook buffer
    if not vim.b.notebook then
        return
    end

    local group = api.nvim_create_augroup('jupyterrender_' .. buf, { clear = true })

    -- Override the write action to save the notebook
    api.nvim_create_autocmd({ "BufWriteCmd" }, {
        group = group,
        buffer = buf,
        callback = function()
            if not api.nvim_buf_is_valid(buf) then
                return
            end
            local nb = M.get_notebook()
            if nb then
                local win = api.nvim_get_current_win()
                local cursor_pos = api.nvim_win_get_cursor(win) -- Store cursor position
                local success, err = pcall(function()
                    -- Update cells from current buffer content
                    -- nb:_update_cells_from_buffer(buf)
                    -- Save the notebook state
                    nb:save()
                    -- Reset the modified flag
                    vim.bo[buf].modified = false
                end)
                if success then
                    vim.notify("Notebook saved to " .. nb.filename, vim.log.levels.INFO)
                else
                    vim.notify("Error saving notebook: " .. err, vim.log.levels.ERROR)
                end
                -- Restore cursor position
                api.nvim_win_set_cursor(win, cursor_pos)
            end
        end
    })
end

-- Setup function to be called when loading a notebook
function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
    -- Create autocommand to initialize notebooks when opening appropriate files
    local group = api.nvim_create_augroup('jupyterinit', { clear = true })
    api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = group,
        pattern = { "*.ipynb" },
        callback = function()
            M.init_notebook()
            setup_autocommands(api.nvim_get_current_buf())
        end
    })
end

return M
