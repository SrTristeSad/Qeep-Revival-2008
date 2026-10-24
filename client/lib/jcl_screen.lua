-- JCL form-screen command model. Java ME h.class maps lsk/rsk into
-- Command entries; the cancel flag determines Command.CANCEL (2) versus
-- Command.ITEM (4). Placement and labels remain a Lua reconstruction.
local M={}
local defaults={lsk={label='Voltar',cancel=true}, rsk={label='Abrir',cancel=false}}
function M.command(form, kind)
  assert(kind=='lsk' or kind=='rsk','invalid softkey')
  for _,item in ipairs((form and form.items) or {}) do
    if item.kind==kind then
      return {kind=kind, label=(item.label and item.label~='' and item.label or defaults[kind].label),
        href=item.href, cancel=item.cancel==true, explicit=true,
        commandType=item.cancel and 2 or 4}
    end
  end
  local default=defaults[kind]
  return {kind=kind,label=default.label,href=nil,cancel=default.cancel,
    commandType=default.cancel and 2 or 4,explicit=false}
end
function M.commands(form, choosing)
  if choosing then
    return {kind='lsk',label='Voltar',cancel=true,commandType=2,explicit=false},
      {kind='rsk',label='Concluir',cancel=false,commandType=4,explicit=false}
  end
  return M.command(form,'lsk'),M.command(form,'rsk')
end
return M
