-- Pure JCL list layout model. Geometry is deliberately not presented as a
-- historical pixel-perfect reproduction of the obfuscated Java ME renderer.
local M = {}
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
      local detail
      if kind == 'input' or kind == 'textarea' then
        detail = tostring(item.value or '')
      elseif kind == 'select' then
        local option = item.options and item.options[item.selected or 1]
        detail = (option and option.label or '[sem opções]') .. '  >'
      elseif kind == 'img' then
        detail = '[recurso de imagem não carregado]'
      elseif kind == 'gauge' then
        detail = tostring(item.value or 0) .. '/' .. tostring(item.max or 100)
      end
      local height
      if kind == 'hr' then height = 12
      else
        local text_height = wrap(font, title, width - 16) * line_height
        if detail then text_height = text_height + wrap(font, detail, width - 18) * line_height + 2 end
        height = text_height + 10
        if kind == 'input' then height = math.max(height, 43)
        elseif kind == 'textarea' then height = math.max(height, 58)
        elseif kind == 'select' then height = math.max(height, 43)
        elseif kind == 'gauge' then height = height + 10
        elseif kind == 'img' then height = math.max(height, 44) end
      end
      local entry = {index=index, item=item, title=title, detail=detail, y=y, height=height, lineHeight=line_height}
      result.entries[#result.entries + 1] = entry
      y = y + height + 3
    end
  end
  result.total = math.max(0,y-3)
  return result
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
