-- Unit integration of concurrent, partial and stalled connections.
package.path='client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('protocol')
local looplib=require('tcp_loop')
local queue={}
local closed=0
local function client(initial,chunkSize)
  local c={incoming=initial or '',sent='',chunkSize=chunkSize or 9,timeout=0}
  function c:settimeout(t) assert(t==0) end
  function c:receive(n)
    if #self.incoming==0 then return nil,'timeout','' end
    local partial=self.incoming:sub(1,math.min(n,self.chunkSize))
    self.incoming=self.incoming:sub(#partial+1)
    return nil,'timeout',partial
  end
  function c:send(bytes,index)
    local last=math.min(#bytes,index+self.chunkSize-1)
    self.sent=self.sent..bytes:sub(index,last)
    if last<#bytes then return nil,'timeout',last end
    return last
  end
  function c:close() self.closed=true;closed=closed+1 end
  return c
end
local listener={}
function listener:settimeout(n) assert(n==0) end
function listener:accept() return table.remove(queue,1) end
function listener:close() end
local socket={}
function socket.select(readers,writers)
  return readers,writers
end
local routeCount=0
local loop=looplib.new(listener,socket,protocol,function(req)
  routeCount=routeCount+1
  return {ok=true,payload=req.path..':'..(req.properties.name or '')}
end)
local stalled=client(protocol.encodeRequest('O','/slow',{},''):sub(1,2))
local alice=client(protocol.encodeRequest('O','/fast',{name='Alice'},''),7)
local bob=client(protocol.encodeRequest('O','/fast',{name='Bob'},''),17)
queue={stalled,alice,bob}
for i=1,200 do looplib.step(loop,0.02) end
assert(alice.closed and bob.closed,'active peers must complete independently')
assert(not stalled.closed,'incomplete peer should not block the others')
assert(routeCount==2)
assert(protocol.decodeReply(alice.sent).payload=='/fast:Alice')
assert(protocol.decodeReply(bob.sent).payload=='/fast:Bob')
looplib.step(loop,9)
assert(stalled.closed,'idle peer must be timed out')
local malformed=client(string.char(255,255,255,255))
queue={malformed}
for i=1,5 do looplib.step(loop,0.02) end
assert(malformed.closed)
assert(routeCount==2,'malformed frame must never reach route')
local overflow={}
for i=1,65 do overflow[i]=client('') end
local surplus=overflow[65]
queue=overflow
looplib.step(loop,0.01)
-- After multiple ticks 64 clients are accepted, the excess must be closed.
for i=1,8 do looplib.step(loop,0.01) end
local active=0
for _ in pairs(loop.clients) do active=active+1 end
assert(active==64)
assert(surplus.closed)
looplib.close(loop)
assert(closed>=68)
print('OK: concurrent TCP state machine, partial IO, quotas and idle timeouts')
