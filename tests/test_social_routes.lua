-- In-memory social smoke: intentionally invented LAN guest prototype.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local social=require('social_routes')
local jcl=require('lib.jcl')
local count=0
local function ck(value,message) assert(value,message or 'failed');count=count+1 end
local function rq(kind,path,props)
 return social.handle({kind=kind,path=path,properties=props or {},payload=''})
end
local function parse(r)
 ck(r.ok,r.payload)
 return jcl.parse(r.payload)
end
local start=parse(rq('O','/revival/social/start'))
ck(start.forms[1].title:find('laboratório',1,true))
ck(not start.props.guestSession)
ck(not rq('P','/revival/social/join',{nickname='A',submitId='join'}).ok)
ck(not rq('P','/revival/social/join',{nickname='<script>',submitId='join',unexpected='x'}).ok)
ck(not rq('O','/revival/social/people').ok)
local alice=parse(rq('P','/revival/social/join',{nickname='Alíce & <>',submitId='join'}))
local a=alice.props.guestSession
ck(type(a)=='string' and #a>=24)
ck(alice.forms[1].items[1].label=='Olá, Alíce & <>. Você é visitante temporário.')
local bob=parse(rq('P','/revival/social/join',{nickname='Bia',submitId='join'}))
local b=bob.props.guestSession
ck(type(b)=='string' and b~=a)
local ap=parse(rq('O','/revival/social/people',{session=a}))
local bp=parse(rq('O','/revival/social/people',{session=b}))
local bHref,aHref
for _,v in ipairs(ap.forms[1].items) do if v.label=='Bia' then bHref=v.href end end
for _,v in ipairs(bp.forms[1].items) do if v.label=='Alíce & <>' then aHref=v.href end end
ck(bHref~=nil and aHref~=nil)
ck(bHref~=aHref)
local targetId=bHref:match('/(%d+)$')
local chat=parse(rq('O',bHref,{session=a}))
ck(chat.forms[1].title=='Conversa — laboratório')
ck(not rq('O',bHref,{session='bad-token'}).ok)
ck(not rq('P','/revival/social/send/'..targetId,{session=a,submitId='send',message=''}).ok)
ck(not rq('P','/revival/social/send/'..targetId,{session=a,submitId='send',message='oi',evil='1'}).ok)
local sent=parse(rq('P','/revival/social/send/'..targetId,{session=a,submitId='send',message='Oi <Bia> & 😀'}))
local present=false
for _,v in ipairs(sent.forms[1].items) do
 if v.label=='Você: Oi <Bia> & 😀' then present=true end
end
ck(present)
local received=parse(rq('O',aHref,{session=b}))
local found=false
for _,v in ipairs(received.forms[1].items) do
 if v.label=='Alíce & <>: Oi <Bia> & 😀' then found=true end
end
ck(found)
ck(not rq('O','/revival/social/chat/999999',{session=a}).ok)
ck(not rq('P','/revival/social/join',{nickname='Joe',submitId='join',session=a}).ok)
ck(rq('O','/revival/social/home',{session=a}).ok)
ck(not social.handle({kind='O',path='/revival/social/home',properties={session=a},payload='malicious'}).ok)
ck(not rq('P','/revival/social/send/'..targetId,{session=a,submitId='send',message=string.rep('x',241)}).ok)
ck(not rq('P','/revival/social/send/'..targetId,{session=a,submitId='send',message='\255'}).ok)
print(('OK: %d social route checks'):format(count))
