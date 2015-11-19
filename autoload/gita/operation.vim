let s:save_cpo = &cpoptions
set cpoptions&vim


let s:C = gita#import('VCS.Git.Core')
let s:A = gita#import('ArgumentParser')
let s:is_windows = has('win16') || has('win32') || has('win64')
let s:TYPE_NUMBER = type(0)
let s:TYPE_FUNC   = type(function('type'))

let s:schemes = {}
let s:schemes.reset = {
      \ 'commit': '%v',
      \}
let s:schemes.show = {
      \ 'object': '%v',
      \}
let s:schemes.diff = {
      \ 'commit': '%v',
      \}
let s:schemes.commit = {
      \ 'C': '-%k %v',
      \ 'c': '-%k %v',
      \ 'F': '-%k %v',
      \ 'm': '-%k %v',
      \ 't': '-%k %v',
      \}
let s:schemes.branch = {
      \ 'u': '-%k %v',
      \ 'contains': '--%k %v',
      \ 'merged': '--%k %v',
      \ 'no-merged': '--%k %v',
      \}
let s:schemes.checkout = {
      \ 'b': '-%k %v',
      \ 'B': '-%k %v',
      \ 'commit': '%v',
      \}
let s:schemes.merge_base = {
      \ 'fork_point': '--%K %v',
      \ 'commit': '%v',
      \ 'commit1': '%v',
      \ 'commit2': '%v',
      \}
let s:schemes.rev_parse = {
      \ 'default': '--%K %V',
      \ 'prefix': '--%K %V',
      \ 'resolve_git_dir': '--%K %V',
      \ 'args': '%v',
      \}
let s:schemes.blame = {
      \ 'L': '--%k %v',
      \ 'S': '--%k %v',
      \ 'contents': '--%k %V',
      \ 'date': '--%k %V',
      \ 'commit': '%v',
      \}
function! s:schemes.clone(name, options) abort " {{{
  let scheme = {
        \ 'reference': '--%K %V',
        \ 'o': '-%K %V',
        \ 'origin': '--%K %V',
        \ 'b': '-%K %V',
        \ 'branch': '--%K %V',
        \ 'u': '-%K %V',
        \ 'upload-pack': '--%K %V',
        \ 'c': '-%K %V',
        \ 'configig': '--%K %V',
        \ 'depth': '--%K %V',
        \}
  let args = s:translate_options(a:options, scheme)
  return extend(args, [
        \ '--',
        \ get(a:options, 'repository', ''),
        \ get(a:options, 'directory', ''),
        \])
endfunction " }}}

function! s:prefer_shellescape(val) abort " {{{
  let val = shellescape(a:val)
  if val !~# '\s'
    if !s:is_windows || (exists('&shellslash') && &shellslash)
      let val = substitute(val, "^'", '', 'g')
      let val = substitute(val, "'$", '', 'g')
    else
      " Windows without shellslash enclos value with double quote
      let val = substitute(val, '^"', '', 'g')
      let val = substitute(val, '"$', '', 'g')
    endif
  endif
  return val
endfunction " }}}
function! s:translate_option(key, val, pattern) abort " {{{
  if type(a:val) ==# s:TYPE_NUMBER
    if a:val == 0
      return ''
    endif
    let val = ''
  else
    let val = a:val
  endif
  if len(a:key) == 1
    let format = empty(a:pattern) ? '-%k%v' : a:pattern
  else
    let format = empty(a:pattern) ? '--%K%{=}V' : a:pattern
  endif
  let format_map = {
        \ 'k': 'key',
        \ 'v': 'val',
        \ 'K': 'escaped_key',
        \ 'V': 'escaped_val',
        \ 'u': 'unixpath_val',
        \ 'U': 'escaped_unixpath_val',
        \ 'r': 'realpath_val',
        \ 'R': 'escaped_realpath_val',
        \}
  let data = {
        \ 'key': a:key,
        \ 'val': val,
        \ 'escaped_key': substitute(a:key, '_', '-', 'g'),
        \ 'escaped_val': len(val) ? s:prefer_shellescape(val) : '',
        \ 'unixpath_val': gita#utils#path#unix_abspath(val),
        \ 'escaped_unixpath_val': len(val)
        \   ? s:prefer_shellescape(gita#utils#path#unix_abspath(val))
        \   : '',
        \ 'realpath_val': gita#utils#path#real_abspath(val),
        \ 'escaped_realpath_val': len(val)
        \   ? s:prefer_shellescape(gita#utils#path#real_abspath(val))
        \   : '',
        \}
  return gita#utils#format_string(format, format_map, data)
endfunction " }}}
function! s:translate_options(options, scheme) abort " {{{
  let args = []
  for [key, val]  in items(a:options)
    if key !~# '^__.\+__$' && key !=# '--'
      let pattern = get(a:scheme, key, '')
      call extend(args, s:A.splitargs(s:translate_option(key, val, pattern)))
    endif
    unlet! val
  endfor
  if has_key(a:options, '--')
    call add(args, '--')
    for str in a:options['--']
      call add(args, fnameescape(gita#utils#path#expand(str)))
    endfor
  endif
  return args
endfunction " }}}
function! s:execute(gita, args, conf) abort " {{{
  let args = filter(deepcopy(a:args), 'len(v:val)')
  let conf = extend({
        \ 'echo_success':   1,
        \ 'echo_fail':      1,
        \ 'doautocmd':      1,
        \ 'success_status': 0,
        \ 'interactive':    0,
        \}, a:conf,
        \)
  if a:gita.enabled
    let ret = a:gita.git.exec(args, {
          \ 'interactive': conf.interactive
          \})
  else
    let ret = s:C.exec(args, {
          \ 'interactive': conf.interactive
          \})
  endif
  let ret.stdout = gita#utils#remove_ansi_sequences(ret.stdout)
  let ret.is_success = ret.status == conf.success_status
  if !conf.interactive
    if conf.echo_success && ret.is_success
      call gita#utils#prompt#info(printf('Ok: %s', join(ret.args)))
      call gita#utils#prompt#echo(ret.stdout)
    elseif conf.echo_fail && !ret.is_success
      call gita#utils#prompt#warn(printf('Fail: %s', join(ret.args)))
      call gita#utils#prompt#echo(ret.stdout)
    endif
  endif
  if conf.doautocmd && ret.is_success
    call gita#compat#doautocmd(printf('vim-gita-%s-post', args[0]))
  endif
  return ret
endfunction " }}}

function! gita#operation#exec(gita, name, options, ...) abort " {{{
  let l:Scheme = get(s:schemes, a:name, {})
  if type(l:Scheme) ==# s:TYPE_FUNC
    let args = l:Scheme(a:name, a:options)
  else
    let args = s:translate_options(a:options, l:Scheme)
  endif
  let args = extend([a:name], args)
  let conf = get(a:000, 0, {})
  return s:execute(a:gita, args, conf)
endfunction " }}}


let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
