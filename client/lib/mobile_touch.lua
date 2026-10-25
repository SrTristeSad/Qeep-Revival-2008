-- Single-pointer gesture recognizer shared by Android and desktop touchscreens.
-- Coordinates supplied to this module are physical window pixels.
-- A drag can scroll only if it began inside the JCL content viewport.
local M = {}
function M.new()
  return {active=nil}
end
function M.press(state,id,x,y,content,scale)
  if state.active then return false end -- Ignore secondary fingers.
  state.active={id=id,x=x,y=y,lastY=y,scroll=not not content,
    threshold=math.max(8,6*math.max(0.1,tonumber(scale) or 1)),dragged=false}
  return true
end
function M.move(state,id,x,y,scale)
  local t=state.active
  if not t or t.id~=id then return 0 end
  local dx=x-t.x;local dy=y-t.y
  if not t.dragged and dx*dx+dy*dy>=t.threshold*t.threshold then
    t.dragged=true
  end
  local step=0
  if t.dragged and t.scroll then
    step=(t.lastY-y)/math.max(0.1,tonumber(scale) or 1)
  end
  t.lastY=y
  return step
end
function M.release(state,id,x,y)
  local t=state.active
  if not t or t.id~=id then return false end
  state.active=nil
  local dx=x-t.x;local dy=y-t.y
  return not t.dragged and dx*dx+dy*dy<t.threshold*t.threshold
end
function M.reset(state)
  state.active=nil
end
return M
