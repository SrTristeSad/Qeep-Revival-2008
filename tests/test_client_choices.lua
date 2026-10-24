-- LÖVE event contract for inline radio and checkbox choices (mock graphics).
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
 printf=function(s) draws[#draws+1]=tostring(s) end},
 keyboard={setTextInput=noop},filesystem={read=function(path)
 if path=='host.txt' then return nil end
 local fd=assert(io.open('client/'..path,'rb'));local content=fd:read('*a');fd:close();return content
 end,write=function() return true end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
local n=0
local function has(s)
  draws={};love.draw()
  for _,v in ipairs(draws) do if v:find(s,1,true) then return true end end
  return false
end
local function check(ok) assert(ok);n=n+1 end
love.load()
love.keypressed('return') -- fixture
for _=1,4 do love.keypressed('down') end
love.keypressed('return') -- open #choices
check(has('Seletor - bytecode s.class'))
check(has('Escolha única'))
check(has('Marque várias'))
check(has('[x]'))
check(has('(*)'))
love.keypressed('return') -- choose radio
check(has('marcar'))
love.keypressed('down');love.keypressed('return') -- choose 2nd radio
check(not has('marcar'))
love.keypressed('down');love.keypressed('return') -- choose multiple
check(has('marcar'))
love.keypressed('down');love.keypressed('return') -- toggle friends
check(has('[x]'))
love.keypressed('right') -- close multiselect
check(not has('marcar'))
love.keypressed('escape') -- return to index
check(has('JCL - Laboratório'))
print(('OK: %d client choice event tests'):format(n))
