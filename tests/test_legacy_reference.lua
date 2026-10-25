package.path='client/?.lua;client/lib/?.lua;'..package.path
local ref=require('lib.legacy_reference')
local palette=require('lib.legacy_palette')
local assets=require('lib.legacy_assets')
local count=0
local function check(value) assert(value);count=count+1 end
check(ref.commands.back=='Back' and ref.commands.select=='Select')
check(ref.commands.cancel=='Cancel' and ref.commands.options=='Options')
check(ref.commands.ok=='OK')
check(#ref.assets==3 and #ref.swatches==8)
for _,asset in ipairs(ref.assets) do
 local info=assets.info(asset.name)
 check(info and info.width==asset.width and info.height==asset.height)
end
for _,swatch in ipairs(ref.swatches) do
 local result=ref.color(swatch)
 check(#result==3 and result[1]>=0 and result[1]<=1)
end
check(ref.swatches[1].hex==palette.registry.s0.bg)
check(ref.swatches[2].hex==palette.registry.s2.bg)
check(ref.swatches[3].hex==palette.registry.s7.cbg)
check(ref.swatches[4].hex==palette.registry.s10.bg)
check(ref.swatches[5].hex==palette.registry.s0.xc)
check(ref.swatches[6].hex==palette.registry.s10.tc)
check(ref.swatches[7].hex==palette.registry.s11.tc)
print(('OK: %d visual evidence checks'):format(count))
