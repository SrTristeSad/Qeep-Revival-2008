-- Qeep Revival 2008: evidence-based JCL laboratory client (NOT historical screens).
-- Windows/Android: shared Lua + LÖVE code, no WebView, no legacy-server contact.
local protocol = require('lib.protocol')
local jcl = require('lib.jcl')
local jcl_view = require('lib.jcl_view')
local layout = require('lib.jcl_layout')
local legacy = require('lib.legacy_palette')
local c = legacy.colors
local W,H = 240,320
local TOP,BOTTOM = 65,281
local VH = BOTTOM-TOP
local view, selected, serverHost, status = 'menu',1,'127.0.0.1',''
local options = {
  'Abrir JCL (offline)', 'Receber JCL do servidor', 'Testar servidor local',
  'Configurar endereco IP', 'Sobre o projeto', 'Sair'
}
local font,big,document,computed,scroll = nil,nil,nil,nil,0
local touches = {}
local function paint(color) love.graphics.setColor(color) end
local function rect(mode,x,y,w,h) love.graphics.rectangle(mode,x,y,w,h) end
local function text(s,x,y,width,align,useBig,color)
  love.graphics.setFont(useBig and big or font)
  paint(color or c.black)
  love.graphics.printf(tostring(s or ''),x,y,width,align or 'left')
end
local function transform()
  local dw,dh=love.graphics.getDimensions()
  local scale=math.min(dw/W,dh/H)
  return scale,(dw-W*scale)/2,(dh-H*scale)/2
end
local function localPoint(x,y)
  local scale,ox,oy=transform()
  return (x-ox)/scale,(y-oy)/scale
end
local function returnMenu()
  view='menu';scroll=0;computed=nil
  love.keyboard.setTextInput(false)
end
local function showError(message)
  status=tostring(message);view='status'
  love.keyboard.setTextInput(false)
end
local function refreshLayout(ensure)
  if not document then return end
  computed=layout.build(jcl_view.form(document),font,220)
  if ensure then scroll=layout.ensure_visible(computed,document.selected,scroll,VH)
  else scroll=layout.clamp_scroll(computed,scroll,VH) end
end
local function openJCL(source)
  local ok,result=pcall(jcl.parse,source)
  if not ok then return showError(result) end
  document=jcl_view.new(result)
  view='jcl';scroll=0
  love.keyboard.setTextInput(false)
  refreshLayout(true)
end
local function socketRequest(path)
  local ok,socklib=pcall(require,'socket')
  if not ok then return nil,'LuaSocket indisponivel nesta compilacao.' end
  local conn,reason=socklib.tcp()
  if not conn then return nil,tostring(reason) end
  conn:settimeout(1.5)
  local connected,connectErr=conn:connect(serverHost,5190)
  if not connected then conn:close();return nil,connectErr end
  local sent,sendErr=conn:send(protocol.encodeRequest('O',path,{lang='pt-BR'},''))
  if not sent then conn:close();return nil,sendErr end
  local reply,readErr,partial=conn:receive('*a')
  conn:close()
  local valid,result=pcall(protocol.decodeReply,reply or partial or '')
  if not valid then return nil,tostring(result)..' ('..tostring(readErr)..')' end
  if result.properties.ok~='true' then return nil,result.payload end
  return result.payload
end
local function activateMenu()
  if selected==1 then
    local file=love.filesystem.read('fixtures/lab.xml')
    if file then openJCL(file) else showError('Fixture JCL nao encontrada no pacote.') end
  elseif selected==2 then
    local source,err=socketRequest('/revival/page/lab')
    if source then openJCL(source) else showError('Falha no servidor: '..tostring(err)) end
  elseif selected==3 then
    local data,err=socketRequest('/revival/ping')
    if data=='PONG' then showError('Servidor Lua respondeu!\nHost: '..serverHost..':5190\n\nTeste somente de transporte.')
    else showError('Falha de teste: '..tostring(err or data)) end
  elseif selected==4 then view='host';love.keyboard.setTextInput(true)
  elseif selected==5 then view='about'
  elseif selected==6 then love.event.quit() end
end
local function navigate(href)
  if type(href)~='string' or href=='' then return end
  if href:sub(1,1)=='#' then
    if not jcl_view.next_form(document,href:sub(2)) then return showError('Formulario JCL ausente: '..href) end
    scroll=0;refreshLayout(true)
  else
    -- Do not follow URL endpoints, old servers, or arbitrary JCL destinations.
    showError('Endereco nao implementado no laboratorio:\n'..href)
  end
