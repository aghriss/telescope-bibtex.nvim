local M = {}

-- Abbreviate author firstnames
M.abbrev_authors = function(parsed)
  -- opts = opts or {}
  -- opts.trim_firstname = opts.trim_firstname or true
  -- opts.max_auth = opts.max_auth or 2

  local shortened
  local authors = {}
  local sep = " and " -- Authors are separated by ' and ' in bibtex entries

  for _, auth in pairs(M.split_str(parsed.author, sep)) do
    local lastname, firstnames = auth:match("(.*)%, (.*)")
    if firstnames == nil then
      firstnames, lastname = auth:match("(.*)% (.*)")
    end
    if BibtexCfg.trim_firstname == true and firstnames ~= nil then
      local initials = M.make_initials(firstnames, ".")
      auth = lastname .. ", " .. initials
    end

    table.insert(authors, auth)
  end

  if #authors > BibtexCfg.max_auth then
    shortened = table.concat(authors, ", ", 1, BibtexCfg.max_auth) .. ", et al."
  elseif #authors == 1 then
    shortened = authors[1]
  else
    shortened = table.concat(authors, ", ", 1, #authors - 1)
      .. " and "
      .. authors[#authors]
  end

  return shortened
end


-- Replace escaped accents by proper UTF-8 char
M.clean_accents = function(str)
  local mappingTable = require("bibtex.accents")
  for k, v in pairs(mappingTable) do
    str = str:gsub(k, v)
  end
  return str
end

-- Remove unwanted char from string
M.clean_str = function(str, exp)
  str = M.clean_accents(str)
  if str ~= nil then
    str = str:gsub(exp, "")
  end

  return str
end

M.construct_case_insensitive_pattern = function(key)
  local pattern = ""
  for char in key:gmatch(".") do
    if char:match("%a") then
      pattern = pattern .. "[" .. string.lower(char) .. string.upper(char) .. "]"
    else
      pattern = pattern .. char
    end
  end
  return pattern
end

-- Parse bibtex entry and format the citation
M.format_citation = function(entry)
  local parsed = M.parse_entry(entry)
  -- local opts = {}
  -- opts.trim_firstname = citation_trim_firstname
  -- opts.max_auth = citation_max_auth

  if parsed.author ~= nil then
    parsed.author = M.abbrev_authors(parsed)
  end

  return M.format_template(parsed)
end

M.format_display = function(entry)
  local display_string = ""
  local search_string = ""
  for _, val in pairs(BibtexCfg.search_keys) do
    if tonumber(entry[val]) ~= nil then
      display_string = display_string .. " " .. "(" .. entry[val] .. ")"
      search_string = search_string .. " " .. entry[val]
    elseif entry[val] ~= nil then
      display_string = display_string .. ", " .. entry[val]
      search_string = search_string .. " " .. entry[val]
    end
  end
  return vim.trim(display_string:sub(2)), search_string:sub(2)
end

-- Format parsed entry according to template
M.format_template = function(parsed, template)
  local citation = template

  for k, v in pairs(parsed) do
    citation = citation:gsub("{{" .. k .. "}}", v)
  end

  -- clean non-exsisting fields
  citation = M.clean_str(citation, "{{.-}}")

  return citation
end

M.get_bibkeys = function(parsed_entry)
  local bibkeys = {}
  for key, _ in pairs(parsed_entry) do
    table.insert(bibkeys, key)
  end
  return bibkeys
end

-- Replace string by initials of each word
M.make_initials = function(str, delim)
  delim = delim or ""
  local initials = ""
  local words = M.split_str(str, " ")

  for i = 1, #words, 1 do
    initials = initials .. words[i]:gsub("[%l|%.]", "") .. delim
    if i ~= #words then
      initials = initials .. " "
    end
  end

  return initials
end

-- Parse bibtex entry into a table
M.parse_entry = function(entry)
  local parsed = {}
  for _, line in pairs(entry) do
    if line:sub(1, 1) == "@" then
      parsed.type = string.match(line, "^@(.-){")
      parsed.label = string.match(line, "^@.+{(.-),$")
    end
    for field, val in string.gmatch(line, '(%w+)%s*=%s*["{]*(.-)["}],?$') do
      parsed[field] = M.clean_str(val, "[%{|%}]")
    end
  end
  return parsed
end

M.parse_wrap = function(opts, user_wrap)
  local wrap = user_wrap
  if opts.wrap ~= nil then
    wrap = opts.wrap
  end
  return wrap
end

-- Split a string according to a delimiter
M.split_str = function(str, delim)
  local result = {}
  for match in (str .. delim):gmatch("(.-)" .. delim) do
    table.insert(result, match)
  end
  return result
end

M.table_contains = function(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

M.trim_whitespace = function(str)
  return str:match("^%s*(.-)%s*$")
end

return M
