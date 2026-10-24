-- Integration test: real TCP account registration + login on localhost.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local socket=require('socket')
local protocol=require('lib.protocol')
local jcl=require('lib.jcl')
local count=0
local function ck(condition,msg) assert(condition,msg or 'failure');count=count+1 end
local function ask(kind,path,props)
  local tcp=assert(socket.tcp());tcp:settimeout(3)
  assert(tcp:connect('127.0.0.1',5190))
  assert(tcp:send(protocol.encodeRequest(kind,path,props or {},'')))
  local reply,error=tcp:receive('*a');tcp:close()
  ck(reply~=nil,error)
  local decoded=protocol.decodeReply(reply)
  ck(decoded.path==path and decoded.kind=='R')
  return decoded
end
local username='p12_'..tostring(os.time())
local created=ask('P','/revival/social/register/submit',{username=username,submitId='register'})
ck(created.properties.ok=='true',created.payload)
local credentials=jcl.parse(created.payload)
ck(credentials.forms[1].id=='credentials')
local secret
for _,item in ipairs(credentials.forms[1].items) do
  if item.kind=='p' and #item.label==48 and item.label:match('^[0-9a-f]+$') then secret=item.label end
end
ck(secret~=nil)
local invalid=ask('P','/revival/social/login/submit',{username=username,accessCode='invalid',submitId='login'})
ck(invalid.properties.ok=='false')
local auth=ask('P','/revival/social/login/submit',{username=username,accessCode=secret,submitId='login'})
ck(auth.properties.ok=='true',auth.payload)
local session=jcl.parse(auth.payload).props.guestSession
ck(session~=nil and session~=credentials.props.guestSession)
local profile=ask('O','/revival/social/home',{session=session})
ck(profile.properties.ok=='true')
local logout=ask('O','/revival/social/logout',{session=session})
ck(jcl.parse(logout.payload).props.sessionClear=='true')
ck(ask('O','/revival/social/home',{session=session}).properties.ok=='false')
print(('OK: %d real TCP account tests'):format(count))
