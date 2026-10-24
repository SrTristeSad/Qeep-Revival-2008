-- Values transcribed from registry.ini inside user-supplied qeep-94724.jar.
-- This is palette evidence, NOT a claim that these particular combinations
-- correspond to any historical page supplied by the missing Qeep server.
local M = {}
M.hex = function(value)
  local n=assert(tonumber(value,16),'invalid hex RGB')
  return {math.floor(n/65536)%256/255,math.floor(n/256)%256/255,n%256/255}
end
M.colors={
  background=M.hex('ebffb9'), highlight=M.hex('cdff3c'), olive=M.hex('a0b419'),
  purple=M.hex('7d147d'), dark=M.hex('501e50'), dark_text=M.hex('3c143c'),
  white=M.hex('ffffff'), black=M.hex('000000')
}
M.registry={
  s0={bg='ebffb9',xc='7d147d'}, s1={bg='ebffb9',cbg='ebffb9',xc='7d147d',tc='000000'},
  s2={bg='cdff3c',cbg='cdff3c',tc='000000'},
  s4={bg='ebffb9',cbg='ebffb9',xc='7d147d',tc='000000'},
  s5={bg='cdff3c',cbg='ebffb9',tc='000000'},
  s7={cbg='a0b419',tc='000000'}, s8={cbg='cdff3c',tc='000000'},
  s10={bg='a1b617',tc='501e50'}, s11={bg='ebffb9',tc='3c143c'},
  s12={bg='cdff3c',fr='7d147d'}, s13={bg='a0b419',fr='7d147d'}
}
return M
