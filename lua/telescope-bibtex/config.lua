if not BibtexCfg then
  -- local citation_format = "{{author}} ({{year}}), {{title}}."
  BibtexCfg = {
    bibtex_is_setup = false,
    citation_format = "{author} ({year}), {title}.",
    citation_trim_firstname = true,
    citation_max_author = 2,
    wrap = false,
    search_keys = { "author", "year", "title" },
    formats = {
      tex = "\\cite{%s}",
      md = "@%s",
      markdown = "@%s",
      rmd = "@%s",
      quarto = "@%s",
      pandoc = "@%s",
      plain = "%s",
    },
    fallback_format = "plain",
    use_auto_format = true,
    user_files = {},
    include_context = true,
    relative_depth = 1,

    mappings = {
      entry_append = "<c-e>",
      citation_append = "<c-c>",
      field_append = "<c-f>",
    },
    bib_files = {}
  }
end
