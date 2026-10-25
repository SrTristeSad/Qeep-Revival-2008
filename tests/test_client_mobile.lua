-- LÖVE event smoke: touch gestures and Android keyboard geometry. No device is
-- simulated here; platform-specific behavior still needs physical testing.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local count=0
local function check(v) assert(v,'mobile client checkpoint '..(count+1));count=count+1 end
local drawn={}
local keyboardCalls={}
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
 newFont=function() return font end,getDimensions=function() return 480,640 end,
 printf=function(s,x,y) drawn[#drawn+1]={text=tostring(s),x=x,y=y} end},
 keyboard={setTextInput=function(...) keyboardCalls[#keyboardCalls+1]={...} end},
 filesystem={read=function(path)
  if path=='host.txt' then return nil end
  local f=assert(io.open('client/'..path,'rb'));local s=f:read('*a');f:close();return s
 end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function visible(v)
 drawn={};love.draw()
 for _,d in ipairs(drawn) do if d.text:find(v,1,true) then return true end end
 return false
end
love.load()
check(visible('Abrir JCL (offline)'))
love.touchpressed(1,80,2*(91+3*22+9))
love.touchreleased(1,80,2*(91+3*22+9))
check(visible('IP ou nome do servidor'))
local hostKeyboard=keyboardCalls[#keyboardCalls]
check(#hostKeyboard==5 and hostKeyboard[1]==true)
check(hostKeyboard[2]>0 and hostKeyboard[3]>0 and hostKeyboard[4]>0)
love.keypressed('escape')
check(keyboardCalls[#keyboardCalls][1]==false)
check(visible('Abrir JCL (offline)'))
love.touchpressed(2,90,200)
love.touchpressed(3,90,200)
love.touchreleased(3,90,200)
check(visible('Abrir JCL (offline)'))
love.touchreleased(2,90,200)
check(visible('JCL - Laboratório'))
love.touchpressed(4,50,615)
love.touchmoved(4,50,300)
love.touchreleased(4,50,300)
check(visible('JCL - Laboratório'))
love.keypressed('return')
check(visible('Campos JCL'))
love.keypressed('return')
local editorKeyboard=keyboardCalls[#keyboardCalls]
check(#editorKeyboard==5 and editorKeyboard[1]==true)
check(editorKeyboard[3]>=2*65 and editorKeyboard[3]<2*281)
love.textinput('Olá')
love.keypressed('return')
check(keyboardCalls[#keyboardCalls][1]==false)
love.focus(false)
check(visible('Campos JCL'))
print(('OK: %d mobile client event checks'):format(count))
