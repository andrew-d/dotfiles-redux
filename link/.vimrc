" Required first
set nocompatible                        " Disable compatibility with vi
filetype on                             " Filetype detection on
filetype plugin on                      " Enable loading plugin files
filetype indent on                      " Enable loading indent files
syntax on                               " Syntax highlighting on

" Load plugins
execute pathogen#infect()


" =============================================================================
" GENERAL SETTINGS
" -----------------------------------------------------------------------------
set shell=bash
set history=1000                        " Command history = lots
set undolevels=1000                     " Lots and lots of undo
set synmaxcol=2048                      " Don't syntax highlight super-long lines (for performance)

set nobk nowb noswf                     " Disable backup, swapfiles, etc. (we have git)

set enc=utf-8                           " Set the default encoding to UTF-8
set mouse=a                             " Enable mouse support.

" Set a long timeout for mappings, but a short timeout for keycodes (so 'Esc'
" is quickly detected, but you can take a while to type mappings).
set timeout timeoutlen=3000 ttimeoutlen=10

" Instantly leave insert mode when pressing <Esc>
augroup FastEscape
    autocmd!

    autocmd InsertEnter * set timeoutlen=0
    autocmd InsertLeave * set timeoutlen=3000
augroup END


" =============================================================================
" PRESENTATION AND DISPLAY
" -----------------------------------------------------------------------------
set t_Co=256                            " Tell Vim that we're on a 256-color terminal
set shortmess=atI                       " Disable the distracting intro screen, truncate file names at
                                        " the start, and use short messages everywhere.
set visualbell t_vb=""                  " No fancy visual bell
set noerrorbells                        " No error bells
set showmode                            " Display the current mode in the status bar
set lazyredraw                          " Don't redraw the screen during macros.
set ttyfast                             " Improve redrawing for 'newer' computers
set numberwidth=5                       " Linenumber width is 5
set scrolloff=8                         " When the page starts to scroll, keep the cursor 8 lines from top/bottom
set number                              " Show line numbers
set cursorline                          " Highlight the line with the cursor

"set list                                " Show tabs as ">"
set listchars=tab:>.

" Pressing F2 will toggle and show the paste value
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>                    " F2 should toggle in insert mode too


" =============================================================================
" DISPLAY AND COLOR SETTINGS
" -----------------------------------------------------------------------------
set showmatch                           " Show matching brackets
set matchpairs+=<:>                     " Also match <> pair (for HTML)

" The following bit sets up a highlight scheme and the associated mappings that
" highlight trailing whitespace. This must be done before the color scheme is specified.
highlight ExtraWhitespace ctermbg=red guibg=red
autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
autocmd BufEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhiteSpace /\s\+$/

" Display tabs at the beginning of lines in Python as bad.
autocmd BufRead,BufNewFile *.py match ExtraWhitespace /^\t\+/

let g:solarized_termcolors=256          " Fixes solarized colors.
set background=dark                     " Use a dark background
colorscheme wombat256mod                " Use the wombat256mod colorscheme

" Add json syntax highlighting
autocmd BufNewFile,BufRead *.json set filetype=javascript

" Enable all python syntax highlighting.
let python_highlight_all=1

" Enable XML syntax folding
let g:xml_syntax_folding=1
autocmd FileType xml setlocal foldmethod=syntax

" Enable omnicompletion for all filetypes that don't have an omnifunction.
if has("autocmd") && exists("+omnifunc")
    autocmd Filetype * if &omnifunc == "" | setlocal omnifunc=syntaxcomplete#Complete | endif
endif

" Fancy Unicode characters for long lines.
set listchars=precedes:◂,extends:▸

" Use a Unicode character for wrapped lines.
set showbreak=↪\ 

" -----------------------------------------------------------------------------
" Statusline / Tabline (subsection)
" -----------------------------------------------------------------------------
set title                               " Show file in titlebar
set ruler                               " Enable the ruler
set showcmd                             " Show incomplete command at bottom right.
set showmode                            " Always show the paste mode in the status line

" Set the ruler format.
set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%)

" Don't use the powerline symbols by default
let g:airline_powerline_fonts=0

" Airline configuration
let g:airline_theme = "badwolf"
let g:airline_left_sep = '▶'
let g:airline_right_sep = '◀'
let g:airline_symbols = get(g:, "airline_symbols", {})
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.whitespace = 'Ξ'


