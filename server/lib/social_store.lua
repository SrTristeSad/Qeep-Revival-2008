-- Phase 13: private-LAN, file-backed social contacts and direct messages.
-- This is a new Revival service, NOT a reconstruction of Qeep's remote database.
-- One server process owns this file. Atomic rename and rollback on write failure.
local accounts=require('account_store')
local utf8edit=require('utf8_edit')
local M={}
local HEADER='QEEP_REVIVAL_SOCIAL_1\n'
local MAX_MESSAGES,MAX_CONTACTS,MAX_REQUESTS,MAX_BYTES=1500,100,100,4194304
local function pair(a,b)
  if a>b then a,b=b,a end
  return a..'\0'..b
end
local function valid_message(s)
  return type(s)=='string' and #s>0 and #s<=960 and
    not s:find('[%z\1-\8\11\12\14-\31]') and
    utf8edit.count(s)~=nil and utf8edit.count(s)<=240
end
local function hex(s) return (s:gsub('.',function(c) return ('%02x'):format(c:byte()) end)) end
local function unhex(s)
  if #s%2~=0 or s:find('[^0-9a-f]') then return nil end
  return (s:gsub('..',function(c) return string.char(tonumber(c,16)) end))
end
local function clone(db)
  local copy={requests={},contacts={},messages={},sequence=db.sequence}
  for k,v in pairs(db.requests) do copy.requests[k]=v end
  for k,v in pairs(db.contacts) do copy.contacts[k]=v end
  for i,v in ipairs(db.messages) do copy.messages[i]=v end
  return copy
