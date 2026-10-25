-- Explicit local screenshot utility. No upload, network, or automatic capture.
local M = {}
local count = 0
function M.take(graphics, clock)
  if not graphics or type(graphics.captureScreenshot) ~= 'function' then
    return nil, 'Screenshot API unavailable'
  end
  count = count + 1
  local time = (clock or os.date)('!%Y%m%d_%H%M%S')
  if not tostring(time):match('^%d%d%d%d%d%d%d%d_%d%d%d%d%d%d$') then
    time = 'undated_000000'
  end
  local filename = ('qeep_capture_%s_%04d.png'):format(time, count)
  graphics.captureScreenshot(filename) -- stored in LOVE user save directory
  return filename
end
return M
