-- Fit JCL titles above the fixed scrolling viewport (logical y=65).
local M={}
local function count(font,title,width)
  local _,lines=font:getWrap(title,width)
  return #lines
end
local function drop_last_utf8(text)
  local i=#text
  while i>1 and text:byte(i)>=128 and text:byte(i)<192 do i=i-1 end
  return text:sub(1,i-1)
end
function M.fit(title,normal,large,width)
  title=tostring(title or '')
  width=width or 224
  if count(large,title,width)<=1 then
    return {value=title,large=true,y=34,rule_y=57,lines=1}
  end
  if count(large,title,width)<=2 then
    return {value=title,large=true,y=26,rule_y=62,lines=2}
  end
  local display=title
  local rows=count(normal,display,width)
  if rows>3 then
    for i=1,#display do
      display=drop_last_utf8(display)
      if display=='' then break end
      rows=count(normal,display..'...',width)
      if rows<=3 then display=display..'...';break end
    end
  end
  return {value=display,large=false,y=26,rule_y=62,lines=math.min(rows,3)}
end
return M
