-- Mocked optional historical-logo drawing; not a GPU pixel comparison.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local seen={paths={},draw=0}
local noop=function() end
local font={getHeight=function() return 12 end}
function font:getWrap(s,w) return w,{tostring(s)} end
local image={getWidth=function() return 128 end,getHeight=function() return 42 end}
love={graphics={setColor=noop,rectangle=noop,printf=noop,setFont=noop,setScissor=noop,
   setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
   newFont=function() return font end,getDimensions=function() return 480,640 end,
   newImage=function(path) seen.paths[#seen.paths+1]=path;return image end,
   draw=function(g,x,y) assert(g==image and x==56 and y==28);seen.draw=seen.draw+1 end},
   keyboard={setTextInput=noop},filesystem={read=function() return nil end},event={quit=noop}}
assert(loadfile('client/main.lua'))()
love.load()
assert(seen.paths[1]=='assets/original/logo.png')
love.draw()
assert(seen.draw==1)
print('OK: 3 optional original-logo UI checks')
