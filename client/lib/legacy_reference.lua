-- Verifiable colors/text/resources from the uploaded qeep-94724.jar's
-- registry.ini and PNG headers. This describes *assets*, not historical screens.
local palette = require('lib.legacy_palette')
local M = {}
M.title = 'Recursos do JAR 1.29'
M.provenance = 'registry.ini / PNGs do JAR, janeiro de 2008'
M.commands = {back='Back', select='Select', cancel='Cancel', options='Options', ok='OK'}
M.assets = {
  {name='logo.png',width=128,height=42},
  {name='icon_15x15.png',width=15,height=15},
  {name='kui/symbols.png',width=12,height=180,cellWidth=12,cellHeight=6}
}
M.swatches = {
  {label='s0 bg',hex='ebffb9'}, {label='s2 bg',hex='cdff3c'},
  {label='s7 cbg',hex='a0b419'}, {label='s10 bg',hex='a1b617'},
  {label='s0 xc',hex='7d147d'}, {label='s10 tc',hex='501e50'},
  {label='s11 tc',hex='3c143c'}, {label='white',hex='ffffff'}
}
function M.color(swatch)
  return palette.hex(assert(swatch.hex))
end
return M
