-- First executable LÖVE prototype. This UI is NOT presented as a recovered Qeep screen.
local protocol = require('lib.protocol')
local colors = {
  background = {235/255, 1, 185/255}, -- registry.ini s0
  focus = {205/255, 1, 60/255},       -- registry.ini s2
  green = {160/255, 180/255, 25/255},
  purple = {125/255, 20/255, 125/255},
  text = {0, 0, 0}, white = {1, 1, 1}, shade = {.18, .18, .18}
}
local W, H = 240, 320
local view = 'menu'
local selected, serverHost, status = 1, '127.0.0.1', ''
local options = {'Testar servidor local', 'Configurar endereco IP', 'Sobre o projeto', 'Sair'}
local font, big
local function paint(color) love.graphics.setColor(color) end
local function rect(mode, x, y, w, h)
  love.graphics.rectangle(mode, x, y, w, h)
end
local function text(s, x, y, width, align, useBig)
  love.graphics.setFont(useBig and big or font)
  paint(colors.text)
  love.graphics.printf(s, x, y, width, align or 'left')
end
local function transform()
  local dw, dh = love.graphics.getDimensions()
  local scale = math.min(dw/W, dh/H)
  return scale, (dw-W*scale)/2, (dh-H*scale)/2
end
local function returnMenu() view = 'menu'; love.keyboard.setTextInput(false) end
local function probe()
  local ok, socklib = pcall(require, 'socket')
  if not ok then status = 'LuaSocket indisponivel nesta compilacao.'; view = 'status'; return end
  local conn, reason = socklib.tcp()
  if not conn then status = tostring(reason); view = 'status'; return end
  conn:settimeout(1.5)
  local done, err = conn:connect(serverHost, 5190)
  if not done then
    status = 'Falha: ' .. tostring(err) .. '\nHost: ' .. serverHost .. ':5190'
  else
    local sent, sendErr = conn:send(protocol.encodeRequest('O', '/revival/ping', {lang='en'}, ''))
    if not sent then status = 'Erro ao enviar: ' .. tostring(sendErr)
    else
      local reply, readErr, partial = conn:receive('*a')
      local raw = reply or partial or ''
      local valid, response = pcall(protocol.decodeReply, raw)
      if valid and response.properties.ok == 'true' and response.payload == 'PONG' then
        status = 'Servidor Lua respondeu!\nHost: ' .. serverHost .. ':5190\n\nEste e apenas um teste de transporte.'
      else status = 'Resposta invalida: ' .. tostring(readErr or response) end
    end
  end
  conn:close()
  view = 'status'
end
local function activate()
  if selected == 1 then probe()
  elseif selected == 2 then view = 'host'; love.keyboard.setTextInput(true)
  elseif selected == 3 then view = 'about'
  elseif selected == 4 then love.event.quit() end
end
function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  font, big = love.graphics.newFont(12), love.graphics.newFont(17)
  if love.filesystem.getInfo('host.txt') then
    local saved = love.filesystem.read('host.txt')
    if saved and #saved < 128 then serverHost = saved:gsub('%s+', '') end
  end
end
function love.draw()
  local scale, ox, oy = transform()
  paint(colors.shade); love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
  love.graphics.push()
  love.graphics.translate(ox, oy); love.graphics.scale(scale, scale)
  paint(colors.background); rect('fill', 0, 0, W, H)
  paint(colors.purple); rect('fill', 0, 0, W, 25)
  paint(colors.white); love.graphics.setFont(font)
  love.graphics.printf('QEEP REVIVAL 2008', 7, 6, W-14, 'center')
  text('Laboratorio Lua / LOVE', 11, 38, W-22, 'center', true)
  text('Interface provisoria - nao e tela original', 7, 63, W-14, 'center')
  paint(colors.green); rect('fill', 9, 83, W-18, 1)
  if view == 'menu' then
    for i, option in ipairs(options) do
      local y = 100 + (i-1)*37
      if selected == i then
        paint(colors.focus); rect('fill', 11, y, W-22, 31)
        paint(colors.purple); rect('line', 11, y, W-22, 31)
      end
      text((selected == i and '> ' or '  ') .. option, 16, y+8, W-32)
    end
  elseif view == 'host' then
    text('IP ou nome do servidor:', 15, 106, 215)
    paint(colors.white); rect('fill', 12, 136, 216, 34)
    paint(colors.purple); rect('line', 12, 136, 216, 34)
    text(serverHost .. '_', 18, 146, 206)
    text('Digite o IP do PC na rede local.\nEnter salva. Esc volta.', 12, 185, 216)
  elseif view == 'status' then
    text('Resultado do teste', 13, 106, 214, 'center', true)
    text(status, 14, 153, 212)
    text('Enter / Esc para voltar', 12, 274, 216, 'center')
  elseif view == 'about' then
    text('Reconstrucao independente de um cliente Java ME de 2008.', 14, 105, 212)
    text('A navegacao e o protocolo de teste ainda nao representam a rede original completa.', 14, 167, 212)
    text('Enter / Esc para voltar', 12, 274, 216, 'center')
  end
  paint(colors.purple); rect('fill', 0, H-25, W, 25)
  paint(colors.white); love.graphics.setFont(font)
  love.graphics.printf(view == 'menu' and 'Selecionar: Enter   Voltar: Esc' or 'Voltar: Esc', 6, H-19, W-12, 'center')
  love.graphics.pop()
end
function love.keypressed(key)
  if view == 'menu' then
    if key == 'up' then selected = (selected-2)%#options+1
    elseif key == 'down' then selected = selected%#options+1
    elseif key == 'return' or key == 'kpenter' or key == 'space' then activate()
    elseif key == 'escape' then love.event.quit() end
  elseif view == 'host' then
    if key == 'return' or key == 'kpenter' then
      serverHost = serverHost:gsub('%s+', '')
      if #serverHost > 0 then love.filesystem.write('host.txt', serverHost) end
      returnMenu()
    elseif key == 'backspace' then serverHost = serverHost:sub(1, -2)
    elseif key == 'escape' then returnMenu() end
  elseif key == 'escape' or key == 'return' or key == 'kpenter' then returnMenu() end
end
function love.textinput(t)
  if view == 'host' and #serverHost + #t < 128 and t:match('^[%w%.:%-]+$') then
    serverHost = serverHost .. t
  end
end
function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  local scale, ox, oy = transform()
  local px, py = (x-ox)/scale, (y-oy)/scale
  if px < 0 or px > W or py < 0 or py > H then return end
  if view == 'menu' then
    for i = 1, #options do
      local top = 100 + (i-1)*37
      if py >= top and py <= top+31 then selected = i; activate(); break end
    end
  elseif py >= H-34 then returnMenu() end
end
function love.touchpressed(_, x, y)
  love.mousepressed(x, y, 1)
end
