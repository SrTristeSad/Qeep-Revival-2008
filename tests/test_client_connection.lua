-- Event smoke for a simulated Android platform, not physical-device validation.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local protocol=require('lib.protocol')
local saved,drawn,keyboard,connections={},{},{},{}
local no=function() end
package.preload.socket=function()
 return {tcp=function()
  local request
  return {settimeout=no,
   connect=function(_,h,p) connections[#connections+1]={h,p};return true end,
   send=function(_,b) request=protocol.decodeRequest(b);return #b end,
   receive=function() return protocol.encodeReply('R',request.path,{ok='true'},'PONG') end,
   close=no}
 end}
end
local width,height=480,640
local f={getHeight=function() return 12 end}
function f:getWrap(s,w) return w,{tostring(s)} end
love={system={getOS=function() return 'Android' end},
 graphics={setColor=no,rectangle=no,setFont=no,setScissor=no,setDefaultFilter=no,
 push=no,pop=no,translate=no,scale=no,newFont=function() return f end,
 getDimensions=function() return width,height end,
 printf=function(v) drawn[#drawn+1]=tostring(v) end},
 keyboard={setTextInput=function(...) keyboard[#keyboard+1]={...} end},
 filesystem={read=function(path)
   if saved[path] then return saved[path] end
   if path=='host.txt' or path=='endpoint.txt' then return nil end
   local ioFile=assert(io.open('client/'..path,'rb'))
   local content=ioFile:read('*a');ioFile:close();return content
 end,write=function(path,v) saved[path]=v;return true end},
 event={quit=no}}
assert(loadfile('client/main.lua'))()
local function visible(t)
 drawn={};love.draw()
 for _,v in ipairs(drawn) do if v:find(t,1,true) then return true end end
 return false
end
love.load()
assert(visible('Configure o IP do PC no menu'))
love.keypressed('return')
assert(visible('Servidor LAN (IPv4:porta)'))
assert(keyboard[#keyboard][1]==true)
love.textinput('8.8.8.8:5190');love.keypressed('return')
assert(visible('Use localhost ou IPv4 de rede privada'))
assert(saved['endpoint.txt']==nil)
for _=1,#'8.8.8.8:5190' do love.keypressed('backspace') end
love.textinput('192.168.1.50:6200');love.keypressed('return')
assert(saved['endpoint.txt']=='192.168.1.50:6200')
love.keypressed('up');love.keypressed('return')
assert(connections[1][1]=='192.168.1.50' and connections[1][2]==6200)
love.keypressed('escape');love.keypressed('down');love.keypressed('return')
local before=keyboard[#keyboard]
width,height=640,480;love.resize(width,height)
local after=keyboard[#keyboard]
assert(after[1] and (before[2]~=after[2] or before[3]~=after[3]))
love.keypressed('escape')
assert(saved['endpoint.txt']=='192.168.1.50:6200')
print('OK: Android LAN settings UI, port and resize')
