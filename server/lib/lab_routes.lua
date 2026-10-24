-- Local-only fixture and echo routes. Not historical Qeep server behavior.
local M = {}
local SUBMIT_XML = [[<?xml version="1.0" encoding="UTF-8"?>
<jcl branding="Qeep Revival 2008">
  <form id="remote" title="Formulário remoto (laboratório)">
    <p label="Página de testes inventada. Nenhum dado é armazenado."/>
    <input id="nickname" label="Apelido de teste" len="35" value=""/>
    <textarea id="message" label="Texto de teste" len="120">Olá!</textarea>
    <select id="choice" label="Opção de teste" type="4">
      <option label="Primeira opção" value="one" selected="true"/>
      <option label="Segunda opção" value="two"/>
    </select>
    <button id="send" label="Enviar ao servidor local" href="/revival/submit/echo" focused="true"/>
    <lsk label="Voltar" href="/revival/page/lab"/>
    <rsk label="Enviar" href="/revival/submit/echo"/>
  </form>
</jcl>]]
local function escape(value)
  return value:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
    :gsub('"','&quot;'):gsub("'",'&apos;')
end
local function valid_string(v,limit)
  return type(v)=='string' and #v<=limit and not v:find('[%z\1-\8\11\12\14-\31]')
end
local function error_reply(message)
  return {ok=false,payload=message}
end
function M.handle(req, labxml)
  if type(req)~='table' or type(req.path)~='string' then return error_reply('Invalid request') end
  local props=req.properties or {}
  if req.kind=='O' and req.payload=='' then
    if req.path=='/revival/ping' then return {ok=true,payload='PONG'} end
    if req.path=='/revival/page/lab' then return {ok=true,payload=labxml} end
    if req.path=='/revival/page/submit' then return {ok=true,payload=SUBMIT_XML} end
  elseif req.kind=='P' and req.path=='/revival/submit/echo' and req.payload=='' then
    for k,v in pairs(props) do
      if k~='nickname' and k~='message' and k~='choice' and k~='submitId'
        and k~='lang' then return error_reply('Unexpected field') end
      if not valid_string(v,2048) then return error_reply('Invalid field value') end
    end
    if props.submitId~='send' or not valid_string(props.nickname or '',140)
      or not valid_string(props.message or '',512)
      or (props.choice~='one' and props.choice~='two') then
      return error_reply('Invalid laboratory form')
    end
    local name=escape(props.nickname or '')
    local msg=escape(props.message or '')
    local choice=escape(props.choice)
    local xml=([[<jcl><form id="result" title="Resposta local - laboratório">
      <p label="Envio de teste recebido. Nada foi armazenado."/>
      <p label="Apelido: %s"/><p label="Mensagem: %s"/>
      <p label="Escolha: %s"/>
      <button label="Novo teste" href="/revival/page/submit"/>
      <lsk label="Voltar" href="/revival/page/lab"/>
      </form></jcl>]]):format(name,msg,choice)
    return {ok=true,payload=xml}
  end
  return error_reply('Unknown laboratory request')
end
return M
