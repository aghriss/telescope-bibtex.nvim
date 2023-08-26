local path = require("plenary.path")
local scan = require("plenary.scandir")
local utils = require("telescope-bibtex.utils")

local M = {}

M.extend_relative_path = function(rel_path)
  local base = vim.fn.expand("%:p:h")
  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  return base .. path_sep .. rel_path
end

M.file_exists = function(file)
  return vim.fn.empty(vim.fn.glob(file)) == 0
end

M.file_present = function(files_tb, filename)
  for _, file in pairs(files_tb) do
    if file.name == filename then
      return true
    end
  end
  return false
end

M.get_buffer_lines = function()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
M.is_latex = function()
  return vim.o.filetype == "tex"
end

M.is_pandoc = function()
  return vim.o.filetype == "pandoc"
    or vim.o.filetype == "markdown"
    or vim.o.filetype == "md"
    or vim.o.filetype == "rmd"
    or vim.o.filetype == "quarto"
end

M.init_files = function(user_files, files)
  for _, file in pairs(user_files) do
    local p = path:new(file)
    if p:is_dir() then
      M.get_bibfiles(file)
    elseif p:is_file() then
      if not utils.file_present(files, file) then
        table.insert(files, { name = file, mtime = 0, entries = {} })
      end
    end
  end
  M.get_bibfiles(".")
end

M.parse_pandoc = function()
  local files = {}
  local bib_started = false
  local bib_yaml = "bibliography:"
  for _, line in ipairs(M.get_buffer_lines()) do
    local bibs = {}
    if bib_started then
      local bib = line:match("- (.+)")
      if bib == nil then
        bib_started = false
      else
        table.insert(bibs, bib)
      end
    elseif line:find(bib_yaml) then
      local bib = line:match(bib_yaml .. " (.+)")
      if bib then
        for _, entry in ipairs(utils.split_str(bib:gsub("%[", ""):gsub("%]", ""), ",")) do
          table.insert(bibs, utils.trim_whitespace(entry))
        end
      end
      bib_started = true
    end
    for _, bib in ipairs(bibs) do
      local rel_bibs = M.extend_relative_path(bib)
      local found = nil
      if M.file_exists(bib) then
        found = bib
      elseif M.file_exists(rel_bibs) then
        found = rel_bibs
      end
      if found ~= nil then
        table.insert(files, bib)
      end
    end
  end
  return files
end

M.parse_latex = function()
  local files = {}
  for _, line in ipairs(M.get_buffer_lines()) do
    local bibs = line:match("^[^%%]*\\bibliography{(%g+)}")
    local bib_resource = line:match("^[^%%]*\\addbibresource{(%g+)}")
    if bibs then
      for _, bib in ipairs(utils.split_str(bibs, ",")) do
        bib = M.extend_relative_path(bib .. ".bib")
        if M.file_exists(bib) then
          table.insert(files, bib)
        end
      end
    elseif bib_resource then
      bib_resource = M.extend_relative_path(bib_resource)
      if M.file_exists(bib_resource) then
        table.insert(files, bib_resource)
      end
    end
  end
  return files
end

M.get_context_bibfiles = function(context_files)
  local found_files = {}
  if M.is_pandoc() then
    found_files = M.parse_pandoc()
  elseif M.is_latex() then
    found_files = M.parse_latex()
  end
  for _, file in pairs(found_files) do
    if not M.file_present(context_files, file) then
      table.insert(context_files, { name = file, mtime = 0, entries = {} })
    end
  end
end

-- get all bib files that exist for the chosen depth in starting from dir
M.get_bibfiles = function(dir, files)
  scan.scan_dir(dir, {
    depth = BibtexCfg.depth,
    search_pattern = ".*%.bib",
    on_insert = function(file)
      local p = path:new(file):absolute()
      if not utils.file_present(files, p) then
        table.insert(files, { name = p, mtime = 0, entries = {} })
      end
    end,
  })
end

-- extract entries from the given file
M.read_file = function(file)
  local labels = {}
  local contents = {}
  local search_relevants = {}
  local p = path:new(file)
  if not p:exists() then
    return {}
  end
  local data = p:read()
  data = data:gsub("\r", "")
  local entries = {}
  local raw_entry = ""
  while true do
    raw_entry = data:match("@%w*%s*%b{}")
    if raw_entry == nil then
      break
    end
    table.insert(entries, raw_entry)
    data = data:sub(#raw_entry + 2)
  end
  for _, entry in pairs(entries) do
    local label = entry:match("{%s*[^{},~#%\\]+,\n")
    if label then
      label = vim.trim(label:gsub("\n", ""):sub(2, -2))
      local content = vim.split(entry, "\n")
      table.insert(labels, label)
      contents[label] = content
      search_relevants[label] = {}
      if utils.table_contains(BibtexCfg.search_keys, [[label]]) then
        search_relevants[label]["label"] = label
      end
      for _, key in pairs(BibtexCfg.search_keys) do
        local key_pattern = utils.construct_case_insensitive_pattern(key)
        local match_base = "%f[%w]" .. key_pattern
        local s = entry:match(match_base .. "%s*=%s*%b{}")
          or entry:match(match_base .. '%s*=%s*%b""')
          or entry:match(match_base .. "%s*=%s*%d+")
        if s ~= nil then
          s = s:match("%b{}") or s:match('%b""') or s:match("%d+")
          s = s:gsub('["{}\n]', ""):gsub("%s%s+", " ")
          search_relevants[label][key] = vim.trim(s)
        end
      end
    end
  end
  return labels, contents, search_relevants
end

return M
