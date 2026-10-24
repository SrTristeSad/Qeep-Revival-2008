-- Screens and commands grounded in j.class/h.class, without historical pages.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local jcl=require('lib.jcl')
local view=require('lib.jcl_view')
local layout=require('lib.jcl_layout')
local screen=require('lib.jcl_screen')
local count=0
local function eq(a,b)
  assert(a==b,tostring(a)..' ~= '..tostring(b))
  count=count+1
end
local f=assert(io.open('client/fixtures/composition.xml','rb'))
local doc=jcl.parse(f:read('*a'));f:close()
eq(#doc.forms,4)
local short=doc.forms[1]
eq(short.valign,nil)
eq(doc.forms[2].valign,'top')
local left,right=screen.commands(short)
eq(left.label,'Sair')
eq(left.cancel,true)
eq(left.commandType,2)
eq(left.explicit,true)
eq(right.label,'Abrir')
eq(right.cancel,false)
eq(right.commandType,4)
local t=screen.command(doc.forms[2],'rsk')
eq(t.explicit,false)
eq(t.cancel,false)
local ch1,ch2=screen.commands(short,true)
eq(ch1.commandType,2)
eq(ch2.commandType,4)
eq(ch2.label,'Concluir')
local flags=jcl.parse('<jcl><form><lsk label="Nao cancelar" cancel="false"/><rsk label="Cancelar" cancel="true"/></form></jcl>')
eq(screen.command(flags.forms[1],'lsk').commandType,4)
eq(screen.command(flags.forms[1],'rsk').commandType,2)
local font={getHeight=function() return 12 end}
function font:getWrap(str,w)
  local out={}
  for line in (tostring(str or '')..'\n'):gmatch('(.-)\n') do
    local cap=math.max(1,math.floor(w/7))
    repeat out[#out+1]=line:sub(1,cap);line=line:sub(cap+1) until #line==0
  end
  return w,out
end
local top=layout.build(doc.forms[2],font,220)
local natural=top.total
layout.place(top,216,'top')
eq(top.topInset,0)
eq(top.entries[1].y,0)
eq(top.total,natural)
local centered=layout.build(doc.forms[2],font,220)
layout.place(centered,216,nil)
eq(centered.topInset>0,true)
eq(centered.entries[1].y,centered.topInset)
eq(centered.total,natural+centered.topInset)
local old=centered.topInset
layout.place(centered,216,nil)
eq(centered.topInset,old)
eq(centered.entries[1].y,old)
eq(layout.hit(centered,10,5,0,220,216),nil)
layout.place(centered,216,'top')
eq(centered.topInset,0)
eq(centered.total,natural)
local tall=layout.build(doc.forms[4],font,220)
eq(tall.total>216,true)
layout.place(tall,216,nil)
eq(tall.topInset,0)
eq(tall.entries[1].y,0)
eq(layout.hit(top,10,5,0,220,216),1)
local model=view.new(doc)
eq(view.item(model).href,'#top')
print(('OK: %d screen and command model checks'):format(count))
