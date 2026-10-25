package.path='client/?.lua;client/lib/?.lua;server/lib/?.lua;'..package.path
local social=require('social_routes')
local account=require('account_store')
local store=require('social_store')
local jcl=require('lib.jcl')
local checks=0
local function ck(cond,msg) assert(cond,msg or ('check '..(checks+1)));checks=checks+1 end
local dbPath='server/data/phase13_accounts_test.db'
local socialPath='server/data/phase13_contacts_test.db'
for _,p in ipairs({dbPath,socialPath}) do os.remove(p);os.remove(p..'.tmp') end
local accounts=assert(account.new(dbPath))
social.configure_accounts(accounts)
local durable=assert(store.new(socialPath));social.configure_social(durable)
local function send(kind,path,props)
 return social.handle({kind=kind,path=path,payload='',properties=props or {}})
end
local function ok(kind,path,props)
 local r=send(kind,path,props);ck(r.ok,r.payload)
 return jcl.parse(r.payload)
end
local function register(name)
 local pg=ok('P','/revival/social/register/submit',{username=name,submitId='register'})
 return pg.props.guestSession
end
local alice=register('alice');local bia=register('beatriz')
local visitor=ok('P','/revival/social/join',{nickname='Visitante',submitId='join'}).props.guestSession
ck(not send('O','/revival/social/contacts',{session=visitor}).ok,'guest cannot access registered contacts')
local a=ok('O','/revival/social/home',{session=alice})
local hasContacts=false
for _,v in ipairs(a.forms[1].items) do if v.href=='/revival/social/contacts' then hasContacts=true end end
ck(hasContacts,'registered account has contacts link')
ck(ok('O','/revival/social/contacts',{session=alice}).forms[1].id=='contacts')
ck(not send('P','/revival/social/contact/request',{session=alice,submitId='request',contact='missing'}).ok)
ck(not send('P','/revival/social/contact/request',{session=alice,submitId='request',contact='beatriz',evil='1'}).ok)
ck(not send('O','/revival/social/contact/request',{session=alice,submitId='request',contact='beatriz'}).ok)
ck(ok('P','/revival/social/contact/request',{session=alice,submitId='request',contact='beatriz'}).forms[1].id=='contacts')
ck(not send('O','/revival/social/account/chat/beatriz',{session=alice}).ok,'no chat before approval')
ck(not send('P','/revival/social/contact/accept/alice',{session=alice,submitId='accept'}).ok,'request must belong to receiver')
ck(not send('O','/revival/social/contact/accept/alice',{session=bia,submitId='accept'}).ok,'approval must POST')
local contacts=ok('O','/revival/social/contacts',{session=bia})
local accepts=false
for _,item in ipairs(contacts.forms[1].items) do
 if item.href=='/revival/social/contact/accept/alice' then accepts=true end
end
ck(accepts,'recipient has approval control')
ck(ok('P','/revival/social/contact/accept/alice',{session=bia,submitId='accept'}).forms[1].id=='contacts')
local chat=ok('O','/revival/social/account/chat/beatriz',{session=alice})
ck(chat.forms[1].id=='chat' and chat.props.chatPeer=='beatriz' and chat.props.chatRevision=='0')
ck(not send('P','/revival/social/account/send/beatriz',{session=visitor,submitId='send',message='hack'}).ok)
ck(not send('P','/revival/social/account/send/beatriz',{session=alice,submitId='send',message='X',evil='1'}).ok)
ck(ok('P','/revival/social/account/send/beatriz',{session=alice,submitId='send',message='Oi, Bia! <3'}).props.chatRevision=='1')
local reply=ok('O','/revival/social/account/chat/alice',{session=bia})
ck(reply.props.chatRevision=='1')
local present=false
for _,item in ipairs(reply.forms[1].items) do if (item.label or ''):find('Oi, Bia! <3',1,true) then present=true end end
ck(present,'messages correctly escaped in XML')
local poll=send('O','/revival/social/account/poll/alice',{session=bia,since='1'})
ck(poll.ok and poll.unchanged==true)
ck(not send('O','/revival/social/account/poll/alice',{session=bia,since='-1'}).ok)
ck(not send('O','/revival/social/account/poll/alice',{session=bia,since='1',hack='x'}).ok)
local persisted=assert(store.new(socialPath))
social.configure_social(persisted)
local chat2=ok('O','/revival/social/account/chat/beatriz',{session=alice})
ck(chat2.props.chatRevision=='1','after server social reload')
ck(ok('P','/revival/social/account/send/alice',{session=bia,submitId='send',message='Olá de volta'}).props.chatRevision=='2')
ck(not send('O','/revival/social/account/chat/intruso',{session=alice}).ok)
local visitors=ok('O','/revival/social/people',{session=visitor})
ck(visitors.forms[1].id=='people','visitor mode unchanged')
for _,p in ipairs({dbPath,socialPath}) do os.remove(p);os.remove(p..'.tmp') end
print(('OK: %d account contact/chat route checks'):format(checks))
