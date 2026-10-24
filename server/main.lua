-- Isolated, disposable diagnostic server. Not the historical Qeep backend.
package.path = 'client/lib/?.lua;' .. package.path
local protocol = require('protocol')
local ok, socket = pcall(require, 'socket')
if not ok then
  io.stderr:write('LuaSocket missing. Install: luarocks install luasocket\n')
  os.exit(1)
end
local host = (arg and arg[1]) or '127.0.0.1'
local port = tonumber((arg and arg[2]) or '5190')
assert(port and port >= 1 and port <= 65535, 'invalid port')
local labfile = assert(io.open('client/fixtures/lab.xml', 'rb'), 'start server from repository root')
local labxml = labfile:read('*a')
labfile:close()
local listener, e = socket.bind(host, port)
assert(listener, e)
listener:settimeout(1)
print(('Qeep Revival 2008 diagnostic server on %s:%d'):format(host, port))
print('No accounts, passwords or legacy domains are used.')
while true do
  local peer = listener:accept()
  if peer then
    peer:settimeout(3)
    local prefix, reason = peer:receive(4)
    if prefix then
      local n = prefix:byte(1) * 16777216 + prefix:byte(2) * 65536 + prefix:byte(3) * 256 + prefix:byte(4)
      if n > 0 and n <= protocol.MAX_FRAME then
        local bytes = peer:receive(n)
        if bytes then
          local success, req = pcall(protocol.decodeRequest, prefix .. bytes)
          if success then
            local ping = req.path == '/revival/ping'
            local page = req.path == '/revival/page/lab'
            local known = ping or page
            local reply = protocol.encodeReply('R', req.path,
              {ok = known and 'true' or 'false', server = 'Qeep-Revival-2008', version = 'phase-1'},
              ping and 'PONG' or (page and labxml or 'UNKNOWN TEST PATH'))
            peer:send(reply)
            print(req.kind, req.path, known and 'OK' or 'UNKNOWN')
          else
            io.stderr:write('Invalid synthetic packet: ' .. tostring(req) .. '\n')
          end
        end
      end
    elseif reason ~= 'closed' then
      io.stderr:write('Client read: ' .. tostring(reason) .. '\n')
    end
    peer:close()
  end
end