end
local function softkey(kind)
  local form=jcl_view.form(document)
  for _,item in ipairs(form.items) do
    if item.kind==kind then
      if item.href and item.href~='' then navigate(item.href) end
      return
    end
  end
  if kind=='lsk' then returnMenu() end
end
local function activateJCL()
  local result=jcl_view.activate(document)
  if result=='editing' then love.keyboard.setTextInput(true)
  elseif result=='selected' then refreshLayout(true)
  elseif result then navigate(result) end
end
function love.load()
  love.graphics.setDefaultFilter('nearest','nearest')
  font,big=love.graphics.newFont(12),love.graphics.newFont(17)
  local saved=love.filesystem.read('host.txt')
  if saved and #saved<128 then serverHost=saved:gsub('%s+','') end
end
local function drawJCL()
  local form=jcl_view.form(document)
  text(form.title,8,34,224,'center',true)
  paint(c.olive);rect('fill',8,57,224,2)
  local scale,ox,oy=transform()
  love.graphics.setScissor(ox+9*scale,oy+TOP*scale,222*scale,VH*scale)
  for _,entry in ipairs(computed.entries) do
    local item=entry.item
    local y=TOP+entry.y-scroll
    local height=entry.height
    if y+height>=TOP and y<=BOTTOM then
      if item.kind=='hr' then
        paint(c.olive);rect('fill',15,y+5,210,1)
      else
        local active=document.selected==entry.index
        if active then
          paint(c.highlight);rect('fill',10,y,220,height)
          paint(c.purple);rect('line',10,y,220,height)
        end
        text(entry.title,17,y+5,204)
        if entry.detail then
          local _,wrapped=font:getWrap(entry.title,204)
          local detail_y=y+7+#wrapped*(font:getHeight()+2)
          if item.kind=='input' or item.kind=='textarea' or item.kind=='select' then
            paint(active and c.white or c.background)
            rect('fill',15,detail_y-2,210,math.max(18,height-(detail_y-y)-4))
            paint(c.olive);rect('line',15,detail_y-2,210,math.max(18,height-(detail_y-y)-4))
          end
          local content=entry.detail
          if document.editing and active then content=content..'_' end
          text(content,19,detail_y,198)
          if item.kind=='gauge' then
            local gy=y+height-13
            paint(c.purple);rect('line',18,gy,198,6)
            local fraction=item.max>0 and math.max(0,math.min(item.value/item.max,1)) or 0
            paint(c.olive);rect('fill',19,gy+1,math.floor(196*fraction),4)
          end
        end
      end
    end
  end
  love.graphics.setScissor()
  text(document.editing and 'Enter: concluir edicao' or 'Setas: navegar  Enter: abrir',7,283,226,'center')
  paint(c.purple);rect('fill',0,H-25,W,25)
  local left,right='Voltar','Abrir'
  for _,item in ipairs(form.items) do
    if item.kind=='lsk' then left=item.label or left end
    if item.kind=='rsk' then right=item.label or right end
  end
  text(left,6,H-19,105,'left',false,c.white)
  text(right,125,H-19,108,'right',false,c.white)
end
function love.draw()
  local scale,ox,oy=transform()
  paint({0.18,0.18,0.18})
  local dw,dh=love.graphics.getDimensions()
  rect('fill',0,0,dw,dh)
  love.graphics.push();love.graphics.translate(ox,oy);love.graphics.scale(scale,scale)
  paint(c.background);rect('fill',0,0,W,H)
  paint(c.purple);rect('fill',0,0,W,25)
  text('QEEP REVIVAL 2008',7,6,W-14,'center',false,c.white)
  if view=='jcl' and document then
    drawJCL()
  else
    text('Laboratorio Lua / LOVE',11,38,W-22,'center',true)
    text('Interface provisoria; nao e tela original',7,63,W-14,'center')
    paint(c.olive);rect('fill',9,83,W-18,1)
    if view=='menu' then
      for i,option in ipairs(options) do
        local y=91+(i-1)*30
        if selected==i then
          paint(c.highlight);rect('fill',11,y,W-22,27)
          paint(c.purple);rect('line',11,y,W-22,27)
        end
        text((selected==i and '> ' or '  ')..option,16,y+6,W-32)
      end
    elseif view=='host' then
      text('IP ou nome do servidor:',15,106,215)
      paint(c.white);rect('fill',12,136,216,34)
      paint(c.purple);rect('line',12,136,216,34)
      text(serverHost..'_',18,146,206)
      text('Digite o IP do PC na rede local.\nEnter salva. Esc volta.',12,185,216)
    elseif view=='status' then
      text('Resultado',13,106,214,'center',true)
      text(status,14,153,212)
      text('Enter / Esc para voltar',12,274,216,'center')
    elseif view=='about' then
      text('Reconstrucao independente de um cliente Java ME de 2008.',14,105,212)
      text('O JCL e parcial. A demonstracao e sintetica.',14,167,212)
      text('Enter / Esc para voltar',12,274,216,'center')
    end
    paint(c.purple);rect('fill',0,H-25,W,25)
    text(view=='menu' and 'Selecionar: Enter   Voltar: Esc' or 'Voltar: Esc',6,H-19,W-12,'center',false,c.white)
  end
  love.graphics.pop()
