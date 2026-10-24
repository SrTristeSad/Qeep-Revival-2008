package.path='client/?.lua;client/lib/?.lua;'..package.path
local parser=require('lib.jcl')
local layout=require('lib.jcl_layout')
local style=require('lib.jcl_style')
local pal=require('lib.legacy_palette')
local n=0
local function eq(a,b)
  assert(a==b,tostring(a)..' ~= '..tostring(b));n=n+1
end
local function bad(xml)
  eq(pcall(parser.parse,xml),false)
end
local doc=parser.parse([=[<jcl><form id="test">
  <a href="#test"/><li/><hr/><hr w="160"/>
  <p style="11" align="2">Antes <b>durante</b> depois &amp; fim</p>
  <p style="s12">texto</p>
  <p>Olá <![CDATA[<Lua>]]> final</p>
</form></jcl>]=])
local widgets=doc.forms[1].items
eq(widgets[1].marker,'>')
eq(widgets[2].marker,'*')
eq(widgets[1].label,'')
eq(widgets[3].width,90)
eq(widgets[4].width,160)
eq(widgets[5].label,'Antes durante depois & fim')
eq(widgets[5].align,2)
eq(widgets[7].label,'Olá <Lua> final')
local font={getHeight=function() return 10 end,
  getWrap=function(_,s,w) return w,{s} end}
local geometries=layout.build(doc.forms[1],font,220)
eq(geometries.entries[1].title,'>')
eq(geometries.entries[2].title,'*')
eq(geometries.entries[3].ruleWidth,90)
eq(geometries.entries[4].ruleWidth,160)
local normal=style.resolve(widgets[5],false)
eq(normal.styleKnown,true)
eq(math.floor(normal.surface[1]*255+0.5),235)
eq(math.floor(normal.text[1]*255+0.5),60)
local focused=style.resolve(widgets[5],true)
eq(focused.surface,pal.colors.highlight)
eq(math.floor(focused.text[1]*255+0.5),math.floor(normal.text[1]*255+0.5))
eq(style.registry_style('11'),pal.registry.s11)
eq(style.registry_style('s11'),pal.registry.s11)
eq(style.registry_style('8'),pal.registry.s8)
eq(style.registry_style('s999'),nil)
eq(style.registry_style('javascript:123'),nil)
eq(style.resolve({style='-12'},false).styleKnown,false)
eq(style.resolve({style='s12'},false).styleKnown,true)
eq(geometries.entries[6].item.style,'s12')
-- Malformed entities must be rejected rather than accidentally rendered.
bad('<jcl><form><p>texto & incorreto</p></form></jcl>')
bad('<jcl><form><p label="a &foo"/></form></jcl>')
bad('<jcl><form><p label="&notKnown;"/></form></jcl>')
local list=parser.parse('<jcl><form><li label="Marcador declarado"/><a label="Link nomeado" href="#x"/></form></jcl>').forms[1].items
eq(list[1].marker,nil)
eq(list[2].marker,nil)
print(('OK: %d Lua JCL visual fidelity checks'):format(n))
