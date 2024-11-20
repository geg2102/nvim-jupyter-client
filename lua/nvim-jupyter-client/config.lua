-- config.lua
local M = {}

M.defaults = {
    nbformat = 4,
    nbformat_minor = 5,
    metadata = {
        kernelspec = {
            display_name = "Python 3 (ipykernel)",
            language = "python",
            name = "python3"
        },
        language_info = {
            name = "python",
            version = "", -- Will be filled dynamically if empty
            mimetype = "text/x-python",
            codemirror_mode = {
                name = "ipython",
                version = 3
            },
            file_extension = ".py",
            pygments_lexer = "ipython3",
            nbconvert_exporter = "python"
        }
    }
}


M.options = vim.tbl_deep_extend("force", {}, M.defaults)

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", {}, M.options, opts or {})
end

return M
