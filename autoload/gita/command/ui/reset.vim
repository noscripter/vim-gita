function! gita#command#ui#reset#open(...) abort
  let options = extend({
        \ 'edit': 0,
        \}, get(a:000, 0, {}))
  let method = options.edit ? 'one' : 'two'
  call gita#command#ui#patch#open(extend({
        \ 'reverse': 1,
        \ 'method': method,
        \}, options)
        \)
endfunction
