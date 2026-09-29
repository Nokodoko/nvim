; Blended markup highlighting for xml files (the `xml` leg of the
; md/xmd/xml blend). Everything between tags -- CharData -- is ordinary
; markdown: headings, emphasis, fenced code blocks, lists. Tags themselves
; keep their xml highlights from the bundled xml highlights.scm, so a
; blended file shows the same markdown AND xml highlights as .md/.xmd
; buffers (where the same blend comes from the promptmd parser plus its
; markdown content injection).
;
; `injection.combined` merges every CharData node in the buffer into one
; markdown parse, so multi-line markdown constructs (lists, fenced blocks)
; work across tag lines, exactly as in queries/promptmd/injections.scm.
; Comment, CData (CDATA sections) and PI nodes are NOT matched here and
; keep their plain xml highlighting.
((CharData) @injection.content
  (#set! injection.language "markdown")
  (#set! injection.combined))
