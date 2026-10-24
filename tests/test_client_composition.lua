-- End-to-end event and drawing-position smoke for synthetic composition pages.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local draws={}
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
 printf=function(s,x,y) draws[#draws+1]={text=tostring(s),x=x,y=y} end},
 keyboard={setTextInput=noop},filesystem={read=function(path)
 if path=='host.txt' then return nil end
 local f=assert(io.open('client/'..path,'rb'));local s=f:read('*a');f:close();return s
 end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local n=0
local function check(ok) assert(ok,"checkpoint "..(n+1));n=n+1 end
local function textY(part)
 draws={};love.draw()
 for _,d in ipairs(draws) do if d.text:find(part,1,true) then return d.y end end
 return nil
end
love.load()
for i=1,4 do love.keypressed('down') end
love.keypressed('return')
check(textY('Composicao JCL')~=nil)
check(textY('LABORATORIO')~=nil)
check(textY('centralizada')>90)
love.keypressed('return') -- focused link to #top
check(textY('Valign top')~=nil)
local topY=textY('Alinhamento superior')
check(topY and topY<90)
love.keypressed('right') -- no explicit RSK: trigger focused button
check(textY('Composicao JCL')~=nil)
love.keypressed('down');love.keypressed('return') -- center page
check(textY('Valign padrao')~=nil)
local centerY=textY('Conteudo curto')
check(centerY and centerY>topY+35)
love.keypressed('left') -- cancel/back
check(textY('Composicao JCL')~=nil)
love.keypressed('down');love.keypressed('return')
check(textY('Rolagem e comandos')~=nil)
check(textY('Esta lista longa')<100)
love.wheelmoved(0,-8)
check(textY('Linha 12')~=nil)
love.keypressed('escape')
check(textY('Composicao JCL')~=nil)
love.keypressed('escape')
check(textY('QEEP REVIVAL 2008')~=nil)
print(('OK: %d client composition checks'):format(n))
