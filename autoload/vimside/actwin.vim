" ============================================================================
" actwin.vim
"
" File:          actwin.vim
" Summary:       action window
" Author:        Richard Emberson <richard.n.embersonATgmailDOTcom>
" Last Modified: 2013
"
" ============================================================================
" Intro: {{{1
" ============================================================================

" let s:LOG = function("vimside#log#log")
" let s:ERROR = function("vimside#log#error")

function! s:LOG(msg)
  execute "redir >> ". "AW_LOG"
  silent echo "INFO: ". a:msg
  execute "redir END"
endfunction

"TODO
" remove entry, list of entries
" help: 
" active row/column highlight 
" range of lines
"
"http://vim.wikia.com/wiki/Deleting_a_buffer_without_closing_the_window
"
"http://stackoverflow.com/questions/2447109/showing-a-different-background-colour-in-vim-past-80-characters
"http://stackoverflow.com/questions/235439/vim-80-column-layout-concerns
"http://vim.wikia.com/wiki/Highlight_current_line
"
"sort entries
"various sort functions
"
"help: no display, one line, full help vim help
"
"range of source lines per target line
"sign a range of lines
"
"
"options
"row/column display

let s:is_colorline_enabled = 0
let s:is_colorcolumn_enabled = 0
let s:is_sign_enabled = 0
let s:is_cursorline = 0
let s:is_entry_highlight = 1

let s:split_mode_default = "new"
let s:split_size_default = "10"
let s:split_below_default = 1
let s:split_right_default = 0
let s:edit_mode_default = "enew"
let s:tab_mode_default = "tabnew"

let s:winname_default="ActWin"

" control whether or not buffer entry events trigger 
" save/restore option code execution
let s:buf_change = 1

" actwin {
"   is_global: 0,
"   source_buffer_nr: source_buffer_nr
"   source_buffer_name: source_buffer_name
"   buffer_nr
"   uid: unique id
"   tag: tag
"   first_buffer_line: first_buffer_line
"   current_line: current_line
"   linenos_to_entrynos: []
"   entrynos_to_linenos: []
"   entrynos_to_nos_of_lines: []
"   data {
"   }
" }
" data {
"   title: ""
"   winname: ""
"   buffer_nr: number
"   action: create/modify/append/replace default create
"   help: {
"     do_show: 0
"     is_open: 0
"     .....
"   }
"   window: {
"     split; {
"        mode: "new"
"        size: "10"
"        below: 1
"        right: 0
"     }
"     edit: {
"        mode: "enew"
"     }
"     tab: {
"        mode: "tabnew"
"     }
"   }
"   window: {
"     split_size: "10"
"     split_mode: "new"
"     split_below: 1
"     split_right: 0
"   }
"   keymappings: {
"     help: ""
"     select: []
"     select_mouse: []
"     enter_mouse: []
"     down: []
"     up: []
"     close: []
"   }
"   builtin_cmd: {
"   }
"   leader_cmd: {
"     up: cp
"     down: cn
"     close: ccl
"   }
"   sign: {
"     category: QuickFix
"     abbreviation: qf
"     kinds: {
"       kname: {text, textlh, linehl }
"       .....
"     }
"   }
"   actions: {
"     enter:
"     leave:
"     select:
"   }
"   entries: [ 
"     file:
"     line:
"     optional col: (default 0)
"     content: [lines] and/or line
"     id: unique identifying number 
"     kind: 'error'
"     optional actions: {
"       enter:
"       leave:
"       select:
"     } (default global actions)
"   ]
" }
"


" quickfix commands
"  :cc 
"  :cn 
"  :cp 
"  :cr 
"  :cl 
"    override
"      http://vim.wikia.com/wiki/Replace_a_builtin_command_using_cabbrev
"      cabbrev e <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'E' : 'e')<CR>
"    leader
" open quickfix commands
"    existing
"      <Leader>ve
"
"

" functions that can be bound to keys (key mappings)
" keymappings
let s:know_km_fns = {
      \ "help": [ "OnHelp", "Display help" ],
      \ "select": [ "OnSelect", "Select current line" ],
      \ "enter_mouse": [ "OnEnterMouse", "Use mouse to set current line" ],
      \ "down": [ "OnDown", "Move down to next line" ],
      \ "up": [ "OnUp", "Move up to next line" ],
      \ "left": [ "OnLeft", "Move left one postion" ],
      \ "right": [ "OnRight", "Move right one postion" ],
      \ "close": [ "OnClose", "Close window"]
      \ }


" globals = {
"   type1: actwin1
"   type2: actwin2
"   .....
" }
let s:globals = {}

" locals = {
"   src_buffer_nos1: {
"      tag1: actwin1
"      tag2: actwin2
"      tag3: actwin3
"      ....
"   }
"   src_buffer_nos2: {
"      ....
"   }
"   ....
" }
"
" source_buffer_nr -> tags 
"    tags 1-1 target_buffer_nr
"
let s:locals = {}

" TODO maps from unique id -> actwin
let s:uid_to_actwin = {}

" maps actwin buffer number to actwin
let s:actwin_buffer_nr_to_actwin = {}


let s:next_uid = 0
function! s:NextUID()
  let l:uid = s:next_uid
  let s:next_uid += 1
  return l:uid
endfunction

function! s:Initialize(actwin)
call s:LOG("Initialize TOP")

  call s:MakeKeyMappings(a:actwin)
  call s:MakeAutoCmds(a:actwin)
  call s:MakeUserCommands(a:actwin)
  call s:MakeOverrideCommands(a:actwin)

  " TODO is this needed ... only when using the same window
  " how about using enter/leave buffer autocmd maps instead
  let b:insertmode = &insertmode
  let b:showcmd = &showcmd
  let b:cpo = &cpo
  let b:report = &report
  let b:list = &list
  set noinsertmode
  set noshowcmd
  set cpo&vim
  let &report = 10000
  set nolist

  set bufhidden=hide

  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  if s:is_cursorline
    setlocal cursorline
  endif
  setlocal nospell
  setlocal nobuflisted
call s:LOG("Initialize BOTTOM")
endfunction

function! s:MakeKeyMappings(actwin)

  for [l:key, l:value] in items(a:actwin.data.keymappings)
    if has_key(s:know_km_fns, l:key)
      let [l:fn, l:txt] = s:know_km_fns[l:key]
      if type(l:value) == type("")
        execute 'nnoremap <script> <silent> <buffer> '. l:value .' :call <SID>'. l:fn .'()<CR>'
      elseif type(l:value) == type([])
        for l:v in l:value
          execute 'nnoremap <script> <silent> <buffer> '. l:v .' :call <SID>'. l:fn .'()<CR>'
        endfor
      endif
    endif

    unlet l:value
  endfor



if 0 " KM
  " These are created as "buffer" maps so they disappear
  " when the buffer is deleted.
  nnoremap <script> <silent> <buffer> <F1> :call <SID>OnHelp()<CR>
"  nnoremap <script> <silent> <buffer> <TAB> :call <SID>ForwardAtion()<CR>
"  nnoremap <script> <silent> <buffer> <C-n> :call <SID>ForwardAtion()<CR>
"  nnoremap <script> <silent> <buffer> <S-TAB> :call <SID>BackwardAtion()<CR>
"  nnoremap <script> <silent> <buffer> <C-p> :call <SID>BackwardAtion()<CR>

  nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <SID>OnSelect()<CR>
  nnoremap <script> <silent> <buffer> <CR> :call <SID>OnSelect()<CR>

  " nnoremap <script> <buffer> <LeftMouse> <LeftMouse> :echo v:mouse_lnum<CR>
  nnoremap <script> <silent> <buffer> <LeftMouse> <LeftMouse> :call <SID>OnEnterMouse()<CR>
  nnoremap <script> <silent> <buffer> <Down> :call <SID>OnDown()<CR>
  nnoremap <script> <silent> <buffer> j :call <SID>OnDown()<CR>
  nnoremap <script> <silent> <buffer> <Up> :call <SID>OnUp()<CR>
  nnoremap <script> <silent> <buffer> k :call <SID>OnUp()<CR>

  nnoremap <script> <silent> <buffer> q :call vimside#actwin#Close()<CR>
  nnoremap <script> <silent> <buffer> :q :call vimside#actwin#Close()<CR>
