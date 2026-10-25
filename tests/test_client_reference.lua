-- Event-level mock checks for the optional *evidence* view, not GPU screenshots.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local draws, labels={},{}
local captured = nil
local function noop() end
local font={getHeight=function() return 12 end}
function font:getWrap(s,w)
  local out={};local cap=math.max(1,math.floor(w/7))
  for part in (tostring(s)..'\n'):gmatch('(.-)\n') do
    repeat out[#out+1]=part:sub(1,cap);part=part:sub(cap+1) until part==''
  end
  return w,out
end
local dims={
 ['assets/original/logo.png']={128,42},
 ['assets/original/icon_15x15.png']={15,15},
 ['assets/original/kui/symbols.png']={12,180}
}
local function image(path)
  local size=dims[path]
  if not size then error('unknown asset '..path) end
  return {getWidth=function() return size[1] end,getHeight=function() return size[2] end,setFilter=noop}
end
love={graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
 setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
 captureScreenshot=function(name) captured=name end,
 getDimensions=function() return 480,640 end,newFont=function() return font end,
 printf=function(s) labels[#labels+1]=tostring(s) end,
 newImage=image,newQuad=function() return {} end,
 draw=function(_,...) draws[#draws+1]={...} end},
 keyboard={setTextInput=noop},filesystem={read=function(path)
 if path=='host.txt' then return nil end
 local f=assert(io.open('client/'..path,'rb'));local s=f:read('*a');f:close();return s
 end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local function has(part)
 for _,label in ipairs(labels) do if label:find(part,1,true) then return true end end
 return false
end
love.load()
love.keypressed('f12')
assert(type(captured)=='string' and captured:match('^qeep_capture_.*%.png$'))
-- The eighth menu item is the graphical-reference view; the exit item remains last.
for _=1,7 do love.keypressed('down') end
love.keypressed('return')
love.draw()
assert(has('Recursos do JAR 1.29'))
assert(has('Back  |  Select  |  Options'))
assert(has('s0 bg') and has('s11 tc'))
assert(#draws>=6,'logo + icon + 4 verified symbol-frame draws')
labels={}
love.keypressed('escape')
love.draw()
assert(has('QEEP REVIVAL 2008'))
assert(has('Sair'))
-- A click in the letterbox must be ignored, while a correctly scaled click
-- must activate the eighth item (logical y = 91 + 7*22 + 10).
love.mousepressed(489,100,1,false)
labels={};love.draw();assert(has('Sair') and not has('Recursos do JAR 1.29'))
love.mousepressed(60,510,1,false)
labels={};love.draw();assert(has('Recursos do JAR 1.29'))
print('OK: 8 visual-reference mock checks')
