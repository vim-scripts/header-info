if(exists('g:vimmsf_header_info_disabled')) | finish | endif
if(exists('g:vimmsf_header_info'))
    echo "plugin 'header_info' has been loaded...'"
    finish
endif
let g:vimmsf_header_info = 'true'
if(!exists('g:vimmsf_header_info_range_marker') || g:vimmsf_header_info_range_marker == '')
    let g:vimmsf_header_info_range_marker = 'vimmsf_header_info_range_marker(never modify me)'
endif
let s:where_installed = expand('<sfile>:p:h')
fun! s:extract_map (path)"{{{
    let lines = readfile(a:path)
    let content = ''
    for line in lines
        let pair = split(line, '\s*->\s*')
        let content .= printf('"%s" : "%s",', pair[0], pair[1])
    endfor
    let content = '{' . content . '}'
    return eval(content)
endfun"}}}
fun! s:get_marked_range (marker)"{{{
    let old_curpos = getpos('.')
    normal gg
    let range = [searchpos(a:marker, 'Wc'), searchpos(a:marker, 'W')]
    call setpos('.', old_curpos)
    if(range[0] == range[1] || range[0] == [0,0] || range[1] == [0,0])
        let range = []
    endif
    return range
endfun"}}}
fun! s:make_header (tp_path, old_header)"{{{

    let tp_file = a:tp_path . get(s:ft_map, &filetype, 'default.txt')
    let res = {'matched': 'true'}
    let temps = readfile(tp_file)
    if(&commentstring[-2:-1] == '%s')
        let is_line_comter = 'true'
    else
        let is_line_comter = 'false'
    endif
    if(is_line_comter == 'true')
        call map(temps, 'printf(&commentstring, v:val)')
    endif
    let new_header = ''
    let sp = "\n\n\n"
    if(len(a:old_header) != len(temps))
        let new_header = substitute(join(temps, sp), "@+remained+@", '', 'g')
        let res['matched'] = 'false'
    else
        for lnu in range(len(temps))
            if(temps[lnu] =~ '@+remained+@$')
                let line = a:old_header[lnu]
            else
                let line = temps[lnu]
            endif
            let new_header .= line . sp
        endfor
    endif
    if(res['matched'] == 'true')
        let new_header = new_header[: len(new_header)-len(sp)-1]
    endif
    let pat = '\(' . join(keys(s:mk_map), '\|') . '\)'
    let new_header = substitute(new_header, pat, '\=eval(s:mk_map[submatch(0)])', 'g')
    if(is_line_comter == 'false')
        let new_header = printf(&commentstring, new_header)
    endif
    let header = split(new_header, sp)
    let res['header'] = header
    return res
endfun"}}}
fun! s:update_header ()"{{{
    let marker = printf('^' . &commentstring . '$', g:vimmsf_header_info_range_marker)
    let marker = substitute(marker, '\(\*\)', '\\\1', 'g')
    let range = s:get_marked_range(marker)
    let header_line_number = 1
    if(range == [])
        let old_header = []
    else
        let old_header = getline(range[0][0]+1, range[1][0]-1)
    endif
    let res = s:make_header(s:where_installed . '/templates/', old_header) 
    if(range != [])
        if(res['matched'] == 'false')
            redraw!
            let ins = input("the structure of current header info is different from template file.\nforce to continue? (\"y\" to continue) ")
            if(ins != 'y') | return | endif
        endif
        exe printf("normal %dGV%dG", range[0][0], range[1][0])
        redraw!
        let ins = input('updating now? ("y" to continue) ')
        if(ins == 'y') 
            normal d
            let old_header = getline(range[0][0]+1, range[1][0]-1)
            let header_line_number = line('.')
        else
            exe "normal \<esc>"
            return 
        endif
    endif
    let header = [printf(&commentstring, g:vimmsf_header_info_range_marker)] + 
               \ res['header'] +
               \ [printf(&commentstring, g:vimmsf_header_info_range_marker)]
    call append(header_line_number-1, header)
    exe 'normal ' . header_line_number . 'G'
endfun"}}}
let s:mk_map = s:extract_map(s:where_installed . '/marker')
let s:ft_map = s:extract_map(s:where_installed . '/filetype')
command! -buffer -nargs=0 HeaderInfo call s:update_header()
nmap <c-k><c-h> :HeaderInfo<cr>
