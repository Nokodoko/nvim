; Every `line` node -- one line of the markdown between tag lines -- is
; ordinary markdown: lists, headings, emphasis, and fenced code blocks (which
; get their own fence-language injection via markdown's own injections.scm)
; all work exactly as in a plain .md file.
;
; The injection targets `line`, NOT its parent `content`: a `line` starts
; after the indentation the promptmd scanner classified as positioning, so
; the markdown parser never sees it. Injecting `content` instead would hand
; markdown the raw indentation, and 4+ columns of it reads as an indented
; code block -- no headings, no emphasis, no fences.
;
; `injection.combined` merges every line in the buffer into one markdown
; parse, so multi-line constructs and fence-language injection work right
; after a tag line with no blank line in between, and consistently across
; separate promptmd sections.
((line) @injection.content
  (#set! injection.language "markdown")
  (#set! injection.combined))
