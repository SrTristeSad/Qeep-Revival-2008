-- Choice-group state grounded in s.class and the select branch of h.class.
-- Rendering and interaction remain a reconstructed approximation.
local M = {}
function M.kind(raw, count)
  if raw == nil or raw == '' then
    if count == 1 then return 2 end  -- one entry -> multiple group
    if count == 2 then return 1 end  -- two entries -> exclusive group
    return 4                            -- other counts -> compact group
  end
  local value = tonumber(raw)
  if value and value >= 1 and value <= 4 and value == math.floor(value) then return value end
  return 4 -- fail closed to compact mode for unrecognized values
end
function M.init(item, raw)
  local options = item.options or {}
  item.choiceType = M.kind(raw, #options)
  item.selectedSet = {}
  local first = nil
  for i, option in ipairs(options) do
    if option.selected then
      item.selectedSet[i] = true
      if not first then first = i end
    end
  end
  item.selected = first or (#options > 0 and 1 or 0)
  if item.choiceType ~= 2 and #options > 0 then
    item.selectedSet={}
    item.selectedSet[item.selected] = true
  end
  return item
end
function M.choose(item, index)
  if not item.options or not item.options[index] then return false end
  if item.choiceType == 2 then
    item.selectedSet = item.selectedSet or {}
    item.selectedSet[index] = not item.selectedSet[index] or nil
    item.selected = index
  else
    item.selected = index
    item.selectedSet = {[index]=true}
  end
  return true
end
function M.labels(item)
  local parts = {}
  if item.choiceType == 2 then
    for i, option in ipairs(item.options or {}) do
      if item.selectedSet and item.selectedSet[i] then parts[#parts+1] = option.label end
    end
  else
    local option = item.options and item.options[item.selected]
    if option then parts[#parts+1] = option.label end
  end
  return parts
end
function M.value(item)
  local parts = {}
  if item.choiceType == 2 then
    for i, option in ipairs(item.options or {}) do
      if item.selectedSet and item.selectedSet[i] then parts[#parts+1] = option.value or '' end
    end
  else
    local option = item.options and item.options[item.selected]
    if option then parts[1] = option.value or '' end
  end
  return table.concat(parts, ',')
end
function M.summary(item)
  local labels = M.labels(item)
  if #labels == 0 then return '[nenhuma opção marcada]' end
  return table.concat(labels, ', ')
end
return M
