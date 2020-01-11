
"{{{ Code Editing
set autoindent          " auto indents
set smartindent         " indent for code
syntax enable           " syntax highlighting

" quick shortcut to open pdf of the tex file
auto FileType tex nnoremap ;open :w<CR>:!zathura <C-R>=expand("%:p:r").".pdf"<CR> &<CR><CR>

" lua run command
" figure out a way to make this only avaliable to executables
auto FileType lua nnoremap ;run :w<CR>:!./<C-R>%<CR>

"}}}

"{{{ Visuals
set number              " line number
set relativenumber      " relative line numbers based on cursor position
set scrolloff=3         " how many rows to keep on screen when cursor moves up or down
set sidescrolloff=5     " how many columns to keep on screen when cursor moves sideways
set wildmenu	        " visual autocomplete stuffs
set lazyredraw	        " redraw screen only when necessary
set showcmd		" show command being typed
set breakindent		" have word wrapping follow indent of wrapped line
set background=dark

autocmd BufRead,BufNewFile *.etlua set filetype=html

colorscheme elflord
"}}}

" {{{ NERDtree imitation
let g:netrw_liststyle=3 " set tree style to default when viewing directories
let g:netrw_banner=0	" get rid of the banner
let g:netrw_browse_split=3 " open files in a new tab
let g:netrw_winsize=20	" have netrw take up 20% of the window
" }}}

"{{{ Text formatting
set linebreak
set wrap
set formatoptions=ltcroj " each letter corresponds to a text formatting option 
                         " from https://vimhelp.org/change.txt.html#fo-table
"}}}

"{{{ Marks
set foldmethod=marker	" allow folding
"}}}

set mouse=a
