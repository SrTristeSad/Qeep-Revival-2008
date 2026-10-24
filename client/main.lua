-- Qeep Revival 2008: diagnostic shell plus an evidence-based JCL subset viewer.
-- Historical screens are NOT included. All local fixture text is synthetic.
local protocol = require('lib.protocol')
local jcl = require('lib.jcl')
local jcl_view = require('lib.jcl_view')
local colors = {
  background={235/255,1,185/255}, focus={205/255,1,60/255},
  green={160/255,180/255,25/255}, purple={125/255,20/255,125/255},
  text={0,0,0},white={1,1,1},shade={.18,.18,.18}
}
local W,H=240,320
local view, selected, serverHost, status = 'menu',1,'127.0.0.1',''
local options={
  'Abrir JCL (offline)', 'Receber JCL do servidor', 'Testar servidor local',
  'Configurar endereco IP', 'Sobre o projeto', 'Sair'
}
local font,big,document,hitboxes,scroll = nil,nil,nil,{},0
local function paint(color) love.graphics.setColor(color) end
local function rect(mode,x,y,w,h) love.graphics.rectangle(mode,x,y,w,h) end
local function text(s,x,y,width,align,useBig)
  love.graphics.setFont(useBig and big or font)
  paint(colors.text)
  love.graphics.printf(tostring(s or ''),x,y,width,align or 'left')
end
local function transform()
  local dw,dh=love.graphics.getDimensions()
  local scale=math.min(dw/W,dh/H)
  return scale,(dw-W*scale)/2,(dh-H*scale)/2
end
local function returnMenu()
  view='menu'; scroll=0
  love.keyboard.setTextInput(false)
end
local function showError(message)
  status=tostring(message); view='status'; love.keyboard.setTextInput(false)
end
local function openJCL(source)
  local ok,result=pcall(jcl.parse,source)
  if not ok then return showError(result) end
  document=jcl_view.new(result)
  view='jcl';scroll=0
  love.keyboard.setTextInput(false)
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
local function activate()
  if selected==1 then
    local file=love.filesystem.read('fixtures/lab.xml')
    if file then openJCL(file) else showError('Fixture JCL nao encontrada no pacote.') end
  elseif selected==2 then
    local source,err=socketRequest('/revival/page/lab')
    if source then openJCL(source) else showError('Falha no servidor: '..tostring(err)) end
  elseif selected==3 then
    local data,err=socketRequest('/revival/ping')
    if data=='PONG' then showError('Servidor Lua respondeu!\nHost: '..serverHost..':5190\n\nEste e apenas um teste de transporte.')
    else showError('Falha de teste: '..tostring(err or data)) end
  elseif selected==4 then view='host';love.keyboard.setTextInput(true)
  elseif selected==5 then view='about'
  elseif selected==6 then love.event.quit() end
end
local function jclNavigate(href)
  if type(href)~='string' or href=='' then return end
  if href:sub(1,1)=='#' then
    if not jcl_view.next_form(document,href:sub(2)) then showError('Formulario JCL ausente: '..href) end
    scroll=0
  else
    -- Never follow arbitrary addresses from untrusted JCL or legacy domains.
    showError('Endereco nao implementado no laboratorio:\n'..href)
  end
end
local function jclSoftkey(kind)
  local form=jcl_view.form(document)
  for _,item in ipairs(form.items) do
    if item.kind==kind then jclNavigate(item.href); return end
  end
  if kind=='lsk' then returnMenu() end
end
function love.load()
  love.graphics.setDefaultFilter('nearest','nearest')
  font,big=love.graphics.newFont(12),love.graphics.newFont(17)
  local saved=love.filesystem.read('host.txt')
  if saved and #saved<128 then serverHost=saved:gsub('%s+','') end
