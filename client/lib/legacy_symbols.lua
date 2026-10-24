-- Verified 12x180 sprite strip from kui/symbols.png in the 2008 Java ME JAR.
-- aa.a(Graphics, Image, x, y, frame, columns, rows) computes these same cells.
-- j.class invokes this helper with columns=1, rows=30, frame=14..17.
local M = {}
local function integer(n) return type(n)=='number' and n%1==0 end
function M.region(imageWidth, imageHeight, frame, columns, rows)
  if not (integer(imageWidth) and integer(imageHeight) and integer(frame) and
    integer(columns) and integer(rows)) then return nil end
  if imageWidth<=0 or imageHeight<=0 or columns<=0 or rows<=0 or
    imageWidth%columns~=0 or imageHeight%rows~=0 or
    frame<0 or frame>=columns*rows then return nil end
  local w,h=imageWidth/columns,imageHeight/rows
  return {x=(frame%columns)*w, y=math.floor(frame/columns)*h, width=w, height=h}
end
function M.scroll_frames(canUp,canDown)
  -- j.class dispatches first image using 15 or 17; second using 14 or 16.
  -- Whether these flags correspond to particular navigation states is inferred.
  return canUp and 15 or 17, canDown and 14 or 16
end
function M.draw(graphics,image,frame,x,y,columns,rows)
  if not (graphics and graphics.newQuad and graphics.draw and image and
    image.getWidth and image.getHeight) then return false end
  local iw,ih=image:getWidth(),image:getHeight()
  local region=M.region(iw,ih,frame,columns,rows)
  if not region then return false end
  local quad=graphics.newQuad(region.x,region.y,region.width,region.height,iw,ih)
  graphics.draw(image,quad,x,y)
  return true
end
return M
