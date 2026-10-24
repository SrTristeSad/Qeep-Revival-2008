package.path='client/?.lua;client/lib/?.lua;'..package.path
local layout=require('lib.jcl_layout')
local edit=require('lib.utf8_edit')
local jcl=require('lib.jcl')
local view=require('lib.jcl_view')
local theme=require('lib.legacy_palette')
local n=0
local function eq(a,b)
  assert(a==b,tostring(a)..' ~= '..tostring(b));n=n+1
end
-- Deterministic font surrogate: 10-pixel height, ASCII-based unit-width.
local font={}
function font:getHeight() return 10 end
function font:getWrap(s,w)
  local lines={}
  local maxchars=math.floor(w/7)
  for line in (s..'\n'):gmatch('(.-)\n') do
    repeat
      lines[#lines+1]=line:sub(1,maxchars)
      line=line:sub(maxchars+1)
    until #line==0
  end
  return w,lines
end
local doc=jcl.parse('<jcl><form id="x"><p label="'..string.rep('A',125)..'"/>'..
  '<hr/><input len="4" label="Nome" value="Á"/><textarea label="Mensagem">Olá</textarea>'..
  '<select label="Selecione" type="4"><option selected="true" label="Um"/></select>'..
  '<gauge label="Progresso" value="10" max="20"/>'..
  '<button label="Abrir" href="#x"/><lsk label="Voltar"/><rsk label="Abrir"/></form></jcl>')
local form=doc.forms[1]
local result=layout.build(form,font,220)
eq(#result.entries,7)
eq(result.entries[1].index,1)
eq(result.entries[1].height>50,true)
eq(result.entries[2].item.kind,'hr')
eq(result.entries[3].item.kind,'input')
eq(result.entries[4].item.kind,'textarea')
eq(result.entries[5].item.kind,'select')
eq(result.entries[6].item.kind,'gauge')
eq(result.entries[7].item.kind,'button')
eq(result.entries[3].detail,'Á')
eq(result.entries[5].detail,'Um  >')
eq(result.entries[6].detail,'10/20')
eq(result.total>216,true)
eq(layout.max_scroll(result,216),result.total-216)
eq(layout.clamp_scroll(result,-50,216),0)
eq(layout.clamp_scroll(result,90000,216),result.total-216)
eq(layout.ensure_visible(result,1,0,216),0)
eq(layout.ensure_visible(result,7,0,216)>0,true)
eq(layout.ensure_visible(result,1,9000,216),0)
eq(layout.hit(result,4,result.entries[1].y,0,220,216),1)
eq(layout.hit(result,4,result.entries[2].y,0,220,216),2)
eq(layout.hit(result,4,-1,0,220,216),nil)
eq(layout.hit(result,221,3,0,220,216),nil)
eq(layout.hit(result,4,217,0,220,216),nil)
local last=result.entries[#result.entries]
local scroll=layout.max_scroll(result,216)
eq(layout.hit(result,4,last.y-scroll+2,scroll,220,216),7)
eq(edit.count('Olá 👋'),5)
eq(edit.backspace('Olá 👋'),'Olá ')
eq(edit.backspace('Á'),'')
eq(edit.backspace(''), '')
eq(edit.append('Á','é🙂abc',3),'Áé🙂')
eq(edit.append('Á','é🙂abc',1),'Á')
eq(edit.append('Olá','!',4),'Olá!')
eq(edit.append('Olá',string.char(255),10),'Olá')
eq(edit.count(string.char(255)),nil)
local state=view.new(doc)
view.next_form(state,'x')
state.selected=3
eq(view.activate(state),'editing')
view.backspace(state)
eq(view.item(state).value,'')
view.text(state,'é🙂mais')
eq(view.item(state).value,'é🙂ma')
view.backspace(state)
eq(view.item(state).value,'é🙂m')
view.cancel_edit(state)
local pal=theme.colors.background
eq(math.floor(pal[1]*255+0.5),235)
eq(math.floor(pal[2]*255+0.5),255)
eq(math.floor(pal[3]*255+0.5),185)
eq(theme.registry.s1.xc,'7d147d')
eq(theme.registry.s11.tc,'3c143c')
print(('OK: %d Lua layout/UTF-8/palette checks'):format(n))
