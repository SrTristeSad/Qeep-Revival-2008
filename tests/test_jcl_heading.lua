package.path='client/?.lua;client/lib/?.lua;'..package.path
local heading=require('lib.jcl_heading')
local function font(width)
 return {getWrap=function(self,s,w)
    local max=math.max(1,math.floor(w/width))
    local lines={};local begin=1
    while begin<=#s do
      lines[#lines+1]=s:sub(begin,math.min(#s,begin+max-1))
      begin=begin+max
    end
    if #lines==0 then lines={''} end
    return w,lines
 end}
end
local small,big=font(7),font(12)
local function check(title)
  local a=heading.fit(title,small,big,224)
  local f=a.large and big or small
  local _,rows=f:getWrap(a.value,224)
  assert(a.rule_y>=a.y+#rows*(a.large and 17 or 12))
  assert(a.rule_y+2<65)
  assert(#rows<=(a.large and 2 or 3))
  return a
end
assert(check('Entrar').y==34)
local wrapped=check('Criar conta local — laboratório')
assert(wrapped.value=='Criar conta local — laboratório')
assert(wrapped.y==26 and wrapped.rule_y==62)
assert(check(('mensagem '):rep(45)).value:sub(-3)=='...')
assert(check('Informações recentes — versão alfa').value~='')
print('OK: JCL title stays above separator and preserves UTF-8')
