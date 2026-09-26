; Every `content` node -- the markdown between tag lines -- is ordinary
; markdown: lists, headings, emphasis, and fenced code blocks (which get
; their own fence-language injection via markdown's own injections.scm)
; all work exactly as in a plain .md file. `injection.combined` merges every
; content node in the buffer into one markdown parse, so multi-line
; constructs and fence-language injection work right after a tag line with
; no blank line in between, and consistently across separate promptmd
; sections.
((content) @injection.content
  (#set! injection.language "markdown")
  (#set! injection.combined))