let g:airline_detect_modified = 0
function! ModifiedInit()
    " EIGHT POINTED PINWHEEL STAR
    call airline#parts#define_raw('modified', '%{&modified ? " ✵" : ""}')
    call airline#parts#define_accent('modified', 'red')
    let g:airline_section_c = airline#section#create(['%f', 'modified'])
endfunction
autocmd VimEnter * call ModifiedInit()

" Set up our status line.
if has('statusline')
    set laststatus=2

    " Broken down into easily includeable segments
    set statusline=                             " Clear the statusline when we reload
    set statusline+=[%n]\                       " Buffer number
    set statusline+=%<%.99f\                    " Filename, truncated to 99 chars + 1 space
    set statusline+=%h%w%m%r                    " Help/preview/modified/readonly flags
    set statusline+=%{fugitive#statusline()}    " Git information
    set statusline+=\ [%{&ff}/%Y]               " Filetype information
    set statusline+=\ [%{getcwd()}]             " Current directory
    "set statusline+=\ [A=\%03.3b/H=\%02.2B]     " ASCII / Hexadecimal value of char
    set statusline+=%=%-14.(%l,%c%V%)\ %p%%     " Right aligned file nav info
endif


" =============================================================================
" NAVIGATION SETTINGS
" -----------------------------------------------------------------------------
set virtualedit=onemore                 " Allow the cursor to go one cell past the end of the line
set backspace=indent,eol,start          " Allow backspacing over anything
set switchbuf=useopen,usetab            " Files are opened from buffers, if it exists

" The following mappings make Ctrl+navkey move that direction in windows
" We set them in both normal and insert mode, for ease of use
noremap <C-j> <C-W>j
noremap <C-k> <C-W>k
noremap <C-l> <C-W>l
noremap <C-h> <C-W>h
inoremap <C-j> <ESC><C-W>j
inoremap <C-k> <ESC><C-W>k
inoremap <C-l> <ESC><C-W>l
inoremap <C-h> <ESC><C-W>h


" =============================================================================
" TAB AND INDENT SETTINGS
" -----------------------------------------------------------------------------
set smarttab                            " Tabs are treated as single characters
set expandtab                           " Expand tab into spaces
set tabstop=4                           " Tabs are width 4 by default
set shiftwidth=4
set softtabstop=4
set autoindent                          " Copy indentation from previous line
"set smartindent                        " Disabled since filetype indent is on

" Set smartindent keywords for Python.
autocmd BufRead,BufNewFile *.py set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class,with

" Don't de-indent comments in Python
autocmd BufRead *.py inoremap # X<c-h>#

" Don't show special characters in Go.
autocmd FileType go set nolist noexpandtab


" =============================================================================
" COMMAND SETTINGS
" -----------------------------------------------------------------------------
set wildmenu                            " Enable command-line tab completion
set wildmode=longest,list,full          " Set tab-completion order

" Types to ignore when autocompleting.
set wildignore+=*.o,*.obj,*.pyc,*.DS_Store,*.db,.git,*.bak,.svn,*.swp
set wildignore+=.tox,*.egg-info

" Auto-insert longest match, show menu for even 1 item, and show more info in
" the preview window.
set completeopt=longest,menuone,preview

" Complete by pulling from, in order: the current file, loaded buffers,
" unloaded buffers, and the tags file.
set complete=.,b,u,]

" Set the tags path.
set tags=tags;/


" =============================================================================
" SEARCH AND REPLACE SETTINGS
" -----------------------------------------------------------------------------
set ignorecase                          " Ignore case when searching all lower-case ...
set smartcase                           " ... but be case-sensitive if the search has mixed case
set hlsearch                            " Highlight search matches!
set incsearch                           " Search incrementally
set wrapscan                            " Wrap searches around the beginning/end of the file
set gdefault                            " Apply substitutions globally by default

" Space will unhighlight search and clear any diplayed message
nnoremap <silent> <Space> :nohlsearch<Bar>:echo<CR><Space>

" Don't update default register when deleting single characters
noremap x "_x

" Don't update default register when pasting in visual mode
noremap p "_c<Esc>P


" =============================================================================
" MAPPINGS AND REMAPPINGS
" -----------------------------------------------------------------------------

" Pressing 'K' splits the line at the current cursor pos
nnoremap K i<CR><Esc>

" Make Y yank until end of line, for consistency with C and D.
nnoremap Y y$

" Shift-Enter will insert a line below the current line, without going into
" insert mode.
map <S-Enter> o<Esc>

