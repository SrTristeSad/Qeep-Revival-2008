package.path='client/?.lua;client/lib/?.lua;'..package.path
local host=require('lib.lab_host')
local yes={'localhost','127.0.0.1','10.0.0.1','10.240.12.99','172.16.0.1','172.31.255.255','192.168.1.50'}
local no={'l2.iatv-be.de','example.com','8.8.8.8','169.254.0.3','172.32.0.1','172.15.1.1',
  '127.0.0.2','192.169.1.1','192.168.1.256','192.168.1.01','192.168..1','192.168.1.1.',
  '.192.168.1.1','::1','','1.2.3','10.0.0.1.2','192.168.1.1:5190','0.0.0.0'}
for _,value in ipairs(yes) do assert(host.valid(value),'valid host rejected: '..value) end
for _,value in ipairs(no) do assert(not host.valid(value),'invalid host accepted: '..value) end
assert(not host.valid(1234))
print(('OK: %d local-only address checks'):format(#yes+#no+1))
