local utils = require("nvim-jupyter-client.utils.utils")
local json = require("dkjson")
local handle = io.popen("python --version")
local result = handle:read("*a")
handle:close()
local python_version = result:match("%d+%.%d+%.%d+")


local template_str = [[{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": null,
   "id": "%s",
   "metadata": {},
   "outputs": [],
   "source": []
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3 (ipykernel)",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "file_extension": ".py",
   "mimetype": "text/x-python",
   "name": "python",
   "nbconvert_exporter": "python",
   "pygments_lexer": "ipython3",
   "version": "%s"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}]]

local bare_notebook = string.format(template_str, utils.uuid(), python_version)
return json.decode(bare_notebook)
