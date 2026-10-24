-- Qeep Revival 2008: transport test codec, based on static inspection of w.class.
-- Synthetic packets ONLY; historical interoperability has not been demonstrated.
local M = {}
local MAX_FRAME = 1024 * 1024

local function err(message) error('protocol: ' .. message, 2) end
local function chr(...) return string.char(...) end
local function u16(n)
  if n < 0 or n > 65535 then err('u16 out of range') end
  return chr(math.floor(n / 256), n % 256)
end
local function u32(n)
  if n < 0 or n > 4294967295 then err('u32 out of range') end
  return chr(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256, n % 256)
end
local function readnum(data, pos, width)
  if pos + width - 1 > #data then err('truncated integer') end
  local v = 0
  for i = 0, width - 1 do v = v * 256 + data:byte(pos + i) end
  return v, pos + width
end
local function utf8_codepoints(s)
  local result, i = {}, 1
  while i <= #s do
    local c = s:byte(i)
    local n, cp
    if c < 128 then n, cp = 1, c
    elseif c >= 194 and c <= 223 then n, cp = 2, c - 192
    elseif c >= 224 and c <= 239 then n, cp = 3, c - 224
    elseif c >= 240 and c <= 244 then n, cp = 4, c - 240
    else err('invalid UTF-8 prefix') end
    for j = 1, n - 1 do
      local d = s:byte(i + j)
      if not d or d < 128 or d > 191 then err('invalid UTF-8 continuation') end
      cp = cp * 64 + d - 128
    end
    if (n == 2 and cp < 128) or (n == 3 and cp < 2048)
       or (n == 4 and cp < 65536) or cp > 1114111
       or (cp >= 55296 and cp <= 57343) then err('invalid Unicode scalar') end
    result[#result + 1] = cp
    i = i + n
  end
  return result
end
local function encode_unit(u)
  if u == 0 then return '\192\128' end
  if u < 128 then return chr(u) end
  if u < 2048 then return chr(192 + math.floor(u / 64), 128 + u % 64) end
  return chr(224 + math.floor(u / 4096), 128 + math.floor(u / 64) % 64, 128 + u % 64)
end
local function utf(s)
  local out = {}
  for _, cp in ipairs(utf8_codepoints(s)) do
    if cp <= 65535 then out[#out + 1] = encode_unit(cp)
    else
      local x = cp - 65536
      out[#out + 1] = encode_unit(55296 + math.floor(x / 1024))
      out[#out + 1] = encode_unit(56320 + x % 1024)
    end
  end
  local payload = table.concat(out)
  if #payload > 65535 then err('writeUTF length overflow') end
  return u16(#payload) .. payload
end
local function utf8_scalar(cp)
  if cp < 128 then return chr(cp) end
  if cp < 2048 then return chr(192 + math.floor(cp / 64), 128 + cp % 64) end
  if cp < 65536 then return chr(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64) end
  return chr(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64,
    128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end
local function readutf(data, pos)
  local size
  size, pos = readnum(data, pos, 2)
  local stop = pos + size
  if stop - 1 > #data then err('truncated UTF value') end
  local units = {}
  while pos < stop do
    local c = data:byte(pos)
    local u
    if c > 0 and c < 128 then u = c; pos = pos + 1
    elseif c >= 192 and c <= 223 and pos + 1 < stop then
      local b = data:byte(pos + 1)
      if b < 128 or b > 191 then err('bad modified UTF-8') end
      u = (c - 192) * 64 + b - 128
      if u == 0 and c ~= 192 then err('bad modified NUL') end
      pos = pos + 2
    elseif c >= 224 and c <= 239 and pos + 2 < stop then
      local b, d = data:byte(pos + 1, pos + 2)
      if b < 128 or b > 191 or d < 128 or d > 191 then err('bad modified UTF-8') end
      u = (c - 224) * 4096 + (b - 128) * 64 + d - 128
      pos = pos + 3
    else err('bad modified UTF-8 prefix') end
    units[#units + 1] = u
  end
  local out, i = {}, 1
  while i <= #units do
    local cp = units[i]
    if cp >= 55296 and cp <= 56319 then
      local lo = units[i + 1]
      if not lo or lo < 56320 or lo > 57343 then err('invalid surrogate pair') end
      cp = 65536 + (cp - 55296) * 1024 + lo - 56320
      i = i + 1
    elseif cp >= 56320 and cp <= 57343 then err('orphan low surrogate') end
    out[#out + 1] = utf8_scalar(cp)
    i = i + 1
  end
  return table.concat(out), pos
end
local function body(kind, path, props, payload)
  if type(kind) ~= 'string' or #kind ~= 1 then err('type must be a single byte') end
  if type(path) ~= 'string' or type(payload) ~= 'string' then err('invalid path or payload') end
  local entries, count = {}, 0
  for k, v in pairs(props or {}) do
    if type(k) ~= 'string' or type(v) ~= 'string' then err('properties must be strings') end
    count = count + 1
    if count > 128 then err('too many properties') end
    entries[#entries + 1] = utf(k) .. utf(v)
  end
  local encoded = kind .. utf(path) .. u32(count) .. table.concat(entries) .. u32(#payload) .. payload
  if #encoded > MAX_FRAME then err('packet too large') end
  return encoded
end
local function parsebody(data)
  if #data < 1 or #data > MAX_FRAME then err('invalid frame size') end
  local kind, pos = data:sub(1, 1), 2
  local path; path, pos = readutf(data, pos)
  local count; count, pos = readnum(data, pos, 4)
  if count > 128 then err('invalid property count') end
  local props = {}
  for _ = 1, count do
    local k, v
    k, pos = readutf(data, pos)
    v, pos = readutf(data, pos)
    props[k] = v
  end
  local size; size, pos = readnum(data, pos, 4)
  if size ~= #data - pos + 1 then err('attachment length mismatch') end
  return {kind = kind, path = path, properties = props, payload = data:sub(pos)}
end
function M.encodeRequest(kind, path, props, payload)
  local encoded = body(kind, path, props, payload or '')
  return u32(#encoded) .. encoded
end
function M.decodeRequest(data)
  local size, pos = readnum(data, 1, 4)
  if size > MAX_FRAME or size ~= #data - 4 then err('frame length mismatch') end
  return parsebody(data:sub(pos))
end
function M.encodeReply(kind, path, props, payload)
  -- Unencrypted reply structure observed in J2ME reader: no leading length.
  return body(kind, path, props, payload or '')
end
function M.decodeReply(data)
  if data == '.' or data == 'C' then return {kind = data, path = '', properties = {}, payload = ''} end
  return parsebody(data)
end
M.MAX_FRAME = MAX_FRAME
return M
