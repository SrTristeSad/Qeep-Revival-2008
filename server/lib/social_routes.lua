-- Invented LAN-only social prototype, NOT the historical Qeep backend.
-- Phase 13: durable account contacts and chats; guest chats remain ephemeral.
local M = {}
local utf8edit = require('utf8_edit')
local people, sessions, messages = {}, {}, {}
local accountStore, socialStore = nil, nil
local accountLib = require('account_store')
function M.configure_accounts(store) accountStore=store end
function M.configure_social(store) socialStore=store end
local socialLib=require('social_store')
local allowed
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
    '<p label="Visitantes e mensagens se perdem quando o servidor fecha."/>'..
    '<input id="nickname" label="Seu apelido de visitante" value="" len="24"/>'..
    '<button id="join" label="Entrar como visitante" href="/revival/social/join" focused="true"/>'..
    '<a label="Criar conta local (laboratório)" href="/revival/social/register"/>'..
    '<a label="Entrar com código de acesso" href="/revival/social/login"/>'..
    '<lsk label="Voltar" href="/revival/page/lab"/>')
end
local function home(person)
  local unread=0
  if person.account and socialStore then
    for _,row in ipairs(socialLib.summaries(socialStore,person.account)) do unread=unread+row.unread end
  end
  return xml('Sala social — laboratório','home',
    '<p label="Olá, '..escape(person.name)..'. '..(person.account and 'Conta local persistente.' or 'Você é visitante temporário.')..'"/>'..
    '<a label="Pessoas conectadas" href="/revival/social/people" focused="true"/>'..
    (person.account and '<a label="Meus contatos e mensagens salvas ('..unread..' não lidas)" href="/revival/social/contacts"/>' or '')..
    '<a label="Atualizar sala" href="/revival/social/home"/>'..
    (person.account and '<p label="Mensagens da conta ficam no disco local, sem criptografia."/>' or '<p label="Mensagens de visitantes não são salvas em disco."/>')..
    '<a label="Encerrar sessão" href="/revival/social/logout"/>'..
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
-- Durable account features use account usernames, not per-process visitor IDs.
local function contacts_page(person)
  local contacts,pending,sent=socialLib.list(socialStore,person.account)
  local summaries=socialLib.summaries(socialStore,person.account)
  local unreadTotal=0
  for _,row in ipairs(summaries) do unreadTotal=unreadTotal+row.unread end
  local parts={
    '<p label="Contatos persistentes (função nova do Revival, não Qeep original)."/>',
    '<p label="Os pedidos precisam ser aprovados para habilitar mensagens."/>',
    '<input id="contact" label="Nome de usuário para convidar" len="24"/>',
    '<button id="request" label="Enviar solicitação" href="/revival/social/contact/request"/>'
  }
  parts[#parts+1]='<p label="Conversas (não lidas: '..unreadTotal..'):"/>'
  for _,row in ipairs(summaries) do
    local label=row.name
    if row.unread>0 then label=label..' ('..row.unread..' não lidas)' end
    parts[#parts+1]='<a label="'..escape(label)..'" href="/revival/social/account/chat/'..row.name..'"/>'
  end
  if #contacts==0 then parts[#parts+1]='<p label="Nenhum contato aprovado."/>' end
  parts[#parts+1]='<p label="Solicitações recebidas:"/>'
  for _,name in ipairs(pending) do
    parts[#parts+1]='<p label="'..escape(name)..' deseja adicionar você"/>'
    parts[#parts+1]='<button id="accept" label="Aceitar '..escape(name)..'" href="/revival/social/contact/accept/'..name..'"/>'
    parts[#parts+1]='<button id="reject" label="Recusar '..escape(name)..'" href="/revival/social/contact/reject/'..name..'"/>'
  end
  if #pending==0 then parts[#parts+1]='<p label="Nenhuma solicitação recebida."/>' end
  parts[#parts+1]='<p label="Solicitações enviadas: '..escape(table.concat(sent,', '))..'"/>'
  parts[#parts+1]='<a label="Atualizar" href="/revival/social/contacts"/>'
  parts[#parts+1]='<lsk label="Sala social" href="/revival/social/home"/>'
  return xml('Contatos — laboratório','contacts',table.concat(parts),person.token)
end
local function stored_chat_page(person,username)
  local messages,revision=socialLib.thread(socialStore,person.account,username)
  if not messages then return nil,revision end
  local readOk,readErr=socialLib.mark_read(socialStore,person.account,username)
  if not readOk then return nil,readErr end
  local parts={'<p label="Chat persistente com '..escape(username)..' (Revival experimental)."/>'}
  for _,m in ipairs(messages) do
    parts[#parts+1]='<p label="'..escape((m.from==person.account and 'Você' or username)..': '..m.text)..'"/>'
  end
  if #messages==0 then parts[#parts+1]='<p label="Nenhuma mensagem salva."/>' end
  parts[#parts+1]='<textarea id="message" label="Escrever mensagem" len="240"></textarea>'
  parts[#parts+1]='<button id="send" label="Enviar" href="/revival/social/account/send/'..username..'"/>'
  parts[#parts+1]='<a label="Atualizar conversa" href="/revival/social/account/chat/'..username..'"/>'
  parts[#parts+1]='<lsk label="Contatos" href="/revival/social/contacts"/>'
  parts[#parts+1]='<rsk label="Enviar" href="/revival/social/account/send/'..username..'"/>'
  return xml('Conversa — laboratório','chat',table.concat(parts),person.token,
    {chatPeer=username,chatRevision=tostring(revision)})
end
local function account_route(person,req)
  if not person.account then return reply_error('Entre em uma conta para usar contatos persistentes') end
  if not accountStore or not socialStore then return reply_error('Armazenamento de contatos indisponível') end
  local path,props=req.path,req.properties or {}
  if path=='/revival/social/contacts' and req.kind=='O' then
    return {ok=true,payload=contacts_page(person)}
  end
  if path=='/revival/social/contact/request' and req.kind=='P' then
    if not allowed(props,{contact=true,submitId=true,lang=true,session=true}) or props.submitId~='request' then
      return reply_error('Campos inválidos')
    end
    local recipient=props.contact
    if not accountLib.allowed(recipient) or not accountStore.records[recipient] then return reply_error('Conta não encontrada') end
    local ok,err=socialLib.request(socialStore,person.account,recipient)
    if not ok then return reply_error(err) end
    return {ok=true,payload=contacts_page(person)}
  end
  local action,user=path:match('^/revival/social/contact/(%a+)/([a-z][a-z0-9_]*)$')
  if (action=='accept' or action=='reject') and req.kind=='P' then
    if not allowed(props,{contact=true,submitId=true,lang=true,session=true}) or props.submitId~=action then
      return reply_error('Confirmação inválida')
    end
    local ok,err=socialLib.answer(socialStore,person.account,user,action=='accept')
    if not ok then return reply_error(err) end
    return {ok=true,payload=contacts_page(person)}
  end
  local kind,peer=path:match('^/revival/social/account/(%a+)/([a-z][a-z0-9_]*)$')
  if kind=='chat' and req.kind=='O' then
    local page,err=stored_chat_page(person,peer)
    if not page then return reply_error(err) end
    return {ok=true,payload=page}
  elseif kind=='poll' and req.kind=='O' then
    if not allowed(props,{session=true,since=true}) then return reply_error('Campos inválidos') end
    if type(props.since)~='string' or #props.since>16 or not props.since:match('^%d+$') then
      return reply_error('Revisão inválida')
    end
    local _,revision=socialLib.thread(socialStore,person.account,peer)
    if not revision then return reply_error('Contato não aprovado') end
    if tonumber(props.since)==revision then return {ok=true,unchanged=true,payload=''} end
    local page,err=stored_chat_page(person,peer)
    if not page then return reply_error(err) end
    return {ok=true,payload=page}
  elseif kind=='send' and req.kind=='P' then
    if not allowed(props,{message=true,submitId=true,lang=true,session=true}) or props.submitId~='send' then
      return reply_error('Campos de envio inválidos')
    end
    local msg=type(props.message)=='string' and trim(props.message) or ''
    local seq,err=socialLib.send(socialStore,person.account,peer,msg)
    if not seq then return reply_error(err) end
    local page,err=stored_chat_page(person,peer)
    if not page then return reply_error(err) end
    return {ok=true,payload=page}
  end
  return reply_error('Ação de conta não permitida')
end
local function register_page()
  return xml('Criar conta local — laboratório','register',
    '<p label="Serviço de teste local. Sem TLS. Não use dados pessoais."/>'..
    '<p label="Você receberá um código aleatório de acesso, mostrado uma única vez."/>'..
    '<input id="username" label="Usuário: 3–24 letras minúsculas, números e _" len="24"/>'..
    '<button id="register" label="Criar conta" href="/revival/social/register/submit"/>'..
    '<lsk label="Voltar" href="/revival/social/start"/>')
end
local function login_page()
  return xml('Entrar na conta local — laboratório','login',
    '<p label="Somente rede local de teste, sem criptografia de transporte."/>'..
    '<input id="username" label="Nome de usuário" len="24"/>'..
    '<input id="accessCode" label="Código de acesso (48 caracteres)" len="48" secret="true"/>'..
    '<button id="login" label="Entrar" href="/revival/social/login/submit"/>'..
    '<lsk label="Voltar" href="/revival/social/start"/>')
end
local function active_count()
  local count=0
  for id,person in pairs(people) do
    if os.time()-person.lastSeen>MAX_IDLE then
      sessions[person.token]=nil;people[id]=nil
    else count=count+1 end
  end
  return count
end
local function new_person(name,account)
  if active_count()>=MAX_PEOPLE then return nil,'Limite de usuários online atingido' end
  local token
  if account then
    token=accountLib.session_token()
    if not token then return nil,'Fonte de aleatoriedade segura indisponível' end
  else token=gen_token() end
  while sessions[token] do
    token=account and accountLib.session_token() or gen_token()
    if not token then return nil,'Fonte de aleatoriedade segura indisponível' end
  end
  local person={id=nextId,name=name,account=account,token=token,lastSeen=os.time()}
  nextId=nextId+1;people[person.id]=person;sessions[token]=person
  return person
end
allowed=function(props,keys)
  for k in pairs(props) do if not keys[k] then return false end end
  return true
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
    local person,err=new_person(name,nil)
    if not person then return reply_error(err) end
    return {ok=true,payload=home(person)}
  end
  if req.kind=='O' and (p=='/revival/social/register' or p=='/revival/social/login') then
    return {ok=true,payload=p=='/revival/social/register' and register_page() or login_page()}
  end
  if p=='/revival/social/register/submit' and req.kind=='P' then
    if not accountStore then return reply_error('Cadastro local não habilitado') end
    local props=req.properties or {}
    if not allowed(props,{username=true,submitId=true,lang=true}) or props.submitId~='register' then
      return reply_error('Campos de cadastro inválidos')
    end
    local username=props.username
    if not accountLib.allowed(username) then return reply_error('Nome de usuário inválido') end
    if active_count()>=MAX_PEOPLE then return reply_error('Limite de usuários online atingido') end
    local code,err=accountLib.register(accountStore,username)
    if not code then return reply_error(err) end
    local person,personErr=new_person(username,username)
    if not person then return reply_error(personErr) end
    local body='<p label="Conta local criada: '..escape(username)..'"/>'..
      '<p label="Guarde este código de 48 caracteres. Ele NÃO será mostrado novamente."/>'..
      '<p label="'..code..'"/>'..
      '<p label="O código dá acesso à conta. Não compartilhe. Somente servidor local sem TLS."/>'..
      '<a label="Abrir sala social" href="/revival/social/home"/>'..
      '<lsk label="Menu" href="/revival/social/start"/>'
    return {ok=true,payload=xml('Código de acesso — laboratório','credentials',body,person.token)}
  end
  if p=='/revival/social/login/submit' and req.kind=='P' then
    if not accountStore then return reply_error('Login local não habilitado') end
    local props=req.properties or {}
    if not allowed(props,{username=true,accessCode=true,submitId=true,lang=true}) or props.submitId~='login' then
      return reply_error('Campos de login inválidos')
    end
    if not accountLib.verify(accountStore,props.username,props.accessCode) then
      return reply_error('Usuário ou código inválido')
    end
    local person,err=new_person(props.username,props.username)
    if not person then return reply_error(err) end
    return {ok=true,payload=home(person)}
  end
  local person=get_person(req)
  if not person then return reply_error('Sessão expirada. Volte e entre como visitante.') end
  if req.kind=='O' and p=='/revival/social/logout' then
    sessions[person.token]=nil;people[person.id]=nil
    local page=welcome():gsub('<form ', '<prop n="sessionClear" v="true"/><form ',1)
    return {ok=true,payload=page}
  end
  if p=='/revival/social/contacts' or p:sub(1,24)=='/revival/social/contact/' or
      p:sub(1,24)=='/revival/social/account/' then
    return account_route(person,req)
  end
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
  peerid=p:match('^/revival/social/poll/([1-9]%d*)$')
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
    if type(since)~='string' or #since>12 or not since:match('^%d+$') then
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
  peerid=p:match('^/revival/social/send/([1-9]%d*)$')
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
