package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local poll=require('lib.social_poll')
local social=require('social_routes')
local jcl=require('lib.jcl')
local function rq(kind,path,props)
 return social.handle({kind=kind,path=path,properties=props or {},payload=''})
end
local a=jcl.parse(assert(rq('P','/revival/social/join',{nickname='Cecilia',submitId='join'}).payload))
local b=jcl.parse(assert(rq('P','/revival/social/join',{nickname='Davi',submitId='join'}).payload))
local alice,bob=a.props.guestSession,b.props.guestSession
local roster=jcl.parse(rq('O','/revival/social/people',{session=alice}).payload)
local target
for _,item in ipairs(roster.forms[1].items) do if item.label=='Davi' then target=item.href:match('(%d+)$') end end
assert(target)
local chat=jcl.parse(rq('O','/revival/social/chat/'..target,{session=alice}).payload)
assert(chat.props.chatRevision=='0' and chat.props.chatPeer==target)
local path='/revival/social/poll/'..target
assert(rq('O',path,{session=alice,since='0'}).unchanged)
assert(not rq('O',path,{session=alice,since='0',extra='1'}).ok)
assert(not rq('O',path,{session=alice,since='-1'}).ok)
assert(not rq('P',path,{session=alice,since='0'}).ok)
assert(not rq('O',path,{session='invalid',since='0'}).ok)
local otherRoster=jcl.parse(rq('O','/revival/social/people',{session=bob}).payload)
local fromAliceId
for _,item in ipairs(otherRoster.forms[1].items) do if item.label=='Cecilia' then fromAliceId=item.href:match('(%d+)$') end end
assert(fromAliceId)
assert(rq('P','/revival/social/send/'..fromAliceId,{session=bob,submitId='send',message='Nova mensagem'}).ok)
local changed=rq('O',path,{session=alice,since='0'})
assert(changed.ok and jcl.parse(changed.payload).props.chatRevision=='1')
assert(rq('O',path,{session=alice,since='1'}).unchanged)
local closed=0
local socket={}
function socket.tcp()
 local c={sent='',count=0}
 function c:settimeout(n) assert(n==0) end
 function c:connect() return nil,'timeout' end
 function c:getpeername() return '127.0.0.1',5190 end
 function c:send(data,i)
  local last=math.min(#data,i+11)
  self.sent=self.sent..data:sub(i,last)
  if last==#data then return last end
  return nil,'timeout',last
 end
 function c:receive()
  self.count=self.count+1
  if not self.answer then
   local r=social.handle(protocol.decodeRequest(self.sent))
   self.answer=protocol.encodeReply('R',path,{ok=r.ok and 'true' or 'false',
     unchanged=r.unchanged and 'true' or 'false'},r.payload)
  end
  if self.count==1 then return nil,'timeout',self.answer:sub(1,12) end
  return nil,'closed',self.answer:sub(13)
 end
 function c:close() closed=closed+1 end
 return c
end
function socket.select(_,write) return {},write end
local t=assert(poll.start(socket,protocol,'127.0.0.1',5190,alice,target,'0'))
local result
for _=1,100 do result=poll.step(t,0.01);if result then break end end
assert(result and result.ok and result.changed)
assert(jcl.parse(result.payload).props.chatRevision=='1')
t=assert(poll.start(socket,protocol,'127.0.0.1',5190,alice,target,'1'))
for _=1,100 do result=poll.step(t,0.01);if result then break end end
assert(result.ok and not result.changed and result.payload=='')
t=assert(poll.start(socket,protocol,'127.0.0.1',5190,alice,target,'1'))
assert(poll.step(t,6).error=='Poll timeout')
t=assert(poll.start(socket,protocol,'127.0.0.1',5190,alice,target,'1'))
poll.cancel(t)
assert(closed>=4)
print('OK: social polling routes and nonblocking transport')
