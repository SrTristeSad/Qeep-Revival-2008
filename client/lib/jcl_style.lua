-- Presentation palette resolver for known registry.ini styles (s0...s13).
-- The source JAR confirms style identifiers/colours; the exact composition of
-- remote historical pages is not available. No arbitrary style expressions.
local theme = require('lib.legacy_palette')
local M = {}
local function rgb(code)
  if type(code) ~= 'string' or not code:match('^%x%x%x%x%x%x$') then return nil end
  return theme.hex(code)
end
function M.registry_style(value)
  if value == nil then return nil end
  local id = tostring(value):match('^s?(%d+)$')
  if not id then return nil end
  return theme.registry['s'..tostring(tonumber(id))]
end
function M.resolve(item, focused)
  local entry = M.registry_style(item and item.style)
  local colors = theme.colors
  local result = {
    surface = focused and colors.highlight or nil,
    border = focused and colors.purple or nil,
    text = colors.black,
    detail = colors.black,
    styleKnown = entry ~= nil
  }
  if entry then
    local surface = rgb(entry.cbg or entry.bg)
    local text = rgb(entry.tc)
    local border = rgb(entry.fr or entry.xc)
    if surface and not focused then result.surface = surface end
    if text then result.text = text; result.detail = text end
    if focused then result.border = rgb(entry.xc) or result.border
    elseif rgb(entry.fr) then result.border = rgb(entry.fr) end
  end
  return result
end
return M
