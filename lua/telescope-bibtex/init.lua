require("telescope-bibtex.config")
local M = {}

M.setup = function(opts)
  opts = opts or {}
  BibtexCfg = vim.tbl_deep_extend("force", BibtexCfg, opts or {})
  -- TODO sanity checks
  -- -- check if citation_format in formats
  -- -- check if fallback_format in formats
  --  
end

return M
