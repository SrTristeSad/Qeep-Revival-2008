-- GENERATED from the 2008 JAR registry.ini: raw style tokens only.
-- Style number and encoded values do not prove the original screen layout.
local M = {source_sha256 = "fd24b6191fbef801f3b7791def8c9c13e30485c9152fe073799f46c383e5e6b3", styles = {
  {id="s0", fields={["bg"]="32,ebffb9", ["lf"]="8", ["tf"]="8", ["xc"]="7d147d"}},
  {id="s1", fields={["bg"]="32,ebffb9", ["cbg"]="32,ebffb9", ["lc"]="000000", ["tc"]="000000", ["tf"]="8", ["xc"]="7d147d"}},
  {id="s2", fields={["bg"]="32,cdff3c", ["cbg"]="32,cdff3c", ["lc"]="000000", ["lf"]="8", ["tc"]="000000", ["tf"]="8"}},
  {id="s4", fields={["bg"]="32,ebffb9", ["cbg"]="32,ebffb9", ["lc"]="000000", ["lf"]="9", ["tc"]="000000", ["tf"]="8", ["xc"]="7d147d"}},
  {id="s5", fields={["bg"]="32,cdff3c", ["cbg"]="32,ebffb9", ["lc"]="000000", ["lf"]="9", ["tc"]="000000", ["tf"]="8"}},
  {id="s7", fields={["cbg"]="32,a0b419", ["cfr"]="5,0,1,a0b419", ["lf"]="9", ["tc"]="000000", ["tf"]="8"}},
  {id="s8", fields={["cbg"]="32,cdff3c", ["cfr"]="5,0,1,a0b419", ["lf"]="9", ["tc"]="000000", ["tf"]="8"}},
  {id="s10", fields={["bg"]="32,a1b617", ["tc"]="501e50", ["tf"]="9"}},
  {id="s11", fields={["bg"]="64,ebffb9,0,a0b419,200,a0b419", ["tc"]="3c143c", ["tf"]="9"}},
  {id="s12", fields={["bg"]="32,cdff3c", ["fr"]="1,1,1,7d147d", ["tf"]="8"}},
  {id="s13", fields={["bg"]="32,a0b419", ["fr"]="1,1,1,7d147d", ["tf"]="9"}},
}}
function M.color(token)
  if type(token) ~= "string" or not token:match("^%x%x%x%x%x%x$") then return nil end
  return {tonumber(token:sub(1,2),16)/255,tonumber(token:sub(3,4),16)/255,tonumber(token:sub(5,6),16)/255}
end
function M.solid(encoded)
  if type(encoded) ~= "string" then return nil end
  local mode,hex=encoded:match("^(%d+),(%x%x%x%x%x%x)$")
  if mode ~= "32" then return nil end
  return M.color(hex)
end
return M
