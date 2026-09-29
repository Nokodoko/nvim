(fenced_code_block
  (info_string
    (language) @injection.language)
  (code_fence_content) @injection.content)

;; Exception: prompt-syntax tags whose tag name contains an underscore
;; (e.g. <document_content>) break tree-sitter-html but parse cleanly under xml.
((html_block) @injection.content
  (#lua-match? @injection.content "<[%a_][%w_]*_")
  (#set! injection.language "xml")
  (#set! injection.combined)
  (#set! injection.include-children))

;; Default: ordinary HTML, unchanged from the bundled query.
((html_block) @injection.content
  (#not-lua-match? @injection.content "<[%a_][%w_]*_")
  (#set! injection.language "html")
  (#set! injection.combined)
  (#set! injection.include-children))

((minus_metadata) @injection.content
  (#set! injection.language "yaml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

((plus_metadata) @injection.content
  (#set! injection.language "toml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

([
  (inline)
  (pipe_table_cell)
] @injection.content
  (#set! injection.language "markdown_inline"))
