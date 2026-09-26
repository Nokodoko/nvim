; Mirrors the html/xml textobjects.scm convention bundled with
; nvim-treesitter-textobjects (element -> function.outer/inner), renamed to
; the generic block.outer/block.inner group.

(element) @block.outer

(element
  (start_tag)
  .
  (_) @block.inner
  .
  [(end_tag) (erroneous_end_tag)])

(element
  (start_tag)
  _+ @block.inner
  [(end_tag) (erroneous_end_tag)])
