-- Display-space transform for the Java ME-sized 240x320 logical canvas.
-- Pixel-exact integer scaling whenever the window fits the original canvas;
-- controlled downscaling only when a mobile/window viewport is smaller.
local M = {}
local function finite_positive(v)
  return type(v)=='number' and v>0 and v<math.huge and v==v
end
function M.fit(width, height, logicalWidth, logicalHeight, options)
  assert(finite_positive(width) and finite_positive(height), 'invalid window dimensions')
  logicalWidth, logicalHeight=logicalWidth or 240, logicalHeight or 320
  assert(finite_positive(logicalWidth) and finite_positive(logicalHeight), 'invalid canvas dimensions')
  local ratio=math.min(width/logicalWidth, height/logicalHeight)
  -- Android touchscreens benefit from using the entire available width. Keep
  -- integer pixel scaling as the historical/default desktop mode.
  local fractional=type(options)=='table' and options.fractional==true
  local scale=(fractional or ratio<1) and ratio or math.floor(ratio)
  return {scale=scale, x=math.floor((width-logicalWidth*scale)/2),
    y=math.floor((height-logicalHeight*scale)/2),width=logicalWidth,height=logicalHeight}
end
function M.fromWindow(transform,x,y)
  if type(x)~='number' or type(y)~='number' then return nil end
  local dx,dy=(x-transform.x)/transform.scale,(y-transform.y)/transform.scale
  if dx<0 or dy<0 or dx>=transform.width or dy>=transform.height then return nil end
  return dx,dy
end
function M.toWindow(transform,x,y)
  return transform.x+x*transform.scale,transform.y+y*transform.scale
end
return M
