local path = require("plenary.path")
local scan = require("plenary.scandir")
local utils = require("telescope-bibtex.utils")

local M = {}

M.expand_relative_path = function(rel_path)
  local base = vim.fn.expand("%:p:h")
  -- local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  return vim.fs.normalize(base .. "/" .. rel_path)
end

M.file_exists = function(file)
  -- return vim.fn.empty(vim.fn.glob(file)) == 0
  return vim.loop.fs_stat(file) ~= nil
end

M.file_present = function(files_tb, filename)
  for _, file in pairs(files_tb) do
    if file.name == filename then
      return true
    end
  end
  return false
end

M.get_buffer_content = function()
  -- return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "")
end

M.include_file = function(bib_files, file)
  file = path:new(file):absolute()
  if (not M.file_present(bib_files, file)) and M.file_exists(file) then
    table.insert(bib_files, { name = file, mtime = 0, entries = {} })
  end
end

M.get_user_bibfiles = function(user_files, bib_files)
  for _, file in pairs(user_files) do
    local p = path:new(file)
    if p:is_dir() then
      M.get_cwd_bibfiles(file)
    elseif p:is_file() then
      M.include_file(bib_files, file)
    end
  end
end

M.get_context_bibfiles = function(bib_files)
  local parsed_files = {}
  if M.is_pandoc() then
    parsed_files = M.parse_pandoc()
  elseif M.is_latex() then
    parsed_files = M.parse_latex()
  end
  for _, file in ipairs(parsed_files) do
    M.include_file(bib_files, file)
  end
end

-- get all bib files that exist for the chosen depth in starting from dir
M.get_cwd_bibfiles = function(bib_files, depth)
  scan.scan_dir(".", {
    depth = depth,
    search_pattern = ".*%.bib",
    on_insert = function(file)
      M.include_file(bib_files, file)
    end,
  })
end

M.is_bibfile = function(file)
  return file:match("^.*%.bib") ~= nil
end

M.is_latex = function()
  return vim.o.filetype == "tex"
end

M.is_pandoc = function()
  return utils.array_contains(
    { "pandoc", "markdown", "md", "rmd", "quarto" },
    vim.o.filetype
  )
end

M.parse_pandoc = function()
  -- TODO: check if needs re-writing
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
        for _, entry in
          ipairs(utils.split_str(bib:gsub("%[", ""):gsub("%]", ""), ","))
        do
          table.insert(bibs, utils.trim_whitespace(entry))
        end
      end
      bib_started = true
    end
    for _, bib in ipairs(bibs) do
      local rel_bibs = M.expand_relative_path(bib)
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

-- get the files of bib items and inplace-add to bib_files
-- items_str: \bibliography{items_str}
M.items_to_files = function(items_str, files)
  local bibfile, bib_items
  if items_str ~= nil then
    bib_items = utils.split_str(items_str, ",")
    for _, item in ipairs(bib_items) do
      bibfile = M.expand_relative_path(item .. ".bib")
      table.insert(files, bibfile)
    end
  end
end

M.parse_latex = function()
  -- TODO: the match looks at the entire buffer, need some optimization by
  -- looking the relevant lines only. the bib items might be multi-lines
  local buffer_content = M.get_buffer_content()
  local files = {}
  local patterns = { "\\bibliography{(.-)}", "\\addbibresource{(.-)}" }
  local items_str
  for _, pattern in ipairs(patterns) do
    items_str = string.match(buffer_content, pattern)
    -- P({ "parse_latex bibs", items_str })
    M.items_to_files(items_str, files)
  end
  -- P({ "parse_latex files", files })
  return files
end

-- extract entries from the given file
M.parse_bibfile = function(bibfile)
  local entries = {}
  local p = path:new(bibfile)
  if not p:exists() then
    return {}
  end
  local data = p:read()
  for raw_entry in data:gmatch("(@[%w%s]+%b{})") do
    local entry = {}
    entry.content = utils.parse_raw_entry(raw_entry)
    entry.raw = raw_entry
    entry.bibfile = bibfile
    table.insert(entries, entry)
  end
  return entries
  -- local labels = {}
  -- local contents = {}
  -- local search_relevants = {}
  -- data = data:gsub("\r", "")
  -- local entry
  -- entry = {
  --   bibfile = bibfile,
  --   entry_type = entry_type,
  -- }
  -- for key, value in raw_entry:gmatch("%s*(%w-)%s*=.-(%b{})") do
  --   entry[key] = value:match("{(.*)}")
  -- end

  -- P({ "read_bibfile entries", entries })
  -- while true do
  --   raw_entry = data:match("@%w*%s*%b{}")
  --   if raw_entry == nil then
  --     break
  --   end
  --   table.insert(entries, raw_entry)
  --   data = data:sub(#raw_entry + 2)
  -- end
  -- for _, entry in pairs(entries) do
  --   local label = entry:match("{%s*[^{},~#%\\]+,\n")
  --   if label then
  --     label = vim.trim(label:gsub("\n", ""):sub(2, -2))
  --     local content = vim.split(entry, "\n")
  --     table.insert(labels, label)
  --     contents[label] = content
  --     search_relevants[label] = {}
  --     if utils.table_contains(BibtexCfg.search_keys, [[label]]) then
  --       search_relevants[label]["label"] = label
  --     end
  --     for _, key in pairs(BibtexCfg.search_keys) do
  --       local key_pattern = utils.construct_case_insensitive_pattern(key)
  --       local match_base = "%f[%w]" .. key_pattern
  --       local s = entry:match(match_base .. "%s*=%s*%b{}")
  --         or entry:match(match_base .. '%s*=%s*%b""')
  --         or entry:match(match_base .. "%s*=%s*%d+")
  --       if s ~= nil then
  --         s = s:match("%b{}") or s:match('%b""') or s:match("%d+")
  --         s = s:gsub('["{}\n]', ""):gsub("%s%s+", " ")
  --         search_relevants[label][key] = vim.trim(s)
  --       end
  --     end
  --   end
  -- end
  -- return labels, contents, search_relevants
end

return M
