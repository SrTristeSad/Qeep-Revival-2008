-- Real localhost TCP test; requires a separately running server/main.lua.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local socket=require('socket')
local protocol=require('lib.protocol')
local jcl=require('lib.jcl')
local checks=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function request(kind,path,props)
  local conn=assert(socket.tcp())
  conn:settimeout(3)
  assert(conn:connect('127.0.0.1',5190))
  assert(conn:send(protocol.encodeRequest(kind,path,props or {},'')))
  local reply,reason,part=conn:receive('*a')
  conn:close()
  assert(reply,'receive failure: '..tostring(reason)..' partial '..tostring(part))
  local parsed=protocol.decodeReply(reply)
  eq(parsed.kind,'R')
  eq(parsed.path,path)
  return parsed
end
local pong=request('O','/revival/ping')
eq(pong.payload,'PONG');eq(pong.properties.ok,'true')
local remote=request('O','/revival/page/submit')
eq(remote.properties.ok,'true')
eq(jcl.parse(remote.payload).forms[1].id,'remote')
local echo=request('P','/revival/submit/echo',{
  submitId='send',nickname='A&B <uma>',message='Olá, 😀',choice='two'})
eq(echo.properties.ok,'true')
local parsed=jcl.parse(echo.payload)
eq(parsed.forms[1].items[2].label,'Apelido: A&B <uma>')
eq(parsed.forms[1].items[3].label,'Mensagem: Olá, 😀')
local denied=request('P','/revival/submit/echo',{submitId='send',choice='two',extra='oops'})
eq(denied.properties.ok,'false')
local forbidden=request('O','/navigation/init/')
eq(forbidden.properties.ok,'false')
print(('OK: %d real TCP laboratory checks'):format(checks))
