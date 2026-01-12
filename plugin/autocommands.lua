-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--    (lua autocommands)autocmd FileType lua inoremap i local status_ok, = pcall(require, "")<cr>if not status_ok then<cr>return<cr>end<esc>3kf,a
--    (lua autocommands)autocmd FileType lua inoremap <leader>mi local modules = {}<cr>local <cr><cr><cr>for i, module in ipairs(modules)do<cr>local status_ok, required_module = pcall(require, module)<cr>if not status_ok then<cr>print("Could not import" .. module)<cr>return<cr>end<cr><cr>if i == 1 then<cr> = required_module<cr>end<cr>end<esc>14kci{
--    (python autocommands)autocmd FileType python inoremap ca case in<esc>o;;<esc>oesac
--    (python autocommands) autocmd FileType python inoremap read read -p "" ANSWER<esc>F"ci"
--    (python autocommands) autocmd FileType python inoremap ii if []; then<esc>oelse<esc>ofi<esc>2kf[ci[
--    (python autocommands) autocmd FileType python inoremap ? RC=$?
--    (python autocommands) autocmd FileType python inoremap NS ns=notify-send
--    (python autocommands) autocmd FileType python inoremap DM dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
--    (python autocommands) autocmd FileType python inoremap DN dun='dunstify -h int:value:'
--    (python autocommands) autocmd FileType python inoremap e<Right> echo $()<esc>ci(
--    (python autocommands) autocmd FileType python inoremap <leader>x :! chmod +x ./%
--    (python autocommands) autocmd FileType python inoremap .. ${}<esc>T{i
--    (python autocommands) autocmd FileType python inoremap <Right> alias=''<esc>i
--    (python autocommands) autocmd FileType python inoremap fn function() {<cr>}<esc>kfn;a
--    (python autocommands) autocmd FileType python inoremap  for<esc>odo<esc>odone<esc>O
vim.cmd([[
  augroup _general_settings
    autocmd!
    autocmd FileType qf,help,man,lspinfo nnoremap <silent> <buffer> q :close<CR> 
    autocmd TextYankPost * silent!lua require('vim.highlight').on_yank({higroup = 'Visual', timeout = 200}) 
    autocmd BufWinEnter * :set formatoptions-=cro
    autocmd FileType qf set nobuflisted
  augroup end


  augroup _git
    autocmd!
    autocmd FileType gitcommit setlocal wrap
    autocmd FileType gitcommit setlocal spell
  augroup end

  augroup _markdown
    autocmd!
    autocmd FileType markdown setlocal wrap
    autocmd FileType markdown setlocal spell
  augroup end

  augroup _auto_resize
    autocmd!
    autocmd VimResized * tabdo wincmd = 
  augroup end

  augroup _alpha
    autocmd!
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
  augroup end

  augroup vimwikwi
    autocmd!
    autocmd FileType vimwiki inoremap b<Right> _**_<esc>hi
    autocmd FileType vimwiki inoremap i<Right> __<esc>ha
  augroup end

  augroup kmonad
  autocmd!
  autocmd BufRead,BufNewFile *.kbd set filetype=lisp
  augroup end

  augroup zsh
    autocmd!
    autocmd FileType zsh inoremap bh #!/usr/bin/env bash
    autocmd FileType zsh inoremap .. ${}<esc>T{i
    autocmd FileType zsh inoremap <Right> alias=''<esc>i
    autocmd FileType zsh inoremap fn function() {<cr>}<esc>kfn;a 
    autocmd FileType zsh inoremap  for<esc>odo<esc>odone<esc>O
    autocmd FileType zsh inoremap :ca case in<esc>o;;<esc>oesac
    autocmd FileType zsh inoremap :read read -p "" ANSWER<esc>F"ci"
    autocmd FileType zsh inoremap ii if []; then<esc>oelse<esc>ofi<esc>2kf[ci[
    autocmd FileType zsh inoremap :? RC=$?
    autocmd FileType zsh inoremap :NS ns=notify-send
    autocmd FileType zsh inoremap :DM dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
    autocmd FileType zsh inoremap :DN dun='dunstify -h int:value:'
    autocmd FileType zsh inoremap <leader>x :! chmod +x ./% 
  augroup end

  augroup lua
  autocmd!
    autocmd FileType lua nnoremap <leader>x :! lua % <cr>
    autocmd FileType lua inoremap lc local 
    autocmd FileType lua inoremap rq require("")<esc>F"i
    autocmd FileType lua inoremap <Left> int
    autocmd FileType lua inoremap <Right> string
    autocmd FileType lua inoremap fout print()<esc>T(i""<esc>ci"
    autocmd FileType lua inoremap bh #!/usr/bin/env env lua<cr><cr><cr>
    autocmd FileType lua inoremap -x local mobdebug = require("mobdebug")<cr>mobdebug.start()<esc>Gomobdebug.done()<esc>
  augroup end


  augroup rust
    autocmd!
    autocmd FileType rust inoremap fout println!();hi""i
    autocmd FileType rust inoremap ;s struct {}bi
    autocmd FileType rust inoremap ;dd #[derive(Debug)]ostruct {}bi
    autocmd FileType rust inoremap <Left> i32
    autocmd FileType rust inoremap <Right> String
    autocmd FileType rust inoremap ;kk {:?}f"a,
    autocmd FileType rust inoremap ;jj {}

  augroup end


  augroup python
    autocmd!
    autocmd FileType python inoremap bh #!/usr/bin/env python3
    autocmd FileType python inoremap !s stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, text=True)
    autocmd FileType python inoremap Ff # vim: set fdm=marker fdl=0 foldmethod=marker foldlevel=0:
  augroup end

  augroup sh
    autocmd!
    autocmd FileType sh inoremap bh #!/usr/bin/env bash 
    autocmd FileType sh inoremap bh #!/usr/bin/env bash<cr><cr>ns=notify-send<cr>dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'<cr>dun='dunstify -h int:value:'
    autocmd FileType sh inoremap .. ${}<esc>T{i
    autocmd FileType sh inoremap <Right> alias=''<esc>i
    autocmd FileType sh inoremap fn function() {<cr>}<esc>kfn;a 
    autocmd FileType sh inoremap  for<esc>odo<esc>odone<esc>O
    autocmd FileType sh inoremap :ca case in<esc>o;;<esc>oesac
    autocmd FileType sh inoremap :read read -p "" ANSWER<esc>F"ci"
    autocmd FileType sh inoremap ii if []; then<esc>oelse<esc>ofi<esc>2kf[ci[
    autocmd FileType sh inoremap :? RC=$?
    autocmd FileType sh inoremap :NS ns=notify-send
    autocmd FileType sh inoremap :DM dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
    autocmd FileType sh inoremap :DN dun='dunstify -h int:value:'
    autocmd FileType sh inoremap <leader>x :! chmod +x ./% <cr>
  augroup end

  augroup go
    autocmd!
"Go
    autocmd FileType go inoremap v<Right> var ()<esc>ha<cr><esc>O
    autocmd FileType go inoremap nN \✗
    autocmd FileType go inoremap yY \✓
    autocmd FileType go inoremap  /**/<esc>F*i
    autocmd FileType go inoremap pout println();space><esc>T(i
    autocmd FileType go inoremap lout log.Println()<space><esc>T(i
    autocmd FileType go inoremap iu ioutil.
    autocmd FileType go inoremap lout log.Printf()<space><esc>T(i
    autocmd FileType go inoremap lof log.Fatal()<space><esc>T(i
    autocmd FileType go inoremap lop log.Println()<space><esc>T(i
    autocmd FileType go inoremap scan fmt.Scanln()<space><esc>T(i
    autocmd FileType go inoremap fout fmt.Println()<space><esc>T(i
    autocmd FileType go inoremap fof fmt.Printf()<space><esc>T(i
    autocmd FileType go inoremap fos fmt.Sprintf()<space><esc>T(i
    autocmd FileType go inoremap foe fmt.Errorf()<space><esc>T(i
    autocmd FileType go inoremap toe t.Error()<space><esc>T(i
    autocmd FileType go inoremap .. :=
    autocmd FileType go inoremap :imp import
    autocmd FileType go inoremap b<Right> []byte
    autocmd FileType go inoremap f<Right> for i := ; i ; i {}<esc>i<cr><esc>k0f;i
    autocmd FileType go inoremap :case case ():<esc>F)i
    autocmd FileType go inoremap :s switch {}<esc>i<cr><esc>Ocase:<esc>Fea
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
    autocmd FileType go inoremap s<Right> type name struct{}<esc>i<cr><esc>Ofield type<esc>kFn
    autocmd FileType go inoremap m<Right> func main(){}<esc>i<cr><esc>O
    autocmd FileType go inoremap i<Right> type name interface{}<esc>i<cr><esc>Omethod<esc>kFm
    autocmd FileType go inoremap vok //TEST<cr>v, ok := m[""]<cr>fmt.Println(v)<cr>fmt.Println(ok)<cr><cr>if v, ok := m[""]; ok{}<esc>i<cr>fmt.Println("value:", v)<esc>5k0f"a
    autocmd FileType go inoremap <M-r> for i, v := range * {}<esc>i<cr>fmt.Println(i, v)<cr><esc>2k0f*cw
    autocmd FileType go inoremap <M-R> for v := range * {}<esc>i<cr>fmt.Println(v)<cr><esc>2k0f*cw
    autocmd FileType go inoremap  :v v, ok := <-c<esc>ofmt.Println(v,ok)
    autocmd FileType go inoremap :mar b, err := json.Marshal()<cr>if err != nil{}<esc>i<cr><esc>Ofmt.Println("error:", err)<esc>jofmt.Println(string(b))<esc>o//os.STdout.Write(b)<esc>5k0f(a
    autocmd FileType go inoremap :umar err := json.Unmarshal()<cr>if err != nil{}<esc>i<cr><esc>Ofmt.Println("error:", err)<esc>jofmt.Println(var)<esc>o//os.STdout.Write(var)<esc>5k0f(a
    autocmd FileType go inoremap  func (b By--) Len() int {return len(b)}<cr>func (b By--) Swap (i, j int) {b[i], b[j]=b[j], b[i]}<cr>func (b By--) Less (i, j int) bool {return b[i].-- < b[j].--}<cr><cr>sort.Sort(By--(var))
    autocmd FileType go inoremap e<Right> if err != nil{}<esc>i<cr><esc>Ofmt.Println(err)<esc>
    "autocmd FileType go inoremap e<Right> if err != nil{ fmt.Println(err) }
    autocmd FileType go inoremap e<down> if err != nil{ log.Fatal(err) }
    autocmd FileType go inoremap :wait var wg sync.WaitGroup<cr>wg.Add()<cr>wg.Done()<cr>wg.Wait()
    autocmd FileType go inoremap :mut var mu sync.Mutex<cr>mu.Lock()<cr>mu.Unlock()
    autocmd FileType go inoremap <M-R> return
    autocmd FileType go inoremap <Right> string
    autocmd FileType go inoremap <M-CR> return
    autocmd FileType go inoremap <M-Right> func(){<cr>}<esc>k0fca 
    autocmd FileType go inoremap <Left> int
    autocmd FileType go inoremap <Up> []byte()<esc>i
    autocmd FileType go inoremap <M-F20> []int{}<esc>i
    autocmd FileType go inoremap <Down> type
    autocmd FileType go inoremap <C-Down> func 
    autocmd FileType go inoremap <M-Left> map[key](value)<esc>Fk
    autocmd FileType go inoremap :wg var wg sync.WaitGroup
    autocmd FileType go inoremap :mu var mu sync.Mutex
    autocmd FileType go inoremap <M-Up> c := make (chan )<esc>F a
    autocmd FileType go inoremap  func() {<cr>}()<esc>O
    autocmd FileType go inoremap  (t *testing.T) {<cr>}esc>O
    autocmd FileType go inoremap  (b *testing.B) {<cr>}<esc>Ofor i:=0; i<b.N; i++
    autocmd FileType go inoremap <F5> chan 
    autocmd FileType go inoremap <F6> ctx := context.Background()
    autocmd FileType go nnoremap <C-S-F7> :GeDoc 
    autocmd FileType go nnoremap <F12> :GoInfo<cr>
    autocmd FileType go nnoremap <F19> :GoPlay<cr>
    autocmd FileType go nnoremap <F16> :GoAlternate<cr>
    autocmd FileType go nnoremap <M-f> daf
    autocmd FileType go nnoremap <M-F> dif
    autocmd FileType go nnoremap <F18> :go tool! cover -html=c.out
    autocmd FileType go inoremap <S-F7> <esc> :GoFillStruct<cr>
    autocmd FileType go nnoremap <F7> res, err := http.Get()<cr>if err != nil{<cr>}<esc>Olog.Fatal(err)
  augroup end

  "augroup rust
  "autocmd!
  "  autocmd FileType rust inoremap m<Right> fn main(){}<esc>i<cr><esc>O
  "  autocmd FileType rust inoremap fout println!();<space><esc>T(i
  "  autocmd FileType rust inoremap <Right> String
  "  autocmd FileType rust inoremap <M-Right> fn (){<cr>}<esc>k0fca 
  "  autocmd FileType rust inoremap <M-Right> fn (){<cr>}<esc>k0fca 
  "  autocmd FileType rust inoremap rq use reqwest;
  "  autocmd FileType rust inoremap sd use serde::derive;
  "  "autocmd FileType rust inoremap tk use tokio;
  "  "autocmd FileType rust inoremap !tk #[tokio::main]<esc>oasync fn main() Box<dyn std::error::Error>>{}<esc>i<cr><esc>OOk()<esc>i()<esc>O<cr><esc>O
  "  autocmd FileType rust inoremap ek use error_chain::error_chain; 
  "  autocmd FileType rust inoremap !ek error_chain! {}<esc>F{a<cr><esc>Oforeign_links {}<esc>F{a<cr><esc>OIo(std::io::Error);<cr>HttpRequest(reqwest::Error);<esc>V><esc>
  "  autocmd FileType rust nnoremap <leader><F3> :RustFmt<cr>
  "augroup end

  augroup toml
  autocmd!
  autocmd FileType toml inoremap rq reqwest = { version = "0.11.14", features = ["json"] }<esc>Oserde = { version = "1", features = ["derive"] }<esc>Otokio = { version = "1", features = ["full"] }<esc>Oserde_json = "1"<esc>:w<cr>
  autocmd FileType toml inoremap sd serde = { version = "1", features = ["derive"] }
  autocmd FileType toml inoremap tk tokio = { version = "1", features = ["full"] }
  augroup end


  augroup terraform
    autocmd!
    autocmd FileType tf inoremap v<Right> variable ""{}<esc>F"ci"
    autocmd FileType tf inoremap m<Right> variable ""{}<esc>i<cr>type = map() <cr><esc>Odefault = {}<esc>i<cr>mykey = <cr><esc>4kf"ci"
    autocmd FileType tf inoremap l<Right> variable ""{}<esc>i<cr>type = list<cr><esc>Odefault = []<esc>2kF"ci"
    autocmd FileType tf inoremap t<Right> type = ""<esc>ci"
    autocmd FileType tf inoremap <Right> string
    autocmd FileType tf inoremap <Left> int
  augroup end

" augroup AutoSaveFolds
"   autocmd!
"   autocmd BufWinLeave * mkview
"   autocmd BufWinEnter * silent loadview
" augroup END

]])

-- Autoformat
-- augroup _lsp
--   autocmd!
--   autocmd BufWritePre * lua vim.lsp.buf.formatting()
-- augroup end