end
function love.keypressed(key)
  if view=='jcl' and document then
    if document.editing then
      if key=='return' or key=='kpenter' or key=='escape' then
        document.editing=false;love.keyboard.setTextInput(false)
      elseif key=='backspace' then jcl_view.backspace(document);refreshLayout(true) end
    elseif key=='up' then jcl_view.move(document,-1);refreshLayout(true)
    elseif key=='down' then jcl_view.move(document,1);refreshLayout(true)
    elseif key=='pageup' then scroll=layout.clamp_scroll(computed,scroll-120,VH)
    elseif key=='pagedown' then scroll=layout.clamp_scroll(computed,scroll+120,VH)
    elseif key=='return' or key=='kpenter' or key=='space' then activateJCL()
    elseif key=='left' then softkey('lsk')
    elseif key=='right' then softkey('rsk')
    elseif key=='escape' then returnMenu() end
    return
  end
  if view=='menu' then
    if key=='up' then selected=(selected-2)%#options+1
    elseif key=='down' then selected=selected%#options+1
    elseif key=='return' or key=='kpenter' or key=='space' then activateMenu()
    elseif key=='escape' then love.event.quit() end
  elseif view=='host' then
    if key=='return' or key=='kpenter' then
      serverHost=serverHost:gsub('%s+','')
      if #serverHost>0 then love.filesystem.write('host.txt',serverHost) end
      returnMenu()
    elseif key=='backspace' then serverHost=serverHost:sub(1,-2)
    elseif key=='escape' then returnMenu() end
  elseif key=='escape' or key=='return' or key=='kpenter' then returnMenu() end
end
function love.textinput(t)
  if view=='host' and #serverHost+#t<128 and t:match('^[%w%.:%-]+$') then
    serverHost=serverHost..t
  elseif view=='jcl' and document and document.editing then
    jcl_view.text(document,t);refreshLayout(true)
  end
end
local function pointer(x,y)
  local px,py=localPoint(x,y)
  if px<0 or px>W or py<0 or py>H then return end
  if view=='menu' then
    for i=1,#options do
      local y=91+(i-1)*30
      if py>=y and py<=y+27 then selected=i;activateMenu();break end
    end
  elseif view=='jcl' and document then
    if py>=H-25 then
      if px<W/2 then softkey('lsk') else softkey('rsk') end
    elseif py>=TOP and py<BOTTOM then
      local index=layout.hit(computed,px-10,py-TOP,scroll,220,VH)
      if index then
        if document.editing then document.editing=false;love.keyboard.setTextInput(false) end
        document.selected=index;activateJCL();refreshLayout(true)
      end
    end
  elseif py>=H-34 then returnMenu() end
end
function love.mousepressed(x,y,button,istouch)
  if button~=1 or istouch then return end
  pointer(x,y)
end
function love.touchpressed(id,x,y)
  touches[id]={x=x,y=y,last=y,moved=false}
end
function love.touchmoved(id,x,y)
  local t=touches[id]
  if not t then return end
  local scale=transform()
  if math.abs(y-t.y)>8 or math.abs(x-t.x)>8 then t.moved=true end
  if view=='jcl' and computed and t.moved then
    scroll=layout.clamp_scroll(computed,scroll+(t.last-y)/scale,VH)
  end
  t.last=y
end
function love.touchreleased(id,x,y)
  local t=touches[id]
  touches[id]=nil
  if t and not t.moved then pointer(x,y) end
end
function love.wheelmoved(_,dy)
  if view=='jcl' and computed then
    scroll=layout.clamp_scroll(computed,scroll-dy*32,VH)
  end
end