endif " KM
endfunction

function! s:MakeAutoCmds(actwin)
  augroup ACT_WIN_AUTOCMD
    autocmd!
    autocmd BufEnter <buffer> call s:BufEnter()
    autocmd BufLeave <buffer> call s:BufLeave()
  augroup END
endfunction

function! s:CloseAutoCmds(actwin)
  augroup ACT_WIN_AUTOCMD
    autocmd!
  augroup END
endfunction

function! s:MakeUserCommands(actwin)
  if has_key(a:actwin.data, 'leader_cmd')
    let l:leader_cmd = a:actwin.data.leader_cmd
    let l:buffer_nr =  a:actwin.buffer_nr

    if has_key(l:leader_cmd,'up')
      execute ":nnoremap <silent> <Leader>". l:leader_cmd.up ." :call g:UserUp(". l:buffer_nr .")<CR>"
    endif

    if has_key(l:leader_cmd,'down')
      execute ":nnoremap <silent> <Leader>". l:leader_cmd.down ." :call g:UserDown(". l:buffer_nr .")<CR>"
    endif

    if has_key(l:leader_cmd,'close')
      execute ":nnoremap <silent> <Leader>". l:leader_cmd.close ." :call g:UserClose(". l:buffer_nr .")<CR>"
    endif
  endif
endfunction

function! s:ClearUserCommands(actwin)
  if has_key(a:actwin.data, 'leader_cmd')
    let l:leader_cmd = a:actwin.data.leader_cmd

    if has_key(l:leader_cmd,'up')
      execute "nunmap <silent> <Leader>". l:leader_cmd.up
    endif

    if has_key(l:leader_cmd,'down')
      execute "nunmap <silent> <Leader>". l:leader_cmd.down
    endif

    if has_key(l:leader_cmd,'close')
      execute "nunmap <silent> <Leader>". l:leader_cmd.close
    endif
  endif
endfunction

function! s:MakeOverrideCommands(actwin)
  " :cabbrev e <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'E' : 'e')<CR>
  if has_key(a:actwin.data, 'builtin_cmd')
    let l:builtin_cmd = a:actwin.data.builtin_cmd
    let l:buffer_nr =  a:actwin.buffer_nr

    if has_key(l:builtin_cmd,'cp')
      execute "cabbrev cp <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'call g:UserUp(". l:buffer_nr .")' : 'cp')<CR>"
    endif

    if has_key(l:builtin_cmd,'cn')
      execute "cabbrev cn <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'call g:UserDown(". l:buffer_nr .")' : 'cn')<CR>"
    endif

    if has_key(l:builtin_cmd,'ccl')
      execute "cabbrev ccl <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'call g:UserClose(". l:buffer_nr .")' : 'ccl')<CR>"
    endif

  endif
endfunction

function! s:ClearOverrideCommands(actwin)
  " :cabbrev e <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'E' : 'e')<CR>
  " cunabbrev e
  if has_key(a:actwin.data, 'builtin_cmd')
    let l:builtin_cmd = a:actwin.data.builtin_cmd

    if has_key(l:builtin_cmd,'cp')
      execute "cunabbrev cp"
    endif

    if has_key(l:builtin_cmd,'cn')
      execute "cunabbrev cn"
    endif

    if has_key(l:builtin_cmd,'ccl')
      execute "cunabbrev ccl"
    endif
  endif
endfunction

" MUST be called from local buffer
" return [0, _] or [1, actwin]
function! s:GetBufferActWin()
  if exists("b:buffer_nr") && has_key(s:actwin_buffer_nr_to_actwin, b:buffer_nr)
    return [1, s:actwin_buffer_nr_to_actwin[b:buffer_nr]]
  else
    return [0, ""]
  endif
endfunction

function! s:GetActWin(buffer_nr)
  if has_key(s:actwin_buffer_nr_to_actwin, a:buffer_nr)
    return [1, s:actwin_buffer_nr_to_actwin[a:buffer_nr]]
  else
    return [0, ""]
  endif
endfunction


function! vimside#actwin#DisplayLocal(tag, data)
call s:LOG("DisplayLocal TOP")
  let l:data = deepcopy(a:data)
  let l:source_buffer_name = bufname("%")
  let l:source_buffer_nr = bufnr("%")

  if has_key(s:locals, l:source_buffer_nr)
    let l:bnr_dic = s:locals[l:source_buffer_nr]
    if has_key(l:bnr_dic, a:tag)
      let l:action = s:GetAction(l:data)
      if l:action == 'm'
        " modify
        let l:actwin = l:bnr_dic[a:tag]
      elseif l:action == 'a'
        " append
        let l:actwin = l:bnr_dic[a:tag]
      elseif l:action == 'r'
        " replace
        let l:actwin = l:bnr_dic[a:tag]
      else
        " create
        let l:uid = s:NextUID()
        let l:actwin = {
            \ "is_global": 0,
            \ "source_buffer_nr": l:source_buffer_nr,
            \ "source_buffer_name": l:source_buffer_name,
            \ "tag": a:tag,
            \ "uid": l:uid,
            \ "data": l:data
          \ }
        let l:bnr_dic[a:tag] = l:actwin

        let l:action = 'c'
      endif

    else
      let l:uid = s:NextUID()
      let l:actwin = {
          \ "is_global": 0,
          \ "source_buffer_nr": l:source_buffer_nr,
          \ "source_buffer_name": l:source_buffer_name,
          \ "tag": a:tag,
          \ "uid": l:uid,
          \ "data": l:data
        \ }
      let l:bnr_dic[a:tag] = l:actwin

      let l:action = 'c'
    endif

  else
    let l:uid = s:NextUID()
    let l:actwin = {
        \ "is_global": 0,
        \ "source_buffer_nr": l:source_buffer_nr,
        \ "source_buffer_name": l:source_buffer_name,
        \ "tag": a:tag,
        \ "uid": l:uid,
        \ "data": l:data
      \ }
    let l:bnr_dic = {}
    let l:bnr_dic[a:tag] = l:actwin
    let s:locals[l:source_buffer_nr] = l:bnr_dic

    let l:action = 'c'
  endif
call s:LOG("DisplayLocal action=". l:action)

  " make adjustments, modification and replacements
  if l:action == 'c'
    " save actwin by its uid
    let s:uid_to_actwin[l:actwin.uid] = l:actwin
    " create = new display
    call s:Adjust(l:actwin.data)
  elseif l:action == 'm'
    " modify = change non-entries
    call s:Modify(l:actwin.data, l:data)
  elseif l:action == 'r'
    " replace entries
    call s:ReplaceEntries(l:actwin.data, l:data)
  else
    " append entries
    call s:AppendEntries(l:actwin.data, l:data)
  endif

  if l:action == 'c'
    let l:window =  l:data.window
    let l:winname =  l:data.winname

    let l:window = l:actwin.data.window
    if has_key(l:window, 'split')
call s:LOG("DisplayLocal split")
      let l:split = l:window.split

      " save current values
      let l:below = &splitbelow
      let &splitbelow = l:split.below

      let l:right = &splitright
      let &splitright = l:split.right

      let l:mode = l:split.mode
      let l:size = l:split.size

      execute l:size . l:mode .' '. l:winname

      " restore values
      let &splitbelow = l:below
      let &splitright = l:right

    elseif has_key(l:window, 'edit')
call s:LOG("DisplayLocal edit")
      let l:edit = l:window.edit
      let l:mode = l:edit.mode
      " execute l:mode .' '. l:winname
      execute l:mode 

    elseif has_key(l:window, 'tab')
call s:LOG("DisplayLocal tab")
      let l:tab = l:window.tab
      let l:mode = l:tab.mode
      execute l:mode .' '. l:winname

    endif

if 0 " WINDOW
    " save current values
    let l:split_below = &splitbelow
    let &splitbelow = l:window.split_below

    let l:split_right = &splitright
    let &splitright = l:window.split_right

    let l:split_mode = l:window.split_mode
    let l:split_size = l:window.split_size

    " do split mode
    if l:split_mode != ""
      " exe 'keepalt '. l:split_mode
