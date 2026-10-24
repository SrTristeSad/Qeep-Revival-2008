-- Event-level smoke test with mocked LÖVE 11.x API; NOT a GPU screenshot test.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local n,draw_calls=0,0
local function check(value)
  assert(value);n=n+1
end
local font={}
function font:getHeight() return 12 end
function font:getWrap(s,w)
  local lines={}
  local capacity=math.max(1,math.floor(w/7))
  for line in (tostring(s)..'\n'):gmatch('(.-)\n') do
    repeat
      lines[#lines+1]=line:sub(1,capacity)
      line=line:sub(capacity+1)
    until #line==0
  end
  return w, lines
end
local function noop() draw_calls=draw_calls+1 end
love={
 graphics={setColor=noop,rectangle=noop,printf=noop,print=noop,
 setFont=noop,setScissor=noop,setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
 newFont=function(_) return font end, getDimensions=function() return 480,640 end},
 keyboard={setTextInput=noop},
 filesystem={
 read=function(path)
  if path=='host.txt' then return nil end
  local f=assert(io.open('client/'..path,'rb'))
  local data=f:read('*a');f:close();return data
 end,
 write=function() return true end},
 event={quit=noop}
}
assert(loadfile('client/main.lua'))()
love.load()
love.draw();check(draw_calls>0)
love.keypressed('return') -- open fixture
love.draw();check(true)
love.keypressed('down')
love.keypressed('return') -- navigate '#fields'
love.draw();check(true)
love.keypressed('return') -- edit input
love.textinput('é')
love.keypressed('backspace')
love.keypressed('return') -- exit edit
love.keypressed('down') -- textarea
love.keypressed('return')
love.textinput('🙂')
love.keypressed('return')
love.keypressed('down') -- select
love.keypressed('return')
love.wheelmoved(0,-8)
love.draw();check(true)
love.touchpressed(1,200,350)
love.touchmoved(1,200,290)
love.touchreleased(1,200,290)
love.draw();check(true)
love.keypressed('pageup')
love.keypressed('escape')
-- Reopen the fixture, use the synthetic style lab and draw both separators.
love.keypressed('return')
love.keypressed('down')  -- '#about' button
love.keypressed('down')  -- '#styles' link
love.keypressed('return')
love.draw();check(true)
love.keypressed('right') -- synthetic right softkey -> '#about'
love.draw();check(true)
love.keypressed('escape')
love.draw();check(true)
print(('OK: %d mocked LÖVE client smoke checks'):format(n))
