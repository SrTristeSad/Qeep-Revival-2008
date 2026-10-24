-- UTF-8-safe input editing, without requiring Lua 5.3's utf8 standard module
-- (LÖVE 11.x includes LuaJIT / Lua 5.1 semantics).
local M = {}
local function lead_len(b)
  if b < 128 then return 1 end
  if b >= 194 and b <= 223 then return 2 end
  if b >= 224 and b <= 239 then return 3 end
  if b >= 240 and b <= 244 then return 4 end
  return 0
end
local function scan(s)
  local offsets = {}
  local i=1
  while i <= #s do
    local count=lead_len(s:byte(i))
    if count == 0 or i+count-1 > #s then return nil end
    for k=i+1,i+count-1 do
      local c=s:byte(k)
      if not c or c < 128 or c > 191 then return nil end
    end
    local cp=s:byte(i)
    if count==2 then cp=(cp-192)*64+s:byte(i+1)-128
    elseif count==3 then cp=(cp-224)*4096+(s:byte(i+1)-128)*64+s:byte(i+2)-128
    elseif count==4 then cp=(cp-240)*262144+(s:byte(i+1)-128)*4096+(s:byte(i+2)-128)*64+s:byte(i+3)-128 end
    if cp > 0x10ffff or (cp >= 0xd800 and cp <= 0xdfff) or (cp < 0x80 and count>1)
      or (cp<0x800 and count>2) or (cp<0x10000 and count>3) then return nil end
    offsets[#offsets+1]=i
    i=i+count
  end
  return offsets
end
function M.count(s)
  local offsets=scan(s)
  return offsets and #offsets or nil
end
function M.append(existing, added, max_chars)
  local before=scan(existing)
  local after=scan(added)
  if not before or not after then return existing end
  local permitted=math.max(0,(max_chars or 2000)-#before)
  if permitted <= 0 or #after==0 then return existing end
  if #after<=permitted then return existing..added end
  return existing..added:sub(1, after[permitted+1]-1)
end
function M.backspace(s)
  local offsets=scan(s)
  if not offsets or #offsets==0 then return s end
  return s:sub(1, offsets[#offsets]-1)
end
return M
