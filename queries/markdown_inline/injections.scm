;; Exception: prompt-syntax tags whose tag name contains an underscore
;; (e.g. <document_content>) break tree-sitter-html but parse cleanly under xml.
((html_tag) @injection.content
  (#lua-match? @injection.content "<[%a_][%w_]*_")
  (#set! injection.language "xml")
  (#set! injection.combined))

;; Default: ordinary HTML, unchanged from the bundled query.
((html_tag) @injection.content
  (#not-lua-match? @injection.content "<[%a_][%w_]*_")
  (#set! injection.language "html")
  (#set! injection.combined))

((latex_block) @injection.content
  (#set! injection.language "latex")
  (#set! injection.include-children))
