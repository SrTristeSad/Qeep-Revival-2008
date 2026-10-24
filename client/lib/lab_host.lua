-- Accept only loopback and RFC1918 IPv4 addresses for this diagnostic client.
-- Do not accidentally send reconstructed JCL requests to historical services.
local M={}
function M.valid(host)
  if host=='localhost' then return true end
  if type(host)~='string' or #host>15 then return false end
  local octets={}
  for part in host:gmatch('[^.]+') do
    if not part:match('^%d+$') or (#part>1 and part:sub(1,1)=='0') then return false end
    octets[#octets+1]=tonumber(part)
  end
  if #octets~=4 or host:find('%.%.',1) or host:sub(1,1)=='.' or host:sub(-1)=='.' then return false end
  for _,o in ipairs(octets) do if o<0 or o>255 then return false end end
  local a,b=octets[1],octets[2]
  return a==10 or (a==172 and b>=16 and b<=31)
    or (a==192 and b==168) or (a==127 and b==0 and octets[3]==0 and octets[4]==1)
end
return M
