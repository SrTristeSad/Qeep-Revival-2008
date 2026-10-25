package.path='server/lib/?.lua;client/lib/?.lua;'..package.path
local store=require('social_store')
local root='server/data/phase14_unread_test.db'
local function clean() os.remove(root);os.remove(root..'.tmp') end
clean()
local checks=0
local function ck(x,msg) assert(x,msg or ('check '..(checks+1)));checks=checks+1 end
local db=assert(store.new(root))
local function connect(a,b)
  assert(store.request(db,a,b)); assert(store.answer(db,b,a,true))
end
connect('alice','beatriz');connect('alice','carla')
local function summaries(user)
  local result={}
  for _,row in ipairs(store.summaries(db,user)) do result[row.name]=row end
  return result
end
ck(#store.summaries(db,'alice')==2)
ck(summaries('alice').beatriz.unread==0)
ck(assert(store.send(db,'beatriz','alice','oi'))==1)
ck(summaries('alice').beatriz.unread==1)
ck(summaries('beatriz').alice.unread==0,'own message never unread')
ck(assert(store.send(db,'alice','beatriz','olá'))==2)
ck(summaries('alice').beatriz.unread==1,'reply does not clear unread')
ck(assert(store.send(db,'carla','alice','uma'))==3)
ck(assert(store.send(db,'carla','alice','duas'))==4)
ck(summaries('alice').carla.unread==2)
local order=store.summaries(db,'alice')
ck(order[1].name=='carla' and order[2].name=='beatriz','recent activity first')
ck(store.mark_read(db,'alice','beatriz'))
ck(summaries('alice').beatriz.unread==0)
ck(summaries('alice').carla.unread==2,'independent cursors')
ck(store.mark_read(db,'alice','beatriz'),'idempotent read')
ck(not store.mark_read(db,'alice','intruso'),'read requires contact')
local reopened=assert(store.new(root));db=reopened
ck(summaries('alice').beatriz.unread==0,'read cursor persisted')
ck(summaries('alice').carla.unread==2,'other unread persisted')
ck(assert(store.send(db,'beatriz','alice','mensagem posterior'))==5)
ck(summaries('alice').beatriz.unread==1,'new incoming unread after cursor')
ck(store.mark_read(db,'alice','carla'))
ck(store.mark_read(db,'alice','beatriz'))
ck(summaries('alice').beatriz.unread==0 and summaries('alice').carla.unread==0)
local f=assert(io.open(root,'rb'));local raw=f:read('*a');f:close()
ck(raw:find('QEEP_REVIVAL_SOCIAL_2\n',1,true)==1)
ck(raw:find('L\talice\tbeatriz\t5\n',1,true)~=nil,'read marker serialized')
-- Version 1 files must migrate automatically on the next write without deleting messages.
local v1=raw:gsub('QEEP_REVIVAL_SOCIAL_2','QEEP_REVIVAL_SOCIAL_1',1):gsub('L\t[^\n]*\n','')
f=assert(io.open(root,'wb'));assert(f:write(v1));f:close()
db=assert(store.new(root))
ck(summaries('alice').beatriz.unread==2,'v1 defaults to unread')
ck(store.mark_read(db,'alice','beatriz'))
f=assert(io.open(root,'rb'));raw=f:read('*a');f:close()
ck(raw:find('QEEP_REVIVAL_SOCIAL_2\n',1,true)==1,'migrated to v2')
ck(#(assert(store.thread(db,'alice','beatriz')))==3,'all old messages survived')
-- Malformed or unauthorized persisted read markers must reject the database.
local bad=raw:gsub('L\talice\tbeatriz\t5\n','L\talice\tintruso\t5\n',1)
f=assert(io.open(root,'wb'));assert(f:write(bad));f:close()
ck(store.new(root)==nil,'reject orphan cursor')
clean()
print(('OK: %d persistent unread checks'):format(checks))
