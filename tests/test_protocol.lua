package.path = 'client/lib/?.lua;' .. package.path
local p = require('protocol')
local n = 0
local function eq(a, b)
  assert(a == b, tostring(a) .. ' ~= ' .. tostring(b))
  n = n + 1
end
local input = {lang = 'pt-BR', note = 'ação 😀', nilbyte = 'a\0b'}
local raw = p.encodeRequest('O', '/navigation/init/', input, 'payload\0')
local pkt = p.decodeRequest(raw)
eq(pkt.kind, 'O')
eq(pkt.path, '/navigation/init/')
eq(pkt.properties.lang, input.lang)
eq(pkt.properties.note, input.note)
eq(pkt.properties.nilbyte, input.nilbyte)
eq(pkt.payload, 'payload\0')
local response = p.decodeReply(p.encodeReply('R', '/revival/ping', {ok = 'true'}, 'PONG'))
eq(response.kind, 'R')
eq(response.path, '/revival/ping')
eq(response.properties.ok, 'true')
eq(response.payload, 'PONG')
eq(p.decodeReply('.').kind, '.')
local valid = pcall(p.decodeRequest, raw:sub(1,-2))
eq(valid, false)
local long = pcall(p.encodeRequest, 'O', string.rep('x', 65536), {}, '')
eq(long, false)
print(('OK: %d Lua protocol checks'):format(n))
