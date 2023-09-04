local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local utils = require("telescope-bibtex.utils")

local M = {}

M.key_append = function(format_string)
  return function(prompt_bufnr)
    local mode = vim.api.nvim_get_mode().mode
    local entry =
      string.format(format_string, action_state.get_selected_entry().entry.label)
    actions.close(prompt_bufnr)
    if mode == "i" then
      vim.api.nvim_put({ entry }, "", false, true)
      vim.api.nvim_feedkeys("a", "n", true)
    else
      vim.api.nvim_put({ entry }, "", true, true)
    end
  end
end

M.entry_append = function(prompt_bufnr)
  -- P({ "get_selected_entry", action_state.get_selected_entry() })
  local content = action_state.get_selected_entry().entry.raw
  -- P({ "get_selected_entry.content", content })
  content = utils.split_str(content, "\n")
  -- P({ "get_selected_entry.content", content })
  actions.close(prompt_bufnr)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "i" then
    vim.api.nvim_put(content, "", false, true)
    vim.api.nvim_feedkeys("a", "n", true)
  else
    vim.api.nvim_put(content, "", true, true)
  end
end

M.field_append = function(opts)
  return function(prompt_bufnr)
    local parsed = action_state.get_selected_entry().entry.content
    -- local parsed = utils.parse_raw_entry(bib_entry)
    actions.close(prompt_bufnr)
    pickers
      .new(opts, {
        prompt_title = "Bibtex fields",
        sorter = conf.generic_sorter(opts),
        finder = finders.new_table({
          results = utils.get_bibkeys(parsed),
        }),
        previewer = previewers.new_buffer_previewer({
          define_preview = function(self, entry, status)
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              -1,
              true,
              { parsed[entry[1]] }
            )
            vim.api.nvim_win_set_option(status.preview_win, "wrap", true)
          end,
        }),
        attach_mappings = function(sub_prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(sub_prompt_bufnr)
            local selection = action_state.get_selected_entry()
            local mode = vim.api.nvim_get_mode().mode
            if mode == "i" then
              vim.api.nvim_put({ parsed[selection[1]] }, "", false, true)
              vim.api.nvim_feedkeys("a", "n", true)
            else
              vim.api.nvim_put({ parsed[selection[1]] }, "", true, true)
            end
          end)
          return true
        end,
      })
      :find()
  end
end

M.citation_append = function(
  citation_format,
  citation_trim_firstname,
  citation_max_author
)
  local map_function = function(prompt_bufnr)
    local entry = action_state.get_selected_entry().entry.content
    actions.close(prompt_bufnr)
    local citation = utils.format_citation(
      entry,
      citation_format,
      citation_trim_firstname,
      citation_max_author
    )
    local mode = vim.api.nvim_get_mode().mode
    if mode == "i" then
      vim.api.nvim_put({ citation }, "", false, true)
      vim.api.nvim_feedkeys("a", "n", true)
    else
      vim.api.nvim_paste(citation, true, -1)
    end
  end
  return map_function
end
return M