call s:LOG("DisplayLocal split=" .l:split_size . l:split_mode .' '. l:winname)
      execute l:split_size . l:split_mode .' '. l:winname
    endif

    " restore values
    let &splitbelow = l:split_below
    let &splitright = l:split_right
endif " WINDOW

    " save the buffer number
    let l:actwin.buffer_nr = bufnr(bufname("%"))
    let b:buffer_nr = l:actwin.buffer_nr
    let s:actwin_buffer_nr_to_actwin[l:actwin.buffer_nr] = l:actwin

let s:buf_change = 0
    call s:Initialize(l:actwin)
  endif

  call s:LoadDisplay(l:actwin)
if s:is_sign_enabled
  call s:DefineSigns(l:actwin)
  call s:WriteSigns(l:actwin)
endif

call s:LOG("Display actwin_buffer=". l:actwin.buffer_nr)

" TODO REMOVE
  " call s:SetAtEntry(1, l:actwin)
  call s:EnterEntry(0, l:actwin)

let s:buf_change = 1

call s:LOG("DisplayLocal BOTTOM")
endfunction

if 0 " GLOBAL
function! vimside#actwin#DisplayGlobal(type, data)
  let l:data = deepcopy(a:data)
  let l:source_buffer_name = bufname("%")
  let l:source_buffer_nr = bufnr("%")

  if has_key(s:globals, a:type)
    let l:action = s:GetAction(l:data)
    " not modify replace or append
    if l:action == 'm' || l:action == 'r' || l:action == 'a'
      let l:actwin = s:globals[a:type]
    else
      let l:uid = s:NextUID()
      let l:actwin = {
          \ "is_global": 1,
          \ "source_buffer_nr": l:source_buffer_nr,
          \ "source_buffer_name": l:source_buffer_name,
          \ "type": a:type,
          \ "uid": l:uid,
          \ "data": l:data
        \ }
      let s:globals[a:type] = l:actwin

      let l:action = 'c'
    endif
  else
    let l:uid = s:NextUID()
    let l:actwin = {
        \ "is_global": 1,
        \ "source_buffer_nr": l:source_buffer_nr,
        \ "source_buffer_name": l:source_buffer_name,
        \ "type": a:type,
        \ "uid": l:uid,
        \ "data": l:data
      \ }
    let s:globals[a:type] = l:actwin

    let l:action = 'c'
  endif
call s:LOG("DisplayGlobal action=". l:action)

  " make adjustments, modification and replacements
  if l:action == 'c'
    " save actwin by its uid
    let s:uid_to_actwin[l:actwin.uid] = l:actwin
    " create = new display
    call s:Adjust(l:actwin.data)
  elseif l:action == 'm'
    " modify = change non-entries
    call s:Modify(l:actwin.data, l:data)
  elseif l:action == 'r'
    " replace entries
    call s:ReplaceEntries(l:actwin.data, l:data)
  else
    " append entries
    call s:AppendEntries(l:actwin.data, l:data)
  endif








  call s:AdjustInput()

  if s:running == 0
    let s:original_buffer_name = bufname("%")
    let s:original_buffer_nr = bufnr("%")

    let s:_splitbelow = &splitbelow
    let &splitbelow = 1

    " do split mode
    if l:split_mode != ""
      " exe 'keepalt '. l:split_mode
      let l:winname = has_key(s:dic, 'winname') ? s:dic.winname : s:winname_default
      execute s:split_size . l:split_mode .' '. l:winname
    endif
  endif


  let s:actwin_buffer = bufnr(bufname("%"))

  " only does something it s:running == 0
  call s:Initialize()

  call s:LoadDisplay()
  call s:DefineSigns()
  call s:WriteSigns()

call s:LOG("Display s:actwin_buffer=". s:actwin_buffer)

" TODO REMOVE
  " call s:SetAtEntry(1, l:actwin)
  call s:EnterEntry(0, l:actwin)

call s:LOG("Display BOTTOM")
endfunction
endif " GLOBAL

"   action: create/modify/append create
function! s:GetAction(data)
  if has_key(a:data, 'action') 
    if a:data.action == 'c' 
      return 'c'
    elseif a:data.action == 'm' 
      return 'm'
    elseif a:data.action == 'a' 
      return 'a'
    elseif a:data.action == 'r' 
      return 'r'
    endif
  endif 

  return 'c'
endfunction


" create = new display
function! s:Adjust(data)
call s:LOG("Adjust  TOP")
  if ! has_key(a:data, 'winname')
    let a:data['winname'] = s:winname_default
  endif

  if ! has_key(a:data, 'keymappings')
    let a:data['keymappings'] = {}
  else
    for [l:key, l:value] in items(a:data.keymappings)
      if ! has_key(s:know_km_fns, l:key)
        call s:ERROR('Adjust keymappings - bad key "'. l:key .'"')
        continue
      endif
      if type(l:value) != type("") && type(l:value) != type([])
        call s:ERROR('Adjust keymappings - for key "'. l:key .'" bad value type: '. type(l:value))
      endif

      unlet l:value
    endfor
  endif
  if ! has_key(a:data, 'window')
    let a:data['window'] = {
      \ "split": {
        \ "mode": s:split_mode_default,
        \ "size": s:split_size_default,
        \ "below": s:split_below_default,
        \ "right": s:split_right_default 
        \ }
      \ }
  else
    let l:window = a:data.window
    if has_key(l:window, 'split')
      let l:split = l:window.split
      if ! has_key(l:split, 'mode')
        let l:split['mode'] = s:split_mode_default
      endif
      if ! has_key(l:split, 'size')
        let l:split['size'] = s:split_size_default
      endif
      if ! has_key(l:split, 'below')
        let l:split['below'] = s:split_below_default
      endif
      if ! has_key(l:split, 'right')
        let l:split['right'] = s:split_right_default
      endif

    elseif has_key(l:window, 'edit')
      let l:edit = l:window.edit
      if ! has_key(l:edit, 'mode')
        let l:edit['mode'] = s:edit_mode_default
      endif

    elseif has_key(l:window, 'tab')
      let l:tab = l:window.tab
      if ! has_key(l:tab, 'mode')
        let l:tab['mode'] = s:tab_mode_default
      endif

    else
      let l:window['split'] = {
          \ "mode": s:split_mode_default,
          \ "size": s:split_size_default,
          \ "below": s:split_below_default,
          \ "right": s:split_right_default 
        \ }
    endif
  endif
if 0 " WINDOW
  if ! has_key(a:data, 'window')
    let a:data['window'] = {
      \ "split_size": s:split_size_default,
      \ "split_mode": s:split_mode_default,
      \ "split_below": s:split_below_default,
      \ "split_right": s:split_right_default 
      \ }
  else
    if ! has_key(a:data.window, 'split_size')
      let a:data.window['split_size'] = s:split_size_default
    endif
    if ! has_key(a:data.window, 'split_mode')
      let a:data.window['split_mode'] = s:split_mode_default
    endif
    if ! has_key(a:data.window, 'split_below')
      let a:data.window['split_below'] = s:split_below_default
    endif
    if ! has_key(a:data.window, 'split_right')
      let a:data.window['split_right'] = s:split_right_default
    endif
  endif
endif " WINDOW

  if ! has_key(a:data, 'help')
    let a:data['help'] = {
      \ "do_show": 0,
      \ "is_open": 0
      \ }
  else
    if ! has_key(a:data.help, 'do_show')
      let a:data.help['do_show'] = 0
    endif
    if ! has_key(a:data.help, 'is_open')
      let a:data.help['is_open'] = 0
    endif
  endif

  if ! has_key(a:data, 'actions')
    let a:data['actions'] = {
      \ "enter": function("s:EnterActionDoNothing"),
      \ "select": function("s:SelectActionDoNothing"),
      \ "leave": function("s:LeaveActionDoNothing")
      \ }
  else
    if ! has_key(a:data.actions, 'enter')
      let a:data.actions['enter'] = function("s:EnterActionDoNothing")
    endif
    if ! has_key(a:data.actions, 'select')
      let a:data.actions['select'] = function("s:SelectActionDoNothing")
    endif
    if ! has_key(a:data.actions, 'leave')
      let a:data.actions['leave'] = function("s:LeaveActionDoNothing")
    endif
  endif
  if ! has_key(a:data, 'formatter')
      let a:data['formatter'] = function("s:FormatterDefault")
  endif
