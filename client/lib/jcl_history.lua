-- Navigation snapshots for the synthetic JCL browser.
-- Page state and scroll position are kept without duplicating entire JCL trees.
-- This is a reconstructed client-side convenience, not proven Qeep 1.29 behavior.
local M = {}
function M.new(max_entries)
  local limit = tonumber(max_entries) or 16
  limit = math.max(1, math.min(32, math.floor(limit)))
  return {entries={}, limit=limit}
end
function M.clear(history)
  history.entries={}
end
function M.depth(history)
  return #history.entries
end
function M.push(history, document, scroll)
  assert(type(document)=='table' and type(document.page)=='number'
    and type(document.selected)=='number', 'invalid JCL navigation state')
  local entries=history.entries
  entries[#entries+1]={document=document,page=document.page,
    selected=document.selected,scroll=math.max(0,tonumber(scroll) or 0)}
  if #entries>history.limit then table.remove(entries,1) end
end
function M.pop(history)
  local entries=history.entries
  if #entries==0 then return nil end
  local state=table.remove(entries)
  local document=state.document
  document.page=state.page
  document.selected=state.selected
  document.editing=false
  document.choosing=false
  document.choiceFocus=nil
  return document,state.scroll
end
return M
