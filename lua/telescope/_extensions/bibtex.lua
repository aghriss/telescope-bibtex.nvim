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

local bib_files = {}

local function get_picker_entries()
  if BibtexCfg.include_context then
    io.get_context_bibfiles(bib_files)
  end
  io.get_user_bibfiles(BibtexCfg.user_files, bib_files)
  if BibtexCfg.relative_depth >= 0 then
    io.get_cwd_bibfiles(bib_files, BibtexCfg.relative_depth)
  end
  local entries = {}
  for _, file in pairs(bib_files) do
    local mtime = loop.fs_stat(file.name).mtime.sec
    if mtime ~= file.mtime then
      file.entries = io.parse_bibfile(file.name)
      file.mtime = mtime
    end
    for _, entry in pairs(file.entries) do
      table.insert(entries, entry)
    end
  end
  return entries
end

local function bibtex_picker(opts)
  opts = opts or {}
  local entries = get_picker_entries()
  local key_format = utils.get_key_format(
    BibtexCfg.formats,
    BibtexCfg.use_auto_format,
    BibtexCfg.citation_format
  )
  pickers
    .new(opts, {
      prompt_title = "Bibtex References",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          local display_string, search_string =
            utils.format_display(entry.content, BibtexCfg.search_keys)
          return {
            value = search_string,
            ordinal = search_string,
            display = display_string,
            entry = entry,
            -- id = line, -- not used, per documentation
          }
        end,
      }),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, entry.content)
          putils.highlighter(self.state.bufnr, "bib")
          vim.api.nvim_win_set_option(
            status.preview_win,
            "wrap",
            BibtexCfg.wrap or opts.wrap
          )
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, map)
        actions.select_default:replace(mappings.key_append(key_format))
        map("i", BibtexCfg.mappings.entry_append, mappings.entry_append)
        map(
          "i",
          BibtexCfg.mappings.citation_append,
          mappings.citation_append(
            BibtexCfg.citation_format,
            BibtexCfg.citation_trim_firstname,
            BibtexCfg.citation_max_author
          )
        )
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
