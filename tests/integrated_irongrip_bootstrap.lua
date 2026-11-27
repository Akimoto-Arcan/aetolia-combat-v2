-- Offline actual-bootstrap tests. No real Mudlet/network or preference writes.
local root=assert(arg[1]);local realdofile=dofile;local clock=100
local handlers,aliases,timers,sent={},{},{},{};local serial=0;local prompt;local triggers={}
local output={};local realprint=print;print=function(...)output[#output+1]=table.concat({...},' ')end
local native_loadfile=loadfile
function loadfile(path,...)return native_loadfile(path:gsub('^/offline/combat_v2/',function()return root end),...)end
function getEpoch()return clock end
function getMudletHomeDir()return '/offline'end
function getConnectionInfo()return 'fixture',0,true end
local event_callbacks={};local event_ids={}
function registerAnonymousEventHandler(name,fn)
 serial=serial+1;event_callbacks[name]=event_callbacks[name] or {};event_callbacks[name][serial]=fn;event_ids[serial]=name
 handlers[name]=function()local copy={};for id,f in pairs(event_callbacks[name])do copy[id]=f end;for _,f in pairs(copy)do f()end end
 return serial
end
function killAnonymousEventHandler(id)local name=event_ids[id];if name then event_callbacks[name][id]=nil end end
function tempRegexTrigger(_,fn)serial=serial+1;triggers[serial]=fn;return serial end
local prompt_callbacks={}
function killTrigger(id)triggers[id]=nil;prompt_callbacks[id]=nil end
function tempPromptTrigger(fn)
 serial=serial+1;prompt_callbacks[serial]=fn
 prompt=function()local copy={};for id,f in pairs(prompt_callbacks)do copy[id]=f end;for _,f in pairs(copy)do f()end end
 return serial
end
function tempAlias(pattern,fn)aliases[pattern]=fn;return pattern end
function killAlias(pattern)aliases[pattern]=nil end
function tempTimer(delay,fn)serial=serial+1;timers[serial]={at=clock+delay,fn=fn};return serial end
function killTimer(id)timers[id]=nil end
function send(command)sent[#sent+1]=command end
function sendGMCP()end
local shown=0
function dofile(path)
 path=path:gsub('^/offline/combat_v2/',function()return root end)
 if path:match('/bootstrap.lua$') and arg[2]=='wired' then
  local f=assert(io.open(path,'r'));local source=f:read('*a');f:close()
  local count;source,count=source:gsub('local audit=command=="racial skills"','local audit=command=="racial help irongrip"or command=="racial skills"',1)
  assert(count==1 or source:find('local audit=command=="racial help irongrip"or command=="racial skills"',1,true),'exact parent audit whitelist integration point')
  return assert((loadstring or load)(source,'@actual-bootstrap-with-one-audit-whitelist-addition'))()
 end
 if path:match('/gui.lua$')then return {create=function()end,refresh=function()end,show_defenses=function()shown=shown+1;return true end}end
 return realdofile(path)
end
-- Preference IO is a deliberately in-memory test adapter.
local nativeio=io;local rename=os.rename;local store={};local payload
io=setmetatable({open=function(path,mode)
 path=path:gsub('^/offline/combat_v2/',function()return root end)
 if not path:match('defup%-settings%.json')then assert(not mode or not mode:match('[wa+]'),'unexpected fixture write '..path);return nativeio.open(path,mode)end
 if mode=='r' and not store[path]then return nil,'missing' end
 return {read=function()return store[path]end,write=function(_,value)store[path]=value;return true end,close=function()return true end}
end},{__index=nativeio})
os.rename=function(a,b)if a:match('defup%-settings%.json%.new$')then store[b]=store[a];store[a]=nil;return true end;return rename(a,b)end
yajl={to_string=function(value)payload=value;return 'fixture-json'end,to_value=function(text)assert(text=='fixture-json');return payload end}
gmcp={Char={Status={name='Fixture',class='Monk',race='Atavian'},Name={name='Fixture'},Skills={Groups={{name='Kaido',rank='Transcendent 100%'}}},Vitals={hp=100,maxhp=100,mp=100,maxmp=100,wp=100,maxwp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,stance='scorpion'}},Room={Info={num=1,area='Fixture Hunt'},Players={}}}
dofile(root..'bootstrap.lua')
local c=combat_v2;local s=c.current;local M=c.buffs;local n=0
local function check(ok,why)assert(ok,why);n=n+1 end
local function tick()clock=clock+1;combat_v2_tick()end
local function only(key)for _,e in ipairs(M.catalog)do s.buffs.wanted[e.key]=e.key==key end end
local function def(kind,data)gmcp.Char.Defences=gmcp.Char.Defences or{};gmcp.Char.Defences[kind]=data;handlers['gmcp.Char.Defences.'..kind]()end
local function text(value)line=value;triggers[c.line_trigger]();line=nil end
local function priority_rows(entries)
 for i=1,25 do text(i..': '..(entries[i]or''))end
end
local function priorities(entries)
 text('Your defense priorities:');priority_rows(entries);text('Defs with priority 26 are ignored.')
end
check(#sent==0 and not s.buffs.master and not s.buffs.sequence,'actual bootstrap startup passive')
handlers['gmcp.Char.Vitals']();handlers['gmcp.Char.Status']();only('irongrip');def('List',{})
check(#sent==0,'genuine OFF status/vitals/List emit no query or cast')
check(combat_v2_buffs('start'),'actual DEFUP API')
if arg[2]~='wired' then
 check(#sent==0 and s.buffs.fault and s.buffs.fault:find('Defense command rejected',1,true),'unchanged actual bootstrap rejects missing audit whitelist safely')
 realprint('PASS actual-bootstrap expected wiring blocker '..n..' assertions');return
end
check(sent[#sent]=='racial help irongrip','actual dispatcher sends read-only help before cast: '..tostring(sent[#sent])..' / '..tostring(c.buff_status)..' / connected='..tostring(s.connected)..' hp='..tostring(s.player.hp)..' dead='..tostring(s.player.dead)..' class='..tostring(s.buffs.class)..' / '..tostring(s.buffs.status)..' / '..tostring(select(2,M.availability(s,'irongrip'))))
local audited=false;for _,event in ipairs(s.history or {})do if event.kind=='buff_audit' and event.detail=='racial help irongrip' then audited=true end end;check(audited,'query goes through existing read-only audit classification')
text('Irongrip (Racial)                             Known: Yes');text('---------------------');text('Syntax: IRONGRIP and RELAX IRONGRIP');text('By gripping your weapons tightly, you can prevent others from disarming you of your precious ');text('weapons.')
check(not M.availability(s,'irongrip'),'help not committed before real prompt')
prompt();tick()
check(s.buffs.pending and s.buffs.pending.key=='irongrip' and not s.buffs.irongrip_proof,'real text/prompt commits then spends single-activation Known proof')
check(sent[#sent]=='IRONGRIP' and s.buffs.pending,'actual DEFUP sends through Buffs')
local p=s.buffs.pending;local before=#sent;tick();check(s.buffs.pending==p and #sent==before,'actual double tick no duplicate')
text('You use Racial Irongrip.');text('You concentrate on gripping tightly with your hands so you don’t lose your hold.');text('You have gained the irongrip defence.');text('Balance Used: 2.79 seconds.')
gmcp.Char.Vitals.balance=0;handlers['gmcp.Char.Vitals']();prompt();tick();check(s.buffs.pending==p,'actual loss/prompt cannot settle')
M.stop(s);check(s.buffs.pending==p,'actual OFF keeps pending')
gmcp.Char.Vitals.balance=1;handlers['gmcp.Char.Vitals']();check(s.buffs.pending==p,'actual Vitals recovery needs later prompt');prompt();tick()
check(not s.buffs.pending and not s.buffs.master,'actual recovery plus later prompt settles while OFF')
text('Your irongrip defence has been stripped.');check(not s.player.defences.irongrip,'actual stripped text removes canonical defense')
realprint('PASS actual-bootstrap Irongrip '..n..' assertions')
