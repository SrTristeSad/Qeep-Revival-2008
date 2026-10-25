-- LAN-only server configuration for the independent Qeep Revival 2008.
local lab_host=require('lib.lab_host')
local M={default_port=5190}
function M.parse(raw)
  if type(raw)~='string' or #raw>64 then return nil,nil,'Endereco invalido' end
  local s=raw:match('^%s*(.-)%s*$')
  if s=='' or s:find('%s') then return nil,nil,'Informe o IPv4 privado do computador' end
  local host,port=s:match('^([^:]+):(%d+)$')
  if not host then
    if s:find(':',1,true) then return nil,nil,'Porta invalida' end
    host=s;port=tostring(M.default_port)
  end
  if not lab_host.valid(host) then return nil,nil,'Use localhost ou IPv4 de rede privada' end
  if #port>5 or (#port>1 and port:sub(1,1)=='0') then return nil,nil,'Porta invalida' end
  port=tonumber(port)
  if not port or port<1 or port>65535 then return nil,nil,'Porta entre 1 e 65535' end
  return host,port
end
function M.format(host,port)
  local valid_host,valid_port=M.parse(tostring(host or '')..':'..tostring(port or M.default_port))
  if not valid_host then return nil end
  return valid_host..':'..tostring(valid_port)
end
function M.append(existing,text)
  if type(existing)~='string' or type(text)~='string' then return existing end
  if #existing+#text>32 or not text:match('^[%w%.:]+$') then return existing end
  return existing..text
end
function M.backspace(text)
  if type(text)~='string' then return '' end
  return text:sub(1,-2)
end
function M.default_for(platform)
  if platform=='Android' or platform=='iOS' then return '' end
  return '127.0.0.1'
end
return M
