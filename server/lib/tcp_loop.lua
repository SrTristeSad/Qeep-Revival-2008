-- Bounded, cooperative TCP server for the synthetic Revival laboratory.
-- One request per connection; does not call blocking receive/send on a client.
local M = {}
local MAX_CLIENTS, MAX_AGE, MAX_ACCEPT = 64, 8, 16
function M.new(listener, socklib, protocol, route)
  assert(listener and socklib and protocol and type(route)=='function')
  listener:settimeout(0)
  return {listener=listener,socket=socklib,codec=protocol,route=route,
    clients={},now=0,maxClients=MAX_CLIENTS}
end
local function discard(loop, client)
  loop.clients[client.conn]=nil
  pcall(function() client.conn:close() end)
end
local function prepare(loop, client, frame)
  local valid,req=pcall(loop.codec.decodeRequest,frame)
  if not valid then return discard(loop,client) end
  local handled,answer=pcall(loop.route,req)
  if not handled or type(answer)~='table' or type(answer.payload)~='string' then
    answer={ok=false,payload='Erro na rota local'}
  end
  local success,reply=pcall(loop.codec.encodeReply,'R',req.path,
    {ok=answer.ok and 'true' or 'false',unchanged=answer.unchanged and 'true' or 'false',
      server='Qeep-Revival-2008',version='phase-11'},answer.payload)
  if not success then return discard(loop,client) end
  client.reply=reply;client.index=1;client.state='write';client.input=''
end
local function readClient(loop, client)
  -- A single bounded read per cycle prevents a busy peer from starving others.
  local data,why,partial=client.conn:receive(4096)
  local chunk=data or partial or ''
  if #chunk>0 then client.input=client.input..chunk;client.deadline=loop.now+MAX_AGE end
  if #client.input>loop.codec.MAX_FRAME+4 then return discard(loop,client) end
  if not client.frameLength and #client.input>=4 then
    local b1,b2,b3,b4=client.input:byte(1,4)
    local n=b1*16777216+b2*65536+b3*256+b4
    if n<1 or n>loop.codec.MAX_FRAME then return discard(loop,client) end
    client.frameLength=n+4
  end
  if client.frameLength and #client.input>=client.frameLength then
    if #client.input~=client.frameLength then return discard(loop,client) end
    return prepare(loop,client,client.input)
  end
  if why and why~='timeout' then return discard(loop,client) end
end
local function writeClient(loop,client)
  local count,why,last=client.conn:send(client.reply,client.index)
  local upto=count or last
  if upto and upto>=client.index then
    client.index=upto+1;client.deadline=loop.now+MAX_AGE
  end
  if client.index>#client.reply then return discard(loop,client) end
  if why and why~='timeout' then return discard(loop,client) end
end
function M.step(loop,dt)
  loop.now=loop.now+math.max(0,tonumber(dt) or 0)
  -- Drain only a bounded batch of queued new clients per iteration.
  for _=1,MAX_ACCEPT do
    local conn=loop.listener:accept()
    if not conn then break end
    conn:settimeout(0)
    local count=0
    for _ in pairs(loop.clients) do count=count+1 end
    if count>=loop.maxClients then conn:close()
    else loop.clients[conn]={conn=conn,state='read',input='',deadline=loop.now+MAX_AGE} end
  end
  local readers,writers={},{}
  for conn,client in pairs(loop.clients) do
    if loop.now>=client.deadline then discard(loop,client)
    elseif client.state=='read' then readers[#readers+1]=conn
    else writers[#writers+1]=conn end
  end
  if #readers==0 and #writers==0 then return end
  local readyRead,readyWrite=loop.socket.select(readers,writers,0)
  for _,conn in ipairs(readyRead or {}) do
    local client=loop.clients[conn]
    if client and client.state=='read' then readClient(loop,client) end
  end
  for _,conn in ipairs(readyWrite or {}) do
    local client=loop.clients[conn]
    if client and client.state=='write' then writeClient(loop,client) end
  end
end
function M.close(loop)
  for _,client in pairs(loop.clients) do discard(loop,client) end
  loop.listener:close()
end
return M
