package.path='client/?.lua;client/lib/?.lua;'..package.path
local M=require('lib.connection_settings')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b));n=n+1 end
for _,t in ipairs({
 {'192.168.1.25','192.168.1.25',5190},{'10.3.4.5:64000','10.3.4.5',64000},
 {'172.31.255.1:1','172.31.255.1',1},{'localhost:5190','localhost',5190},
 {'127.0.0.1','127.0.0.1',5190},{'  192.168.0.7:5200 \n','192.168.0.7',5200}
}) do
 local h,p=M.parse(t[1]);eq(h,t[2]);eq(p,t[3]);eq(M.format(h,p),t[2]..':'..t[3])
end
for _,bad in ipairs({'','192.168.1.1:','192.168.1.1:0','192.168.1.1:65536',
 '192.168.1.1:-1','192.168.1.1:005','192.168.1.1:1:1',
 '192.168.1.01:5190','192.168.1.256:5190','example.org:5190',
 '8.8.8.8:5190','127.0.0.2:5190','0.0.0.0:5190',
 '192.168.1.1;evil','192.168.1.1:5\n3','192.168.1.1:5190--',
 '1.2.3.4:80','::1:5190',string.rep('x',70)}) do eq(M.parse(bad),nil) end
eq(M.default_for('Android'),'');eq(M.default_for('iOS'),'')
eq(M.default_for('Windows'),'127.0.0.1')
eq(M.append('192.168.','1.50:5190'),'192.168.1.50:5190')
eq(M.append('x',';rm -rf'),'x')
eq(M.append('x',string.rep('9',100)),'x')
eq(M.backspace('abc'),'ab')
print(('OK: %d LAN endpoint settings checks'):format(n))