" Ctrl-Shift-Enter does the same as Shift-Enter, except above.
map <CS-Enter> O<Esc>

" NOTE: the above two lines don't seem to work in a terminal :(

" Ctrl-s saves the file (like other editors!)
map <C-s> :w<CR>

" Remap F1 to escape.  This is especially useful on Kinesis keyboards, where
" it's very easy to accidentally hit the wrong key.
map <F1> <Esc>
imap <F1> <Esc>
vmap <F1> <Esc>

" Tab in visual mode indents the selection
vmap <Tab> >

" Shift-Tab in visual mode dedents the selection
vmap <S-Tab> <

" Two mappings from vim-unimpaired
nmap <silent> [q :cprevious<CR>
nmap <silent> ]q :cnext<CR>

" Make Enter and Tab select a highlighted menu item.
inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
inoremap <expr> <Tab> pumvisible() ? "\<C-y>" : "\<Tab>"
" inoremap <expr> <Space> pumvisible() ? "\<C-y>" : "\<Space>"

" Map Ctrl-@ to Ctrl-Space, to support some terminals that do this.  This is
" used in the autocomplete mapping, below.
imap <C-@> <C-Space>

" w!! will save the file with sudo
cmap w!! w !sudo tee % >/dev/null

" Generate tags on the current directory with F4
map <F4> :!ctags -R --fields=+iaS --extra=+q .<CR>

" Disable arrow keys
inoremap  <Up>     <NOP>
inoremap  <Down>   <NOP>
inoremap  <Left>   <NOP>
inoremap  <Right>  <NOP>
noremap   <Up>     <NOP>
noremap   <Down>   <NOP>
noremap   <Left>   <NOP>
noremap   <Right>  <NOP>

" Turn off Q for Ex mode
noremap Q :q

" -----------------------------------------------------------------------------
" Leader Mappings (subsection)
" -----------------------------------------------------------------------------
" Explicitly set the leader.
let mapleader="\\"

" <leader>W will strip all trailing whitespace in the file
nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>

" <leader>a calls Ack, since it's shorter!
" NOTE: the trailing space is IMPORTANT - it means that I don't have to type it
" after using <leader>a
nnoremap <leader>a :Ack 

" <leader>w will open a new vertical split window, and switch to it
nnoremap <leader>w <C-w>v<C-w>l

" <leader>v will open a new, empty vertical window to the right
nnoremap <leader>v :rightbelow vnew<CR>

" <leader>h will toggle highlighting the 80th column
" Highlight the colored column in red.
nnoremap <leader>h
    \ :if &colorcolumn > 0 <bar>
    \   set colorcolumn= <bar>
    \   echo "colorcolumn off" <bar>
    \ else <bar>
    \   set colorcolumn=80 <bar>
    \   highlight ColorColumn ctermbg=red guibg=red <bar>
    \   echo "colorcolumn on" <bar>
    \ endif<CR><CR>

" <leader>d is a helper to download files to the current buffer
" NOTE: trailing whitespace is important
nnoremap <leader>d :r ! curl -sL 

" Open CtrlP for tags
nnoremap <silent> <leader>. :CtrlPTag<CR>

" Search for the word under the cursor
nnoremap <leader>s :Ack <C-r><C-w>

" Copy the current file and line to the clipboard
nnoremap <leader>b :let @* = expand("%") . ", line " . line(".")<cr>
vnoremap <leader>b :let @* = expand("%") . ", line " . line(".")<cr>


" =============================================================================
" PLUGIN SETTINGS
" -----------------------------------------------------------------------------

" CtrlP: set the command and command name
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" CtrlP: use git to list files (ignoring untracked)
let g:ctrlp_user_command = {
  \ 'types': {
  \ 1: ['.git', 'cd %s && git ls-files . -co --exclude-standard'],
  \ 2: ['.hg', 'hg --cwd %s status -numac -I . $(hg root)'],
  \ },
  \ 'fallback': 'find %s -type f'
  \ }

" Ack: Use 'Ag' instead of 'ack'.  Also: ignore ctags files
let g:ackprg = 'ag --nogroup --nocolor --column --ignore tags'

" vim-go: Disable the 'K' binding
let g:go_doc_keywordprg_enabled = 0


" =============================================================================
" LOCAL
" -----------------------------------------------------------------------------

" If it exists, include user's local vim config
if filereadable(expand("~/.vimrc.local"))
    source ~/.vimrc.local
endif
