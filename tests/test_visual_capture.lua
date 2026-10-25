package.path='client/?.lua;client/lib/?.lua;'..package.path
local capture = require('lib.visual_capture')
local saved = {}
local fakeGraphics = {captureScreenshot=function(name) saved[#saved+1] = name end}
local first = assert(capture.take(fakeGraphics, function() return '20261025_130000' end))
local second = assert(capture.take(fakeGraphics, function() return '20261025_130000' end))
assert(first == 'qeep_capture_20261025_130000_0001.png')
assert(second == 'qeep_capture_20261025_130000_0002.png')
assert(#saved == 2 and saved[1] == first and saved[2] == second)
assert(select(1, capture.take({})) == nil)
print('OK: explicit local screenshot naming')
