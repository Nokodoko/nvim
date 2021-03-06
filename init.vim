" _       _ _         _           
"(_)_ __ (_) |___   _(_)_ __ ___  
"| | '_ \| | __\ \ / / | '_ ` _ \ 
"| | | | | | |_ \ V /| | | | | | |
"|_|_| |_|_|\__| \_/ |_|_| |_| |_|


"let $NVIM_TUI_ENABLE_TRUE_COLOR=1                               
let mapleader = "t"
set background=dark    
syntax on
colorscheme gruvbox
syn match Braces display '[:={}()\[\]]'
hi Braces guifg=blue
filetype on                                
set ma
set hidden
set si 
set scrolloff=5 
set tabstop=5 softtabstop=5
set history=1000
set autoindent
set relativenumber 
set nu
set noerrorbells
set undodir=~/.nvim/undodir
nnoremap <F13>:set cursorline!<cr> :set cursorcolumn!<cr>
set undofile
set nobackup
set noswapfile
set smartcase
"set nowrap
set expandtab
set smartindent
set shiftwidth=4
set showcmd
set t_co=256
set t_AB=^[[48;5;%dm
set t_AF=^[[38;5;%dm
set splitright
set splitbelow
set laststatus=2
set clipboard=unnamedplus
set list
set listchars=tab:\|\ 
set nocompatible
set encoding=utf-8
hi DiffAdd ctermfg=142  ctermbg=235
hi DiffChange  ctermfg=166 ctermbg=235
hi DiffDelete ctermfg=132 ctermbg=235
"hi DiffText ctermfg=  ctermbg=None
set diffopt=internal,filler,vertical,context:5,foldcolumn:1,indent-heuristic,algorithm:patience

highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline
highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline

let g:vimwiki_table_mappings = 0

let g:semanticTermColors = [28,9,13,49,89,190,118,7,45,57,129,208,46,13,14,15,159,125,124,249]

inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

let g:coc_snippet_next = '<tab>'
"augroup aug_color_scheme
"    au!
"
"autocmd ColorScheme gruvy call s:PatchColorScheme()
"augroup END

"function s:PatchColorScheme()
"    hi! link DiffChange NONE
"    hi! clear DiffChange
"    hi! DiffText term=None ctermfg=215 ctermbg=233 cterm=NONE
"endfunction

function! FirstFunction()
    echom "First Vim function!"
endfunction


"
"
"Modifying .VIMRC
nnoremap <leader>t :TableModeEnable<cr>
nnoremap <leader>d :TableModeDisable<cr>
nnoremap <BS> :bd<cr>
nnoremap <M-Up> :bn<cr>
nnoremap <M-Down> :bp<cr>
nnoremap <M-(> ci(
nnoremap <M-{> ci{
nnoremap <M-"> ci"
nnoremap <M-'> ci'
nnoremap <leader>a :help airline-configuration<cr>
nnoremap <leader>B :split $HOME/.zshrc<cr>
nnoremap <leader>e :split $HOME/.config/nvim/init.vim<cr>
nnoremap <leader>E :vsplit $HOME/.config/nvim/init.vim<cr>
nnoremap  :source $HOME/.config/nvim/init.vim<cr>
nnoremap <leader>q :term://gtop<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://glances<cr>:set number!<cr>:set relativenumber!<cr>
nnoremap <leader>3 :vsplit term://tty-clock -c<cr>:set number!<cr>:set relativenumber!<cr>:split term://zsh<cr>:split term://cmus<cr><esc><C-w>h<C-w>h
nnoremap <F12> :vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://tty-clock -c<cr>:split term://cmus<cr>:split term://calcurse<cr><C-W>h<C-W>h
nnoremap <leader>1 :vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://neomutt<cr><cr>:vsplit term://glances<cr>:split term://gtop<cr>:split term://cmus<cr>:vsplit term://calcurse<cr><C-W>k<C-W>k:vsplit term://tty-clock -cs<cr><C-w>h<C-w>h<C-w>h
nnoremap <leader>m :vsplit term://cmus<cr>
nnoremap <leader>o :set ma<cr>
nnoremap <leader><F2> :split term://cmus<cr>
nnoremap <leader>r <C-w>la<esc>k<cr><C-\><C-n><C-w>h<esc>
nnoremap <leader>s :SemanticHighlightToggle<cr>
nnoremap <Down> :split term://zsh<cr>:set number!<cr>:set relativenumber!<cr>a
nnoremap <C-Down> :split term://zsh<cr>:set number!<cr>:set relativenumber!<cr>agm<cr>
nnoremap <leader><C-Space> :vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>a
nnoremap <leader><Right>  :vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>a
nnoremap <leader>z :split term://tty-clock -c<cr>:set number!<cr>:set relativenumber!<cr>:
nnoremap <leader>M :vsplit erm://neomutt<cr>
nnoremap <esc> A
nnoremap ' cw
nnoremap " caw
nnoremap <C-'> dw<esc><esc>
nnoremap <C-Space> f cw
nnoremap <leader>> <C-w>v<C-w>60>
map <F6> :setlocal spell! spelllang=en_us<cr>
nnoremap <silent> <Right> :Files<cr>
nnoremap <silent> <S-F6> :Lines<cr>
nnoremap <silent> <Up> :RG<cr> 
nnoremap <Left> :Buffers<cr>
nnoremap <silent> <F1> :Helptags<cr>
imap <c-x><c-f> <plug>(fzf-complete-path)

"  ____       ____ 
" / ___|___  / ___|
"| |   / _ \| |    
"| |__| (_) | |___ 
" \____\___/ \____|
"

if exists('*complete_info')
  inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
else
  imap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
endif

nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)


 "Splitting
nnoremap <leader>v :vsplit<cr>
nnoremap <leader>c :split<cr>

vnoremap <C-c> "+y
vnoremap <Up> g<C-a>

"Changing buffers
nnoremap <F6>  l
nnoremap <F4>  j
nnoremap <F5>  k
nnoremap <F10> h
nnoremap <leader>b :checkhealth<cr>
nnoremap <leader>C :CocInfo<cr>
nnoremap <M-r> :CocRestart<cr>
nnoremap <leader>i :CocInstall
"nnoremap <leader>d :g/^$/d<cr>
map <leader>n :cnext<cr>
map <leader>N :cprevious<cr>
noremap <leader>gc :GCheckout<cr>
noremap <leader>g :GitMessenger<cr>
let g:git_messenger_no_default_mappings = v:true
    
"Changing Terminal Buffers
tnoremap <A-h> <C-\><C-N><C-w>h
tnoremap <A-j> <C-\><C-N><C-w>j
tnoremap <A-k> <C-\><C-N><C-w>k 
tnoremap <A-l> <C-\><C-N><C-w>l
nnoremap <F3> :w!<cr>
inoremap <F3> <esc>:w!<cr>
nnoremap <leader>V :VimBeGood<cr>

let g:kitty_navigator_no_mappings = 1

nnoremap <silent> <M-F10> :KittyNavigateLeft<cr>
nnoremap <silent> <M-F4> :KittyNavigateDown<cr>
nnoremap <silent> <M-F5> :KittyNavigateUp<cr>
nnoremap <silent> <M-F6> :KittyNavigateRight<cr>

nnoremap Q :q!<cr>
nnoremap <F9> :set hlsearch!<cr> 

"
"Headers
iabbrev bh #!/bin/bash
iabbrev adn and
iabbrev ec echo ""
iabbrev cs $()
iabbrev ts [[ ]]
iabbrev gv #Global Variables
iabbrev fs #Functions
iabbrev qt /* vim: set filetype=tex : */
iabbrev \l {\Latex}
iabbrev  for(i=;i ;i )<Esc>F=a
iabbrev rf func recurse (i int)int{}<esc>i<cr><esc>Ototal=1<esc>ofor ; i>0; i--{}<esc>i<cr>total=i<esc>2jareturn total<esc>2kF=i
iabbrev pg Plug ''<esc>T'i
iabbrev gogo // 2>/dev/null;/usr/bin/go run $0 $@; exit $?

autocmd FileType tex nnoremap <F7> :VimtexCompile<cr>
autocmd FileType tex nnoremap <F17> :VimtexView<cr>

"Escaping Terminal mode
tnoremap <M-F10> <C-\><C-n><C-w>h
tnoremap  <C-\><C-n>:q!<cr>

filetype plugin on


call plug#begin()
Plug 'hkupty/iron.nvim'
Plug 'donRaphaco/neotex'
Plug 'https://github.com/kevinhwang91/rnvimr.git'
Plug 'stsewd/fzf-checkout.vim'
Plug 'garyburd/go-explorer'
Plug 'brennier/quicktex'
Plug 'jaxbot/semantic-highlight.vim'
Plug 'Valloric/vim-operator-highlight'
Plug 'jacoborus/tender.vim'
Plug 'ryanoasis/vim-devicons'
Plug 'knubie/vim-kitty-navigator'
"Plug 'ternjs/tern_for_vimWatch'
Plug 'flazz/vim-colorschemes'
Plug 'uarun/vim-protobuf'
Plug 'rhysd/git-messenger.vim'
Plug 'dhruvasagar/vim-table-mode'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'morhetz/gruvbox'
Plug 'ThePrimeagen/vim-be-good'
Plug 'machakann/vim-highlightedyank'
Plug 'luochen1990/rainbow'
Plug 'jalvesaq/Nvim-R'
Plug 'plasticboy/vim-markdown'
Plug 'lervag/vimtex'
"Plug 'xuhdev/vim-latex-live-preview'
Plug 'edkolev/tmuxline.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'vimwiki/vimwiki'
Plug 'golang/tools'
Plug 'ncm2/ncm2-bufword'
Plug 'ncm2/ncm2-path'
Plug 'Shougo/neocomplete.vim'
Plug 'tpope/vim-fugitive'
Plug 'BurntSushi/ripgrep'
Plug 'majutsushi/tagbar'
Plug 'roxma/nvim-yarp'
Plug 'SirVer/ultisnips'
Plug 'preservim/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'neoclide/coc.nvim', {'do': 'yarn install --frozen-lockfile'}
Plug 'jiangmiao/auto-pairs'
Plug 'mattn/emmet-vim'
Plug 'mattn/webapi-vim'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'AndrewRadev/splitjoin.vim'
Plug 'unblevable/quick-scope'       
Plug 'jceb/vim-orgmode'
call plug#end() 

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction
let g:fzf_layout ={'window': {'width': 0.8, 'height': 0.8}}
"let $FZF_DEFAULT_OPTS='--reverse'

command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)


function! s:isAtStartOfLine(mapping)
  let text_before_cursor = getline('.')[0 : col('.')-1]
  let mapping_pattern = '\V' . escape(a:mapping, '\')
  let comment_pattern = '\V' . escape(substitute(&l:commentstring, '%s.*$', '', ''), '\')
  return (text_before_cursor =~? '^' . ('\v(' . comment_pattern . '\v)?') . '\s*\v' . mapping_pattern . '\v$')
endfunction

inoreabbrev <expr> <bar><bar>
          \ <SID>isAtStartOfLine('\|\|') ?
          \ '<c-o>:TableModeEnable<cr><bar><space><bar><left><left>' : '<bar><bar>'
inoreabbrev <expr> __
          \ <SID>isAtStartOfLine('__') ?
          \ '<c-o>:silent! TableModeDisable<cr>' : '__'

nnoremap <leader>4 :PlugInstall<cr>
nnoremap <leader>@ :PlugUpdate<cr>
nnoremap <leader># :PlugClean<cr>

" _____                          _   
"| ____|_ __ ___  _ __ ___   ___| |_ 
"|  _| | '_ ` _ \| '_ ` _ \ / _ \ __|
"| |___| | | | | | | | | | |  __/ |_ 
"|_____|_| |_| |_|_| |_| |_|\___|\__|
let g:user_emmet_install_global = 0
let g:multi_cursor_use_default_mapping=0
let g:user_emmet_leader_key='tt'

autocmd Filetype html nnoremap <F7> :!xdg-open % <cr>

autocmd Filetype html,css EmmetInstall
iabbrev hh html:5tt,
"
"  ____       
" / ___| ___  
"| |  _ / _ \ 
"| |_| | (_) |
" \____|\___/ 
autocmd FileType go inoremap nN \u2717
autocmd FileType go inoremap :o os.Args[]<esc>i
autocmd FileType go inoremap yY \u2713
autocmd FileType go inoremap  /**/F*i
autocmd FileType go inoremap pout println()<space><esc>T(i
autocmd FileType go inoremap lout log.Println()<space><esc>T(i
autocmd FileType go inoremap lof log.Printf()<space><esc>T(i
autocmd FileType go inoremap fout fmt.Println()<space><esc>T(i
autocmd FileType go inoremap fof fmt.Printf()<space><esc>T(i
autocmd FileType go inoremap fos fmt.Sprintf()<space><esc>T(i
autocmd FileType go inoremap foe fmt.Errorf()<space><esc>T(i
autocmd FileType go inoremap toe t.Error()<space><esc>T(i
autocmd FileType go inoremap .. :=
autocmd FileType go inoremap :imp import
autocmd FileType go inoremap :b []byte0
autocmd FileType go inoremap  for i := ; i ; i {}<esc>i<cr><esc>k0f;i
autocmd FileType go inoremap :sw switch {}<esc>i<cr><esc>Ocase:<esc>Fea
autocmd FileType go inoremap :case case ():<esc>F)i
autocmd FileType go inoremap :ar x := []{}<esc>F{i
autocmd FileType go inoremap ** :[]{}<esc>F{i
autocmd FileType go inoremap :dsl append([:],[:])<esc>0f:
autocmd FileType go inoremap :make make([],){}<esc>i<cr><esc>k0f]a
autocmd FileType go inoremap :: ...
autocmd FileType go inoremap :L <-
autocmd FileType go inoremap :gar var x = []{}<esc>F{i
autocmd FileType go inoremap :add x = append(x,)<esc>0fx
autocmd FileType go inoremap :append x = append(x,...)<esc>0fx
autocmd FileType go inoremap :del x = append([:],[:]...)<esc>0f:
autocmd FileType go inoremap :amap m[]=type{}<esc>0f[a
autocmd FileType go inoremap :map m := make(map[type]type)
autocmd FileType go inoremap :dmap delete(m,key)<esc>Fk
autocmd FileType go inoremap :s type name struct{}<esc>i<cr><esc>Ofield type<esc>kFn
autocmd FileType go inoremap :m func main(){}<esc>i<cr><esc>O
autocmd FileType go inoremap :i type name interface{}<esc>i<cr><esc>Omethod<esc>kFm
autocmd FileType go inoremap vok //TEST<cr>v, ok := m[""]<cr>fmt.Println(v)<cr>fmt.Println(ok)<cr><cr>if v, ok := m[""]; ok{}<esc>i<cr>fmt.Println("value:", v)<esc>5k0f"a
autocmd FileType go inoremap <M-r> for i, v := range * {}<esc>i<cr>fmt.Println(i, v)<cr><esc>2k0f*cw
autocmd FileType go inoremap <M-R> for v := range * {}<esc>i<cr>fmt.Println(v)<cr><esc>2k0f*cw
autocmd FileType go inoremap  :v v, ok := <-c<esc>ofmt.Println(v,ok)
autocmd FileType go inoremap :mar b, err := json.Marshal()<cr>if err != nil{}<esc>i<cr><esc>Ofmt.Println("error:", err)<esc>jofmt.Println(string(b))<esc>o//os.STdout.Write(b)<esc>5k0f(a
autocmd FileType go inoremap :umar err := json.Unmarshal()<cr>if err != nil{}<esc>i<cr><esc>Ofmt.Println("error:", err)<esc>jofmt.Println(var)<esc>o//os.STdout.Write(var)<esc>5k0f(a
autocmd FileType go inoremap  func (b By--) Len() int {return len(b)}<cr>func (b By--) Swap (i, j int) {b[i], b[j]=b[j], b[i]}<cr>func (b By--) Less (i, j int) bool {return b[i].-- < b[j].--}<cr><cr>sort.Sort(By--(var))
autocmd FileType go inoremap  if err != nil{}<esc>i<cr><esc>Ofmt.Println(err)<esc>
autocmd FileType go inoremap :wait var wg sync.WaitGroup<cr>wg.Add()<cr>wg.Done()<cr>wg.Wait()
autocmd FileType go inoremap :mut var mu sync.Mutex<cr>mu.Lock()<cr>mu.Unlock()
autocmd FileType go inoremap <M-R> return
autocmd FileType go inoremap <Right> string
autocmd FileType go inoremap <M-CR> return
autocmd FileType go inoremap  error
autocmd FileType go inoremap <Left> int
autocmd FileType go inoremap <Up> []byte()<esc>i
autocmd FileType go inoremap <M-Right> []string
autocmd FileType go inoremap <M-F20> []int{}<esc>i
autocmd FileType go inoremap <Down> type
autocmd FileType go inoremap <M-Down> func 
autocmd FileType go inoremap <M-Left> map[key](value)<esc>Fk
autocmd FileType go inoremap :wg var wg sync.WaitGroup
autocmd FileType go inoremap :mu var mu sync.Mutex
autocmd FileType go inoremap <M-Up> c := make (chan )<esc>F a
autocmd FileType go inoremap  func() {<cr>}()<esc>O
autocmd FileType go inoremap  (t *testing.T) {<cr>}esc>O
autocmd FileType go inoremap  (b *testing.B) {<cr>}<esc>Ofor i:=0; i<b.N; i++
autocmd FileType go inoremap <F5> chan 
autocmd FileType go inoremap <F6> ctx := context.Background()
autocmd FileType go nnoremap <S-F1> :GoDoc<cr>
autocmd FileType go nnoremap <M-F1> :GoDef<cr>
autocmd FileType go nnoremap <C-S-F1> :GeDoc 
autocmd FileType go nnoremap <F12> :GoInfo<cr>
autocmd FileType go nnoremap <F19> :GoPlay<cr>
autocmd FileType go nnoremap <F16> :GoAlternate<cr>
autocmd FileType go nnoremap <M-f> daf
autocmd FileType go nnoremap <M-F> dif
autocmd FileType go nnoremap <F18> :go tool! cover -html=c.out
autocmd FileType go inoremap <S-F7> <esc> :GoFillStruct<cr>
autocmd FileType go nnoremap <F7> res, err := http.Get()<cr>if err != nil{<cr>}<esc>Olog.Fatal(err)
"let g:go_def_resuse_buffer
map <leader>G :GoTestFunc<cr>
"let g:go_auto_sameids = 1
let g:go_fmt_command = "goimports" 

autocmd FileType proto inoremap :s syntax = "proto3";<cr><cr>option go_package = "";<cr><cr>message {}<esc>i<cr><esc>k0f i
autocmd FileType proto inoremap <Right> string
autocmd FileType proto inoremap <Left> int32

"  ____ ____ ____  
" / ___/ ___/ ___| 
"| |   \___ \___ \ 
"| |___ ___) |__) |
" \____|____/____/ 
"                  
"---------------FONT---------------
autocmd FileType css inoremap :fs font-size:;<esc>i
autocmd FileType css inoremap :fc font-color:;<esc>i
autocmd FileType css inoremap :ff font-family:;<esc>i
autocmd FileType css inoremap :fw font-weight:;<esc>i
autocmd FileType css inoremap :fv font-variant:;<esc>i
"---------------ALIGN---------------
"autocmd FileType css inoremap :alc align-items:center;
"autocmd FileType css inoremap :h height:;<esc>i
"autocmd FileType css inoremap :lh line-height:;<esc>i
"autocmd FileType css inoremap :ta text-align:;<esc>i
"autocmd FileType css inoremap :w width:;<esc>i
"autocmd FileType css inoremap :fl flex-direction:;<esc>i
"autocmd FileType css inoremap :c color:;<esc>i
""---------------ATTRIBUTE---------------
"autocmd FileType css inoremap :tar [target="_blank"]:focus{<cr>}<esc>O
""---------------JUSTIFY--------------
"autocmd FileType css inoremap :jc justify-content:;<esc>i
"autocmd FileType css inoremap :jc justify-content:;<esc>i
""---------------BORDER---------------
"autocmd FileType css inoremap :bd border:;<esc>i
"autocmd FileType css inoremap :br border-radius:;<esc>i
""---------------BACKGROUND---------------
"autocmd FileType css inoremap bc background-color:;<esc>i
""---------------TYPES---------------
"autocmd FileType css inoremap :ts [type=submit]{<cr>}<esc>O
"autocmd FileType css inoremap :tsf [type=submit]:focus{<cr>}<esc>O
"autocmd FileType css inoremap :tsh [type=submit]:hover{<cr>}<esc>O
""---------------MARGINS---------------
"autocmd FileType css inoremap :mt margin-top:;<esc>i
"autocmd FileType css inoremap :m margin:;<esc>i
"autocmd FileType css inoremap :m0 margin: 0 auto;<esc>i
""---------------INPUT---------------
"autocmd FileType css inoremap :ir input:required{<cr>}<esc>O
"autocmd FileType css inoremap :ir input:required{<cr>}<esc>O
""---------------PADDING---------------
"autocmd FileType css inoremap :pt padding-top:;<esc>i
" ____            _       ____            _       _   _             
"| __ )  __ _ ___| |__   / ___|  ___ _ __(_)_ __ | |_(_)_ __   __ _ 
"|  _ \ / _` / __| '_ \  \___ \ / __| '__| | '_ \| __| | '_ \ / _` |
"| |_) | (_| \__ \ | | |  ___) | (__| |  | | |_) | |_| | | | | (_| |
"|____/ \__,_|___/_| |_| |____/ \___|_|  |_| .__/ \__|_|_| |_|\__, |
"                                          |_|                |___/ 
"Bash Scripting Syntax 
let @f = 'i() {function}b'
let @p = 'cwprintln!("");hh'
let @r = 'a$()????aci(var????abcw????a'
let g:airline_theme='distinguished'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
" _         _____         
"| |    __ |_   _|____  __
"| |   / _` || |/ _ \ \/ /
"| |__| (_| || |  __/>  < 
"|_____\__,_||_|\___/_/\_\
autocmd FileType tex inoremap
autocmd FileType tex inoremap :art \documentclass{article}<Space><Esc>T{i
autocmd FileType tex inoremap :beam \documentclass{beamer}<Space><Esc>T{i
autocmd FileType tex inoremap :stand \documentclass{standalone}<Space><Esc>T{i
autocmd FileType tex inoremap :up \usepackage{}<Space><Esc>T{i
autocmd FileType tex inoremap :uP \usepackage[]<Space><Esc>T[i
autocmd FileType tex inoremap :ua \usepackage{algorithm}<Space><Esc>T{i
autocmd FileType tex inoremap :ul \usepackage{listings}<Space><Esc>T{i
autocmd FileType tex inoremap :ut \usepackage{tikz}<Space><Esc>T{i
autocmd FileType tex inoremap :cen \begin{center}<cr><cr><cr><cr>\end{center}<Esc>2ki
autocmd FileType tex inoremap :doc \begin{document}<cr><cr><cr><cr>\end{document}<Esc>2ki
autocmd FileType tex inoremap :ba \begin{algorithm}<cr>\begin{algorithmic}<cr><cr>\end{algorithmic}<cr>\end{algorithm}<Esc>2Oi
autocmd FileType tex inoremap :bb \begin{abstract}<cr>\end{abstract}<Esc>2Oi
autocmd FileType tex inoremap :algo \begin{algorithm}<cr><cr><cr><cr>\end{algorithm}<Esc>2Oi<Tab>
autocmd FileType tex inoremap :tik \begin{tikzpicture}<cr><cr>\end{tikzpicture}<Esc>ki<Tab>
autocmd FileType tex inoremap :gant \begin{gantt}[drawledgerline=true]{}<cr><cr>\end{gantt}<Esc>2k$F{a
autocmd FileType tex inoremap :gt \begin{ganttitle}<cr>\end{ganttitle}<Esc>Oa
autocmd FileType tex inoremap :gm \gantmilestone{}{}<Space><Esc>0f{a
autocmd FileType tex inoremap :gg \gantgroup{}{}<Space><Esc>0f{a
autocmd FileType tex inoremap :gb \gantbar[color=/defcolor]{}{}{}<Space><Esc>0f{a
autocmd FileType tex inoremap :gc \gantbarcon[color=/defcolor]{}{}{}<Space><Esc>0f{a
autocmd FileType tex inoremap :block \begin{block}<cr>\end{block}<Esc>Oa
autocmd FileType tex inoremap :frame \begin{frame}<cr><cr>\end{frame}<Esc>ki
autocmd FileType tex inoremap :f1 \frametitle{}<Space><Esc>T{i
autocmd FileType tex inoremap :vb \begin{verbatim}<cr><cr>\end{verbatim}<Esc>Oa
autocmd FileType tex inoremap :pm \begin{pmatrix}<cr><cr>\end{pmatrix}<Esc>Oa
autocmd FileType tex inoremap :list \begin{lstlistings}<cr><cr>\end{lstlistings}<Esc>Oa
autocmd FileType tex inoremap :ew \[<cr><cr>\]<Esc>Oi
autocmd FileType tex inoremap :sec \section{}<Space><Esc>T{i
autocmd FileType tex inoremap :ss \subsection{}<Space><Esc>T{i
autocmd FileType tex inoremap :in \input{}<Space><Esc>T{i
autocmd FileType tex inoremap :ref ~\ref{}<Space><Esc>T{i
autocmd FileType tex inoremap :cite ~\cite{}<Space><Esc>T{i
autocmd FileType tex inoremap :ll \label{}<Space><Esc>T{i
autocmd FileType tex inoremap :ls \lstset{}<Space><Esc>T{i
autocmd FileType tex inoremap :nc \newcommand{\}{\}<Esc>0f\a
autocmd FileType tex inoremap :tit \title{}<Space><Esc>T{i
autocmd FileType tex inoremap :mt \maketitle
autocmd FileType tex inoremap :yo \maketitle
autocmd FileType tex inoremap :auth \author{Chris Montgomery}<Space><Esc>T{i
autocmd FileType tex inoremap :tab \begin{table}<cr>\end{table}<Esc>ko\begin{tabular}{}\\ \hline<cr><cr>\end{tabular}<esc>o\hline<esc>o\caption{}\label{} <esc>4kf{a
autocmd FileType tex inoremap :ab \begin{abstract}<cr><cr>\end{abstract}<Esc>Oi<Space><Space><Space>
autocmd FileType tex inoremap :ol \begin{enumerate}<cr><cr>\end{enumerate}<Esc>Oi<Space><Space><Space>\item
autocmd FileType tex inoremap :tm \begin{itemize}<cr><cr>\end{itemize}<Esc>Oi<Space><Space><Space>\item
autocmd FileType tex inoremap :fig \begin{figure}<cr><cr>\end{figure}<Esc>Oi<Space><Space><Space>
autocmd FileType tex inoremap :cap \caption{}<Space><Esc>T{i
autocmd FileType tex inoremap :ig \includegraphics[]{}<Space><Esc>T{i
autocmd FileType tex inoremap :bo \textbf{}<Esc>T{i
autocmd FileType tex inoremap :em \emph{}<Space><Esc>T{i
autocmd FileType tex inoremap :it \textit{}<Esc>T{i
autocmd FileType tex inoremap :bib \bibliography{}<Space><Esc>T{i
autocmd FileType tex inoremap :x \being{xlist}<Cr>\ex<Space>\end{xlist}<Esc>ka<Space>
autocmd FileType tex inoremap :/ \\*
autocmd FileType tex nnoremap tq :!pdflatex
autocmd FileType tex inoremap :su {\displaytyle subset}
autocmd FileType tex inoremap :cc \cancel{}<esc>F{a
autocmd FileType tex nnoremap <S-F7> :NeoTexOn<cr>
autocmd FileType tex nnoremap <S-F8> :NeoTexOff<cr>

"Math
autocmd FileType tex inoremap :$ $$<Space><Esc>F$i

nmap <F8> :TagbarToggle<CR>

let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'

let g:tex_flavor  = 'latex'
let g:tex_conceal = ''
"let g:qs_highlight_on_keys = ['f', 'F']
"let g:vimtex_fold_manual = 1
"let g:vimtex_latexmk_continuous = 1
"let g:vimtex_compiler_progname = 'nvr'

let g:asyncomplete_auto_popup = 1


highlight Pmenu ctermbg=234 
highlight Pmenu ctermfg=15 

"nmap <C-n> :NERDTreeToggle<CR>
"autocmd VimEnter * NERDTree | wincmd p
nnoremap  :RnvimrToggle<cr>

" Make Ranger replace Netrw and be the file explorer
let g:rnvimr_enable_ex = 1

" Make Ranger to be hidden after picking a file
let g:rnvimr_enable_picker = 1

" Disable a border for floating window
let g:rnvimr_draw_border = 0

" Hide the files included in gitignore
let g:rnvimr_hide_gitignore = 1

" Change the border's color
let g:rnvimr_border_attr = {'fg': 14, 'bg': -1}

" Make Neovim wipe the buffers corresponding to the files deleted by Ranger
let g:rnvimr_enable_bw = 1

" Set up only two columns in miller mode and draw border with both
let g:rnvimr_ranger_cmd = 'ranger --cmd="set column_ratios 1,1"
            \ --cmd="set draw_borders both"'
if !exists('##TextYankPost')
  map y <Plug>(highlightedyank)
endif
"
" Link CursorLine into RnvimrNormal highlight in the Floating window
highlight link RnvimrNormal CursorLine

" Resize floating window by all preset layouts
tnoremap <silent> <M-i> <C-\><C-n>:RnvimrResize<CR>

" Resize floating window by special preset layouts
tnoremap <silent> <M-l> <C-\><C-n>:RnvimrResize 1,8,9,11,5<CR>

" Resize floating window by single preset layout
tnoremap <silent> <M-y> <C-\><C-n>:RnvimrResize 6<CR>

" Map Rnvimr action
let g:rnvimr_action = {
            \ '<C-t>': 'NvimEdit tabedit',
            \ '<C-x>': 'NvimEdit split',
            \ '<C-v>': 'NvimEdit vsplit',
            \ 'gw': 'JumpNvimCwd',
            \ 'yw': 'EmitRangerCwd'
            \ }

let g:highlightedyank_highlight_duration = 100
"let g:airline_symbols
"let g:airline_theme='distinguished'
let g:airline_powerline_fonts = 1
"let g:airline#extensions#cursormode#enabled = 1
let g:cursormode_mode_func = 'mode'

nnoremap <leader><BS> :ls<CR>:b<Space>

luafile $HOME/.config/nvim/plugins.lua
