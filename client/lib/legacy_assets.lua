-- Strict local-only resource map. Original PNG bytes are imported by the user
-- from qeep-94724.jar (never fetched from URLs or referenced untrusted paths).
local M = {}
local resources = {
  ['logo.png']={path='assets/original/logo.png',width=128,height=42},
  ['icon_15x15.png']={path='assets/original/icon_15x15.png',width=15,height=15},
  ['kui/symbols.png']={path='assets/original/kui/symbols.png',width=12,height=180}
}
function M.info(src)
  if type(src)~='string' then return nil end
  return resources[src]
end
function M.load(src,graphics,cache)
  local info=M.info(src)
  if not info or not graphics or type(graphics.newImage)~='function' then return nil end
  cache=cache or {}
  local prior=cache[src]
  if prior~=nil then return prior or nil end
  local ok,img=pcall(graphics.newImage,info.path)
  if not ok or not img or type(img.getWidth)~='function' or type(img.getHeight)~='function' or
      img:getWidth()~=info.width or img:getHeight()~=info.height then
    cache[src]=false
    return nil
  end
  if type(img.setFilter)=='function' then img:setFilter('nearest','nearest') end
  cache[src]=img
  return img
end
return M
