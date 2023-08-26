local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error(
    "This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)"
  )
end
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")
local conf = require("telescope.config").values
local loop = vim.loop

local io = require("telescope-bibtex.files")
local mappings = require("telescope-bibtex.mappings")
local utils = require("telescope-bibtex.utils")

-- variables to save entries
local user_files = {}
local files_initialized = false
local files = {}
local context_files = {}

local function get_picker_entries()
  if BibtexCfg.context then
    io.get_context_bibfiles(context_files)
  end
  if not files_initialized then
    io.init_files(user_files, files)
    files_initialized = true
  end
  local results = {}
  local current_files = files
  if BibtexCfg.context and next(context_files) then
    current_files = context_files
  end
  for _, file in pairs(current_files) do
    local mtime = loop.fs_stat(file.name).mtime.sec
    if mtime ~= file.mtime then
      file.entries = {}
      local result, content, search_relevants = io.read_file(file.name)
      for _, entry in pairs(result) do
        table.insert(results, {
          name = entry,
          content = content[entry],
          search_keys = search_relevants[entry],
        })
        table.insert(file.entries, {
          name = entry,
          content = content[entry],
          search_keys = search_relevants[entry],
        })
      end
      file.mtime = mtime
    else
      for _, entry in pairs(file.entries) do
        table.insert(results, entry)
      end
    end
  end
  return results
end

local function bibtex_picker(opts)
  opts = opts or {}
  local results = get_picker_entries()
  pickers
    .new(opts, {
      prompt_title = "Bibtex References",
      finder = finders.new_table({
        results = results,
        entry_maker = function(line)
          local display_string, search_string =
            utils.format_display(line.search_keys)
          if display_string == "" then
            display_string = line.name
          end
          if search_string == "" then
            search_string = line.name
          end
          return {
            value = search_string,
            ordinal = search_string,
            display = display_string,
            id = line,
          }
        end,
      }),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
          vim.api.nvim_buf_set_lines(
            self.state.bufnr,
            0,
            -1,
            true,
            results[entry.index].content
          )
          putils.highlighter(self.state.bufnr, "bib")
          vim.api.nvim_win_set_option(
            status.preview_win,
            "wrap",
            utils.parse_wrap(opts, BibtexCfg.wrap)
          )
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, map)
        actions.select_default:replace(mappings.key_append)
        map("i", BibtexCfg.mappings.entry_append, mappings.entry_append)
        map("i", BibtexCfg.mappings.citation_append, mappings.citation_append)
        map("i", BibtexCfg.mappings.field_append, mappings.field_append(opts))
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  setup = function(ext_config, _)
    require("telescope-bibtex").setup(ext_config)
  end,
  exports = {
    bibtex = bibtex_picker,
  },
})
