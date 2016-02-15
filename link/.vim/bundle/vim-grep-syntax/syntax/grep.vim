syntax case ignore

syntax match GrepFile /[^:]*/
            \ nextgroup=GrepSeparator1
syntax match GrepSeparator1 /:/ contained
            \ nextgroup=GrepLineNr
syntax match GrepLineNr /\d*/ contained
            \ nextgroup=GrepSeparator2
syntax match GrepSeparator2 /:/ contained
            \ nextgroup=GrepPattern
syntax match GrepPattern /.*/ contained


" Needs to be defined below due to priority
syntax match NoteGood /^GOOD|\s*/
            \ nextgroup=GrepFile
syntax match NoteBad /^BAD|\s*/
            \ nextgroup=GrepFile


" 33 == a nice dark blue, should work in most places
highlight GrepFile          ctermfg=33          guifg=#00ff00
highlight GrepSeparator1    ctermfg=red         guifg=#ff0000
highlight GrepSeparator2    ctermfg=red         guifg=#ff0000
highlight GrepLineNr        ctermfg=yellow      guifg=#ffff00
highlight link GrepPattern  Normal

highlight NoteGood          ctermfg=green       guifg=#0000ff
highlight NoteBad           ctermfg=red         guifg=#ff0000