call s:LOG("Adjust  BOTTOM")
endfunction

"   sign: {
"     category: QuickFix
"     kinds: {
"       kname: {text, textlh, linehl }
"     }
"   }
function! s:Modify(org_data, new_data)
  " Change sign
  "   category 
  "   abbreviation
  "   kinds
  if has_key(a:org_data, 'sign') && has_key(a:new_data, 'sign')
    " TODO
  elseif has_key(a:org_data, 'sign') 
    " TODO
  elseif has_key(a:new_data, 'sign') 
    " register sign
    let l:sign = a:new_data.sign
    if ! vimside#sign#HasCategory(l:sign.category)
      vimside#sign#AddCategory(l:sign.category, l:sign)
    endif
  endif

  " Change action
  "   enter
  "   leave
  "   select
  "   If the new data has actions, then copy those key/values that it
  "   does not have from the original data; otherwise, copy the
  "   complete actions from original to new.
  if has_key(a:new_data, 'actions')
    let l:new_actions = a:new_data.actions
    if ! has_key(l:new_actions, 'enter')
      let l:new_actions['enter'] = a:org_data.actions.enter
    endif
    if ! has_key(l:new_actions, 'select')
      let l:new_actions['select'] = a:org_data.actions.select
    endif
    if ! has_key(l:new_actions, 'leave')
      let l:new_actions['leave'] = a:org_data.actions.leave
    endif
  else
    let a:new_data['actions'] = a:original.actions
  endif

endfunction

" remove org entries and copy new entries
function! s:ReplaceEntries(org_data, new_data)
  if has_key(a:new_data, 'entries')
    let a:org_data['entries'] = a:new_data.entries
  else
    let a:org_data['entries'] = []
  endif
endfunction

" copy entries from new_data.entries to org_data.entries
function! s:AppendEntries(org_data, new_data)
  if ! has_key(a:new_data, 'entries')
    " nothing to add
    return
  endif
  let l:new_entries = a:new_data.entries

  if ! has_key(a:org_data, 'entries')
    let a:org_data['entries'] = []
  endif

  let l:org_entries = a:org_data.entries

  for l:entry in l:new_entries
    call add(l:org_entries, l:entry)
  endfor
endfunction





function! s:AdjustInput()
  if ! has_key(s:dic, 'actions')
    let s:dic['actions'] = {
      \ "enter": function("s:EnterActionDoNothing"),
      \ "select": function("s:SelectActionDoNothing"),
      \ "leave": function("s:LeaveActionDoNothing")
      \ }
  else
    if ! has_key(s:dic.actions, 'enter')
      let s:dic.actions['enter'] = function("s:EnterActionDoNothing")
    endif
    if ! has_key(s:dic.actions, 'select')
      let s:dic.actions['select'] = function("s:SelectActionDoNothing")
    endif
    if ! has_key(s:dic.actions, 'leave')
      let s:dic.actions['leave'] = function("s:LeaveActionDoNothing")
    endif
  endif
endfunction

function! s:LoadDisplay(actwin)
  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap

  execute "1,$d"

  " call s:SetupSyntax()
  call s:BuildDisplay(a:actwin)
  call cursor(a:actwin.first_buffer_line, 1)
  let a:actwin.current_line = a:actwin.first_buffer_line

 setlocal nomodifiable
endfunction

" return [lines...]
function! s:CreateHelp(actwin)
if 0 " HELP
  let l:help = a:actwin.data.help

  if l:help.do_show
    let help_lines = []
    if l:help.is_open
      call add(help_lines, s:dic.title )
      call add(help_lines, "-------------------")
      call add(help_lines, "<F1>    : toggle help")
      call add(help_lines, "<CR>    : inspect type")
      call add(help_lines, "<TAB>   : next type")
      call add(help_lines, "<C-n>   : next type")
      call add(help_lines, "<S-TAB> : previous type (may not work)")
      call add(help_lines, "<C-p>   : previous type")
      call add(help_lines, "q       : quit")
    else
      call add(help_lines, "Press <F1> for Help")
    endif
    
    let a:actwin.first_buffer_line = len(help_lines) + 1
    return help_lines
  else
    let a:actwin.first_buffer_line = 1
    return []
  endif
endif " HELP

  let a:actwin.first_buffer_line = 1
  return []
endfunction

function! s:BuildDisplay(actwin)
  let l:Formatter = a:actwin.data.formatter

  let a:actwin.first_buffer_line = 1
  " call setline(1, s:CreateHelp(a:actwin))

  let l:linenos_to_entrynos = []
  let l:entrynos_to_linenos = []
  let l:entrynos_to_nos_of_lines = []

  let l:linenos = 0
  let l:entrynos = 0
  let l:lines = []
  let l:lineslen = 0
  for entry in a:actwin.data.entries
    let l:current_lineslen = l:lineslen

    call l:Formatter(lines, entry)

    let l:lineslen = len(l:lines)
    let l:delta = l:lineslen - l:current_lineslen
    if l:delta == 1
      call add(l:linenos_to_entrynos, l:entrynos)
    else
      call extend(l:linenos_to_entrynos, repeat([l:entrynos], l:delta))
    endif

    call add(l:entrynos_to_linenos, l:lineslen)
    call add(l:entrynos_to_nos_of_lines, l:delta)

    let l:entrynos += 1

  endfor

  call setline(a:actwin.first_buffer_line, lines)
  let a:actwin.linenos_to_entrynos = l:linenos_to_entrynos
  let a:actwin.entrynos_to_linenos = l:entrynos_to_linenos
  let a:actwin.entrynos_to_nos_of_lines = l:entrynos_to_nos_of_lines

  " TODO REMOVE
  " let lines = s:GetLines(a:actwin)
  " call setline(a:actwin.first_buffer_line, lines)
endfunction

" ============================================================================
" Sign {{{1
" ============================================================================

function! s:DefineSigns(actwin)
  let l:data = a:actwin.data
  if has_key(l:data, 'sign')
    let l:sign = l:data.sign
    let l:category = l:sign.category
    if has_key(l:sign, 'kinds') && ! vimside#sign#HasCategory(l:category)
      call vimside#sign#AddCategory(l:category, l:sign)
    endif
  endif
endfunction

function! s:WriteSigns(actwin)
"     file:
"     line:
"     sign: kind
  let l:data = a:actwin.data
  if has_key(l:data, 'sign')
    let l:sign = l:data.sign
    let l:category = l:sign.category
    for entry in l:data.entries
      let l:file = entry.file
      let l:line = entry.line
      let l:kind = entry.kind
      call vimside#sign#PlaceFile(l:line, l:file, l:category, l:kind)
    endfor
  endif
endfunction

function! s:ClearSigns(actwin)
  let l:data = a:actwin.data
  if has_key(l:data, 'sign')
    let l:sign = l:data.sign
    let l:category = l:sign.category
    call vimside#sign#ClearCategory(l:category)
  endif
endfunction

" ============================================================================
" Util {{{1
" ============================================================================

if 0 " NOT USED
" return [line, ...]
function! s:GetLines(actwin)
  let l:lines = []
  for entry in a:actwin.data.entries
    let l:content = entry.content
    call add(l:lines, l:content)
  endfor

  return l:lines
endfunction
endif " NOT USED

" return [found, line]
function! s:GetEntry(entrynos, actwin)
  if a:entrynos < 0
    return [0, {}]
  else
    let l:entries = a:actwin.data.entries
    if a:entrynos < len(l:entries)
      return [1, l:entries[a:entrynos]]
    else
      return [0, {}]
    endif
endfunction

" ============================================================================
" Close {{{1
" ============================================================================

