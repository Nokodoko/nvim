; Highlights for promptmd tag lines. Ordinary markdown content is NOT
; highlighted here -- it is handled by the markdown/markdown_inline
; injection defined in injections.scm, using their own highlights.scm.

["<" ">" "/"] @tag.delimiter

(tag_name) @tag

(attribute_name) @tag.attribute
(attribute_value) @string

(erroneous_end_tag
  (tag_name) @error)
