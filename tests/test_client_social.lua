-- Full client event and mock socket JCL social interaction.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local social=require('social_routes')
local laboratory=require('lab_routes')
local labxml=assert(io.open('client/fixtures/lab.xml','rb')):read('*a')
local bob=social.handle({kind='P',path='/revival/social/join',payload='',
 properties={nickname='Bia',submitId='join'}})
assert(bob.ok)
local sentReq={}
package.loaded.socket=nil
package.preload.socket=function() return {tcp=function()
  local request
  return {settimeout=function() end,
    connect=function(_,host,port) assert(host=='127.0.0.1' and port==5190);return true end,
    send=function(_,bytes) request=protocol.decodeRequest(bytes);sentReq[#sentReq+1]=request;return #bytes end,
    receive=function(_,fmt)
      assert(fmt=='*a')
      local r
      if request.path:sub(1,16)=='/revival/social/' then r=social.handle(request)
      else r=laboratory.handle(request,labxml) end
      return protocol.encodeReply('R',request.path,{ok=r.ok and 'true' or 'false'},r.payload)
    end,close=function() end}
end} end
local prints={}
local function noop() end
local font={getHeight=function() return 12 end}
function font:getWrap(s,w)
 local lines={};local cap=math.max(1,math.floor(w/7))
 for part in (tostring(s)..'\n'):gmatch('(.-)\n') do
  repeat lines[#lines+1]=part:sub(1,cap);part=part:sub(cap+1) until #part==0
 end
 return w,lines
end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
 setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
 newFont=function() return font end,getDimensions=function() return 480,640 end,
 printf=function(s) prints[#prints+1]=tostring(s) end},keyboard={setTextInput=noop},
 filesystem={read=function(path)
  if path=='host.txt' then return nil end
  local f=assert(io.open('client/'..path,'rb'));local s=f:read('*a');f:close();return s
 end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local checks=0
local function check(b) assert(b,'check '..checks+1);checks=checks+1 end
local function shown(part)
 prints={};love.draw()
 for _,t in ipairs(prints) do if t:find(part,1,true) then return true end end
 return false
end
love.load()
for _=1,6 do love.keypressed('down') end
love.keypressed('return')
check(shown('Visitantes'))
check(sentReq[#sentReq].path=='/revival/social/start')
for _=1,3 do love.keypressed('down') end -- join -> new account links -> nickname
love.keypressed('return');love.textinput('Alex');love.keypressed('return')
love.keypressed('down');love.keypressed('return') -- submit join
check(shown('Sala social'))
check(sentReq[#sentReq].kind=='P' and sentReq[#sentReq].properties.nickname=='Alex')
love.keypressed('return') -- people
check(shown('Pessoas online'))
love.keypressed('return') -- Bia
check(shown('Conversa'))
love.keypressed('return') -- first textarea
love.textinput('Olá, Bia!');love.keypressed('return')
love.keypressed('down');love.keypressed('return') -- send button
check(shown('Enviando mensagem')) -- non-blocking: not yet delivered
love.update(0.05)
check(sentReq[#sentReq].path:find('/revival/social/send/',1,true))
check(sentReq[#sentReq].properties.message=='Olá, Bia!')
check(shown('Você: Olá, Bia!'))
love.keypressed('escape') -- recover message editor with history
check(shown('Conversa'))
print(('OK: %d client social event checks'):format(checks))
