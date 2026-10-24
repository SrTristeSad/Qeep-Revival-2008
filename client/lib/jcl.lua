-- Bounded offline reader for the JCL XML subset identified in h.class.
-- It is NOT a complete implementation of the historical Java ME renderer.
local M = {}
local choices = require('lib.jcl_choices')
local MAX_BYTES, MAX_DEPTH, MAX_NODES = 262144, 32, 512
local function fail(message) error('jcl: ' .. message, 0) end
local function unicode(cp)
  if not cp or cp < 1 or cp > 0x10ffff or (cp >= 0xd800 and cp <= 0xdfff) then fail('invalid XML character reference') end
  if cp < 128 then return string.char(cp) end
  if cp < 2048 then return string.char(192 + math.floor(cp/64), 128 + cp%64) end
  if cp < 65536 then return string.char(224 + math.floor(cp/4096),128 + math.floor(cp/64)%64,128 + cp%64) end
  return string.char(240 + math.floor(cp/262144),128 + math.floor(cp/4096)%64,128 + math.floor(cp/64)%64,128 + cp%64)
end
local entities = {amp='&', lt='<', gt='>', quot='"', apos="'"}
local function decode(s)
  -- Bare ampersands must not silently turn malformed XML into page text.
  if s:gsub('&[^;]*;', ''):find('&', 1, true) then fail('unterminated XML entity') end
  return (s:gsub('&([^;]+);', function(entity)
    if entities[entity] then return entities[entity] end
    local n = entity:match('^#([0-9]+)$')
    if n then return unicode(tonumber(n)) end
    n = entity:match('^#[xX]([0-9a-fA-F]+)$')
    if n then return unicode(tonumber(n, 16)) end
    fail('unknown entity &' .. entity .. ';')
  end))
