let s:V = hita#vital()
let s:Guard = s:V.import('Vim.Guard')
let s:Prompt = s:V.import('Vim.Prompt')

function! s:is_debug() abort
  return g:hita#debug
endfunction
function! s:is_batch() abort
  return g:hita#test
endfunction

function! hita#util#prompt#echo(...) abort
  call call(s:Prompt.echo, a:000, s:Prompt)
endfunction

function! hita#util#prompt#debug(...) abort
  call call(s:Prompt.debug, a:000, s:Prompt)
endfunction
function! hita#util#prompt#info(...) abort
  call call(s:Prompt.info, a:000, s:Prompt)
endfunction
function! hita#util#prompt#warn(...) abort
  call call(s:Prompt.warn, a:000, s:Prompt)
endfunction
function! hita#util#prompt#error(...) abort
  call call(s:Prompt.error, a:000, s:Prompt)
endfunction
function! hita#util#prompt#ask(...) abort
  return call(s:Prompt.ask, a:000, s:Prompt)
endfunction
function! hita#util#prompt#select(...) abort
  return call(s:Prompt.select, a:000, s:Prompt)
endfunction
function! hita#util#prompt#confirm(...) abort
  return call(s:Prompt.confirm, a:000, s:Prompt)
endfunction

function! hita#util#prompt#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | echo a:message
  endif
endfunction


call s:Prompt.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
