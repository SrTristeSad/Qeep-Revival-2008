-- Fase 9: original ephemeral LAN-only social prototype. NOT historical Qeep backend.
-- No passwords, persistence, encryption, registration or identity verification.
local M = {}
local utf8edit = require('utf8_edit')
local people, sessions, messages = {}, {}, {}
local nextId, messageSequence, MAX_PEOPLE, MAX_MESSAGES, MAX_IDLE = 1, 0, 24, 160, 3600
local function escape(s)
  return (tostring(s):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
    :gsub('"','&quot;'):gsub("'",'&apos;'))
end
local function text_ok(s, maxBytes, maxChars)
  if type(s)~='string' or #s>maxBytes or s:find('[%z\1-\8\11\12\14-\31]') then return false end
  local chars=utf8edit.count(s)
  return chars~=nil and chars<=maxChars
end
local function trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
local function reply_error(message) return {ok=false,payload=message} end
local function xml(title, id, body, token, extra)
  local prop=token and ('<prop n="guestSession" v="'..escape(token)..'"/>') or ''
  for k,v in pairs(extra or {}) do prop=prop..'<prop n="'..escape(k)..'" v="'..escape(v)..'"/>' end
  return '<?xml version="1.0" encoding="UTF-8"?><jcl branding="Revival: social experimental">'..
    prop..'<form id="'..id..'" title="'..escape(title)..'" valign="top">'..body..'</form></jcl>'
end
local function get_person(req)
  local token=(req.properties or {}).session
  if type(token)~='string' or #token>128 then return nil end
  local person=sessions[token]
  if person then
    if os.time()-person.lastSeen>MAX_IDLE then
      sessions[token]=nil;people[person.id]=nil
      return nil
    end
    person.lastSeen=os.time()
  end
  return person
end
local function gen_token()
  -- /dev/urandom on POSIX; fallback is adequate only for NON-SECURE local demo.
  local f=io.open('/dev/urandom','rb')
  if f then
    local bytes=f:read(24);f:close()
    if bytes and #bytes==24 then
      return (bytes:gsub('.',function(c) return ('%02x'):format(c:byte()) end))
    end
  end
  -- Windows fallback: still only a guest identifier, NEVER production auth.
  local parts={}
  for i=1,12 do parts[i]=('%02x'):format(math.random(0,255)) end
  return table.concat(parts)..('%08x'):format(nextId)
end
local function welcome()
  return xml('Visitantes — laboratório','welcome',
    '<p label="Rede social local demonstrativa; NÃO é uma tela recuperada de 2008."/>'..
    '<p label="Sem senha. Apelidos e mensagens se perdem quando o servidor fecha."/>'..
    '<input id="nickname" label="Seu apelido de visitante" value="" len="24"/>'..
    '<button id="join" label="Entrar como visitante" href="/revival/social/join" focused="true"/>'..
    '<lsk label="Voltar" href="/revival/page/lab"/>')
end
local function home(person)
  return xml('Sala social — laboratório','home',
    '<p label="Olá, '..escape(person.name)..'. Você é visitante temporário."/>'..
    '<a label="Pessoas conectadas" href="/revival/social/people" focused="true"/>'..
    '<a label="Atualizar sala" href="/revival/social/home"/>'..
    '<p label="Mensagens não são salvas em disco. Não compartilhe dados pessoais."/>'..
    '<lsk label="Menu de testes" href="/revival/page/lab"/>',person.token)
