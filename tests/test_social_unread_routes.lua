package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local route=require('social_routes')
local accounts=require('account_store')
local social=require('social_store')
local jcl=require('lib.jcl')
local aPath='server/data/phase14_account_routes_test.db'
local sPath='server/data/phase14_social_routes_test.db'
for _,p in ipairs({aPath,sPath}) do os.remove(p);os.remove(p..'.tmp') end
local acc=assert(accounts.new(aPath));route.configure_accounts(acc)
local db=assert(social.new(sPath));route.configure_social(db)
local checks=0
local function ck(x,msg) assert(x,msg or ('check '..(checks+1)));checks=checks+1 end
local function call(kind,path,props)
  local reply=route.handle({kind=kind,path=path,properties=props or {},payload=''})
  ck(reply.ok, reply.payload)
  return jcl.parse(reply.payload)
end
local function register(name)
  return call('P','/revival/social/register/submit',{username=name,submitId='register'}).props.guestSession
end
local alice=register('alice'); local bia=register('beatriz')
call('P','/revival/social/contact/request',{session=alice,submitId='request',contact='beatriz'})
call('P','/revival/social/contact/accept/alice',{session=bia,submitId='accept'})
call('P','/revival/social/account/send/alice',{session=bia,submitId='send',message='A primeira'})
call('P','/revival/social/account/send/alice',{session=bia,submitId='send',message='A segunda'})
local contacts=call('O','/revival/social/contacts',{session=alice})
local function hasLabel(doc,fragment)
  for _,item in ipairs(doc.forms[1].items) do
    if (item.label or ''):find(fragment,1,true) then return true end
  end
  return false
end
ck(hasLabel(contacts,'beatriz (2 não lidas)'),'count displayed')
ck(hasLabel(contacts,'não lidas: 2'),'total displayed')
call('O','/revival/social/account/chat/beatriz',{session=alice})
contacts=call('O','/revival/social/contacts',{session=alice})
ck(not hasLabel(contacts,'beatriz (2 não lidas)'),'opening marks read')
ck(hasLabel(contacts,'não lidas: 0'))
call('P','/revival/social/account/send/alice',{session=bia,submitId='send',message='Novidade'})
local poll=route.handle({kind='O',path='/revival/social/account/poll/beatriz',properties={session=alice,since='2'},payload=''})
ck(poll.ok and not poll.unchanged,'poll returns new message')
contacts=call('O','/revival/social/contacts',{session=alice})
ck(hasLabel(contacts,'não lidas: 0'),'poll on active chat marks read')
local unauthorized=route.handle({kind='O',path='/revival/social/account/chat/intruso',properties={session=alice},payload=''})
ck(not unauthorized.ok)
for _,p in ipairs({aPath,sPath}) do os.remove(p);os.remove(p..'.tmp') end
print(('OK: %d unread JCL route checks'):format(checks))
