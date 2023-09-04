local accents_table = require("telescope-bibtex.accents")
local M = {}

-- Abbreviate author firstnames
M.abbrev_authors = function(parsed_entry, trim_firstname, citation_max_author)
  local shortened
  local authors = {}
  local sep = " and " -- Authors are separated by ' and ' in bibtex entries
  for _, auth in pairs(M.split_str(parsed_entry.author, sep)) do
    local lastname, firstnames = auth:match("(.*)%, (.*)")
    if firstnames == nil then
      firstnames, lastname = auth:match("(.*)% (.*)")
    end
    if trim_firstname == true and firstnames ~= nil then
      local initials = M.make_initials(firstnames, ".")
      auth = lastname .. ", " .. initials
    end
    table.insert(authors, auth)
  end
  if #authors > citation_max_author then
    shortened = table.concat(authors, ", ", 1, citation_max_author) .. ", et al."
  elseif #authors == 1 then
    shortened = authors[1]
  else
    shortened = table.concat(authors, ", ", 1, #authors - 1)
      .. " and "
      .. authors[#authors]
  end
  return shortened
end

M.array_contains = function(list, element)
  for _, value in ipairs(list) do
    if value == element then
      return true
    end
  end
  return false
end

-- Replace escaped accents by proper UTF-8 char
M.clean_accents = function(str)
  for k, v in pairs(accents_table) do
    str = str:gsub(k, v)
  end
  return str
end

-- Remove unwanted char from string
M.clean_str = function(str, pattern)
  str = M.clean_accents(str)
  if str ~= nil then
    str = str:gsub(pattern, "")
  else
    str = ""
  end
  return vim.trim(str:gsub("%s+", " "))
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
M.format_citation = function(parsed, citation_format, trim_firstname, citation_max_author)
  -- local parsed = M.parse_raw_entry(entry)
  if parsed.author ~= nil then
    parsed.author = M.abbrev_authors(parsed, trim_firstname, citation_max_author)
  end
  return M.format_template(parsed, citation_format)
end

M.format_display = function(entry, search_keys)
  local display_elements = {}
  local search_elements = {}
  for _, val in pairs(search_keys) do
    if tonumber(entry[val]) ~= nil then
      table.insert(display_elements, " (" .. entry[val] .. ") ")
    elseif entry[val] ~= nil then
      table.insert(display_elements, entry[val])
    end

    table.insert(search_elements, entry[val])
  end
  local display_string = vim.trim(table.concat(display_elements), ",")
  local search_string = vim.trim(table.concat(search_elements), ",")
  display_string = (#display_string > 0 and display_string) or entry.label
  search_string = (#search_string > 0 and search_string) or entry.label
  return display_string, search_string
end

-- Format parsed entry according to template
M.format_template = function(parsed, citation_format)
  local citation = citation_format
  for k, v in pairs(parsed) do
    citation = citation:gsub("{" .. k .. "}", v)
  end
  -- clean non-exsisting fields
  citation = M.clean_str(citation, "{.-}")
  return citation
end

M.get_bibkeys = function(parsed_entry)
  local bibkeys = {}
  for key, _ in pairs(parsed_entry) do
    table.insert(bibkeys, key)
  end
  return bibkeys
end

-- if this returns nil, then we need to use the fallback_format
M.get_key_format = function(formats, use_auto_format, citation_format)
  if use_auto_format then
    local format_string = formats[vim.o.filetype]
    if format_string ~= nil then
      return format_string
    end
    if vim.bo.filetype:match("markdown%.%a+") then
      return formats["markdown"]
    end
  end
  return formats[citation_format]
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
M.parse_raw_entry = function(raw_entry)
  local type, fields = raw_entry:match("@([%w%s]+)(%b{})")
  local parsed = { type = type, label = fields:match("{([^,]+)") }
  for key, value in fields:gmatch("%s*(%w-)%s*=.-(%b{})") do
    parsed[key] = M.clean_str(value, "[%{|%}]")
  end
  return parsed
end

-- Split a string according to a delimiter
M.split_str = function(str, delim)
  local elements = {}
  for match in str:gmatch("([^" .. delim .. "]+)") do
    table.insert(elements, match)
  end
  return elements
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