end
local function people_page(person)
  local parts={
    '<p label="Pessoas conectadas ao mesmo servidor Lua (não são contatos históricos)."/>'
  }
  local count=0
  for id=1,nextId-1 do
    local other=people[id]
    if other and other~=person and os.time()-other.lastSeen<=MAX_IDLE then
      count=count+1
      parts[#parts+1]='<a label="'..escape(other.name)..'" href="/revival/social/chat/'..id..'"/>'
    end
  end
  if count==0 then parts[#parts+1]='<p label="Nenhuma outra pessoa conectada."/>' end
  parts[#parts+1]='<a label="Atualizar" href="/revival/social/people"/>'
  parts[#parts+1]='<lsk label="Voltar" href="/revival/social/home"/>'
  return xml('Pessoas online — laboratório','people',table.concat(parts),person.token)
end
local function chat_page(person, other)
  local parts={
    '<p label="Conversa temporária com '..escape(other.name)..' (somente laboratório)."/>'
  }
  local start=1
  local matches={}
  for i=start,#messages do
    local message=messages[i]
    if (message.from==person.id and message.to==other.id) or
      (message.from==other.id and message.to==person.id) then
      matches[#matches+1]=message
    end
  end
  local revision=matches[#matches] and matches[#matches].sequence or 0
  local first=math.max(1,#matches-11)
  for i=first,#matches do
    local message=matches[i]
    local owner=message.from==person.id and 'Você' or other.name
    parts[#parts+1]='<p label="'..escape(owner..': '..message.text)..'"/>'
  end
  if #matches==0 then parts[#parts+1]='<p label="Ainda não há mensagens."/>' end
  parts[#parts+1]='<textarea id="message" label="Escrever mensagem" len="240"></textarea>'
  parts[#parts+1]='<button id="send" label="Enviar mensagem" href="/revival/social/send/'..other.id..'"/>'
  parts[#parts+1]='<a label="Atualizar conversa" href="/revival/social/chat/'..other.id..'"/>'
  parts[#parts+1]='<lsk label="Pessoas" href="/revival/social/people"/>'
  parts[#parts+1]='<rsk label="Enviar" href="/revival/social/send/'..other.id..'"/>'
  return xml('Conversa — laboratório','chat',table.concat(parts),person.token,
    {chatPeer=tostring(other.id),chatRevision=tostring(revision)})
end
function M.handle(req)
  if type(req)~='table' or type(req.path)~='string' or type(req.kind)~='string' then
    return reply_error('Requisição inválida')
  end
  if type(req.payload)~='string' or req.payload~='' then return reply_error('Payload não permitido') end
  local p=req.path
  if p=='/revival/social/start' and req.kind=='O' then
    return {ok=true,payload=welcome()}
  end
  if p=='/revival/social/join' and req.kind=='P' then
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='nickname' and k~='submitId' and k~='lang' then
        return reply_error('Campo não permitido')
      end
    end
    local name=type(props.nickname)=='string' and trim(props.nickname) or ''
    if props.submitId~='join' or #name<2 or not text_ok(name,80,24) then
      return reply_error('Apelido inválido (2 a 24 caracteres)')
    end
    local active=0
    for _,user in pairs(people) do
      if os.time()-user.lastSeen<=MAX_IDLE then active=active+1 end
    end
    if active>=MAX_PEOPLE then return reply_error('Limite de visitantes atingido') end
    local token=gen_token()
    while sessions[token] do token=gen_token() end
    local person={id=nextId,name=name,token=token,lastSeen=os.time()}
    nextId=nextId+1;people[person.id]=person;sessions[token]=person
    return {ok=true,payload=home(person)}
  end
  local person=get_person(req)
  if not person then return reply_error('Sessão expirada. Volte e entre como visitante.') end
  if req.kind=='O' and p=='/revival/social/home' then return {ok=true,payload=home(person)} end
  if req.kind=='O' and p=='/revival/social/people' then return {ok=true,payload=people_page(person)} end
  local peerid=p:match('^/revival/social/chat/([1-9]%d*)$')
  if peerid and req.kind=='O' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Visitante não encontrado')
    end
    return {ok=true,payload=chat_page(person,other)}
  end
  peerid=p:match('^/revival/social/poll/([1-9]%d*)
  if peerid and req.kind=='P' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Destinatário indisponível')
    end
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='message' and k~='submitId' and k~='lang' and k~='session' then
        return reply_error('Campo não permitido')
      end
    end
    local msg=type(props.message)=='string' and trim(props.message) or ''
    if props.submitId~='send' or #msg==0 or not text_ok(msg,960,240) then
      return reply_error('Mensagem inválida (máximo de 240 caracteres)')
    end
    messageSequence=messageSequence+1
    messages[#messages+1]={from=person.id,to=other.id,text=msg,sequence=messageSequence}
    if #messages>MAX_MESSAGES then table.remove(messages,1) end
    return {ok=true,payload=chat_page(person,other)}
  end
  return reply_error('Rota social desconhecida')
end
return M
)
  if peerid and req.kind=='O' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Destinatário indisponível')
    end
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='session' and k~='since' then return reply_error('Campo não permitido') end
    end
    local since=props.since
    if type(since)~='string' or #since>12 or not since:match('^%d+
  if peerid and req.kind=='P' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Destinatário indisponível')
    end
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='message' and k~='submitId' and k~='lang' and k~='session' then
        return reply_error('Campo não permitido')
      end
    end
    local msg=type(props.message)=='string' and trim(props.message) or ''
    if props.submitId~='send' or #msg==0 or not text_ok(msg,960,240) then
      return reply_error('Mensagem inválida (máximo de 240 caracteres)')
    end
    messages[#messages+1]={from=person.id,to=other.id,text=msg}
    if #messages>MAX_MESSAGES then table.remove(messages,1) end
    return {ok=true,payload=chat_page(person,other)}
  end
  return reply_error('Rota social desconhecida')
end
return M
) then
      return reply_error('Revisão inválida')
    end
    local revision=0
    for _,message in ipairs(messages) do
      if (message.from==person.id and message.to==other.id) or
        (message.from==other.id and message.to==person.id) then
        revision=message.sequence
      end
    end
    if tonumber(since)==revision then return {ok=true,unchanged=true,payload=''} end
    return {ok=true,payload=chat_page(person,other)}
  end
  peerid=p:match('^/revival/social/send/([1-9]%d*)
  if peerid and req.kind=='P' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Destinatário indisponível')
    end
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='message' and k~='submitId' and k~='lang' and k~='session' then
        return reply_error('Campo não permitido')
      end
    end
    local msg=type(props.message)=='string' and trim(props.message) or ''
    if props.submitId~='send' or #msg==0 or not text_ok(msg,960,240) then
      return reply_error('Mensagem inválida (máximo de 240 caracteres)')
    end
    messages[#messages+1]={from=person.id,to=other.id,text=msg}
    if #messages>MAX_MESSAGES then table.remove(messages,1) end
    return {ok=true,payload=chat_page(person,other)}
  end
  return reply_error('Rota social desconhecida')
end
return M
)
  if peerid and req.kind=='P' then
    local other=people[tonumber(peerid)]
    if not other or other==person or os.time()-other.lastSeen>MAX_IDLE then
      return reply_error('Destinatário indisponível')
    end
    local props=req.properties or {}
    for k in pairs(props) do
      if k~='message' and k~='submitId' and k~='lang' and k~='session' then
        return reply_error('Campo não permitido')
      end
    end
    local msg=type(props.message)=='string' and trim(props.message) or ''
    if props.submitId~='send' or #msg==0 or not text_ok(msg,960,240) then
      return reply_error('Mensagem inválida (máximo de 240 caracteres)')
    end
    messages[#messages+1]={from=person.id,to=other.id,text=msg}
    if #messages>MAX_MESSAGES then table.remove(messages,1) end
    return {ok=true,payload=chat_page(person,other)}
  end
  return reply_error('Rota social desconhecida')
end
return M
