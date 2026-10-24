-- Verify automatic chat refresh never clobbers drafts or creates Back-stack entries.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local social=require('social_routes')
local lab=require('lab_routes')
local jcl=require('lib.jcl')
local labxml=assert(io.open('client/fixtures/lab.xml','rb')):read('*a')
local b=social.handle({kind='P',path='/revival/social/join',properties={nickname='Bia',submitId='join'},payload=''})
local btoken=jcl.parse(b.payload).props.guestSession
local lastToken=nil
local connections={}
package.loaded.socket=nil
package.preload.socket=function() return {tcp=function()
 local self={request=nil,chunk=0,async=false}
 connections[#connections+1]=self
 function self:settimeout(n) self.async=(n==0) end
 function self:connect() return true end
 function self:send(bytes,index)
   self.request=protocol.decodeRequest(bytes)
   return #bytes
 end
 function self:receive(fmt)
   assert(fmt=='*a')
   if not self.response then
     local req=self.request
     local r
     if req.path:sub(1,16)=='/revival/social/' then r=social.handle(req)
     else r=lab.handle(req,labxml) end
     if req.path=='/revival/social/join' then lastToken=jcl.parse(r.payload).props.guestSession end
     self.response=protocol.encodeReply('R',req.path,
       {ok=r.ok and 'true' or 'false',unchanged=r.unchanged and 'true' or 'false'},r.payload)
   end
   if not self.async then return self.response end
   self.chunk=self.chunk+1
   if self.chunk==1 then return nil,'timeout',self.response:sub(1,7) end
   return nil,'closed',self.response:sub(8)
 end
 function self:close() self.closed=true end
 return self
end,
select=function(_,write) return {},write end} end
local output={}
local function noop() end
local font={getHeight=function()return 12 end}
function font:getWrap(s,w)
 local lines={};local cap=math.max(1,math.floor(w/7))
 for part in (tostring(s)..'\n'):gmatch('(.-)\n') do
  repeat lines[#lines+1]=part:sub(1,cap);part=part:sub(cap+1) until #part==0
 end
 return w,lines
end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
newFont=function()return font end,getDimensions=function()return 480,640 end,
printf=function(s) output[#output+1]=tostring(s) end},keyboard={setTextInput=noop},
filesystem={read=function(path) if path=='host.txt' then return nil end
 local f=assert(io.open('client/'..path,'rb'));local s=f:read('*a');f:close();return s end,
write=function()return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function shown(s)
 output={};love.draw()
 for _,v in ipairs(output) do if v:find(s,1,true) then return true end end
 return false
end
love.load()
for _=1,6 do love.keypressed('down') end
love.keypressed('return') -- start
love.keypressed('down');love.keypressed('return');love.textinput('Alex');love.keypressed('return')
love.keypressed('down');love.keypressed('return') -- join
assert(lastToken)
love.keypressed('return') -- people
love.keypressed('return') -- Bia
assert(shown('Conversa'))
local roster=jcl.parse(social.handle({kind='O',path='/revival/social/people',properties={session=btoken},payload=''}).payload)
local alexId
for _,item in ipairs(roster.forms[1].items) do if item.label=='Alex' then alexId=item.href:match('(%d+)$') end end
assert(alexId)
love.keypressed('return') -- editor
love.textinput('Meu rascunho')
local sent=social.handle({kind='P',path='/revival/social/send/'..alexId,
 properties={session=btoken,submitId='send',message='Oi Alex!'},payload=''})
assert(sent.ok)
love.update(3.2)
love.update(0.1)
love.update(0.1)
assert(shown('Meu rascunho'))
assert(not shown('Bia: Oi Alex!')) -- deferred while typing
love.keypressed('return') -- finish composing
love.update(0.1)
assert(shown('Bia: Oi Alex!'))
assert(shown('Meu rascunho'))
love.update(3.2);love.update(0.1);love.update(0.1)
assert(shown('Meu rascunho')) -- unchanged revision leaves draft intact
love.keypressed('down');love.keypressed('return') -- send draft
assert(shown('Enviando mensagem'))
love.update(0.1);love.update(0.1)
assert(shown('Você: Meu rascunho'))
love.keypressed('escape') -- only manual send makes a Back-stack entry
assert(shown('Bia: Oi Alex!'))
assert(shown('Meu rascunho'))
print('OK: live chat refresh, draft preservation and unchanged history')
