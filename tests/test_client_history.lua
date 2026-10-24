-- Event-level navigation and failed-request recovery with mocked network.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local routes=require('lab_routes')
local file=assert(io.open('client/fixtures/lab.xml','rb'))
local labxml=file:read('*a');file:close()
local failure=false
local requests={}
package.loaded.socket=nil
package.preload.socket=function()
  return {tcp=function()
    local req
    return {settimeout=function() end,connect=function() return true end,
      send=function(_,bytes) req=protocol.decodeRequest(bytes);requests[#requests+1]=req;return #bytes end,
      receive=function()
        if failure then return nil,'closed','not a valid response' end
        local result=routes.handle(req,labxml)
        return protocol.encodeReply('R',req.path,{ok=result.ok and 'true' or 'false'},result.payload)
      end,close=function() end}
  end}
end
local text_calls={}
local noop=function() end
local font={getHeight=function() return 12 end}
function font:getWrap(s,width)
  local lines={}
  local n=math.max(1,math.floor(width/7))
  for line in (tostring(s)..'\n'):gmatch('(.-)\n') do
    repeat lines[#lines+1]=line:sub(1,n);line=line:sub(n+1) until #line==0
  end
  return width,lines
end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
  setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
  newFont=function() return font end,getDimensions=function() return 480,640 end,
  printf=function(s) text_calls[#text_calls+1]=tostring(s) end},
  keyboard={setTextInput=noop},filesystem={read=function(path)
    if path=='host.txt' then return nil end
    local f=assert(io.open('client/'..path,'rb'));local data=f:read('*a');f:close();return data
  end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local checks=0
local function displayed(part)
  text_calls={};love.draw()
  for _,s in ipairs(text_calls) do if s:find(part,1,true) then return true end end
  return false
end
local function check(condition,msg) assert(condition,msg);checks=checks+1 end
love.load()
check(displayed('Laboratorio'),'menu exists')
love.keypressed('5') -- J2ME-like numerical select
check(displayed('JCL - Laboratório'),'offline opens')
love.keypressed('5') -- initial focused action opens #fields
check(displayed('Campos JCL'),'inner form')
love.keypressed('escape')
check(displayed('JCL - Laboratório'),'back returns form instead of menu')
love.keypressed('5')
check(displayed('Campos JCL'),'forward again works')
love.keypressed('0')
check(displayed('JCL - Laboratório'),'numeric back works')
-- Go to remote-form link (the fourth actionable element on index).
for _=1,3 do love.keypressed('down') end
love.keypressed('return')
check(displayed('Formulário remoto'),'server form')
check(#requests==1 and requests[1].path=='/revival/page/submit','remote request')
-- The server form starts with a focused Send button, cycle to input.
love.keypressed('down')
love.keypressed('return')
love.textinput('amigo')
love.keypressed('return')
love.keypressed('right')
check(displayed('Resposta local'),'submit response')
check(requests[#requests].kind=='P','submitted POST-like message')
love.keypressed('escape')
check(displayed('Formulário remoto'),'back to typed form')
check(displayed('amigo'),'kept form data')
love.keypressed('escape')
check(displayed('JCL - Laboratório'),'back to index')
-- Simulated server failure must not discard the source document.
failure=true
love.keypressed('return') -- selected remote link remains focused
check(displayed('Falha no servidor'),'error shown')
love.keypressed('escape')
check(displayed('JCL - Laboratório'),'dismiss error returns to prior form')
love.keypressed('escape')
check(displayed('Laboratorio'),'final back exits to menu')
print(('OK: %d client JCL navigation history checks'):format(checks))
