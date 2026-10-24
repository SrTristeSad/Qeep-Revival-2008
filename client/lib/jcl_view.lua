-- Stateful, UI-framework-independent navigation through supported JCL widgets.
local M = {}
local utf8_edit = require('lib.utf8_edit')
local choices = require('lib.jcl_choices')
local function actionable(i)
  return (i.kind ~= 'lsk' and i.kind ~= 'rsk' and i.href and i.href ~= '') or i.kind == 'input' or i.kind == 'textarea'
    or i.kind == 'select' or i.kind == 'button'
end
local function selected_index(form)
  for n, item in ipairs(form.items) do if actionable(item) and item.focused then return n end end
  for n, item in ipairs(form.items) do if actionable(item) then return n end end
  return 0
end
function M.new(doc)
  local self = {document=doc, page=1, selected=selected_index(doc.forms[1]), editing=false, modified=false}
  return self
end
function M.form(self) return self.document.forms[self.page] end
function M.item(self) return M.form(self).items[self.selected] end
function M.move(self, step)
  if self.editing or self.choosing then return false end
  local items = M.form(self).items
  local n = #items
  if n == 0 then return false end
  local i = self.selected
  for _=1,n do
    i = (i - 1 + step + n) % n + 1
    if actionable(items[i]) then self.selected = i; return true end
  end
  return false
end
function M.activate(self)
  local item = M.item(self)
  if not item then return nil end
  if item.kind == 'select' and #item.options > 0 then
    if item.choiceType == 4 then
      choices.choose(item, item.selected % #item.options + 1)
      self.modified = true
      return 'selected'
    end
    self.choosing = true
    self.choiceFocus = item.selected > 0 and item.selected or 1
    return 'choosing'
  elseif item.kind == 'input' or item.kind == 'textarea' then
    self.editing = true
    return 'editing'
  elseif item.href and item.href ~= '' then return item.href
  end
  return nil
end
function M.text(self, value)
  local item = M.item(self)
  if not self.editing or not item or type(value) ~= 'string' then return end
  local updated = utf8_edit.append(item.value, value, item.length)
  if updated ~= item.value then item.value=updated; self.modified=true end
end
function M.backspace(self)
  local item = M.item(self)
  if not self.editing or not item then return end
  local updated = utf8_edit.backspace(item.value)
  if updated ~= item.value then item.value=updated; self.modified=true end
end
function M.cancel_edit(self) self.editing=false end
function M.choice_move(self, step)
  if not self.choosing then return false end
  local item=M.item(self)
  local n=item and #item.options or 0
  if n==0 then return false end
  self.choiceFocus=math.max(1,math.min(n,(self.choiceFocus or 1)+step))
  return true
end
function M.choice_choose(self, index)
  local item=M.item(self)
  if not item or item.kind~='select' then return false end
  if not choices.choose(item, index or self.choiceFocus) then return false end
  self.modified = true
  if item.choiceType ~= 2 then self.choosing = false end
  return true
end
function M.choice_close(self) self.choosing=false;self.choiceFocus=nil end
function M.next_form(self, id)
  for n,form in ipairs(self.document.forms) do
    if form.id == id then self.page=n; self.selected=selected_index(form);self.editing=false;self.choosing=false;self.choiceFocus=nil;return true end
  end
  return false
end
return M
