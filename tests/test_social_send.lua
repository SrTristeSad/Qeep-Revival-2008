-- Fragmented async chat send; never duplicates message on retries or failed receive.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local send=require('lib.social_send')
local social=require('social_routes')
local jcl=require('lib.jcl')
local function join(name)
  return jcl.parse(social.handle({kind='P',path='/revival/social/join',
    properties={nickname=name,submitId='join'},payload=''}).payload).props.guestSession
end
local token=join('Emilia')
local receiver=join('Sofia')
local roster=jcl.parse(social.handle({kind='O',path='/revival/social/people',
 properties={session=token},payload=''}).payload)
local peer
for _,i in ipairs(roster.forms[1].items) do
  if i.label=='Sofia' then peer=i.href:match('(%d+)$') end
end
assert(peer)
local count,closed=0,0
local mock={}
function mock.tcp()
  local self={sent='',partial=false,readCount=0}
  function self:settimeout(t) assert(t==0) end
  function self:connect() return nil,'timeout' end
  function self:getpeername() return '127.0.0.1',5190 end
  function self:send(request,first)
    local last=math.min(#request,first+9)
    self.sent=self.sent..request:sub(first,last)
    if last<#request then return nil,'timeout',last end
    return last
  end
  function self:receive()
    if not self.reply then
      local req=protocol.decodeRequest(self.sent)
      count=count+1
      local r=social.handle(req)
      self.reply=protocol.encodeReply('R',req.path,{ok=r.ok and 'true' or 'false'},r.payload)
    end
    self.readCount=self.readCount+1
    if self.readCount==1 then return nil,'timeout',self.reply:sub(1,10) end
    return nil,'closed',self.reply:sub(11)
  end
  function self:close() closed=closed+1 end
  return self
end
function mock.select(_,w) return {},w end
assert(not send.start(mock,protocol,'127.0.0.1',5190,token,peer,{message=''}))
local job=assert(send.start(mock,protocol,'127.0.0.1',5190,token,peer,
  {submitId='send',message='Olá, Sofia 😊'}))
local result
for i=1,100 do
  result=send.step(job,0.01)
  if result then break end
end
assert(result and result.ok)
assert(count==1,'request must reach the route exactly once')
assert(jcl.parse(result.payload).forms[1].id=='chat')
assert(send.step(job,0.1).ok==false,'completed job must not resend')
local chat=social.handle({kind='O',path='/revival/social/chat/'..peer,
  properties={session=token},payload=''})
assert(chat.ok and chat.payload:find('Olá, Sofia',1,true))
local timeout=assert(send.start(mock,protocol,'127.0.0.1',5190,token,peer,
  {submitId='send',message='Mensagem incerta'}))
assert(not send.step(timeout,0.1))
assert(send.step(timeout,8).ok==false)
assert(count==1,'timed-out send is NEVER automatically retried')
assert(closed>=2)
print('OK: nonblocking sending, fragmentation and no automatic resend')
