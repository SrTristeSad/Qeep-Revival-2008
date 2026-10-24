-- Full event-level laboratory navigation with an in-process fake socket.
-- This is not a real network test or historical Qeep screenshot test.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local routes=require('lab_routes')
local captured, calls, prints = {}, 0, {}
local source=assert(io.open('client/fixtures/lab.xml','rb')):read('*a')
package.loaded.socket=nil
package.preload.socket=function()
  return {tcp=function()
    local request
    return {
      settimeout=function() end,
      connect=function(_,host,port) assert(host=='127.0.0.1' and port==5190);return true end,
      send=function(_,bytes) request=protocol.decodeRequest(bytes);captured[#captured+1]=request;return #bytes end,
      receive=function(_,fmt)
        assert(fmt=='*a')
        local ans=routes.handle(request,source)
        return protocol.encodeReply('R',request.path,{ok=ans.ok and 'true' or 'false'},ans.payload)
      end,
      close=function() end
    }
  end}
end
local font={}
function font:getHeight() return 12 end
function font:getWrap(s,w)
  local lines={}
  local capacity=math.max(1,math.floor(w/7))
  for line in (tostring(s)..'\n'):gmatch('(.-)\n') do
    repeat lines[#lines+1]=line:sub(1,capacity);line=line:sub(capacity+1) until #line==0
  end
  return w,lines
end
local function noop() end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
  setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
  newFont=function() return font end,getDimensions=function() return 480,640 end,
  printf=function(s) prints[#prints+1]=tostring(s) end},
  keyboard={setTextInput=noop},
  filesystem={read=function(path)
    if path=='host.txt' then return nil end
    local file=assert(io.open('client/'..path,'rb'));local v=file:read('*a');file:close();return v
  end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function displayed(needle)
  prints={};love.draw()
  for _,value in ipairs(prints) do if value:find(needle,1,true) then return true end end
  return false
end
love.load()
love.keypressed('return') -- open local fixture
for _=1,3 do love.keypressed('down') end -- move to remote-form link
love.keypressed('return') -- remote request O
assert(displayed('Formulário remoto'))
assert(captured[1].path=='/revival/page/submit' and captured[1].kind=='O')
-- JCL starts on focused submit button: move to input by wrapping.
love.keypressed('down');love.keypressed('return')
love.textinput('Alex');love.keypressed('return')
love.keypressed('down');love.keypressed('return')
love.textinput(' texto');love.keypressed('return')
love.keypressed('down');love.keypressed('return')
love.keypressed('right') -- send from RSK (same submitId as active button)
assert(captured[2].kind=='P' and captured[2].path=='/revival/submit/echo')
assert(captured[2].properties.nickname=='Alex')
assert(captured[2].properties.message=='Olá! texto')
assert(captured[2].properties.choice=='two')
assert(captured[2].properties.submitId=='send')
assert(displayed('Resposta local'))
assert(displayed('Apelido: Alex'))
assert(displayed('Mensagem: Olá! texto'))
assert(#captured==2)
print('OK: 11 client/server-in-process interface checks')
