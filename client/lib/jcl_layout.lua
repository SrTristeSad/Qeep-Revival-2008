-- Pure JCL list layout model. Geometry is deliberately not presented as a
-- historical pixel-perfect reproduction of the obfuscated Java ME renderer.
local M = {}
local choices = require('lib.jcl_choices')
local assets = require('lib.legacy_assets')
local function wrap(font, value, width)
  local _, lines = font:getWrap(tostring(value or ''), width)
  return math.max(1, #lines)
end
local function bound(n, lo, hi)
  return math.max(lo, math.min(n, hi))
end
function M.build(form, font, width)
  assert(form and form.items and font and font.getWrap and font.getHeight)
  width = width or 220
  local line_height = font:getHeight() + 2
  local result = {entries={}, total=0, width=width}
  local y = 0
  for index,item in ipairs(form.items) do
    if item.kind ~= 'lsk' and item.kind ~= 'rsk' then
      local kind = item.kind
      local title = tostring(item.label or '')
      if item.marker then title = item.marker .. (title ~= '' and (' '..title) or '') end
      local detail, imageInfo, imageY
      if kind == 'input' or kind == 'textarea' then
        detail = item.secret and string.rep('*', math.min(tonumber(#(item.value or '')) or 0, 48)) or tostring(item.value or '')
      elseif kind == 'select' then
        local option = item.options and item.options[item.selected or 1]
        if item.choiceType == 4 then
          detail = (option and option.label or '[sem opções]') .. '  >'
        end
      elseif kind == 'img' then
        imageInfo = assets.info(item.src)
        if not imageInfo then detail='[recurso de imagem desconhecido]' end
      elseif kind == 'gauge' then
        detail = tostring(item.value or 0) .. '/' .. tostring(item.max or 100)
      end
      local height, choiceRows
      if kind == 'hr' then height = 12
      else
        local text_height = wrap(font, title, width - 16) * line_height
        if detail then text_height = text_height + wrap(font, detail, width - 18) * line_height + 2 end
        height = text_height + 10
        if kind == 'select' and item.choiceType ~= 4 then
          choiceRows = {}
          local cursor = wrap(font, title, width - 16) * line_height + 8
          for i,opt in ipairs(item.options or {}) do
            local h = wrap(font, opt.label or '', width - 50) * line_height + 6
            choiceRows[i] = {index=i, y=cursor, height=h, label=opt.label or ''}
            cursor = cursor + h
          end
          height=math.max(cursor+3,30)
        end
        if kind == 'input' then height = math.max(height, 43)
        elseif kind == 'textarea' then height = math.max(height, 58)
        elseif kind == 'select' and item.choiceType == 4 then height = math.max(height, 43)
        elseif kind == 'gauge' then height = height + 10
        elseif kind == 'img' then
          imageY=title~='' and (8 + wrap(font,title,width-16)*line_height) or 5
          height=math.max(height, imageY + (imageInfo and imageInfo.height or 24) + 5)
        end
      end
      local entry = {index=index, item=item, title=title, detail=detail, y=y, height=height, lineHeight=line_height,
        ruleWidth = kind == 'hr' and bound(item.width or 90, 1, width - 10) or nil,
        choiceRows = choiceRows, imageInfo=imageInfo, imageY=imageY}
      result.entries[#result.entries + 1] = entry
      y = y + height + 3
    end
  end
  result.total = math.max(0,y-3)
  return result
end
-- j.class centers short pages by default (j.B=true), while h.class
-- changes j.B to false for form valign="top". This placement function
-- deliberately leaves long/scrollable pages top-aligned.
function M.place(result, viewport_height, valign)
  assert(type(result)=='table' and type(result.entries)=='table')
  viewport_height=math.max(0,tonumber(viewport_height) or 0)
  -- Safe to call again after font size or screen dimensions change.
  local old=result.topInset or 0
  for _,entry in ipairs(result.entries) do entry.y=entry.y-old end
  local content=result.total-old
  local inset=0
  if valign~='top' and content < viewport_height then
    inset=math.floor((viewport_height-content)/2)
  end
  for _,entry in ipairs(result.entries) do entry.y=entry.y+inset end
  result.topInset=inset
  result.total=content+inset
  result.valign=valign
  return result
end
function M.choice_hit(layout, index, y, scroll)
  local actual = y + (scroll or 0)
  for _,entry in ipairs(layout.entries) do
    if entry.index == index and entry.choiceRows then
      for _,row in ipairs(entry.choiceRows) do
        local top = entry.y + row.y
        if actual >= top and actual < top + row.height then return row.index end
      end
    end
  end
  return nil
end
function M.ensure_choice_visible(layout, index, choice_index, scroll, viewport_height)
  scroll = M.clamp_scroll(layout,scroll,viewport_height)
  for _,entry in ipairs(layout.entries) do
    if entry.index==index and entry.choiceRows and entry.choiceRows[choice_index] then
      local row=entry.choiceRows[choice_index]
      local top=entry.y+row.y
      local bottom=top+row.height
      if top < scroll then scroll=top
      elseif bottom > scroll+viewport_height then scroll=bottom-viewport_height end
      return M.clamp_scroll(layout,scroll,viewport_height)
    end
  end
  return scroll
end
function M.max_scroll(layout, viewport_height)
  return math.max(0,layout.total - viewport_height)
end
function M.clamp_scroll(layout, scroll, viewport_height)
  return bound(scroll or 0,0,M.max_scroll(layout,viewport_height))
end
function M.ensure_visible(layout, index, scroll, viewport_height)
  scroll = M.clamp_scroll(layout,scroll,viewport_height)
  for _,entry in ipairs(layout.entries) do
    if entry.index == index then
      if entry.y < scroll then scroll=entry.y
      elseif entry.y + entry.height > scroll + viewport_height then
        scroll=entry.y + entry.height - viewport_height
      end
      return M.clamp_scroll(layout,scroll,viewport_height)
    end
  end
  return scroll
end
function M.hit(layout, x, y, scroll, viewport_width, viewport_height)
  if x < 0 or x > viewport_width or y < 0 or y >= viewport_height then return nil end
  local actual = y + (scroll or 0)
  for _,entry in ipairs(layout.entries) do
    if actual >= entry.y and actual < entry.y + entry.height then return entry.index end
  end
end
return M
