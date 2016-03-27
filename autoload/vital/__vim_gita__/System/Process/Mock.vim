let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:is_available() abort
  return 1
endfunction

function! s:is_supported(options) abort
  return 1
endfunction

function! s:execute(args, options) abort
  if &verbose > 0
    echomsg printf(
          \ 'vital: System.Process.Mock: %s',
          \ join(a:args)
          \)
  endif
  return {
        \ 'success': 1,
        \ 'output': 'Output of System.Process.Mock',
        \}
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