end
local function rowHeight(item)
  if item.kind=='hr' then return 13 end
  if item.kind=='textarea' then return 65 end
  if item.kind=='input' then return 44 end
  if item.kind=='select' then return 43 end
  if item.kind=='img' then return 45 end
  if item.kind=='p' and #(item.label or '')>65 then return 40 end
  return 27
end
local function keepSelectedVisible()
  if not document or document.selected==0 then return end
  local top=67
  for i,item in ipairs(jcl_view.form(document).items) do
    if item.kind~='lsk' and item.kind~='rsk' then
      local height=rowHeight(item)
      if i==document.selected then
        if top-scroll<66 then scroll=math.max(0,top-68)
        elseif top+height-scroll>285 then scroll=math.max(0,top+height-285) end
        return
      end
      top=top+height+2
    end
  end
end
local function drawJCL()
  local form=jcl_view.form(document)
  text(form.title,8,34,224,'center',true)
  paint(colors.green);rect('fill',8,57,224,2)
  hitboxes={}
  local y=67-scroll
  love.graphics.setScissor()
  local scale,ox,oy=transform()
  love.graphics.setScissor(ox+6*scale,oy+65*scale,228*scale,225*scale)
  local items=form.items
  for i,item in ipairs(items) do
    local kind=item.kind
    if kind~='lsk' and kind~='rsk' then
      local content=item.label or ''
      local height=rowHeight(item)
      if kind=='input' or kind=='textarea' then
        content=content..':\n'..item.value..(document.editing and document.selected==i and '_' or '')
      elseif kind=='select' then
        local opt=item.options[item.selected]
        content=content..': '..(opt and opt.label or '[vazio]')..'  >'
      elseif kind=='gauge' then content=content..'  '..tostring(item.value)..'/'..tostring(item.max)
      elseif kind=='img' then content='[Imagem remota nao carregada: '..tostring(item.src or '')..']' end
      if y+height>=64 and y<=290 then
        if kind=='hr' then paint(colors.green);rect('fill',13,y+5,214,1)
        else
          if document.selected==i then
            paint(colors.focus);rect('fill',10,y,220,height-3)
            paint(colors.purple);rect('line',10,y,220,height-3)
          end
          text(content,17,y+5,206,'left',false)
          if kind=='gauge' then
            paint(colors.purple);rect('line',17,y+20,195,6)
            if item.max>0 then
              paint(colors.green);rect('fill',18,y+21,math.floor(193*math.max(0,math.min(item.value/item.max,1))),4)
            end
          end
        end
        hitboxes[#hitboxes+1]={index=i,y=y,height=height}
      end
      y=y+height+2
    end
  end
  love.graphics.setScissor()
  local hint=document.editing and 'Editando: Enter conclui' or 'Setas: navegar  Enter: abrir'
  text(hint,7,290,226,'center')
  paint(colors.purple);rect('fill',0,H-25,W,25)
  local left,right='Voltar','Abrir'
  for _,item in ipairs(items) do
    if item.kind=='lsk' then left=item.label or left end
    if item.kind=='rsk' then right=item.label or right end
  end
  paint(colors.white);love.graphics.setFont(font)
  love.graphics.print(left,6,H-19)
  love.graphics.printf(right,125,H-19,108,'right')
end
function love.draw()
  local scale,ox,oy=transform()
  paint(colors.shade);love.graphics.rectangle('fill',0,0,love.graphics.getDimensions())
  love.graphics.push();love.graphics.translate(ox,oy);love.graphics.scale(scale,scale)
  paint(colors.background);rect('fill',0,0,W,H)
  paint(colors.purple);rect('fill',0,0,W,25)
  paint(colors.white);love.graphics.setFont(font)
  love.graphics.printf('QEEP REVIVAL 2008',7,6,W-14,'center')
  if view=='jcl' and document then drawJCL()
  else
    text('Laboratorio Lua / LOVE',11,38,W-22,'center',true)
    text('Interface provisoria - nao e tela original',7,63,W-14,'center')
    paint(colors.green);rect('fill',9,83,W-18,1)
    if view=='menu' then
      for i,option in ipairs(options) do
        local y=91+(i-1)*30
        if selected==i then
          paint(colors.focus);rect('fill',11,y,W-22,27)
          paint(colors.purple);rect('line',11,y,W-22,27)
        end
        text((selected==i and '> ' or '  ')..option,16,y+6,W-32)
      end
    elseif view=='host' then
      text('IP ou nome do servidor:',15,106,215)
      paint(colors.white);rect('fill',12,136,216,34)
      paint(colors.purple);rect('line',12,136,216,34)
      text(serverHost..'_',18,146,206)
      text('Digite o IP do PC na rede local.\nEnter salva. Esc volta.',12,185,216)
    elseif view=='status' then
      text('Resultado',13,106,214,'center',true)
      text(status,14,153,212)
      text('Enter / Esc para voltar',12,274,216,'center')
    elseif view=='about' then
      text('Reconstrucao independente de um cliente Java ME de 2008.',14,105,212)
      text('O interpretador JCL e parcial. A demonstracao e sintetica.',14,167,212)
      text('Enter / Esc para voltar',12,274,216,'center')
    end
    paint(colors.purple);rect('fill',0,H-25,W,25)
    paint(colors.white);love.graphics.setFont(font)
    love.graphics.printf(view=='menu' and 'Selecionar: Enter   Voltar: Esc' or 'Voltar: Esc',6,H-19,W-12,'center')
  end
  love.graphics.pop()
end
function love.keypressed(key)
  if view=='jcl' and document then
    if document.editing then
      if key=='return' or key=='kpenter' or key=='escape' then
        document.editing=false;love.keyboard.setTextInput(false)
      elseif key=='backspace' then jcl_view.backspace(document) end
    elseif key=='up' then jcl_view.move(document,-1);keepSelectedVisible()
    elseif key=='down' then jcl_view.move(document,1);keepSelectedVisible()
    elseif key=='pageup' then scroll=math.max(0,scroll-120)
    elseif key=='pagedown' then scroll=scroll+120
    elseif key=='return' or key=='kpenter' or key=='space' then
      local response=jcl_view.activate(document)
      if response=='editing' then love.keyboard.setTextInput(true)
      elseif response and response~='selected' then jclNavigate(response) end
    elseif key=='left' then jclSoftkey('lsk')
    elseif key=='right' then jclSoftkey('rsk')
    elseif key=='escape' then returnMenu() end
    return
  end
  if view=='menu' then
    if key=='up' then selected=(selected-2)%#options+1
    elseif key=='down' then selected=selected%#options+1
    elseif key=='return' or key=='kpenter' or key=='space' then activate()
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
    jcl_view.text(document,t)
  end
end
function love.mousepressed(x,y,button)
  if button~=1 then return end
  local scale,ox,oy=transform()
  local px,py=(x-ox)/scale,(y-oy)/scale
  if px<0 or px>W or py<0 or py>H then return end
  if view=='menu' then
    for i=1,#options do
      local top=91+(i-1)*30
      if py>=top and py<=top+27 then selected=i;activate();break end
    end
  elseif view=='jcl' and document then
    if py>=H-25 then if px<W/2 then jclSoftkey('lsk') else jclSoftkey('rsk') end
    elseif py>=65 and py<289 then
      for _,hit in ipairs(hitboxes) do
        if py>=hit.y and py<hit.y+hit.height then
          document.selected=hit.index
          local response=jcl_view.activate(document)
          if response=='editing' then love.keyboard.setTextInput(true)
          elseif response and response~='selected' then jclNavigate(response) end
          break
        end
      end
    end
  elseif py>=H-34 then returnMenu() end
end
function love.touchpressed(_,x,y)
  love.mousepressed(x,y,1)
end
function love.wheelmoved(_,dy)
  if view=='jcl' and document then scroll=math.max(0,scroll-dy*32) end
end
