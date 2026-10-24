-- Bounded form-value collector. Inspired by n.b()/handler.Submit in the
-- original JAR, but wire interoperability is NOT established.
local M = {}
local choices = require('lib.jcl_choices')
local function fail(s) error('jcl_submit: '..s, 2) end
local function valid_id(id)
  return type(id)=='string' and #id>0 and #id<=50 and id:match('^[%w_%-]+$') ~= nil
end
function M.collect(form, button)
  if type(form)~='table' or type(form.items)~='table' then fail('invalid form') end
  local values, count = {}, 0
  for _,item in ipairs(form.items) do
    if item.kind=='input' or item.kind=='textarea' or item.kind=='select' then
      local id=item.id
      if id~=nil then
        if not valid_id(id) or id=='submitId' then fail('invalid field id') end
        if values[id]~=nil then fail('duplicate field id') end
        local value
        if item.kind=='select' then
          value=choices.value(item)
        else value=item.value or '' end
        if type(value)~='string' or #value>2048 then fail('field value too long') end
        values[id]=value
        count=count+1
        if count>32 then fail('too many fields') end
      end
    end
  end
  if button and button.id then
    if not valid_id(button.id) then fail('invalid submit id') end
    values.submitId=button.id
  end
  return values
end
return M
