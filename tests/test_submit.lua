-- JAR-derived collection behavior; original server interoperability unverified.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local submit=require('lib.jcl_submit')
local jcl=require('lib.jcl')
local view=require('lib.jcl_view')
local routes=require('lab_routes')
local protocol=require('lib.protocol')
local checks=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); checks=checks+1 end
local function rejects(fn) local ok=pcall(fn);eq(ok,false) end
local xml=[=[<jcl><form id="f" title="Teste"><input id="nickname" value="abc"/>
<textarea id="message">A &amp; B</textarea><select id="choice"><option label="1" value="one" selected="true"/>
<option label="2" value="two"/></select><button id="send" label="Enviar" href="/revival/submit/echo"/>
</form></jcl>]=]
local form=jcl.parse(xml).forms[1]
local button=form.items[4]
local props=submit.collect(form,button)
eq(props.nickname,'abc');eq(props.message,'A & B');eq(props.choice,'one');eq(props.submitId,'send')
form.items[3].selected=2
eq(submit.collect(form,button).choice,'two')
form.items[1].value='≤ 🙂 <&"\''
props=submit.collect(form,button)
eq(props.nickname,'≤ 🙂 <&"\'')
local kind='P'
local bytes=protocol.encodeRequest(kind,'/revival/submit/echo',props,'')
local decoded=protocol.decodeRequest(bytes)
eq(decoded.kind,'P');eq(decoded.properties.nickname,props.nickname)
local ok=routes.handle(decoded,'')
eq(ok.ok,true)
local parsed=jcl.parse(ok.payload)
eq(parsed.forms[1].id,'result')
eq(parsed.forms[1].items[2].label,'Apelido: ≤ 🙂 <&"\'')
local reply=protocol.decodeReply(protocol.encodeReply('R',decoded.path,{ok='true'},ok.payload))
eq(reply.path,decoded.path)
eq(reply.kind,'R')
local nextpage=routes.handle({kind='O',path='/revival/page/submit',properties={},payload=''},'')
eq(nextpage.ok,true)
local shown=jcl.parse(nextpage.payload)
eq(shown.forms[1].id,'remote')
eq(shown.forms[1].items[5].href,'/revival/submit/echo')
local ping=routes.handle({kind='O',path='/revival/ping',properties={},payload=''},'testpage')
eq(ping.payload,'PONG')
eq(routes.handle({kind='O',path='/revival/page/lab',properties={},payload=''},'testpage').payload,'testpage')
eq(routes.handle({kind='O',path='/revival/submit/echo',properties=props,payload=''}).ok,false)
eq(routes.handle({kind='P',path='/revival/submit/echo',properties=props,payload='bad'}).ok,false)
eq(routes.handle({kind='P',path='/revival/submit/echo',properties={submitId='send',choice='bad'},payload=''}).ok,false)
eq(routes.handle({kind='P',path='/revival/submit/echo',properties={submitId='send',choice='one',hack='x'},payload=''}).ok,false)
eq(routes.handle({kind='P',path='/revival/submit/echo',properties={submitId='send',choice='one',message='\0'},payload=''}).ok,false)
eq(routes.handle({kind='O',path='socket://l2.iatv-be.de:5190',properties={},payload=''},'').ok,false)
form.items[1].id='submitId';rejects(function() submit.collect(form,button) end)
form.items[1].id='bad key';rejects(function() submit.collect(form,button) end)
form.items[1].id='nickname';form.items[2].id='nickname';rejects(function() submit.collect(form,button) end)
form.items[2].id='message';form.items[1].value=string.rep('é',1100);rejects(function() submit.collect(form,button) end)
form.items[1].value='ok';rejects(function() submit.collect(form,{id='bad id'}) end)
local d=view.new(jcl.parse(xml))
view.move(d,1);view.activate(d);d.selected=3;view.activate(d)
eq(submit.collect(view.form(d),button).choice,'two')
print(('OK: %d laboratory submit checks'):format(checks))