" TODO how to close from a different buffer???
" MUST be called from local buffer
function! vimside#actwin#Close()
call s:LOG("vimside#actwin#Close TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("vimside#actwin#Close NOT FOUND BOTTOM")
    return
  endif
  call s:Close(l:actwin)
endfunction

function! s:OnClose()
call s:LOG("s:OnClose TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("s:OnClose NOT FOUND BOTTOM")
    return
  endif
  call s:Close(l:actwin)
endfunction

function! s:Close(actwin)
  let l:actwin = a:actwin
  call s:CloseAutoCmds(l:actwin)
  call s:BufLeave()
call s:LOG("s:Close l:actwin.buffer_nr=". l:actwin.buffer_nr)

  if s:is_entry_highlight && exists("b:actwin_sids")
    " execute 'silent '. l:actwin.buffer_nr.'wincmd w'
    call s:HighlightClear(b:actwin_sids)
    " wincmd p
  endif

  call s:ClearUserCommands(l:actwin)
  call s:ClearOverrideCommands(l:actwin)

  " If we needed to split the main window, close the split one.
  let l:window = l:actwin.data.window
  if has_key(l:window, 'split')
call s:LOG("s:Close split")
execute 'silent '. l:actwin.buffer_nr.'wincmd w'
    exec "wincmd c"
wincmd p
  elseif has_key(l:window, 'edit')
call s:LOG("s:Close edit")
    let l:source_buffer_nr = l:actwin.source_buffer_nr
call s:LOG("s:Close source_buffer_nr=". l:source_buffer_nr)
    " exec "wincmd c"
    execute "buffer ". l:source_buffer_nr
    execute "bwipeout ". l:actwin.buffer_nr
    " exec "e!#"
  elseif has_key(l:window, 'tab')
call s:LOG("s:Close tab")
execute 'silent '. l:actwin.buffer_nr.'wincmd w'
    exec "e!#"
wincmd p
    " exec "wincmd c"
  endif


"  exec "keepjumps silent b ". l:actwin.source_buffer_name
"  execute 'silent set colorcolumn='

if s:is_sign_enabled
  call s:ClearSigns(l:actwin)
endif

  " Clear any messages.
  "  echo ""

  unlet s:actwin_buffer_nr_to_actwin[l:actwin.buffer_nr]
call s:LOG("Close BOTTOM")
endfunction

" ============================================================================
" KeyMappings: {{{1
" ============================================================================

" MUST be called from local buffer
function! s:OnHelp()
call s:LOG("OnHelp TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("OnHelp NOT FOUND BOTTOM")
    return
  endif

  let l:help = l:actwin.data.help

  if l:help.do_show
      let l:help.is_open = !l:help.is_open
      call vimside#actwin#DisplayLocal('testhelp', l:help.data)
  endif

if 0 " HELP
    setlocal modifiable

    " Save position.
    normal! ma
    
    " Remove existing help
    if (l:actwin.first_buffer_line > 1)
      exec "keepjumps 1,".(l:actwin.first_buffer_line - 1) "d _"
    endif
    
    call append(0, s:CreateHelp(l:actwin))

    silent! normal! g`a
    delmarks a

    setlocal nomodifiable
endif " HELP

call s:LOG("OnHelp BOTTOM")
endfunction




" MUST be called from local buffer
" cursor entering given entrynos
function! s:EnterEntry(entrynos, actwin)
call s:LOG("s:EnterEntry entrynos=". a:entrynos)
  call a:actwin.data.actions.enter(a:entrynos, a:actwin)

  if s:is_entry_highlight
    let l:entry = a:actwin.data.entries[a:entrynos]
    let l:content = l:entry.content
    let l:nos_lines = (type(l:content) == type("")) ? 0 : (len(l:content)-1)
    let l:line_start = a:actwin.entrynos_to_linenos[a:entrynos]  - l:nos_lines
call s:LOG("s:EnterEntry line_start=". l:line_start)
call s:LOG("s:EnterEntry nos_lines=". l:nos_lines)
    let b:actwin_sids = s:HighlightDisplay(l:line_start, l:line_start + l:nos_lines)
  endif
endfunction

" MUST be called from local buffer
function! s:SelectEntry(entrynos, actwin)
  call a:actwin.data.actions.select(a:entrynos, a:actwin)
endfunction

" MUST be called from local buffer
" cursor leaving given entrynos
function! s:LeaveEntry(entrynos, actwin)
  if s:is_entry_highlight
    call s:HighlightClear(b:actwin_sids)
  endif

  call a:actwin.data.actions.leave(a:entrynos, a:actwin)
endfunction





" MUST be called from local buffer
function! s:OnEnterMouse()
call s:LOG("s:OnEnterMouse: TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("s:OnEnterMouse NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos
  let l:entrynos_to_linenos = l:actwin.entrynos_to_linenos

  let l:current_line = l:actwin.current_line
  let l:linenos = line(".")
  let l:current_entrynos = l:linenos_to_entrynos[l:current_line-1]
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]

"call s:LOG("s:OnEnterMouse l:current_line=". l:current_line)
"call s:LOG("s:OnEnterMouse l:linenos=". l:linenos)
if 1
  if l:entrynos != l:current_entrynos
    call s:LeaveEntry(l:current_entrynos, l:actwin)
    call s:EnterEntry(l:entrynos, l:actwin)
    let l:actwin.current_line = l:linenos
  endif

else
  if l:linenos != l:current_line
    call s:LeaveEntry(l:current_line, l:actwin)
    call s:EnterEntry(l:linenos, l:actwin)
    let l:actwin.current_line = l:linenos
  endif
endif
call s:LOG("s:OnEnterMouse: BOTTOM")
endfunction

" MUST be called from local buffer
function! s:OnSelect()
call s:LOG("s:OnSelect: TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("s:OnSelect NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos

  let l:linenos = line(".")
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]

  call s:SelectEntry(l:entrynos, l:actwin)
  let l:actwin.current_line = l:linenos
call s:LOG("s:OnSelect: BOTTOM")
endfunction

" MUST be called from local buffer
function! s:OnUp()
call s:LOG("s:OnUp: TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("s:OnUp NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos
  let l:entrynos_to_linenos = l:actwin.entrynos_to_linenos

  let l:linenos = line(".")
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]
  let l:entrynos_to_nos_of_lines = l:actwin.entrynos_to_nos_of_lines

call s:LOG("s:OnUp l:entrynos=". l:entrynos)
  if l:entrynos > 0
    call s:LeaveEntry(l:entrynos, l:actwin)

    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos-1] 
    let l:new_linenos = l:entrynos_to_linenos[l:entrynos-1] 
    if l:nos_of_linenos == 1
      call feedkeys('k', 'n')
    else
      call feedkeys(repeat('k', l:nos_of_linenos), 'n')
    endif

if 0 " XXXX
    let l:delta = l:linenos - l:new_linenos
    if l:delta == 1
      call feedkeys('k', 'n')
    else
      call feedkeys(repeat('k', l:delta), 'n')
    endif
endif " XXXX

    call s:EnterEntry(l:entrynos-1, l:actwin)
    let l:actwin.current_line = l:new_linenos
  endif
call s:LOG("s:OnUp: BOTTOM")
endfunction

" MUST be called from local buffer
function! s:OnDown()
call s:LOG("s:OnDown: TOP")
  let [l:found, l:actwin] = s:GetBufferActWin()
  if ! l:found
call s:LOG("s:OnDown NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos
  let l:entrynos_to_linenos = l:actwin.entrynos_to_linenos
  let l:entrynos_to_nos_of_lines = l:actwin.entrynos_to_nos_of_lines

  let l:linenos = line(".")
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]
call s:LOG("s:OnDown l:entrynos=". l:entrynos)

  let l:len = len(l:entrynos_to_linenos)
call s:LOG("s:OnDown l:len=". l:len)

  if l:entrynos < l:len - 1
    call s:LeaveEntry(l:entrynos, l:actwin)

    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos] 
    let l:new_linenos = l:entrynos_to_linenos[l:entrynos+1] 
    if l:nos_of_linenos == 1
      call feedkeys('j', 'n')
    else
      call feedkeys(repeat('j', l:nos_of_linenos), 'n')
    endif

if 0 " XXXX
    let l:delta = l:new_linenos - l:linenos
    if l:delta == 0
      call feedkeys('j', 'n')
    else
      call feedkeys(repeat('j', l:delta-1), 'n')
    endif
endif " XXXX

    call s:EnterEntry(l:entrynos+1, l:actwin)
    let l:actwin.current_line = l:new_linenos
  endif
call s:LOG("s:OnDown: BOTTOM")
endfunction

function! s:OnLeft()
call s:LOG("s:OnLeft: TOP")
  call feedkeys('h', 'n')
call s:LOG("s:OnLeft: BOTTOM")
endfunction

function! s:OnRight()
call s:LOG("s:OnRight: TOP")
  call feedkeys('l', 'n')
call s:LOG("s:OnLeft: BOTTOM")
endfunction

" ============================================================================
" User commands: {{{1
" ============================================================================

" Called from external buffer
function! g:UserUp(buffer_nr)
call s:LOG("g:UserUp: TOP")
  let [l:found, l:actwin] = s:GetActWin(a:buffer_nr)
  if ! l:found
call s:LOG("g:UserUp NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos
  let l:entrynos_to_linenos = l:actwin.entrynos_to_linenos
  let l:entrynos_to_nos_of_lines = l:actwin.entrynos_to_nos_of_lines

  let l:linenos = l:actwin.current_line
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]

  " let l:len = len(l:actwin.data.entries)
  if l:entrynos > 0
let s:buf_change = 0
if 0 " MMMMM

execute 'silent '. a:buffer_nr.'wincmd w'
    call s:LeaveEntry(l:entrynos, l:actwin)
wincmd p

    let l:new_linenos = l:entrynos_to_linenos[l:entrynos-1] 
    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos-1] 

    call s:SelectEntry(l:entrynos-1, l:actwin)

    if l:nos_of_linenos == 1
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")-1),1) | redraw'
    else
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")-'. l:nos_of_linenos .'),1) | redraw'
    endif
    
    wincmd p
execute 'silent '. a:buffer_nr.'wincmd w'
    call s:EnterEntry(l:entrynos-1, l:actwin)
wincmd p
else

execute 'silent '. a:buffer_nr.'wincmd w'
    call s:LeaveEntry(l:entrynos, l:actwin)

    let l:new_linenos = l:entrynos_to_linenos[l:entrynos-1] 
    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos-1] 

    call s:SelectEntry(l:entrynos-1, l:actwin)

    if l:nos_of_linenos == 1
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")-1),1)'
      " call cursor((line(".")-1),1)
    else
      " call cursor((line(".")-l:nos_of_linenos),1)
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")-'. l:nos_of_linenos .'),1)'
    endif
    
    call s:EnterEntry(l:entrynos-1, l:actwin)
redraw
wincmd p

endif " MMMMM

let s:buf_change = 1

    let l:actwin.current_line = l:new_linenos
  endif
echo ""
call s:LOG("g:UserUp: BOTTOM")
endfunction

" Called from external buffer
function! g:UserDown(buffer_nr)
call s:LOG("g:UserDown: TOP")
  let [l:found, l:actwin] = s:GetActWin(a:buffer_nr)
  if ! l:found
call s:LOG("g:UserDown NOT FOUND BOTTOM")
    return
  endif

  let l:linenos_to_entrynos = l:actwin.linenos_to_entrynos
  let l:entrynos_to_linenos = l:actwin.entrynos_to_linenos
  let l:entrynos_to_nos_of_lines = l:actwin.entrynos_to_nos_of_lines

  let l:linenos = l:actwin.current_line
  let l:entrynos = l:linenos_to_entrynos[l:linenos-1]

  let l:len = len(l:actwin.data.entries)
  if l:entrynos < l:len - 1
let s:buf_change = 0
if 0 " MMMMM
execute 'silent '. a:buffer_nr.'wincmd w'
    call s:LeaveEntry(l:entrynos, l:actwin)
wincmd p

    let l:new_linenos = l:entrynos_to_linenos[l:entrynos+1] 
    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos] 

    call s:SelectEntry(l:entrynos+1, l:actwin)

    if l:nos_of_linenos == 1
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")+1),1) | redraw'
    else
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")+'. l:nos_of_linenos .'),1) | redraw'
    endif

    wincmd p

execute 'silent '. a:buffer_nr.'wincmd w'
    call s:EnterEntry(l:entrynos+1, l:actwin)
wincmd p
else

execute 'silent '. a:buffer_nr.'wincmd w'
    call s:LeaveEntry(l:entrynos, l:actwin)

    let l:new_linenos = l:entrynos_to_linenos[l:entrynos+1] 
    let l:nos_of_linenos = l:entrynos_to_nos_of_lines[l:entrynos] 

    call s:SelectEntry(l:entrynos+1, l:actwin)

    if l:nos_of_linenos == 1
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")+1),1)'
      "call cursor((line(".")+1),1)
    else
      execute 'silent '. a:buffer_nr.'wincmd w | :call cursor((line(".")+'. l:nos_of_linenos .'),1)'
      "call cursor((line(".")+ l:nos_of_linenos),1)
    endif


    call s:EnterEntry(l:entrynos+1, l:actwin)
redraw
wincmd p

endif " MMMMM

let s:buf_change = 1

    let l:actwin.current_line = l:new_linenos
  endif
echo ""
call s:LOG("g:UserDown: BOTTOM")
endfunction

" Called from external buffer
function! g:UserClose(buffer_nr)
call s:LOG("g:UserClose: TOP")
  let [l:found, l:actwin] = s:GetActWin(a:buffer_nr)
  if ! l:found
call s:LOG("g:UserClose NOT FOUND BOTTOM")
    return
  endif

  call s:Close(l:actwin)

echo ""
call s:LOG("g:UserClose: BOTTOM")
endfunction

" ============================================================================
" AutoCmd functions: {{{1
" ============================================================================

function! s:BufEnter()
  if s:buf_change
call s:LOG("s:BufEnter: TOP")
    let b:insertmode = &insertmode
    let b:showcmd = &showcmd
    let b:cpo = &cpo
    let b:report = &report
    let b:list = &list
call s:LOG("s:BufEnter: BOTTOM")
  endif
endfunction

function! s:BufLeave()
  if s:buf_change
call s:LOG("s:BufLeave: TOP")
    if exists("b:insertmode")
      let &insertmode = b:insertmode
      unlet b:insertmode
    endif
    if exists("b:showcmd")
      let &showcmd = b:showcmd
      unlet b:showcmd
    endif
    if exists("b:cpo")
      let &cpo = b:cpo
      unlet b:cpo
    endif
    if exists("b:report")
      let &report = b:report
      unlet b:report
    endif
    if exists("b:list")
      let &list = b:list
      unlet b:list
    endif
call s:LOG("s:BufLeave: BOTTOM")
  endif
endfunction

" ============================================================================
" Formatter Functions: {{{1
" ============================================================================

function! s:FormatterDefault(lines, entry)
" call s:LOG("s:FormatterDefault: TOP")
  let content = a:entry.content
  if type(content) == type([])
    call extend(a:lines, content)
  else
    call add(a:lines, string(content))
  endif
" call s:LOG("s:FormatterDefault: BOTTOM")
endfunction

" ============================================================================
" Default Action Functions: {{{1
" ============================================================================

" --------------------------------------------
" Behavior: Do Nothing, Text
" --------------------------------------------

" Set Non-ActWin cursor file and postion but stay in ActWin
function! s:EnterActionDoNothing(entrynos, actwin)
call s:LOG("s:EnterActionDoNothing: entrynos=". a:entrynos)
endfunction

" Goto Non-ActWin cursor file and postion
function! s:SelectActionDoNothing(entrynos, actwin)
call s:LOG("s:SelectActionDoNothing")
endfunction

" Do Nothing
function! s:LeaveActionDoNothing(entrynos, actwin)
call s:LOG("s:LeaveActionDoNothing: entrynos=". a:entrynos)
endfunction

" --------------------------------------------
" Behavior: QuickFix
" --------------------------------------------
" Set Non-ActWin cursor file and postion but stay in ActWin
function! s:EnterActionQuickFix(entrynos, actwin)
call s:LOG("s:EnterActionQuickFix: entrynos=". a:entrynos)
  call s:SetAtEntry(a:entrynos, a:actwin)
endfunction

" Goto Non-ActWin cursor file and postion
function! s:SelectActionQuickFix(entrynos, actwin)
call s:LOG("s:SelectActionQuickFix")
  call s:GoToEntry(a:entrynos, a:actwin)
endfunction

" Do Nothing
function! s:LeaveActionQuickFix(entrynos, actwin)
call s:LOG("s:LeaveActionQuickFix: entrynos=". a:entrynos)
  call s:RemoveAtEntry(a:entrynos, a:actwin)
endfunction

" --------------------------------------------
" Behavior: History/Search Command Window
" --------------------------------------------

" --------------------------------------------
" Behavior: Type Inspector, Multi-line Structured
" --------------------------------------------

" --------------------------------------------
" Behavior: Type Inspector
" --------------------------------------------


" ============================================================================
" Support Action Function: {{{1
" ============================================================================


" Set Non-ActWin cursor file and postion but stay in ActWin
function! s:SetAtEntry(entrynos, actwin)
let s:buf_change = 0
call s:LOG("s:SetAtEntry: entrynos=". a:entrynos)
  " let [l:found, l:entry] = s:GetLine(a:entrynos - 1, a:actwin)
  let [l:found, l:entry] = s:GetEntry(a:entrynos, a:actwin)
  if l:found && has_key(l:entry, 'file')
    let l:file = l:entry.file
    let l:winnr = bufwinnr(l:file)
call s:LOG("s:SetAtEntry: winnr=". l:winnr)
    if l:winnr > 0
      let l:linenos = has_key(l:entry, 'line') ? l:entry.line : 1
      let l:colnos = has_key(l:entry, 'col') ? l:entry.col : -1
call s:LOG("s:SetAtEntry: linenos=". l:linenos)
call s:LOG("s:SetAtEntry: colnos=". l:colnos)
      " execute 'keepjumps silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G' . l:colnos . " "
      if l:colnos > 1
        execute 'silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G' . l:colnos . "l"
      else
        execute 'silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G'
      endif
if s:is_colorline_enabled
  if has_key(a:actwin.data, 'sign')
    let l:category = a:actwin.data.sign.category
    let l:kind = l:entry.kind
    call  vimside#sign#ChangeKindFile(l:linenos, l:file, l:category, 'marker')
  endif
endif
if s:is_colorcolumn_enabled
  if l:colnos > 0
    execute 'silent '. l:winnr.'wincmd w | :set colorcolumn='. l:colnos
  else
    execute 'silent '. l:winnr.'wincmd w | :set colorcolumn='
  endif
endif

      " execute 'keepjumps silent '. actwin_buffer.'wincmd 2'
      wincmd p
    endif
  endif
call s:LOG("s:SetAtEntry: BOTTOM")
let s:buf_change = 1
endfunction

function! s:RemoveAtEntry(entrynos, actwin)
let s:buf_change = 0
call s:LOG("s:RemoveAtEntry: entrynos=". a:entrynos)
  " let [l:found, l:entry] = s:GetLine(a:entrynos - 1, a:actwin)
  let [l:found, l:entry] = s:GetEntry(a:entrynos, a:actwin)
  if l:found && has_key(l:entry, 'file')
    let l:file = l:entry.file
    let l:linenos = has_key(l:entry, 'line') ? l:entry.line : 1
if s:is_colorline_enabled
  if has_key(a:actwin.data, 'sign')
    let l:category = a:actwin.data.sign.category
    let l:kind = l:entry.kind
    call vimside#sign#ChangeKindFile(l:linenos, l:file, l:category, l:kind)
  endif
endif
  endif
call s:LOG("s:RemoveAtEntry: BOTTOM")
let s:buf_change = 1
endfunction

" Goto Non-ActWin cursor file and postion
function! s:GoToEntry(entrynos, actwin)
call s:LOG("s:GoToEntry: entrynos=". a:entrynos)
  " let [l:found, l:entry] = s:GetLine(a:entrynos - 1, a:actwin)
  let [l:found, l:entry] = s:GetEntry(a:entrynos, a:actwin)
  if l:found && has_key(l:entry, 'file')
    let l:file = l:entry.file
    let l:winnr = bufwinnr(l:file)
call s:LOG("s:GoToEntry: winnr=". l:winnr)
    if l:winnr > 0
      let l:linenos = has_key(l:entry, 'line') ? l:entry.line : 1
      let l:colnos = has_key(l:entry, 'col') ? l:entry.col : -1
call s:LOG("s:GoToEntry: linenos=". l:linenos)
call s:LOG("s:GoToEntry: colnos=". l:colnos)
      " execute 'keepjumps silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G' . l:colnos . " "
      if l:colnos > 1
        execute 'silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G' . l:colnos . "l"
      else
        execute 'silent '. l:winnr.'wincmd w | :normal '. l:linenos .'G'
      endif

if s:is_colorcolumn_enabled
  if l:colnos > 1
    execute 'silent '. l:winnr.'wincmd w | :set colorcolumn='. l:colnos
  else
    execute 'silent '. l:winnr.'wincmd w | :set colorcolumn='
  endif
endif
    endif
  endif
endfunction

" ============================================================================
" Highlight Patterns: {{{1
" ============================================================================

function! s:GetOption(name)
  let [found, value] = g:vimside.GetOption(a:name)
  if ! found
    throw "Option not found: '". a:name ."'
  endif
  return value
endfunction

function! s:Color_2_Number(color)
  " is it a name
  let rgbtxt = forms#color#util#ConvertName_2_RGB(a:color)
  if rgbtxt == ''
    let nos = forms#color#term#ConvertRGBTxt_2_Int(a:color)
  else
    let nos = forms#color#term#ConvertRGBTxt_2_Int(rgbtxt)
  endif
  return nos
endfunction

function! s:InitGui()
  if &background == 'light' 
    let selectedColor = s:GetOption('tailor-expand-selection-highlight-color-light')

  else " &background == 'dark'
    let selectedColor = s:GetOption('tailor-expand-selection-highlight-color-dark')
  endif
call s:LOG("s:InitGui: selectedColor=". selectedColor) 
  execute "hi VimsideActWin_HL gui=bold guibg=#" . selectedColor
endfunction

function! s:InitCTerm()
  if exists("g:vimside.plugins.forms") && g:vimside.plugins.forms
    if &background == 'light' 
      let selectedColor = s:GetOption('tailor-expand-selection-highlight-color-light')
    else " &background == 'dark'
      let selectedColor = s:GetOption('tailor-expand-selection-highlight-color-dark')
    endif
call s:LOG("s:InitCTerm: selectedColor=". selectedColor) 
    let selectedNumber = s:Color_2_Number(selectedColor)
  else
    if &background == 'light' 
      " TODO: hardcode for now
      let selectedNumber = '87'
    else " &background == 'dark'
      " TODO: hardcode for now
      let selectedNumber = '87'
    endif
  endif
call s:LOG("s:InitCTerm: selectedNumber=". selectedNumber) 
  execute "hi VimsideActWin_HL cterm=bold ctermbg=" . selectedNumber
endfunction

function! s:InitializeHighlight()
  if has("gui_running")
    call s:InitGui()
  else
    call s:InitCTerm()
  endif
endfunction

call s:InitializeHighlight()

function! s:GetLinesMatchPatterns(line_start, line_end)
  let lnum1 = a:line_start
  let lnum2 = a:line_end
  let endCol = 200

  if lnum1 == lnum2
    " one lines
    " let range = [ '\%'.lnum1.'l\%>'.(0).'v.*\%<'.(endCol+2).'v' ]
    let patterns = [ '\%'.lnum1.'l', '\%3c' ]
  elseif lnum1+1 == lnum2
    " two lines
    " let pat1 = '\%'.lnum1.'l\%>'.(col1+1).'v.*\%<'.(endCol).'v'
    " let pat1 = '\%'.lnum1.'l\%>'.(0).'v.*\%<'.(endCol).'v'
    " let pat2 = '\%'.lnum2.'l\%>'.(1).'v.*\%<'.(endCol).'v'
    let pat1 = '\%'.lnum1.'l'
    let pat2 = '\%'.lnum2.'l'
    let patterns = [ pat1, pat2 ]
  else
    " general case
    let patterns = [ ]
    let l:ln = lnum1
    while l:ln <= lnum2
      let pat = '\%'.l:ln.'l'
      call add(patterns, pat)
      let l:ln += 1
    endwhile
if 0 " XXX
    let range_start = '\%'.lnum1.'l\%>'.(0).'v.*\%<'.(endCol).'v'
    call add(range, range_start)

    let range_mid =
             \'\%>'.(0).'v'.
             \'\%<'.(endCol).'v'.
             \'\%>'.(lnum1).'l'.
             \'\%<'.(lnum2).'l'.
             \'.'
    call add(range, range_mid)

    let range_end = '\%'.lnum2.'l\%>'.(0).'v.*\%<'.(endCol).'v'
    call add(range, range_end)
endif " XXX

  endif
call s:LOG("s:GetLinesMatchPatterns: patterns=". string(patterns)) 
  return patterns
endfunction

function! s:HighlightClear(sids)
call s:LOG("s:HighlightClear: TOP") 
call s:LOG("s:HighlightClear: clearing sids") 
  for sid in a:sids
call s:LOG("s:HighlightClear: clear sid=". sid) 
    try
      if matchdelete(sid) == -1
call s:LOG("s:HighlightClear: failed to clear sid=". sid) 
      endif
    catch /.*/
call s:LOG("ERROR s:HighlightClear: sid=". sid) 
    endtry
  endfor
call s:LOG("s:HighlightClear: matches=". string(getmatches())) 
call s:LOG("s:HighlightClear: BOTTOM") 
endfunction

" returns list of sids
function! s:HighlightDisplay(line_start, line_end)
call s:LOG("s:HighlightDisplay: line_start=". a:line_start .", line_end=". a:line_end) 
  let patterns = s:GetLinesMatchPatterns(a:line_start, a:line_end)
  let l:sids = []
  for pattern in patterns
    let sid = matchadd("VimsideActWin_HL", pattern)
call s:LOG("s:HighlightDisplay: sid=". sid) 
    call add(l:sids, sid)
  endfor
  return l:sids
endfunction

" ============================================================================
" Test: {{{1
" ============================================================================

function! vimside#actwin#TestQuickFix()

"   help: {
"     do_show: 0
"     is_open: 0
"     .....
"   }
"   window: {
"     split_size: "10"
"     split_mode: "new"
"     split_below: 1
"     split_right: 0
"   }
"   builtin_cmd: {
"   }
"   leader_cmd: {
"   }
"   sign: {
"     category: QuickFix
"     kinds: {
"       kname: {text, textlh, linehl }
"     }
"   }
"     file:
"     line:
"     kind: 'error'
"
  let l:helpdata = {
        \ "title": "Help Window",
        \ "winname": "Help",
        \ "window": {
          \ "edit": {
          \ "mode": "enew"
          \ }
        \ },
        \ "keymappings": {
          \ "close": "q"
        \ },
        \ "actions": {
          \ "enter": function("s:EnterActionDoNothing"),
          \ "select": function("s:SelectActionDoNothing"),
          \ "leave": function("s:LeaveActionDoNothing")
        \ },
        \ "entries": [
        \  { 'content': [
            \  "This is some help text",
            \  "  Help text line 1",
            \  "  Help text line 2",
            \  "  Help text line 3",
            \  "  Help text line 4",
            \  "  Help text line 5",
            \  "  Help text line 6"
            \ ],
          \ "kind": "info"
          \ }
        \ ]
    \ }

  let l:data = {
        \ "title": "Test Window",
        \ "winname": "Test",
        \ "help": {
          \ "do_show": 1,
          \ "data": l:helpdata,
        \ },
        \ "keymappings": {
          \ "help": "<F1>",
          \ "select": [ "<CR>", "<2-LeftMouse>"],
          \ "enter_mouse": "<LeftMouse> <LeftMouse>",
          \ "down": [ "j", "<Down>"],
          \ "up": [ "k", "<Up>"],
          \ "close": "q"
        \ },
        \ "builtin_cmd": {
          \ "cp": "cp",
          \ "cn": "cn",
          \ "ccl": "ccl"
        \ },
        \ "leader_cmd": {
          \ "up": "cp",
          \ "down": "cn",
          \ "close": "ccl"
        \ },
        \ "sign": {
          \ "category": "TestWindow",
          \ "abbreviation": "tw",
          \ "toggle": "tw",
          \ "kinds": {
            \ "error": {
              \ "text": "EE",
              \ "texthl": "Todo",
              \ "linehl": "Error",
            \ },
            \ "warn": {
              \ "text": "WW",
              \ "texthl": "ToDo",
              \ "linehl": "StatusLine",
            \ },
            \ "info": {
              \ "text": "II",
              \ "texthl": "DiffAdd",
              \ "linehl": "Ignore",
            \ },
            \ "marker": {
              \ "text": "MM",
              \ "texthl": "Search",
              \ "linehl": "Ignore",
            \ }
          \ }
        \ },
        \ "actions": {
          \ "enter": function("s:EnterActionQuickFix"),
          \ "select": function("s:SelectActionQuickFix"),
          \ "leave": function("s:LeaveActionQuickFix")
        \ },
        \ "entries": [
        \  { 'content': "line one",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 1,
          \ "col": 1,
          \ "kind": "error"
          \ },
        \  { 'content': "line three",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 3,
          \ "col": 6,
          \ "kind": "warn"
          \ },
        \  { 'content': [
            \  "Entry 3 line 0",
            \  "   Entry 3 line 1",
            \  "   Entry 3 line 2"
            \ ],
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 5,
          \ "col": 7,
          \ "kind": "info"
          \ },
        \  { 'content': "line seven",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 7,
          \ "col": 2,
          \ "kind": "error"
          \ },
        \  { 'content': [
            \  "Entry 5 line 0",
            \  "   Entry 5 line 1",
            \  "   Entry 5 line 2"
            \ ],
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 9,
          \ "col": 4,
          \ "kind": "warn"
          \ },
        \  { 'content': [
            \  "Entry 6 line 0"
            \ ],
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 10,
          \ "col": 8,
          \ "kind": "info"
          \ },
        \  { 'content': [
            \  "Entry 7 line 0",
            \  "  Entry 7 line 1"
            \ ],
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 11,
          \ "col": 10,
          \ "kind": "error"
          \ },
        \  { 'content': "line thirteen",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 13,
          \ "kind": "warn"
          \ },
        \  { 'content': "line fourteen",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 14,
          \ "kind": "info"
          \ },
        \  { 'content': "line fifteen",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 15,
          \ "kind": "error"
          \ },
        \  { 'content': "line sixteen",
          \ "file": "src/main/scala/com/megaannum/Foo.scala",
          \ "line": 16,
          \ "kind": "warn"
          \ }
        \ ]
    \ }
  call vimside#actwin#DisplayLocal('testqf', l:data)

endfunction

function! vimside#actwin#TestHelp()
  let l:data = {
        \ "title": "Help Window",
        \ "winname": "Help",
        \ "keymappings": {
          \ "close": "q"
        \ },
        \ "actions": {
          \ "enter": function("s:EnterActionDoNothing"),
          \ "select": function("s:SelectActionDoNothing"),
          \ "leave": function("s:LeaveActionDoNothing")
        \ },
        \ "entries": [
        \  { 'content': [
            \  "This is some help text",
            \  "  Help text line 1",
            \  "  Help text line 2",
            \  "  Help text line 3",
            \  "  Help text line 4",
            \  "  Help text line 5",
            \  "  Help text line 6"
            \ ],
          \ "kind": "info"
          \ }
        \ ]
    \ }
  call vimside#actwin#DisplayLocal('testhelp', l:data)
endfunction