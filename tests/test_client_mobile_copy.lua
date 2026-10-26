-- Regression from actual Android 34 emulator captures: no desktop key hints
-- in touch screens, and no wrapped About subtitle crossing the header rule.
package.path='client/?.lua;client/lib/?.lua;'..package.path
local checks=0
local function check(value, label) assert(value,label);checks=checks+1 end
local function scenario(os_name)
  local prints={}
  local font={}
  function font:getHeight() return 12 end
  function font:getWrap(s,width)
    local lines={}
    local cap=math.max(1,math.floor(width/7))
    for para in (tostring(s)..'\n'):gmatch('(.-)\n') do
      repeat
        lines[#lines+1]=para:sub(1,cap)
        para=para:sub(cap+1)
      until #para==0
    end
    return width,lines
  end
  local function noop() end
  love={
    system={getOS=function() return os_name end},
    graphics={setColor=noop,rectangle=noop,setFont=noop,setScissor=noop,
      setDefaultFilter=noop,push=noop,pop=noop,translate=noop,scale=noop,
      getDimensions=function() return 540,960 end,
      newFont=function() return font end,
      printf=function(s,x,y,width,align)
        prints[#prints+1]={value=tostring(s),x=x,y=y,width=width,align=align}
      end},
    keyboard={setTextInput=noop},
    filesystem={read=function(path)
      if path=='endpoint.txt' or path=='host.txt' then return nil end
      local f=assert(io.open('client/'..path,'rb'))
      local data=f:read('*a');f:close();return data
    end,write=function()return true end},
    event={quit=noop}
  }
  assert(loadfile('client/main.lua'))()
  love.load()
  local function draw()
    prints={}
    love.draw()
    return prints
  end
  local function find(value)
    for _,entry in ipairs(prints) do
      if entry.value==value then return entry end
    end
    return nil
  end
  draw()
  if os_name=='Android' then
    love.touchpressed(22,250,120+ (91+5*22+11)*2.25)
    love.touchreleased(22,250,120+ (91+5*22+11)*2.25)
    draw()
    check(find('Sobre o projeto')~=nil,'About title displayed')
    local subtitle=find('Reconstrucao experimental')
    check(subtitle~=nil,'compact About subtitle')
    local _,wrapped=font:getWrap(subtitle.value,subtitle.width)
    check(subtitle.y + #wrapped*font:getHeight()<=83,'no overlap with y83 separator')
    check(find('Interface provisoria; nao e tela original')==nil,'old subtitle excluded')
    love.touchpressed(22,250,120+307*2.25)
    love.touchreleased(22,250,120+307*2.25)
  end
  if os_name=='Android' then
    love.touchpressed(22,250,120+ (91+11)*2.25)
    love.touchreleased(22,250,120+ (91+11)*2.25)
  else
    love.keypressed('home')
    love.keypressed('return')
  end
  draw()
  if os_name=='Android' then
    check(find('Toque para abrir ou deslize')~=nil,'touch hint visible in JCL')
    check(find('Setas: navegar  Enter: abrir')==nil,'desktop navigation hint suppressed')
  else
    check(find('Setas: navegar  Enter: abrir')~=nil,'Windows keypad hint preserved')
    check(find('Toque para abrir ou deslize')==nil,'touch hint not on desktop')
  end
end
scenario('Android')
scenario('Windows')
print(('OK: %d Android/Windows responsive copy checks'):format(checks))