end
local function serialize(db)
  local rows={HEADER:sub(1,-2)}
  local requests={}
  for k,v in pairs(db.requests) do requests[#requests+1]={k,v} end
  table.sort(requests,function(a,b) return a[1]<b[1] end)
  for _,item in ipairs(requests) do
    local from,to=item[1]:match('^([^\0]+)\0([^\0]+)$')
    rows[#rows+1]='R\t'..from..'\t'..to
  end
  local contacts={}
  for k in pairs(db.contacts) do contacts[#contacts+1]=k end
  table.sort(contacts)
  for _,k in ipairs(contacts) do
    local a,b=k:match('^([^\0]+)\0([^\0]+)$')
    rows[#rows+1]='C\t'..a..'\t'..b
  end
  for _,v in ipairs(db.messages) do
    rows[#rows+1]=table.concat({'M',v.seq,v.from,v.to,hex(v.text)},'\t')
  end
  return table.concat(rows,'\n')..'\n'
end
local function save(db,state)
  local raw=serialize(state)
  if #raw>MAX_BYTES then return nil,'Armazenamento social atingiu o limite de tamanho' end
  local temp=db.path..'.tmp'
  local f,err=io.open(temp,'wb')
  if not f then return nil,'Arquivo social indisponível: '..tostring(err) end
  local wrote,writeErr=f:write(raw)
  local closed,closeErr=f:close()
  if not wrote or not closed then os.remove(temp);return nil,'Erro ao gravar: '..tostring(writeErr or closeErr) end
  local moved,renameErr=os.rename(temp,db.path)
  if not moved then os.remove(temp);return nil,'Erro ao salvar dados: '..tostring(renameErr) end
  db.contacts,db.requests,db.messages,db.sequence=state.contacts,state.requests,state.messages,state.sequence
  return true
end
local function parse(path)
  local f=io.open(path,'rb')
  if not f then
    local probe=io.open(path..'.tmp','wb')
    if not probe then return nil,'Pasta social ausente ou não gravável' end
    probe:close();os.remove(path..'.tmp')
    return {contacts={},requests={},messages={},sequence=0}
  end
  local raw=f:read(MAX_BYTES+1);local more=f:read(1);f:close()
  if not raw or more or #raw>MAX_BYTES or raw:sub(1,#HEADER)~=HEADER or raw:sub(-1)~='\n' then
    return nil,'Arquivo social inválido ou grande demais'
  end
  local db={contacts={},requests={},messages={},sequence=0}
  for line in raw:sub(#HEADER+1):gmatch('([^\n]+)\n') do
    local kind=line:sub(1,1)
    if kind=='R' or kind=='C' then
      local a,b=line:match('^[RC]\t([a-z][a-z0-9_]*)\t([a-z][a-z0-9_]*)$')
      if not accounts.allowed(a) or not accounts.allowed(b) or a==b then
        return nil,'Registro de contato inválido'
      end
      if kind=='R' then
        if db.requests[a..'\0'..b] then return nil,'Solicitação duplicada' end
        db.requests[a..'\0'..b]=true
      else
        if a>b or db.contacts[pair(a,b)] then return nil,'Contato duplicado ou desordenado' end
        db.contacts[pair(a,b)]=true
      end
    elseif kind=='M' then
      local seq,from,to,encoded=line:match('^M\t(%d+)\t([a-z][a-z0-9_]*)\t([a-z][a-z0-9_]*)\t([0-9a-f]+)$')
      local number=tonumber(seq or '')
      local body=encoded and unhex(encoded)
      if not number or number<=db.sequence or number>9007199254740991 or
        not accounts.allowed(from) or not accounts.allowed(to) or from==to or
        not valid_message(body) or #db.messages>=MAX_MESSAGES then return nil,'Mensagem social inválida' end
      db.messages[#db.messages+1]={seq=number,from=from,to=to,text=body}
      db.sequence=number
    else return nil,'Registro social desconhecido' end
  end
  -- Reject persisted states that exceed runtime quotas or violate link invariants.
  for k in pairs(db.contacts) do
    local a,b=k:match('^([^\0]+)\0([^\0]+)$')
    if db.requests[a..'\0'..b] or db.requests[b..'\0'..a] then
      return nil,'Contato e solicitação conflitantes'
    end
  end
  return db
end
function M.new(path)
  assert(type(path)=='string' and #path>0)
  local db,err=parse(path)
  if not db then return nil,err end
  db.path=path
  return db
end
local function count_for(db,field,username)
  local count=0
  for k in pairs(db[field]) do
    local a,b=k:match('^([^\0]+)\0([^\0]+)$')
    if a==username or b==username then count=count+1 end
  end
  return count
end
function M.is_contact(db,a,b)
  return type(a)=='string' and type(b)=='string' and a~=b and db.contacts[pair(a,b)]==true
end
function M.list(db,username)
  local contacts,pending,sent={},{},{}
  for k in pairs(db.contacts) do
    local a,b=k:match('^([^\0]+)\0([^\0]+)$')
    if a==username then contacts[#contacts+1]=b
    elseif b==username then contacts[#contacts+1]=a end
  end
  for k in pairs(db.requests) do
    local a,b=k:match('^([^\0]+)\0([^\0]+)$')
    if b==username then pending[#pending+1]=a
    elseif a==username then sent[#sent+1]=b end
  end
  table.sort(contacts);table.sort(pending);table.sort(sent)
  return contacts,pending,sent
end
function M.request(db,from,to)
  if not accounts.allowed(from) or not accounts.allowed(to) or from==to then return nil,'Contato inválido' end
  if M.is_contact(db,from,to) then return nil,'Já são contatos' end
  if db.requests[from..'\0'..to] or db.requests[to..'\0'..from] then return nil,'Solicitação já existente' end
  if count_for(db,'requests',from)>=MAX_REQUESTS or count_for(db,'requests',to)>=MAX_REQUESTS then return nil,'Limite de solicitações' end
  local state=clone(db);state.requests[from..'\0'..to]=true
  return save(db,state)
end
function M.answer(db,recipient,sender,accept)
  if not accounts.allowed(recipient) or not accounts.allowed(sender) or not db.requests[sender..'\0'..recipient] then return nil,'Solicitação não encontrada' end
  if accept and (count_for(db,'contacts',recipient)>=MAX_CONTACTS or count_for(db,'contacts',sender)>=MAX_CONTACTS) then return nil,'Limite de contatos' end
  local state=clone(db);state.requests[sender..'\0'..recipient]=nil
  if accept then state.contacts[pair(sender,recipient)]=true end
  return save(db,state)
end
function M.send(db,from,to,message)
  if not M.is_contact(db,from,to) then return nil,'Somente contatos aprovados podem trocar mensagens' end
  if not valid_message(message) then return nil,'Mensagem inválida' end
  local state=clone(db)
  state.sequence=state.sequence+1
  state.messages[#state.messages+1]={seq=state.sequence,from=from,to=to,text=message}
  if #state.messages>MAX_MESSAGES then table.remove(state.messages,1) end
  local ok,err=save(db,state)
  if not ok then return nil,err end
  return state.sequence
end
function M.thread(db,a,b)
  if not M.is_contact(db,a,b) then return nil,'Contato não aprovado' end
  local matches={};local revision=0
  for _,v in ipairs(db.messages) do
    if (v.from==a and v.to==b) or (v.from==b and v.to==a) then
      revision=v.seq
      matches[#matches+1]=v
      if #matches>12 then table.remove(matches,1) end
    end
  end
  return matches,revision
end
return M
