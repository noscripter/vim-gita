let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'ignore-submodules',
        \ 'no-prefix', 'no-index', 'exit-code',
        \ 'U', 'unified', 'minimal',
        \ 'patience', 'histogram', 'diff-algorithm',
        \ 'cached',
        \])
  return options
endfunction
function! s:get_diff_content(hita, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['no-color'] = 1
  let options['commit'] = a:commit
  if !has_key(options, 'R')
    let options['R'] = get(a:options, 'reverse', 0)
  endif
  if !empty(a:filenames)
    let options['--'] = map(
          \ copy(a:filenames),
          \ 'a:hita.get_absolute_path(v:val)',
          \)
  endif
  let result = hita#operation#exec(a:hita, 'diff', options)
  if get(options, 'no-index') || get(options, 'exit-code')
    " NOTE:
    " --no-index force --exit-code option.
    " --exit-code mean that the program exits with 1 if there were differences
    " and 0 means no differences
    return split(result.stdout, '\r\?\n')
  elseif result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n')
endfunction
function! s:is_patchable(commit, options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'reverse': 0,
        \}, a:options)
  if empty(a:commit) && !options.cached && !options.reverse
    " Diff between TREE <> INDEX
    return 1
  elseif options.cached && options.reverse
    " Diff between {ANY} <> INDEX
    return 1
  endif
  return 0
endfunction

function! s:on_BufWriteCmd() abort
  let commit = hita#core#get_meta('commit', '')
  let options = hita#core#get_meta('options', {})
  if !s:is_patchable(commit, options)
    call hita#util#prompt#warn(join([
          \ 'Patching diff is only available when diff was produced',
          \ 'by ":Hita diff [-- {filename}...]" or',
          \ '":Hita diff --cached --reverse [-- {filename}...]"',
          \]))
    return
  endif
  let hita = hita#core#get()
  try
    let result = hita#command#apply#call({
          \ 'diff_content': getline(1, '$'),
          \ 'cached': 1,
          \ 'reverse': 0,
          \ 'unidiff-zero': get(options, 'unified', '') == '0',
          \})
    if empty(result)
      return
    endif
    redraw | echo printf('The changes are %s INDEX',
          \ get(options, 'cached', 0)
          \   ? 'unstaged from'
          \   : 'staged to',
          \)
    " force to reload the content
    silent doautocmd BufReadCmd
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
  endtry
endfunction

function! hita#command#diff#bufname(...) abort
  let options = extend({
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    if !empty(options.filenames)
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
    else
      let filenames = []
    endif
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  if len(filenames) == 1
    return hita#autocmd#bufname(hita, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.cached ? 'cached' : '',
          \   options.reverse ? 'reverse' : '',
          \ ],
          \ 'treeish': commit . ':' . hita.get_relative_path(filenames[0]),
          \})
  else
    return hita#autocmd#bufname(hita, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.cached ? 'cached' : '',
          \   options.reverse ? 'reverse' : '',
          \ ],
          \ 'treeish': commit . ':',
          \})
  endif
endfunction
function! hita#command#diff#call(...) abort
  let options = extend({
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    if !empty(options.filenames)
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
    else
      let filenames = []
    endif
    let content = s:get_diff_content(hita, commit, filenames, options)
    let result = {
          \ 'commit': commit,
          \ 'filenames': filenames,
          \ 'content': content,
          \}
    return result
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! hita#command#diff#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:hita#command#diff#default_opener
        \ : options.opener
  let bufname = hita#command#diff#bufname(options)
  if !empty(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will call ...#edit to apply the content
  endif
endfunction
function! hita#command#diff#read(...) abort
  silent doautocmd FileReadPre
  let options = extend({}, get(a:000, 0, {}))
  let result = hita#command#diff#call(options)
  if empty(result)
    return
  endif
  call hita#util#buffer#read_content(result.content)
  silent doautocmd FileReadPost
endfunction
function! hita#command#diff#edit(...) abort
  silent doautocmd BufReadPre
  let options = extend({}, get(a:000, 0, {}))
  if hita#core#get_meta('content_type', '') ==# 'diff'
    let options = extend(options, hita#core#get_meta('options', {}))
  endif
  let result = hita#command#diff#call(options)
  if empty(result)
    return
  endif
  call hita#core#set_meta('content_type', 'diff')
  call hita#core#set_meta('options', options)
  call hita#core#set_meta('commit', result.commit)
  call hita#core#set_meta('filename', get(result.filenames, 0, ''))
  call hita#core#set_meta('filenames', result.filenames)
  call hita#util#buffer#edit_content(result.content)
  setfiletype diff
  setlocal buftype=acwrite
  augroup vim_gita_internal_diff_apply_diff
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
  augroup END
  if s:is_patchable(result.commit, options)
    setlocal noreadonly
  else
    setlocal readonly
  endif
  silent doautocmd BufReadPost
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita diff',
          \ 'description': 'Show a diff content of a commit or files',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'Compare the changes you staged for the next commit', {
          \})
    call s:parser.add_argument(
          \ '--reverse',
          \ 'reverse', {
          \})
    call s:parser.add_argument(
          \ 'commit',
          \ 'A commit', {
          \   'complete': function('hita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#diff#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call hita#option#assign_commit(options)
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#diff#default_options),
        \ options,
        \)
  call hita#command#diff#open(options)
endfunction
function! hita#command#diff#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#define_variables('command#diff', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
