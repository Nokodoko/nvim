" Vim color file
" Maintainer:	Chris Montgomery
" Last Change:	2006 Dec 07
" Gruv for Chris
" optimized for TFT panels

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
"colorscheme default
let g:colors_name = "gruvy"

" hardcoded colors :
"bright colors
let white=223
let gray=246
let yellow=214
let blue=66
let purple=132 
let aqua=72
let red=167

" GUI Comment : #80a0ff = Light blue

" GUI
hi Normal     guifg=Grey80	guibg=Black
hi Search     guifg=Black	guibg=Red	gui=bold
hi Visual     guifg=#404040			gui=bold
hi Cursor     guifg=Black	guibg=Green	gui=bold
hi Special    guifg=Orange
hi Comment    guifg=#80a0ff
hi StatusLine guifg=blue		guibg=white
hi Statement  guifg=Yellow			gui=NONE
hi Type						gui=NONE

" Console
hi VertSplit        guifg=#202020     guibg=#202020     gui=NONE      ctermfg=darkgray    ctermbg=NONE    cterm=NONE
hi LineNr     ctermfg=246
hi WhiteSpace ctermfg=246
hi Normal     ctermfg=223	ctermbg=Black 
hi Search     ctermfg=Black	ctermbg=75	cterm=NONE
hi Visual                   cterm=reverse
hi Cursor     ctermfg=Black	ctermbg=Green	cterm=bold
hi Special    ctermfg=166 
hi Comment    ctermfg=241
hi StatusLine ctermfg=166	ctermbg=NONE
hi String     ctermfg=yellow
hi Statement  ctermfg=167			cterm=bold
hi PreConit   ctermfg=166
hi Type       ctermfg=214   cterm=bold
hi Pmenu      ctermfg=230 ctermbg=239  
"hi goDirective 
"hi goConstants 
"hi goDeclaration 
"hi goDeclType 
"hi goBuiltins 
hi goVariable ctermbg=208
"hi Boolean
"hi CTagsClass
"hi CTagsGlobalConstant
"hi CTagsGlobalVariable
"hi CTagsImport
"hi CTagsMember
hi Character  ctermfg=166
"hi Comment
"hi Conditional
"hi Constant
hi Cursor ctermfg=green
"hi CursorColumn
"hi CursorLine
"hi Debug
"hi Define
hi DefinedName ctermfg=66
"hi Delimiter
"hi DiffAdd
"hi DiffChange
"hi DiffDelete
"hi DiffText
"hi Directory
"hi EnumerationName
"hi EnumerationValue
"hi Error
"hi ErrorMsg
"hi Exception
"hi Float
"hi FoldColumn
hi Folded ctermfg=245 ctermbg=235
hi Function ctermfg=142
hi Identifier ctermfg=108
"hi Ignore
"hi IncSearch
"hi Include
hi Keyword ctermfg=167
"hi Label
"hi LineNr
hi LocalVariable ctermfg=208
"hi Macro
"hi MatchParen
"hi ModeMsg
"hi MoreMsg
"hi NonText
"hi Normal
hi Number ctermfg=132
"hi Operator
"hi PMenu
"hi PMenuSbar
hi PMenuSel ctermfg=214 
hi PMenuThumb ctermfg=214 
"hi PreCondit
"hi PreProc
"hi Question
"hi Repeat
"hi Search
"hi SignColumn
"hi Special
"hi SpecialChar
"hi SpecialComment
"hi SpecialKey
"hi SpellBad
"hi SpellCap
"hi SpellLocal
"hi SpellRare
"hi Statement
"hi StatusLine
"hi StatusLineNC
"hi StorageClass
"hi String
"hi Structure
"hi TabLine
"hi TabLineFill
"hi TabLineSel
"hi Tag
"hi Title
"hi Todo
"hi Type
hi Typedef ctermfg=142
"hi Underlined
"hi Union
"hi VertSplit
"hi Visual
"hi VisualNOS
"hi WarningMsg
"hi WildMenu
"hi pythonBuiltin
"hi JavaScriptStri
