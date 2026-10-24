-- Local persistent accounts for Qeep Revival's *invented* social laboratory.
-- Access codes are random 192-bit secrets, never user-selected passwords.
-- Only the salted SHA-256 digest is persisted. Not a public internet auth server.
local M={}
local sha=require('sha256')
local MAX_ACCOUNTS=250
local function hex(bytes) return (bytes:gsub('.',function(c) return ('%02x'):format(c:byte()) end)) end
local function secure_bytes(count)
  local f=io.open('/dev/urandom','rb')
  if not f then return nil,'Secure random source unavailable (requires /dev/urandom)' end
  local bytes=f:read(count);f:close()
  if not bytes or #bytes~=count then return nil,'Secure random source returned insufficient bytes' end
  return bytes
end
local function allowed(name)
  return type(name)=='string' and #name>=3 and #name<=24 and
    name:match('^[a-z][a-z0-9_]*$')~=nil
end
local function verify_code(code)
  return type(code)=='string' and #code==48 and code:match('^[0-9a-f]+$')~=nil
end
local function digest(salt,code) return sha.hex('qeep-revival-v1:'..salt..':'..code) end
local function constant_equal(a,b)
  if type(a)~='string' or type(b)~='string' or #a~=#b then return false end
  local diff=0
  for i=1,#a do diff=diff | (a:byte(i) ~ b:byte(i)) end
  return diff==0
end
local function serialize(db)
  local lines={'QEEP_REVIVAL_ACCOUNTS_1'}
  local usernames={}
  for username in pairs(db.records) do usernames[#usernames+1]=username end
  table.sort(usernames)
  for _,username in ipairs(usernames) do
    local r=db.records[username]
    lines[#lines+1]=table.concat({username,r.salt,r.hash},'\t')
  end
  return table.concat(lines,'\n')..'\n'
end
local function load(path)
  local f,err=io.open(path,'rb')
  if not f then
    -- The directory must exist; don't overwrite a damaged database.
    local probe=io.open(path..'.tmp','wb')
    if not probe then return nil,'Account storage directory is missing or not writable' end
    probe:close();os.remove(path..'.tmp')
    return {}
  end
  local raw=f:read(524288);local remainder=f:read(1);f:close()
  if remainder or #raw>524287 then return nil,'Account storage exceeds size limit' end
  if not raw:match('^QEEP_REVIVAL_ACCOUNTS_1\n') then return nil,'Invalid account database header' end
  local result={};local count=0
  for line in raw:sub(#'QEEP_REVIVAL_ACCOUNTS_1\n'+1):gmatch('([^\n]+)\n') do
    local username,salt,hash=line:match('^([^\t]+)\t([^\t]+)\t([^\t]+)$')
    if not allowed(username) or not salt or not salt:match('^[0-9a-f]+$') or #salt~=32
        or not hash or #hash~=64 or not hash:match('^[0-9a-f]+$') or result[username] then
      return nil,'Account database contains invalid or duplicate rows'
    end
    count=count+1
    if count>MAX_ACCOUNTS then return nil,'Account database capacity exceeded' end
    result[username]={salt=salt,hash=hash}
  end
  -- No unparsed/truncated trailing data permitted.
  if raw:sub(-1)~='\n' then return nil,'Account database has truncated row' end
  return result
end
function M.new(path)
  assert(type(path)=='string' and #path>0,'path required')
  local records,err=load(path)
  if not records then return nil,err end
  return {path=path,records=records}
end
function M.register(db,username)
  if not allowed(username) then return nil,'Use 3–24 caracteres: letras minúsculas, números e _; comece com letra.' end
  if db.records[username] then return nil,'Nome de usuário indisponível' end
  local count=0
  for _ in pairs(db.records) do count=count+1 end
  if count>=MAX_ACCOUNTS then return nil,'Limite de contas locais atingido' end
  local secret,err=secure_bytes(24)
  if not secret then return nil,err end
  local salt,err2=secure_bytes(16)
  if not salt then return nil,err2 end
  local code=hex(secret)
  db.records[username]={salt=hex(salt),hash=digest(hex(salt),code)}
  local file,problem=io.open(db.path..'.tmp','wb')
  if not file then db.records[username]=nil;return nil,'Não foi possível abrir arquivo temporário: '..tostring(problem) end
  local success,writeErr=file:write(serialize(db))
  local closed,closeErr=file:close()
  if not success or not closed then
    db.records[username]=nil;os.remove(db.path..'.tmp')
    return nil,'Falha ao gravar conta: '..tostring(writeErr or closeErr)
  end
  local moved,renameErr=os.rename(db.path..'.tmp',db.path)
  if not moved then
    db.records[username]=nil;os.remove(db.path..'.tmp')
    return nil,'Falha ao salvar conta (rename): '..tostring(renameErr)
  end
  return code
end
function M.verify(db,username,code)
  if not allowed(username) or not verify_code(code) then return false end
  local record=db.records[username]
  if not record then return false end
  return constant_equal(record.hash,digest(record.salt,code))
end
function M.session_token()
  local bytes=secure_bytes(24)
  return bytes and hex(bytes) or nil
end
function M.allowed(username) return allowed(username) end
return M
