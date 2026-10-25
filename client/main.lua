-- Qeep Revival 2008: evidence-based JCL laboratory client (NOT historical screens).
-- Windows/Android: shared Lua + LÖVE code, no WebView, no legacy-server contact.
local protocol = require('lib.protocol')
local jcl = require('lib.jcl')
local jcl_view = require('lib.jcl_view')
local layout = require('lib.jcl_layout')
local legacy = require('lib.legacy_palette')
local jcl_style = require('lib.jcl_style')
local jcl_submit = require('lib.jcl_submit')
local lab_host = require('lib.lab_host')
local jcl_history = require('lib.jcl_history')
local assets = require('lib.legacy_assets')
local symbols = require('lib.legacy_symbols')
local jcl_screen = require('lib.jcl_screen')
local viewport = require('lib.legacy_viewport')
local visual_reference = require('lib.legacy_reference')
local registry_tokens = require('lib.registry_tokens')
local visual_capture = require('lib.visual_capture')
local social_poll = require('lib.social_poll')
local social_send = require('lib.social_send')
local c = legacy.colors
local W,H = 240,320
local MENU_Y,MENU_ROW=91,22
local TOP,BOTTOM = 65,281
local VH = BOTTOM-TOP
local view, selected, serverHost, status = 'menu',1,'127.0.0.1',''
local options = {
  'Abrir JCL (offline)', 'Receber JCL do servidor', 'Testar servidor local',
  'Configurar endereco IP', 'Composicao JCL (laboratorio)', 'Sobre o projeto',
  'Social local (prototipo)', 'Recursos originais (JAR)', 'Sair'
}
local font,big,document,computed,scroll = nil,nil,nil,nil,0
local touches = {}
local history = jcl_history.new(16)
local previousView = 'menu'
local guestSession = nil -- ephemeral; never persisted
local pollJob, pollPending, pollElapsed, pollHint = nil,nil,0,''
local sendJob, sendHint = nil,''
local originalLogo = nil
local visualMode = 1 -- 1=original assets, 2=raw registry style tokens
local imageCache = {}
local function paint(color) love.graphics.setColor(color) end
local function rect(mode,x,y,w,h) love.graphics.rectangle(mode,x,y,w,h) end
local function text(s,x,y,width,align,useBig,color)
  love.graphics.setFont(useBig and big or font)
  paint(color or c.black)
  love.graphics.printf(tostring(s or ''),x,y,width,align or 'left')
end
local function transform()
  local dw,dh=love.graphics.getDimensions()
  local t=viewport.fit(dw,dh,W,H)
  return t.scale,t.x,t.y
end
local function localPoint(x,y)
  local dw,dh=love.graphics.getDimensions()
  return viewport.fromWindow(viewport.fit(dw,dh,W,H),x,y)
end
local function cancelPoll()
  if pollJob then social_poll.cancel(pollJob);pollJob=nil end
  pollPending=nil;pollElapsed=0;pollHint=''
end
local function cancelSend()
  if sendJob then social_send.cancel(sendJob);sendJob=nil end
