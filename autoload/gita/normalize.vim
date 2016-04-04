let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')

" NOTE:
" git requires an unix relative path from the repository often
function! gita#normalize#relpath_for_git(git, path) abort
  let path = s:Git.get_relative_path(a:git, gita#meta#expand(a:path))
  return s:Path.unixpath(path)
endfunction

" NOTE:
" sys(tem) requires a real absolute path often
function! gita#normalize#abspath_for_sys(git, path) abort
  let path = s:Git.get_absolute_path(a:git, gita#meta#expand(a:path))
  return s:Path.realpath(path)
endfunction

" NOTE:
" most of git command does not understand A...B type assignment so translate
" it to an exact revision
function! gita#normalize#commit(git, commit) abort
  if a:commit =~# '^.\{-}\.\.\..\{-}$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    return s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
  elseif a:commit =~# '^.\{-}\.\..\{-}$'
    return s:GitTerm.split_range(a:commit)[0]
  else
    return a:commit
  endif
endfunction

" NOTE:
" git diff command does not understand A...B type assignment so translate
" it to an exact revision
function! gita#normalize#commit_for_diff(git, commit, ...) abort
  let split = get(a:000, 0, 0)
  if a:commit =~# '^.\{-}\.\.\..\{-}$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let lhs = s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
    return split ? [lhs, rhs] : lhs . '..' . rhs
  elseif a:commit =~# '^.\{-}\.\..\{-}$'
    return split ? s:GitTerm.split_range(a:commit) : a:commit
  else
    return split ? [a:commit, a:commit] : a:commit
  endif
endfunction
