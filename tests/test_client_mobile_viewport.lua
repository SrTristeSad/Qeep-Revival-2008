-- Android scale and touch footer regression after verified emulator screenshot.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local viewport=require('lib.legacy_viewport')
local checks=0
local function check(v,label)
  assert(v,label or ('checkpoint '..tostring(checks+1)))
  checks=checks+1
end
local full=viewport.fit(540,960,240,320,{fractional=true})
check(full.scale==2.25,'fractional mobile scale should fill 540 pixel width')
check(full.x==0 and full.y==120,'mobile centered vertically')
local traditional=viewport.fit(540,960,240,320)
check(traditional.scale==2 and traditional.x==30,'integer default preserved')
local dx,dy=viewport.fromWindow(full,270,120+160*2.25)
check(math.abs(dx-120)<0.001 and math.abs(dy-160)<0.001,'inverse coordinates')
local draws,transforms,scales,keyboard,store,quitCalled={},{},{},{},{},false
local font={getHeight=function() return 12 end}
function font:getWrap(s,w)
  local lines={}
  local cap=math.max(1,math.floor(w/7))
  for part in (tostring(s)..'\n'):gmatch('(.-)\n') do
    repeat lines[#lines+1]=part:sub(1,cap);part=part:sub(cap+1) until #part==0
  end
  return w,lines
end
local function noop() end
love={
 system={getOS=function() return 'Android' end},
 graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
   setDefaultFilter=noop,push=noop,pop=noop,
   translate=function(x,y) transforms[#transforms+1]={x,y} end,
   scale=function(x,y) scales[#scales+1]={x,y} end,
   newFont=function() return font end,
   getDimensions=function() return 540,960 end,
   printf=function(s) draws[#draws+1]=tostring(s) end},
 keyboard={setTextInput=function(...) keyboard[#keyboard+1]={...} end},
 filesystem={read=function(path)
   if path=='endpoint.txt' or path=='host.txt' then return nil end
   local f=io.open('client/'..path,'rb')
   if not f then return nil end
   local s=f:read('*a');f:close();return s
 end,write=function(path,data) store[path]=data;return true end},
 event={quit=function() quitCalled=true end}
}
assert(loadfile('client/main.lua'))()
love.load()
local function visible(value)
  draws={};transforms={};scales={};love.draw()
  for _,valueInDraw in ipairs(draws) do
    if valueInDraw==value then return true end
  end
  return false
end
local function tap(x,y)
  love.touchpressed(42,x,y)
  love.touchreleased(42,x,y)
end
check(visible('Abrir'),'mobile footer open')
check(visible('Sair'),'mobile footer exit')
check(not visible('Selecionar: Enter   Voltar: Esc'),'no desktop footer label')
check(#scales>0 and scales[#scales][1]==2.25,'draw uses mobile viewport')
check(#transforms>0 and transforms[#transforms][2]==120,'mobile vertical centering')
-- On Android no server host is configured; selected option is Configure IP.
-- Touch menu footer left to activate it; it is NOT a dummy text label.
tap(80,120+308*2.25)
check(visible('Servidor LAN (IPv4:porta)'),'footer Open enters Configure')
check(visible('Salvar') and visible('Cancelar'),'usable mobile host footer')
check(#keyboard>0 and keyboard[#keyboard][1]==true,'IME opened')
love.textinput('192.168.1.50:5190')
tap(60,120+309*2.25)
check(store['endpoint.txt']=='192.168.1.50:5190','save by left footer touch')
check(visible('Abrir'),'returns to menu')
-- Second tap opens editor and right footer cancels without replacing the saved IP.
tap(70,120+308*2.25)
check(visible('Cancelar'),'host reopens')
love.textinput('192.168.1.60:5190')
tap(480,120+308*2.25)
check(visible('Abrir'),'cancel returns to menu')
check(store['endpoint.txt']=='192.168.1.50:5190','cancel did not write')
tap(480,120+308*2.25)
check(quitCalled,'Sair exits from menu on mobile touch')
print(('OK: %d Android viewport/footer checks'):format(checks))