end
local function activeChatPeer()
  if view~='jcl' or not document or not guestSession then return nil end
  local props=document.document.props or {}
  if jcl_view.form(document).id~='chat' then return nil end
  if type(props.chatPeer)=='string' and (props.chatPeer:match('^[1-9]%d*$') or
      (props.chatPeer:match('^[a-z][a-z0-9_]*$') and #props.chatPeer>=3 and #props.chatPeer<=24)) then
    return props.chatPeer
  end
  return nil
end
local function returnMenu()
  cancelSend()
  cancelPoll()
  view='menu';scroll=0;computed=nil;document=nil
  jcl_history.clear(history)
  love.keyboard.setTextInput(false)
end
local function showError(message)
  if view ~= 'status' then previousView=view end
  status=tostring(message);view='status'
  love.keyboard.setTextInput(false)
end
local function dismissStatus()
  if previousView=='jcl' and document then view='jcl'
  else returnMenu() end
end
local function refreshLayout(ensure)
  if not document then return end
  local form=jcl_view.form(document)
  computed=layout.place(layout.build(form,font,220),VH,form.valign)
  if ensure and document.choosing then
    scroll=layout.ensure_choice_visible(computed,document.selected,document.choiceFocus,scroll,VH)
  elseif ensure then scroll=layout.ensure_visible(computed,document.selected,scroll,VH)
  else scroll=layout.clamp_scroll(computed,scroll,VH) end
end
local function openJCL(source, preservePrevious, socialResponse)
  local ok,result=pcall(jcl.parse,source)
  if not ok then showError(result);return false end
  if preservePrevious and view=='jcl' and document then
    jcl_history.push(history,document,scroll)
  else
    jcl_history.clear(history)
  end
  if socialResponse and result.props then
    if result.props.sessionClear=='true' then guestSession=nil
    elseif result.props.guestSession then guestSession=result.props.guestSession end
  end
  cancelPoll()
  cancelSend()
  sendHint=''
  document=jcl_view.new(result)
  view='jcl';scroll=0
  love.keyboard.setTextInput(false)
  refreshLayout(true)
  return true
end
local function goBack()
  cancelSend()
  cancelPoll()
  local prior,priorScroll=jcl_history.pop(history)
  if prior then
    document=prior
    view='jcl';scroll=priorScroll
    love.keyboard.setTextInput(false)
    refreshLayout(false)
  else returnMenu() end
end
local function socketRequest(path, kind, properties)
  if not lab_host.valid(serverHost) then return nil,'Use somente IP de rede privada ou localhost.' end
  local ok,socklib=pcall(require,'socket')
  if not ok then return nil,'LuaSocket indisponivel nesta compilacao.' end
  local conn,reason=socklib.tcp()
  if not conn then return nil,tostring(reason) end
  conn:settimeout(1.5)
  local connected,connectErr=conn:connect(serverHost,5190)
  if not connected then conn:close();return nil,connectErr end
  local props={}
  for k,v in pairs(properties or {lang='pt-BR'}) do props[k]=v end
  if path:sub(1,16)=='/revival/social/' and path~='/revival/social/start'
    and path~='/revival/social/join' and path~='/revival/social/register/submit'
    and path~='/revival/social/login/submit' and guestSession then props.session=guestSession end
  local request=protocol.encodeRequest(kind or 'O',path,props,'')
  local sent,sendErr,last=conn:send(request)
  if not sent and (not last or last<#request) then conn:close();return nil,sendErr end
  local reply,readErr,partial=conn:receive('*a')
  conn:close()
  local valid,result=pcall(protocol.decodeReply,reply or partial or '')
  if not valid then return nil,tostring(result)..' ('..tostring(readErr)..')' end
  if result.kind~='R' or result.path~=path then return nil,'Resposta inesperada do laboratorio.' end
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
  elseif selected==5 then
    local file=love.filesystem.read('fixtures/composition.xml')
    if file then openJCL(file) else showError('Fixture de composicao nao encontrada.') end
  elseif selected==6 then view='about'
  elseif selected==7 then
    local source,err=socketRequest('/revival/social/start')
    if source then openJCL(source,false,true) else showError('Servidor social indisponivel: '..tostring(err)) end
  elseif selected==8 then view='visual';visualMode=1
  elseif selected==9 then love.event.quit() end
end
local function navigate(href, activated)
  if type(href)~='string' or href=='' then return end
  cancelPoll()
  if href:sub(1,1)=='#' then
    local id=href:sub(2)
    local target
    for i,form in ipairs(document.document.forms) do
      if form.id==id then target=i;break end
    end
    if not target then return showError('Formulario JCL ausente: '..href) end
    if target==document.page then return end
    jcl_history.push(history,document,scroll)
    jcl_view.next_form(document,id)
    scroll=0;refreshLayout(true)
  elseif href=='/revival/page/lab' or href=='/revival/page/submit' then
    local source,err=socketRequest(href)
    if source then openJCL(source,true) else showError('Falha no servidor: '..tostring(err)) end
  elseif href:match('^/revival/social/') then
    local authSubmit=href=='/revival/social/register/submit' or href=='/revival/social/login/submit'
    local contactPost=href=='/revival/social/contact/request' or
      href:match('^/revival/social/contact/(%a+)/')
    local accountSend=href:match('^/revival/social/account/send/([a-z][a-z0-9_]*)$')
    local submitting=href=='/revival/social/join' or authSubmit or contactPost or
      accountSend or href:match('^/revival/social/send/[1-9]%d*$')
    local props={}
    if submitting then
      local ok,fields=pcall(jcl_submit.collect,jcl_view.form(document),activated)
      if not ok then return showError(fields) end
      props=fields;props.lang='pt-BR'
    end
    local peer=href:match('^/revival/social/send/([1-9]%d*)$') or accountSend
    if peer then
      if sendJob then return end
      if not lab_host.valid(serverHost) then return showError('Endereço local inválido') end
      local available,socklib=pcall(require,'socket')
      if not available then return showError('LuaSocket indisponível no cliente') end
      local task,err=social_send.start(socklib,protocol,serverHost,5190,guestSession,peer,props)
      if task then
        sendHint=''
        sendJob=task;sendHint='Enviando mensagem...';cancelPoll()
      else sendHint='Não enviado: '..tostring(err) end
      return
    end
    local source,err=socketRequest(href,submitting and 'P' or 'O',props)
    if source then openJCL(source,not authSubmit,true) else showError('Falha social: '..tostring(err)) end
  elseif href=='/revival/submit/echo' then
    local ok,fields=pcall(jcl_submit.collect,jcl_view.form(document),activated)
    if not ok then return showError(fields) end
    fields.lang='pt-BR'
    local source,err=socketRequest(href,'P',fields)
    if source then openJCL(source,true) else showError('Falha ao enviar: '..tostring(err)) end
  else
    -- Restricted to explicit local laboratory routes; never contact legacy endpoints.
    showError('Endereco nao permitido no laboratorio:\n'..href)
  end
end
-- Refresh only the active conversation; preserve draft text, focus and scroll.
-- Do not modify the Back stack for background refreshes.
local function applyPolledChat(source, peer)
  local ok,parsed=pcall(jcl.parse,source)
  if not ok or not parsed.props or parsed.props.chatPeer~=peer or
      not parsed.forms[1] or parsed.forms[1].id~='chat' then
    pollHint='Resposta de atualização inválida'
    return
  end
  local former=document
  local oldItems=jcl_view.form(former).items
  local oldSelected=oldItems[former.selected]
  local candidate=jcl_view.new(parsed)
  local newItems=jcl_view.form(candidate).items
  for _,item in ipairs(newItems) do
    if item.id=='message' and item.kind=='textarea' then
      for _,previous in ipairs(oldItems) do
        if previous.id=='message' and previous.kind=='textarea' then
          item.value=previous.value or ''
        end
      end
    end
  end
  if oldSelected then
    for i,item in ipairs(newItems) do
      if item.id and item.id==oldSelected.id and item.kind==oldSelected.kind then
        candidate.selected=i;break
      end
    end
  end
  local bottom=computed and scroll>=layout.max_scroll(computed,VH)-20
  document=candidate
  refreshLayout(false)
  if bottom then scroll=layout.max_scroll(computed,VH) end
  pollHint='Conversa atualizada automaticamente'
end
function love.update(dt)
  if sendJob then
    local result=social_send.step(sendJob,dt)
    if result then
      sendJob=nil
      if result.ok then
        -- Only a confirmed reply advances the chat page. The Back stack retains
        -- the original draft; a failed/ambiguous send never clears it.
        if openJCL(result.payload,true,true) then sendHint='' end
      else
        sendHint=(result.rejected and 'Rejeitado: ' or 'Envio não confirmado: ')..tostring(result.error)
        pollElapsed=0
      end
    end
    return
  end
  local peer=activeChatPeer()
  if not peer then
    if pollJob or pollPending then cancelPoll() end
    return
  end
  pollElapsed=pollElapsed+math.max(0,tonumber(dt) or 0)
  if pollJob then
    local result=social_poll.step(pollJob,dt)
    if result then
      pollJob=nil
      pollElapsed=0
      if result.ok and result.changed then pollPending={peer=peer,payload=result.payload}
      elseif not result.ok then pollHint='Atualização indisponível; nova tentativa automática' end
    end
  end
  if pollPending and not document.editing and not document.choosing then
    local fresh=pollPending
    pollPending=nil
    if activeChatPeer()==fresh.peer then applyPolledChat(fresh.payload,fresh.peer) end
  end
  if not pollJob and not pollPending and pollElapsed>=3 then
    if not lab_host.valid(serverHost) then return end
    local ok,socklib=pcall(require,'socket')
    if not ok then pollHint='LuaSocket ausente: atualização manual';pollElapsed=0;return end
    local props=document.document.props or {}
    local job,err=social_poll.start(socklib,protocol,serverHost,5190,guestSession,peer,props.chatRevision)
    if job then pollJob=job else pollHint='Não foi possível atualizar a conversa';pollElapsed=0 end
  end
end
local activateJCL
local function softkey(kind)
  if document.choosing then
    jcl_view.choice_close(document)
    refreshLayout(true)
    return
  end
  if document.editing then
    document.editing=false
    love.keyboard.setTextInput(false)
    refreshLayout(true)
    return
  end
  local form=jcl_view.form(document)
  local cmd=jcl_screen.command(form,kind)
  if cmd.href and cmd.href~='' then
    -- An unproductive root Back command should still leave the laboratory.
    if cmd.cancel and cmd.href=='#'..tostring(form.id or '') then return goBack() end
    local button=nil
    if cmd.href=='/revival/submit/echo' or cmd.href=='/revival/social/join' or
      cmd.href=='/revival/social/register/submit' or cmd.href=='/revival/social/login/submit' or
      cmd.href:match('^/revival/social/send/[1-9]%d*$') or
      cmd.href=='/revival/social/contact/request' or
      cmd.href:match('^/revival/social/contact/(%a+)/') or
      cmd.href:match('^/revival/social/account/send/[a-z][a-z0-9_]*$') then
      for _,candidate in ipairs(form.items) do
        if candidate.kind=='button' and candidate.href==cmd.href then button=candidate;break end
      end
    end
    return navigate(cmd.href,button)
  end
  if cmd.cancel or kind=='lsk' then return goBack() end
  -- Java ME's default right-side action in this reconstruction activates focus.
  return activateJCL()
end
activateJCL = function()
  local active=jcl_view.item(document)
  local result=jcl_view.activate(document)
  if result=='editing' then love.keyboard.setTextInput(true)
  elseif result=='choosing' or result=='selected' then refreshLayout(true)
  elseif result then navigate(result,active) end
end
function love.load()
  love.graphics.setDefaultFilter('nearest','nearest')
  font,big=love.graphics.newFont(12),love.graphics.newFont(17)
  originalLogo=assets.load('logo.png',love.graphics,imageCache)
  local saved=love.filesystem.read('host.txt')
  if saved and #saved<128 then
    local clean=saved:gsub('%s+','')
    if lab_host.valid(clean) then serverHost=clean end
  end
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
        local width=entry.ruleWidth or 90
        paint(c.olive);rect('fill',math.floor((W-width)/2),y+5,width,1)
      else
        local active=document.selected==entry.index
        local style=jcl_style.resolve(item,active)
        if style.surface then paint(style.surface);rect('fill',10,y,220,height) end
        if style.border then paint(style.border);rect('line',10,y,220,height) end
        text(entry.title,17,y+5,204,'left',false,style.text)
        if item.kind=='img' and entry.imageInfo then
          local image=assets.load(item.src,love.graphics,imageCache)
          if image and love.graphics.draw then
            paint(c.white)
            love.graphics.draw(image,math.floor((W-image:getWidth())/2),y+(entry.imageY or 5))
          else
            text('[imagem original não importada]',17,y+(entry.imageY or 5),204)
          end
        end
        if entry.choiceRows then
          for _,choice in ipairs(entry.choiceRows) do
            local optionY = y + choice.y
            if optionY + choice.height >= TOP and optionY <= BOTTOM then
              local chosen = item.selectedSet and item.selectedSet[choice.index] or false
              local pointer = document.choosing and active and document.choiceFocus == choice.index
              if pointer then
                paint(c.highlight)
                rect('fill',15,optionY,210,choice.height)
              end
              local indicator
              if item.choiceType == 2 then indicator = chosen and '[x]' or '[ ]'
              else indicator = chosen and '(*)' or '( )' end
              text(indicator,17,optionY+3,32,'left',false,style.text)
              text(choice.label,52,optionY+3,171,'left',false,style.text)
            end
          end
        end
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
          text(content,19,detail_y,198,'left',false,style.detail)
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
  local hint = sendHint~='' and sendHint or
    (pollPending and 'Nova mensagem: concluir edicao' or
    (pollHint~='' and pollHint or nil) or
    (document.editing and 'Enter: concluir edicao' or
    (document.choosing and 'Cima/Baixo: opcao  Enter: marcar' or 'Setas: navegar  Enter: abrir')))
  text(hint,7,283,204,'center')
  local strip=assets.load('kui/symbols.png',love.graphics,imageCache)
  if strip then
    local canUp=scroll>0
    local canDown=scroll<layout.max_scroll(computed,VH)
    local first,second=symbols.scroll_frames(canUp,canDown)
    paint(c.white)
    symbols.draw(love.graphics,strip,first,220,284,1,30)
    symbols.draw(love.graphics,strip,second,220,290,1,30)
  end
  paint(c.purple);rect('fill',0,H-25,W,25)
  local left,right=jcl_screen.commands(form,document.choosing)
  text(left.label,6,H-19,105,'left',false,c.white)
  text(right.label,125,H-19,108,'right',false,c.white)
end
-- Evidence gallery: does not purport to reproduce any network-delivered 2008 screen.
local function drawReference()
  text(visual_reference.title,8,32,224,'center',true)
  paint(c.olive);rect('fill',9,51,222,1)
  local logo=assets.load('logo.png',love.graphics,imageCache)
  if logo then
    paint(c.white)
    love.graphics.draw(logo,12,59)
  else
    text('logo.png: importe o JAR',11,63,150)
  end
  local icon=assets.load('icon_15x15.png',love.graphics,imageCache)
  if icon then
    paint(c.white)
    love.graphics.draw(icon,203,73)
  else text('15x15',187,76,48) end
  text('Cores extraidas de registry.ini',10,108,220,'left')
  for i,swatch in ipairs(visual_reference.swatches) do
    local column=(i-1)%2
    local row=math.floor((i-1)/2)
    local x=12+column*114
    local y=128+row*22
    paint(visual_reference.color(swatch))
    rect('fill',x,y,23,15)
    paint(c.dark);rect('line',x,y,23,15)
    text(swatch.label,x+29,y+1,79,'left')
  end
  text('Sprites 14 a 17 (12x6)',10,219,220)
  local strip=assets.load('kui/symbols.png',love.graphics,imageCache)
  if strip then
    for i=0,3 do
      paint(c.white)
      symbols.draw(love.graphics,strip,14+i,25+i*48,241,1,30)
      text(tostring(14+i),42+i*48,236,23,'left')
    end
  else text('kui/symbols.png nao importado',10,241,220) end
  text('Back  |  Select  |  Options',8,266,224,'center')
  text('Tab: mostrar os estilos originais',7,281,226,'center')
  paint(c.purple);rect('fill',0,H-25,W,25)
  text('Voltar: Esc',8,H-19,224,'center',false,c.white)
end
-- Raw style-token inspector, not a reproduction of a delivered Qeep screen.
local function drawRegistryTokens()
  text('Estilos do registry.ini',8,32,224,'center',true)
  text('11 registros sN presentes no JAR',8,51,224,'center')
  paint(c.olive);rect('fill',10,70,220,1)
  for i,style in ipairs(registry_tokens.styles) do
    local y=78+(i-1)*18
    local bg=registry_tokens.solid(style.fields.bg) or registry_tokens.solid(style.fields.cbg)
    if bg then
      paint(bg)
      rect('fill',13,y,37,15)
    else
      paint(c.white);rect('line',13,y,37,15)
    end
    paint(c.purple);rect('line',13,y,37,15)
    local info=style.fields.bg or style.fields.cbg or '(sem fundo)'
    local label=style.id..'  '..info
    text(label,58,y+2,170)
  end
  text('s11 = gradiente codificado (64),',9,278,222)
  text('nao e cor plana nem tela real.',9,287,222)
  paint(c.purple);rect('fill',0,H-25,W,25)
  text('Tab: recursos   Esc: voltar',6,H-19,W-12,'center',false,c.white)
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
  elseif view=='visual' then
    if visualMode==1 then drawReference() else drawRegistryTokens() end
  else
    if view=='menu' and originalLogo and love.graphics.draw then
      paint(c.white)
      love.graphics.draw(originalLogo,math.floor((W-originalLogo:getWidth())/2),28)
      text('Laboratorio (nao historico)',7,72,W-14,'center')
    else
      text('Laboratorio Lua / LOVE',11,38,W-22,'center',true)
      text('Interface provisoria; nao e tela original',7,63,W-14,'center')
    end
    paint(c.olive);rect('fill',9,83,W-18,1)
    if view=='menu' then
      for i,option in ipairs(options) do
        local y=MENU_Y+(i-1)*MENU_ROW
        if selected==i then
          paint(c.highlight);rect('fill',11,y,W-22,MENU_ROW-1)
          paint(c.purple);rect('line',11,y,W-22,MENU_ROW-1)
        end
        text((selected==i and '> ' or '  ')..option,16,y+4,W-32)
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
  -- F12 is an explicit, local screenshot. It captures the actual LOVE window
  -- (including letterboxing); use --crop-candidate/--scale-candidate in QA.
  if key=='f12' then
    local filename = visual_capture.take(love.graphics)
    if filename then print('Qeep screenshot: '..filename..' (LOVE save directory)') end
    return
  end
  if sendJob then return end -- prevent double submit or navigation during in-flight send
  -- Optional J2ME-like numeric keyboard controls; no 1:1 keypad mapping claimed.
  if view=='jcl' or view=='menu' then
    local numeric={['2']='up',['8']='down',['5']='return',['4']='left',
      ['6']='right',['0']='escape',kp2='up',kp8='down',kp5='return',
      kp4='left',kp6='right',kp0='escape'}
    if not (document and document.editing) then key=numeric[key] or key end
  end
  if view=='jcl' and document then
    if document.choosing then
      if key=='up' then jcl_view.choice_move(document,-1);refreshLayout(true)
      elseif key=='down' then jcl_view.choice_move(document,1);refreshLayout(true)
      elseif key=='return' or key=='kpenter' or key=='space' then
        jcl_view.choice_choose(document);refreshLayout(true)
      elseif key=='escape' or key=='backspace' or key=='left' or key=='right' then
        softkey(key=='right' and 'rsk' or 'lsk') end
      return
    end
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
    elseif key=='escape' or key=='backspace' then goBack() end
    return
  end
  if view=='menu' then
    if key=='up' then selected=(selected-2)%#options+1
    elseif key=='down' then selected=selected%#options+1
    elseif key=='return' or key=='kpenter' or key=='space' then activateMenu()
    elseif key=='escape' then love.event.quit() end
  elseif view=='visual' and (key=='tab' or key=='right' or key=='left') then
    visualMode=(visualMode==1 and 2 or 1)
  elseif view=='host' then
    if key=='return' or key=='kpenter' then
      serverHost=serverHost:gsub('%s+','')
      if lab_host.valid(serverHost) then
        love.filesystem.write('host.txt',serverHost)
        returnMenu()
      else
        return showError('Endereco invalido. Use localhost ou IPv4 privado (192.168.x.x, 10.x.x.x, 172.16-31.x.x).')
      end
    elseif key=='backspace' then serverHost=serverHost:sub(1,-2)
    elseif key=='escape' then returnMenu() end
  elseif view=='status' and (key=='escape' or key=='return' or key=='kpenter') then
    dismissStatus()
  elseif key=='escape' or key=='return' or key=='kpenter' then returnMenu() end
end
function love.textinput(t)
  if sendJob then return end
  if view=='host' and #serverHost+#t<128 and t:match('^[%w%.:%-]+$') then
    serverHost=serverHost..t
  elseif view=='jcl' and document and document.editing then
    jcl_view.text(document,t);refreshLayout(true)
  end
end
local function pointer(x,y)
  if sendJob then return end
  local px,py=localPoint(x,y)
  if not px then return end
  if view=='menu' then
    for i=1,#options do
      local y=MENU_Y+(i-1)*MENU_ROW
      if py>=y and py<y+MENU_ROW then selected=i;activateMenu();break end
    end
  elseif view=='jcl' and document then
    if py>=H-25 then
      if px<W/2 then softkey('lsk') else softkey('rsk') end
    elseif py>=TOP and py<BOTTOM then
      local index=layout.hit(computed,px-10,py-TOP,scroll,220,VH)
      if index then
        local item = jcl_view.form(document).items[index]
        if document.editing then document.editing=false;love.keyboard.setTextInput(false) end
        if document.choosing then jcl_view.choice_close(document) end
        document.selected=index
        local option=layout.choice_hit(computed,index,py-TOP,scroll)
        if item.kind=='select' and option and item.choiceType~=4 then
          document.choosing=true
          document.choiceFocus=option
          jcl_view.choice_choose(document,option)
        else activateJCL() end
        refreshLayout(true)
      end
    end
  elseif view=='visual' and py>=H-25 then returnMenu()
  elseif view=='visual' and py>=255 then visualMode=(visualMode==1 and 2 or 1)
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
  if sendJob then return end
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
  if sendJob then return end
  if view=='jcl' and computed then
    scroll=layout.clamp_scroll(computed,scroll-dy*32,VH)
  end
end
