-- Selection types and selection-value serialization evidenced in h/s.class.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local parse=require('lib.jcl').parse
local view=require('lib.jcl_view')
local layout=require('lib.jcl_layout')
local choice=require('lib.jcl_choices')
local submit=require('lib.jcl_submit')
local checks=0
local function eq(actual, expected)
  assert(actual==expected,tostring(actual)..' ~= '..tostring(expected))
  checks=checks+1
end
local xml=[=[<jcl><form id="choices" title="Choices">
<select id="radio"><option label="A" value="a" selected="true"/><option label="B" value="b"/></select>
<select id="multi" type="2"><option value="x" label="X" selected="true"/><option value="y" label="Y" selected="true"/><option value="z" label="Z"/></select>
<select id="compact"><option label="1" value="1"/><option label="2" value="2"/><option label="3" value="3"/></select>
<select id="explicit" type="3"><option value="one"/><option value="two"/></select>
</form></jcl>]=]
local form=parse(xml).forms[1]
local radio,multi,compact,explicit=table.unpack(form.items)
eq(radio.choiceType,1)
eq(multi.choiceType,2)
eq(compact.choiceType,4)
eq(explicit.choiceType,3)
eq(choice.kind(nil,1),2)
eq(choice.kind(nil,2),1)
eq(choice.kind(nil,3),4)
eq(choice.value(radio),'a')
eq(choice.value(multi),'x,y')
eq(choice.value(compact),'1')
local state=view.new({forms={form}})
eq(state.selected,1)
eq(view.activate(state),'choosing')
eq(view.choice_move(state,1),true)
eq(view.choice_choose(state),true)
eq(state.choosing,false)
eq(choice.value(radio),'b')
eq(submit.collect(form).radio,'b')
eq(view.move(state,1),true)
eq(view.activate(state),'choosing')
eq(view.choice_choose(state,2),true)
eq(state.choosing,true)
eq(choice.value(multi),'x')
eq(view.choice_choose(state,3),true)
eq(choice.value(multi),'x,z')
eq(submit.collect(form).multi,'x,z')
view.choice_close(state)
eq(state.choosing,false)
eq(view.move(state,1),true)
eq(view.activate(state),'selected')
eq(choice.value(compact),'2')
eq(view.activate(state),'selected')
eq(choice.value(compact),'3')
local font={getHeight=function() return 12 end,getWrap=function(_,s,w) return w,{tostring(s)} end}
local render=layout.build(form,font,220)
eq(#render.entries,4)
eq(#render.entries[1].choiceRows,2)
eq(#render.entries[2].choiceRows,3)
eq(render.entries[3].choiceRows,nil)
local row=render.entries[2].choiceRows[3]
eq(layout.choice_hit(render,2,render.entries[2].y+row.y+1,0),3)
eq(layout.choice_hit(render,2,render.entries[2].y,0),nil)
local target=layout.ensure_choice_visible(render,2,3,0,80)
eq(target>0,true)
local one=parse('<jcl><form><select id="alone"><option value="hi"/></select></form></jcl>').forms[1].items[1]
eq(one.choiceType,2)
eq(choice.value(one),'')
choice.choose(one,1)
eq(choice.value(one),'hi')
choice.choose(one,1)
eq(choice.value(one),'')
-- Defensive: unknown type falls back to compact, preserving bounded behavior.
eq(choice.kind('not-number',5),4)
print(('OK: %d JCL choice semantics checks'):format(checks))
