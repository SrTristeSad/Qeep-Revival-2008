-- End-to-end social demo over a REAL TCP server. Requires server/main.lua.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local socket=require('socket')
local protocol=require('lib.protocol')
local jcl=require('lib.jcl')
local checks=0
local function eq(a,b)
 assert(a==b,'expected '..tostring(b)..' but got '..tostring(a))
 checks=checks+1
end
local function request(kind,path,props)
 local conn=assert(socket.tcp())
 conn:settimeout(3)
 assert(conn:connect('127.0.0.1',5190))
 assert(conn:send(protocol.encodeRequest(kind,path,props or {},'')))
 local raw,reason=conn:receive('*a')
 conn:close()
 assert(raw,'TCP receive failure: '..tostring(reason))
 local reply=protocol.decodeReply(raw)
 eq(reply.kind,'R')
 eq(reply.path,path)
 return reply
end
local function valid(req)
 eq(req.properties.ok,'true')
 return jcl.parse(req.payload)
end
local welcome=valid(request('O','/revival/social/start'))
eq(welcome.forms[1].id,'welcome')
local a=valid(request('P','/revival/social/join',{nickname='Aline',submitId='join'}))
local b=valid(request('P','/revival/social/join',{nickname='Beto',submitId='join'}))
local tokenA=a.props.guestSession
local tokenB=b.props.guestSession
assert(tokenA and tokenB and tokenA~=tokenB)
local people=valid(request('O','/revival/social/people',{session=tokenA}))
local target
for _,item in ipairs(people.forms[1].items) do if item.label=='Beto' then target=item.href end end
assert(target and target:match('^/revival/social/chat/%d+$'))
local thread=valid(request('O',target,{session=tokenA}))
eq(thread.forms[1].id,'chat')
local destination=target:gsub('/chat/','/send/')
valid(request('P',destination,{session=tokenA,submitId='send',message='Olá, Beto <3'}))
local peopleB=valid(request('O','/revival/social/people',{session=tokenB}))
local backHref
for _,item in ipairs(peopleB.forms[1].items) do if item.label=='Aline' then backHref=item.href end end
assert(backHref)
local seen=valid(request('O',backHref,{session=tokenB}))
local delivered=false
for _,item in ipairs(seen.forms[1].items) do
 if item.label=='Aline: Olá, Beto <3' then delivered=true end
end
assert(delivered,'message was not delivered')
eq(request('O',target,{session='invalid'}).properties.ok,'false')
print(('OK: %d real TCP social guest checks'):format(checks))
