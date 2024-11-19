if exists('g:loaded_nvim_jupyter_client')
    finish
endif
let g:loaded_nvim_jupyter_client = 1

command! -nargs=0 JupyterAddCellBelow lua require('nvim-jupyter-client').get_notebook():add_cell_below()
command! -nargs=0 JupyterAddCellAbove lua require('nvim-jupyter-client').get_notebook():add_cell_above()
command! -nargs=0 JupyterRemoveCell lua require('nvim-jupyter-client').get_notebook():remove_cell()
command! -nargs=0 JupyterMergeCellAbove lua require('nvim-jupyter-client').get_notebook():merge_above()
command! -nargs=0 JupyterMergeCellBelow lua require('nvim-jupyter-client').get_notebook():merge_below()
command! -nargs=0 JupyterConvertCellType lua require('nvim-jupyter-client').get_notebook():convert_type()
command! -nargs=0 JupyterNew lua require('nvim-jupyter-client').new_notebook()
