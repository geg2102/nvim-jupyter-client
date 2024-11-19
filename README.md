# nvim-jupyter-client
[![asciicast](https://asciinema.org/a/x9usnBgPpL8AcmgaG3vOk5qrG.svg)](https://asciinema.org/a/x9usnBgPpL8AcmgaG3vOk5qrG)

A Neovim plugin for editing Jupyter notebooks in Neovim, providing a seamless integration between `.ipynb` files and Neovim's editing capabilities.

## Features

- Open and edit Jupyter notebooks (`.ipynb` files) directly in Neovim
- Convert between code and markdown cells
- Add, remove, and merge cells
- Automatic cell boundary detection and highlighting
- Preserves notebook metadata and cell outputs
- Native Neovim feel while maintaining Jupyter notebook compatibility

## Installation
Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'geg2102/nvim-jupyter-client',
    config = function()
        require('nvim-jupyter-client').setup({})
    end
}
```

## Configuration

Basic setup with default configuration:

```lua
require('nvim-jupyter-client').setup({})
```

Custom configuration with template:

```lua
require('nvim-jupyter-client').setup({
    template = {
        cells = {
            {
                cell_type = "code",
                execution_count = nil,
                metadata = {},
                outputs = {},
                source = {"# Custom template cell\n"}
            }
        },
        metadata = {
            kernelspec = {
                display_name = "Python 3",
                language = "python",
                name = "python3"
            }
        },
        nbformat = 4,
        nbformat_minor = 5
    }
})
```

## Commands

Example configuration with specific keybindings:

```lua
-- Add cells
vim.keymap.set("n", "<leader>ja", "<cmd>JupyterAddCellBelow<CR>", { desc = "Add Jupyter cell below" })
vim.keymap.set("n", "<leader>jA", "<cmd>JupyterAddCellAbove<CR>", { desc = "Add Jupyter cell above" })

-- Cell operations
vim.keymap.set("n", "<leader>jd", "<cmd>JupyterRemoveCell<CR>", { desc = "Remove current Jupyter cell" })
vim.keymap.set("n", "<leader>jm", "<cmd>JupyterMergeCellAbove<CR>", { desc = "Merge with cell above" })
vim.keymap.set("n", "<leader>jM", "<cmd>JupyterMergeCellBelow<CR>", { desc = "Merge with cell below" })
vim.keymap.set("n", "<leader>jt", "<cmd>JupyterConvertCellType<CR>", { desc = "Convert cell type (code/markdown)" })
```


- `:JupyterAddCellBelow` - Add a new cell below the current cell
- `:JupyterAddCellAbove` - Add a new cell above the current cell
- `:JupyterRemoveCell` - Remove the current cell
- `:JupyterMergeCellAbove` - Merge current cell with the cell above
- `:JupyterMergeCellBelow` - Merge current cell with the cell below
- `:JupyterConvertCellType` - Toggle between code and markdown cell types

## Usage

1. Open a Jupyter notebook:

2. The plugin automatically converts the notebook into an editable format while preserving all notebook metadata.

3. Edit cells as normal Neovim text. Cell boundaries are automatically detected and highlighted.

4. Save changes using `:w` to maintain all changes in underlying `ipynb` file:

## Notes

- The plugin maintains notebook compatibility by preserving all metadata and cell information
- Cell execution count and outputs are preserved when saving
- Files are saved in standard `.ipynb` format

## Requirements

- Neovim >= 0.10.0

## Bonus 

- The rendered `.ipynb` file will also work with [nvim-python-repl](https://github.com/geg2102/nvim-python-repl). 

## Acknowledgements
- This pluging heavily leverages [dkjson](https://github.com/LuaDist/dkjson) Lua JSON library (packaged with plugin)

## License

MIT License
