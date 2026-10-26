-- Isolated, disposable diagnostic server. Not the historical Qeep backend.
package.path = 'client/lib/?.lua;' .. package.path
local protocol = require('protocol')
package.path = 'server/lib/?.lua;' .. package.path
local routes = require('lab_routes')
local social = require('social_routes')
local account_store = require('account_store')
local db,dbErr=account_store.new('server/data/accounts.db')
assert(db, 'Account storage unavailable: '..tostring(dbErr))
social.configure_accounts(db)
local social_store=require('social_store')
local durable,socialErr=social_store.new('server/data/social.db')
assert(durable,'Social storage unavailable: '..tostring(socialErr))
social.configure_social(durable)
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
local tcp_loop=require('tcp_loop')
local listener, e = socket.bind(host, port)
assert(listener, e)
-- Opt-in route-name-only trace for local emulator CI (no user data).
-- Enabled only on loopback; never log request properties or message payloads.
local route_trace_path=host=='127.0.0.1' and os.getenv('QEEP_ROUTE_TRACE') or nil
local route_trace=route_trace_path and assert(io.open(route_trace_path,'a')) or nil
local function route(req)
  if route_trace and type(req.path)=='string' and #req.path<=180 then
    route_trace:write(req.path,'\n')
    route_trace:flush()
  end
  if req.path:sub(1,16)=='/revival/social/' then return social.handle(req) end
  return routes.handle(req,labxml)
end
local loop=tcp_loop.new(listener,socket,protocol,route)
print(('Qeep Revival 2008 diagnostic server on %s:%d'):format(host, port))
print('Local laboratory only: persistent access-code accounts; registered contacts and messages persisted; guest messages ephemeral; NO TLS.')
if host ~= '127.0.0.1' and host ~= 'localhost' then
  io.stderr:write('WARNING: access codes cross TCP in plaintext. DO NOT expose this service to untrusted networks.\n')
end
local last=socket.gettime()
while true do
  local current=socket.gettime()
  tcp_loop.step(loop,math.min(math.max(current-last,0),1))
  last=current
  socket.sleep(0.01)
end
