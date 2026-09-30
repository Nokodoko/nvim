; Blended markup highlighting for xml files (the `xml` leg of the
; md/xmd/xml blend). Everything between tags -- CharData -- is ordinary
; markdown: headings, emphasis, fenced code blocks, lists. Tags themselves
; keep their xml highlights from the bundled xml highlights.scm, so a
; blended file shows the same markdown AND xml highlights as .md/.xmd
; buffers (where the same blend comes from the promptmd parser plus its
; markdown content injection).
;
; CharData is injected as `promptmd`, NOT directly as markdown: xml content
; is normally indented to its nesting depth, and markdown reads 4+ columns
; of indentation as an indented code block. The promptmd parser sees no tags
; here (xml already consumed them), so all it does is split the text into
; `line` nodes that start after the positioning indentation;
; queries/promptmd/injections.scm then injects markdown over those, exactly
; as in a .md/.xmd buffer.
;
; `injection.combined` merges every CharData node in the buffer into one
; promptmd parse, so multi-line markdown constructs (lists, fenced blocks)
; work across tag lines. Comment, CData (CDATA sections) and PI nodes are
; NOT matched here and keep their plain xml highlighting.
((CharData) @injection.content
  (#set! injection.language "promptmd")
  (#set! injection.combined))