end
local function parse_xml(source)
  if type(source) ~= 'string' or #source > MAX_BYTES then fail('source too large or not text') end
  local root, stack, count, at = nil, {}, 0, 1
  local function append_text(value)
    if #stack == 0 then
      if value:match('%S') then fail('text outside root') end
      return
    end
    local item = stack[#stack]
    local part = decode(value)
    item.text = item.text .. part
    item.parts[#item.parts + 1] = part
  end
  while at <= #source do
    local a = source:find('<', at, true)
    if not a then append_text(source:sub(at)); break end
    append_text(source:sub(at, a - 1))
    if source:sub(a, a + 3) == '<!--' then
      local b = source:find('-->', a + 4, true)
      if not b then fail('unclosed comment') end
      at = b + 3
    elseif source:sub(a, a + 8) == '<![CDATA[' then
      local b = source:find(']]>', a + 9, true)
      if not b then fail('unclosed CDATA') end
      if #stack == 0 then fail('CDATA outside root') end
      local item = stack[#stack]
      local part = source:sub(a + 9, b - 1)
      item.text = item.text .. part
      item.parts[#item.parts + 1] = part
      at = b + 3
    elseif source:sub(a, a + 1) == '<?' then
      local b = source:find('?>', a + 2, true)
      if not b then fail('unclosed declaration') end
      at = b + 2
    elseif source:sub(a, a + 1) == '<!' then
      fail('DOCTYPE and external entities are not supported')
    elseif source:sub(a, a + 1) == '</' then
      local b = source:find('>', a + 2, true)
      if not b then fail('unclosed closing tag') end
      local name = source:sub(a + 2, b - 1):match('^%s*([%w_:%-%.]+)%s*$')
      if not name or #stack == 0 or stack[#stack].tag ~= name then fail('mismatched closing tag') end
      table.remove(stack)
      at = b + 1
    else
      local i, quote = a + 1, nil
      while i <= #source do
        local c = source:sub(i, i)
        if quote then if c == quote then quote = nil end
        elseif c == '"' or c == "'" then quote = c
        elseif c == '>' then break end
        i = i + 1
      end
      if i > #source then fail('unclosed start tag') end
      local inside = source:sub(a + 1, i - 1)
      local self_close = inside:match('/%s*$') ~= nil
      if self_close then inside = inside:gsub('/%s*$', '') end
      local tag, rest = inside:match('^%s*([%a_][%w_:%-%.]*)(.*)$')
      if not tag then fail('invalid start tag') end
      local attrs, pos = {}, 1
      while pos <= #rest do
        local ws = rest:sub(pos):match('^%s*')
        pos = pos + #ws
        if pos > #rest then break end
        local key, tail = rest:sub(pos):match('^([%a_][%w_:%-%.]*)(.*)$')
        if not key then fail('invalid attribute name') end
        pos = #rest - #tail + 1
        ws = rest:sub(pos):match('^%s*'); pos = pos + #ws
        if rest:sub(pos, pos) ~= '=' then fail('attribute missing equals') end
        pos = pos + 1
        ws = rest:sub(pos):match('^%s*'); pos = pos + #ws
        local q = rest:sub(pos, pos)
        if q ~= '"' and q ~= "'" then fail('attribute must be quoted') end
        local last = rest:find(q, pos + 1, true)
        if not last then fail('unclosed attribute') end
        if attrs[key] ~= nil then fail('duplicate attribute') end
        attrs[key] = decode(rest:sub(pos + 1, last - 1))
        pos = last + 1
      end
      count = count + 1
      if count > MAX_NODES then fail('too many nodes') end
      local node = {tag = tag, attrs = attrs, children = {}, parts = {}, text = ''}
      if #stack > 0 then
        local parent = stack[#stack]
        parent.children[#parent.children + 1] = node
        parent.parts[#parent.parts + 1] = node
      elseif root then fail('multiple root elements')
      else root = node end
      if not self_close then
        if #stack >= MAX_DEPTH then fail('too deeply nested') end
        stack[#stack + 1] = node
      end
      at = i + 1
    end
  end
  if #stack ~= 0 then fail('unclosed element') end
  if not root or root.tag ~= 'jcl' then fail('expected <jcl> root') end
  return root
end
local function all_text(node)
  local content = {}
  for _, part in ipairs(node.parts) do
    content[#content + 1] = type(part) == 'table' and all_text(part) or part
  end
  return table.concat(content)
end
local function items_from(node, out)
  local tag, a = node.tag, node.attrs
  if tag == 'layout' or tag == 'ul' or tag == 'ol' or tag == 'div' then
    for _, child in ipairs(node.children) do items_from(child, out) end
    return
  end
  local included = {p=true, a=true, li=true, button=true, hr=true, img=true,
    input=true, textarea=true, select=true, gauge=true, lsk=true, rsk=true, calc=true}
  if not included[tag] then return end
  local child_text = all_text(node)
  local label = a.label or a.clabel or child_text
  local item = {kind = tag, id = a.id, label = label,
    href = a.href, cancel = a.cancel == 'true' or (a.cancel == nil and tag == 'lsk'),
    style = a.style, focus = a.focus, focused = a.focused == 'true',
    layout = a.layout, align = tonumber(a.align), flags = tonumber(a.flags) or 0}
  -- h.class gives text-link/list widgets these symbols if their label is absent.
  if a.label == nil and a.clabel == nil then
    if tag == 'a' then item.marker = '>'
    elseif tag == 'li' then item.marker = '*' end
  end
  if tag == 'hr' then
    -- h.class sets ac.G to 90 for <hr>, overridden by the integer w attribute.
    item.width = math.max(1,math.min(math.floor(tonumber(a.w) or 90),2000))
  end
  if tag == 'input' or tag == 'textarea' then
    item.value = (tag == 'input' and a.value or all_text(node)) or ''
    item.secret = a.secret == 'true' -- laboratory-only masked field extension
    item.length = math.max(0, math.min(tonumber(a.len) or (tag == 'input' and 30 or 2000), 2000))
    item.type = tonumber(a.type) or 0
    item.mode = tonumber(a.mode) or 0
  elseif tag == 'select' then
    item.options = {}
    item.selected = 1
    for _, opt in ipairs(node.children) do
      if opt.tag == 'option' then
        local oa = opt.attrs
        item.options[#item.options + 1] = {label = oa.label or all_text(opt),
          value = oa.value or all_text(opt), selected = oa.selected == 'true'}
      end
    end
    choices.init(item, a.type)
  elseif tag == 'gauge' then
    item.value = tonumber(a.value) or 0
    item.max = tonumber(a.max) or 100
  elseif tag == 'img' then item.src = a.src
  end
  out[#out + 1] = item
end
function M.parse(source)
  local root = parse_xml(source)
  local doc = {base=root.attrs.base, branding=root.attrs.branding, timeout=root.attrs.timeout,
    forms={}, props={}, unsupported={}}
  for _, child in ipairs(root.children) do
    if child.tag == 'form' then
      local form = {id=child.attrs.id, title=child.attrs.title or '',
        valign=child.attrs.valign, items={}}
      for _, sub in ipairs(child.children) do items_from(sub, form.items) end
      doc.forms[#doc.forms + 1] = form
    elseif child.tag == 'prop' and child.attrs.n then
      doc.props[child.attrs.n] = child.attrs.v or ''
    else doc.unsupported[#doc.unsupported + 1] = child.tag end
  end
  if #doc.forms == 0 then fail('no form in JCL document') end
  return doc
end
return M
