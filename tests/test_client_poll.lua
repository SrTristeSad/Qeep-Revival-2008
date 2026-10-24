package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local social=require('social_routes')
local lab=require('lab_routes')
local jcl=require('lib.jcl')
local labxml=assert(io.open('client/fixtures/lab.xml','rb')):read('*a')
local b=social.handle({kind='P',path='/revival/social/join',properties={nickname='Bia',submitId='join'},payload=''})
local btoken=jcl.parse(b.payload).props.guestSession
local lastToken=nil
package.loaded.socket=nil
package.preload.socket=function() return {tcp=function()
 local c={count=0,async=false}
 function c:settimeout(n) self.async=(n==0) end
 function c:connect() return true end
 function c:send(bytes) self.req=protocol.decodeRequest(bytes);return #bytes end
 function c:receive()
  if not self.answer then
   local r
   if self.req.path:sub(1,16)=='/revival/social/' then r=social.handle(self.req)
   else r=lab.handle(self.req,labxml) end
   if self.req.path=='/revival/social/join' then lastToken=jcl.parse(r.payload).props.guestSession end
   self.answer=protocol.encodeReply('R',self.req.path,
    {ok=r.ok and 'true' or 'false',unchanged=r.unchanged and 'true' or 'false'},r.payload)
  end
  if not self.async then return self.answer end
  self.count=self.count+1
  if self.count==1 then return nil,'timeout',self.answer:sub(1,7) end
  return nil,'closed',self.answer:sub(8)
 end
 function c:close() end
 return c
end, select=function(_,write) return {},write end} end
local output={}
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
 newFont=function()return font end,getDimensions=function()return 480,640 end,
 printf=function(s)output[#output+1]=tostring(s) end},keyboard={setTextInput=noop},
 filesystem={read=function(path)
 if path=='host.txt' then return nil end
 local f=assert(io.open('client/'..path,'rb'));local data=f:read('*a');f:close();return data
 end,write=function()return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function shown(part)
 output={};love.draw()
 for _,value in ipairs(output) do if value:find(part,1,true) then return true end end
 return false
end
love.load()
for _=1,6 do love.keypressed('down') end
love.keypressed('return')
love.keypressed('down');love.keypressed('return');love.textinput('Alex');love.keypressed('return')
love.keypressed('down');love.keypressed('return')
assert(lastToken)
love.keypressed('return')
love.keypressed('return')
assert(shown('Conversa'))
local roster=jcl.parse(social.handle({kind='O',path='/revival/social/people',properties={session=btoken},payload=''}).payload)
local alexId
for _,item in ipairs(roster.forms[1].items) do if item.label=='Alex' then alexId=item.href:match('(%d+)$') end end
assert(alexId)
love.keypressed('return')
love.textinput('Meu rascunho')
assert(social.handle({kind='P',path='/revival/social/send/'..alexId,
 properties={session=btoken,submitId='send',message='Oi Alex!'},payload=''}).ok)
love.update(3.2);love.update(0.1);love.update(0.1)
assert(shown('Meu rascunho') and not shown('Bia: Oi Alex!'))
love.keypressed('return')
love.update(0.1)
assert(shown('Bia: Oi Alex!') and shown('Meu rascunho'))
love.update(3.2);love.update(0.1);love.update(0.1)
assert(shown('Meu rascunho'))
love.keypressed('down');love.keypressed('return')
assert(shown('Você: Meu rascunho'))
love.keypressed('escape')
assert(shown('Bia: Oi Alex!') and shown('Meu rascunho'))
print('OK: automatic refresh preserves drafts and navigation')
