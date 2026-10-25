-- Non-blocking, bounded polling transport for synthetic local Revival routes.
-- Intentionally separate from the historical protocol; never contacts Qeep servers.
local M = {}
local TIMEOUT = 5
local function close(job)
  if job.conn then pcall(function() job.conn:close() end); job.conn = nil end
end
function M.cancel(job) if job then close(job) end end
local function fail(job, reason)
  close(job)
  return {ok=false,error=tostring(reason)}
end
function M.start(socklib, codec, host, port, token, peer, revision)
  local guest=type(peer)=='string' and peer:match('^[1-9]%d*$') and #peer<=10
  local account=type(peer)=='string' and peer:match('^[a-z][a-z0-9_]*$') and #peer>=3 and #peer<=24
  if not guest and not account then return nil,'Invalid peer' end
  if type(token)~='string' or token=='' or #token>128 then return nil,'Missing guest session' end
  local conn,err=socklib.tcp()
  if not conn then return nil,err end
  conn:settimeout(0)
  local path=(account and '/revival/social/account/poll/' or '/revival/social/poll/')..peer
  local ok,request=pcall(codec.encodeRequest,'O',path,{session=token,since=tostring(revision or 0)},'')
  if not ok then conn:close();return nil,request end
  local connected,why=conn:connect(host,port)
  if not connected and why~='timeout' and why~='Operation already in progress' and why~='already connected' then
    conn:close();return nil,why
  end
  return {conn=conn,socklib=socklib,codec=codec,path=path,request=request,
    phase=connected and 'send' or 'connect',index=1,parts={},size=0,elapsed=0}
end
function M.step(job,dt)
  if not job or not job.conn then return {ok=false,error='Cancelled'} end
  job.elapsed=job.elapsed+math.max(0,tonumber(dt) or 0)
  if job.elapsed>TIMEOUT then return fail(job,'Poll timeout') end
  if job.phase=='connect' then
    local _,writeable,err=job.socklib.select(nil,{job.conn},0)
    if err and err~='timeout' then return fail(job,err) end
    if not writeable or #writeable==0 then return nil end
    if job.conn.getpeername then
      local peer,why=job.conn:getpeername()
      if not peer then return fail(job,why or 'Connection failed') end
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
    if job.size>job.codec.MAX_FRAME then return fail(job,'Oversize reply') end
    job.parts[#job.parts+1]=chunk
    if why=='timeout' then return nil end
    if why and why~='closed' then return fail(job,why) end
    if not data and why~='closed' then return nil end
    local valid,reply=pcall(job.codec.decodeReply,table.concat(job.parts))
    if not valid then return fail(job,reply) end
    if reply.kind~='R' or reply.path~=job.path then return fail(job,'Unexpected poll reply') end
    close(job)
    if reply.properties.ok~='true' then return {ok=false,error=reply.payload} end
    local unchanged=reply.properties.unchanged=='true'
    if unchanged and reply.payload~='' then return {ok=false,error='Invalid empty poll response'} end
    if not unchanged and reply.payload=='' then return {ok=false,error='Missing poll page'} end
    return {ok=true,changed=not unchanged,payload=reply.payload}
  end
  return nil
end
return M
