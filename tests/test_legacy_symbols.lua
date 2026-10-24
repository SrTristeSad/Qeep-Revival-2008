package.path='client/?.lua;client/lib/?.lua;'..package.path
local sym=require('lib.legacy_symbols')
local assets=require('lib.legacy_assets')
local layout=require('lib.jcl_layout')
local parser=require('lib.jcl')
local checks=0
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b));checks=checks+1 end
local top=sym.region(12,180,15,1,30)
eq(top.x,0);eq(top.y,90);eq(top.width,12);eq(top.height,6)
eq(sym.region(12,180,14,1,30).y,84)
eq(sym.region(12,180,17,1,30).y,102)
eq(sym.region(12,180,-1,1,30),nil)
eq(sym.region(12,180,30,1,30),nil)
eq(sym.region(12,180,15,0,30),nil)
eq(sym.region(12,180,15,1,31),nil)
eq(sym.region(12,180,0.5,1,30),nil)
local a,b=sym.scroll_frames(true,false);eq(a,15);eq(b,16)
a,b=sym.scroll_frames(false,true);eq(a,17);eq(b,14)
local image={getWidth=function() return 12 end,getHeight=function() return 180 end}
local drawn={}
local fake={newQuad=function(...) return {...} end,draw=function(...) drawn[#drawn+1]={...} end}
eq(sym.draw(fake,image,15,10,20,1,30),true)
eq(#drawn,1);eq(drawn[1][2][2],90);eq(drawn[1][3],10);eq(drawn[1][4],20)
eq(sym.draw(fake,image,99,0,0,1,30),false);eq(#drawn,1)
eq(assets.info('logo.png').width,128)
eq(assets.info('icon_15x15.png').height,15)
eq(assets.info('kui/symbols.png').height,180)
eq(assets.info('../logo.png'),nil)
eq(assets.info('https://qeep.test/logo.png'),nil)
eq(assets.info('LOGO.PNG'),nil)
local calls,cache=0,{}
local gfx={newImage=function(path)
  calls=calls+1
  eq(path,'assets/original/logo.png')
  return {getWidth=function() return 128 end,getHeight=function() return 42 end,
    setFilter=function(_,min,mag) eq(min,'nearest');eq(mag,'nearest') end}
end}
eq(assets.load('logo.png',gfx,cache)~=nil,true)
eq(assets.load('logo.png',gfx,cache)~=nil,true)
eq(calls,1)
eq(assets.load('../../bad.png',gfx,cache),nil);eq(calls,1)
local badcache={}
eq(assets.load('logo.png',{newImage=function() return {getWidth=function() return 13 end,getHeight=function() return 42 end} end},badcache),nil)
eq(badcache['logo.png'],false)
local font={getHeight=function() return 10 end,getWrap=function(_,s,w) return w,{s} end}
local form=parser.parse('<jcl><form id="a"><img src="logo.png"/><img src="icon_15x15.png"/><img src="../../evil.png"/></form></jcl>').forms[1]
local entries=layout.build(form,font,220).entries
eq(entries[1].imageInfo.height,42)
eq(entries[1].height>=52,true)
eq(entries[2].imageInfo.height,15)
eq(entries[3].imageInfo,nil)
eq(entries[3].detail,'[recurso de imagem desconhecido]')
print(('OK: %d Lua legacy graphics and safe image resource checks'):format(checks))
