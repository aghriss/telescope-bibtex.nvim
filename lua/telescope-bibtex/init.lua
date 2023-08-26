require("telescope-bibtex.config")
local M = {}

M.setup = function(opts)
  opts = opts or {}
  BibtexCfg = vim.tbl_deep_extend("force", BibtexCfg, opts or {})
  if not BibtexCfg.bibtex_is_setup then
    if BibtexCfg.format ~= nil then
      BibtexCfg.format_string = BibtexCfg.formats[opts.format]
    elseif BibtexCfg.use_auto_format then
      BibtexCfg.format_string = BibtexCfg.formats[vim.bo.filetype]
      if BibtexCfg.format_string == nil and vim.bo.filetype:match("markdown%.%a+") then
        BibtexCfg.format_string = BibtexCfg.formats["markdown"]
      end
    end
    BibtexCfg.format_string = BibtexCfg.format_string
      or BibtexCfg.formats[BibtexCfg.fallback_format]
  end
  BibtexCfg.bibtex_is_setup = true
end

return M
