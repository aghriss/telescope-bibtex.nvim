require("telescope-bibtex.config")
local M = {}

M.setup = function(opts)
  opts = opts or {}
  BibtexCfg = vim.tbl_deep_extend("force", BibtexCfg, opts or {})
end

return M
