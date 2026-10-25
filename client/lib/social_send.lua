-- Phase 11: asynchronous, one-shot sends to the local synthetic social laboratory.
-- A timeout is ambiguous: NEVER automatically retransmit a chat message.
local M = {}
local TIMEOUT, MAX_REPLY = 7, 1024 * 1024
local function close(job)
  if job.conn then pcall(function() job.conn:close() end); job.conn=nil end
end
function M.cancel(job) if job then close(job) end end
local function fail(job, reason)
  close(job)
  return {ok=false,error=tostring(reason)}
end
function M.start(socklib, codec, host, port, token, peer, fields)
  local guest=type(peer)=='string' and peer:match('^[1-9]%d*$') and #peer<=10
  local account=type(peer)=='string' and peer:match('^[a-z][a-z0-9_]*$') and #peer>=3 and #peer<=24
  if not guest and not account then return nil,'Destinatário inválido' end
  if type(token)~='string' or token=='' or #token>128 then return nil,'Sessão ausente' end
  if type(fields)~='table' or fields.submitId~='send' or type(fields.message)~='string' or
     fields.message=='' or #fields.message>960 then return nil,'Mensagem inválida' end
  local props={session=token,submitId='send',message=fields.message,lang='pt-BR'}
  local path=(account and '/revival/social/account/send/' or '/revival/social/send/')..peer
  local ok,request=pcall(codec.encodeRequest,'P',path,props,'')
  if not ok then return nil,request end
  local conn,err=socklib.tcp()
  if not conn then return nil,err end
  conn:settimeout(0)
  local connected,why=conn:connect(host,port)
  if not connected and why~='timeout' and why~='Operation already in progress' and why~='already connected' then
    conn:close();return nil,why
  end
  return {conn=conn,socklib=socklib,codec=codec,path=path,request=request,
    phase=connected and 'send' or 'connect',index=1,parts={},size=0,elapsed=0}
end
function M.step(job,dt)
  if not job or not job.conn then return {ok=false,error='Envio cancelado'} end
  job.elapsed=job.elapsed+math.max(0,tonumber(dt) or 0)
  if job.elapsed>TIMEOUT then return fail(job,'Tempo de envio esgotado; entrega não confirmada') end
  if job.phase=='connect' then
    local _,writable,err=job.socklib.select(nil,{job.conn},0)
    if err and err~='timeout' then return fail(job,err) end
    if not writable or #writable==0 then return nil end
    if job.conn.getpeername then
      local target,why=job.conn:getpeername()
      if not target then return fail(job,why or 'Conexão recusada') end
    end
    job.phase='send'
  end
  if job.phase=='send' then
    local count,why,last=job.conn:send(job.request,job.index)
    local upto=count or last
    if upto and upto>=job.index then job.index=upto+1 end
    if job.index>#job.request then job.phase='receive'
    elseif why and why~='timeout' then return fail(job,why)
    else return nil end
  end
  if job.phase=='receive' then
    local data,why,partial=job.conn:receive('*a')
    local chunk=data or partial or ''
    job.size=job.size+#chunk
    if job.size>math.min(MAX_REPLY,job.codec.MAX_FRAME) then return fail(job,'Resposta muito grande') end
    job.parts[#job.parts+1]=chunk
    if why=='timeout' then return nil end
    if why and why~='closed' then return fail(job,why) end
    if not data and why~='closed' then return nil end
    local valid,reply=pcall(job.codec.decodeReply,table.concat(job.parts))
    if not valid then return fail(job,reply) end
    if reply.kind~='R' or reply.path~=job.path then return fail(job,'Resposta inesperada') end
    close(job)
    if reply.properties.ok~='true' then return {ok=false,error=reply.payload,rejected=true} end
    if reply.payload=='' then return {ok=false,error='Resposta vazia'} end
    return {ok=true,payload=reply.payload}
  end
  return nil
end
return M
