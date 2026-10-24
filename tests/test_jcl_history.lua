package.path='client/?.lua;client/lib/?.lua;'..package.path
local hist=require('lib.jcl_history')
local checks=0
local function same(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local history=hist.new(2)
same(hist.depth(history),0)
local a={page=1,selected=3,editing=false,document={forms={{id='start'},{id='next'}}}}
hist.push(history,a,73)
a.page=2;a.selected=5;a.editing=true
local b={page=1,selected=2,editing=false,document={forms={{id='remote'}}}}
hist.push(history,b,12)
hist.push(history,b,80) -- cap 2, drops A
same(hist.depth(history),2)
local doc,scroll=hist.pop(history)
same(doc,b);same(scroll,80);same(doc.page,1);same(doc.selected,2)
same(hist.depth(history),1)
doc,scroll=hist.pop(history)
same(doc,b);same(scroll,12)
same(hist.pop(history),nil)
same(hist.depth(history),0)
hist.push(history,a,-100)
doc,scroll=hist.pop(history)
same(doc,a);same(doc.page,2);same(doc.selected,5);same(doc.editing,false);same(scroll,0)
hist.push(history,a,1)
hist.clear(history)
same(hist.depth(history),0)
local bounded=hist.new(999)
same(bounded.limit,32)
print(('OK: %d JCL history checks'):format(checks))
