-- End-to-end mock of LÖVE client account login, contacts and persisted chat.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local social=require('social_routes')
local account=require('account_store')
local socialStore=require('social_store')
local jcl=require('lib.jcl')
local accountPath='server/data/phase13_client_accounts.db'
local socialPath='server/data/phase13_client_contacts.db'
for _,p in ipairs({accountPath,socialPath}) do os.remove(p);os.remove(p..'.tmp') end
local accounts=assert(account.new(accountPath))
local secretAlice=assert(account.register(accounts,'alice'))
assert(account.register(accounts,'beatriz'))
local db=assert(socialStore.new(socialPath))
assert(socialStore.request(db,'alice','beatriz'))
assert(socialStore.answer(db,'beatriz','alice',true))
social.configure_accounts(accounts);social.configure_social(db)
local calls={}
package.loaded.socket=nil
package.preload.socket=function() return {
  tcp=function()
    local request
    return {settimeout=function()end,connect=function()return true end,
      send=function(_,s) request=protocol.decodeRequest(s);calls[#calls+1]=request;return #s end,
      receive=function()
        local reply=social.handle(request)
        return protocol.encodeReply('R',request.path,
          {ok=reply.ok and 'true' or 'false', unchanged=reply.unchanged and 'true' or 'false'},reply.payload)
      end,close=function()end}
  end,
  select=function(_,write) return {},write end
} end
local screen={};local function noop() end
local font={getHeight=function() return 12 end}
function font:getWrap(str,width)
  local lines={};local cap=math.max(1,math.floor(width/7))
  for part in (tostring(str)..'\n'):gmatch('(.-)\n') do
    repeat lines[#lines+1]=part:sub(1,cap);part=part:sub(cap+1) until #part==0
  end
  return width,lines
end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
 setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
 newFont=function() return font end,getDimensions=function()return 480,640 end,
 printf=function(s)screen[#screen+1]=tostring(s)end},keyboard={setTextInput=noop},
 filesystem={read=function(path)
   if path=='host.txt' then return nil end
   local f=assert(io.open('client/'..path,'rb'));local v=f:read('*a');f:close();return v
 end,write=function()return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function shown(s)
 screen={};love.draw()
 for _,v in ipairs(screen) do if v:find(s,1,true) then return true end end
 return false
end
love.load()
for _=1,6 do love.keypressed('down') end
love.keypressed('return') -- open social welcome
assert(shown('Visitantes'))
love.keypressed('down');love.keypressed('down') -- login from focused visitor button
love.keypressed('return')
assert(shown('Entrar na conta'))
love.keypressed('return');love.textinput('alice');love.keypressed('return')
love.keypressed('down');love.keypressed('return');love.textinput(secretAlice);love.keypressed('return')
love.keypressed('down');love.keypressed('return')
assert(shown('Sala social'),'login must open home')
love.keypressed('down');love.keypressed('return') -- contacts link
assert(shown('Contatos'))
local hasContact=false
for _=1,12 do
  if shown('beatriz') then hasContact=true end
  love.keypressed('down')
end
assert(hasContact)
-- Find an account chat by using the visible selectable links, without private access to main.lua.
-- The last request remains a contact page until activating the exact link.
local clicked=false
for _=1,15 do
  love.keypressed('return')
  if calls[#calls].path=='/revival/social/account/chat/beatriz' then clicked=true;break end
  if shown('Conversa') then error('unexpected conversation') end
  love.keypressed('escape')
  love.keypressed('down')
end
assert(clicked,'client should navigate to approved contact')
assert(shown('Conversa'))
love.keypressed('return');love.textinput('Mensagem persistente');love.keypressed('return')
love.keypressed('down');love.keypressed('return')
assert(shown('Enviando mensagem'))
love.update(0.1)
assert(shown('Você: Mensagem persistente'))
assert(calls[#calls].path=='/revival/social/account/send/beatriz')
assert(assert(socialStore.thread(db,'alice','beatriz'))[1].text=='Mensagem persistente')
for _,p in ipairs({accountPath,socialPath}) do os.remove(p);os.remove(p..'.tmp') end
print('OK: client account login -> contacts -> asynchronous persisted chat')
