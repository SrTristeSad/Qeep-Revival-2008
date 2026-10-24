-- Registration/login/session bridge, synthetic JCL only.
package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local accountStore=require('account_store')
local social=require('social_routes')
local jcl=require('lib.jcl')
local choices=0
local function ck(b,m) assert(b,m or ('check '..(choices+1)));choices=choices+1 end
local path='server/data/phase12_routes_test.db'
os.remove(path);os.remove(path..'.tmp')
local db=assert(accountStore.new(path))
social.configure_accounts(db)
local function req(kind,route,props)
 return social.handle({kind=kind,path=route,properties=props or {},payload=''})
end
local function ok(kind,route,props)
 local result=req(kind,route,props)
 ck(result.ok,result.payload)
 return jcl.parse(result.payload)
end
local start=ok('O','/revival/social/start')
local hasRegister,hasLogin=false,false
for _,item in ipairs(start.forms[1].items) do
 if item.href=='/revival/social/register' then hasRegister=true end
 if item.href=='/revival/social/login' then hasLogin=true end
end
ck(hasRegister and hasLogin,'welcome options')
ck(ok('O','/revival/social/register').forms[1].id=='register')
local login=ok('O','/revival/social/login')
ck(login.forms[1].id=='login')
local secretField
for _,item in ipairs(login.forms[1].items) do if item.id=='accessCode' then secretField=item end end
ck(secretField and secretField.secret,'secret must be masked')
ck(not req('P','/revival/social/register/submit',{username='Abc',submitId='register'}).ok)
ck(not req('P','/revival/social/register/submit',{username='alex22',submitId='register',hacker='evil'}).ok)
local created=ok('P','/revival/social/register/submit',{username='alex22',submitId='register'})
ck(created.forms[1].id=='credentials')
local session=created.props.guestSession
ck(type(session)=='string' and #session==48)
local secret
for _,item in ipairs(created.forms[1].items) do
 if item.kind=='p' and (item.label or ''):match('^[0-9a-f]+$') and #item.label==48 then secret=item.label end
end
ck(secret~=nil,'access code disclosed exactly at registration')
local reloaded=assert(accountStore.new(path))
ck(accountStore.verify(reloaded,'alex22',secret))
social.configure_accounts(reloaded)
ck(not req('P','/revival/social/register/submit',{username='alex22',submitId='register'}).ok)
ck(not req('P','/revival/social/login/submit',{username='alex22',accessCode='wrong',submitId='login'}).ok)
ck(not req('P','/revival/social/login/submit',{username='alex22',accessCode=secret,submitId='login',evil='x'}).ok)
local home=ok('P','/revival/social/login/submit',{username='alex22',accessCode=secret,submitId='login'})
ck(home.forms[1].id=='home' and home.props.guestSession~=session)
local logged=home.props.guestSession
ck(ok('O','/revival/social/home',{session=logged}).forms[1].id=='home')
local loggedOut=ok('O','/revival/social/logout',{session=logged})
ck(loggedOut.props.sessionClear=='true')
ck(not req('O','/revival/social/home',{session=logged}).ok)
ck(req('O','/revival/social/home',{session=session}).ok)
local visitor=ok('P','/revival/social/join',{nickname='Pessoa <teste>',submitId='join'})
ck(visitor.props.guestSession~=nil)
ck(ok('O','/revival/social/people',{session=session}).forms[1].id=='people')
os.remove(path);os.remove(path..'.tmp')
print(('OK: %d account social route checks'):format(choices))
