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
s.connected=true;s.player.dead=false;c.mode='OFF';s.mode='OFF'
check(c.minigames and not c.minigames.poker and not c.minigames.farkle,'bootstrap loads games OFF')
local function command(value)matches={[2]=value};aliases[c.alias]();matches=nil end
local before=#sent
command('games on');text('It is now your turn. Do you wish to check, raise, fold or allin?')
check(sent[#sent]=='poker check'and #sent==before+1,'actual core alias and text dispatch poker')
text('Friend takes a seat at the poker table.');check(sent[#sent]=='poker buyin for 200','actual core buy-in')
local at=#sent;text('Other takes a seat at the poker table.');check(#sent==at,'core prevents repeat buy-in')
text('You take your remaining 42 gold and leave the poker table.');text('Other takes a seat at the poker table.');check(#sent==at+1,'core leave resets buy-in')
command('games off');at=#sent;text('It is now your turn! Please FARKLE ROLL to continue.');check(#sent==at,'core games off')
command('farkle on');text('It is now your turn! Please FARKLE ROLL to continue.');check(sent[#sent]=='farkle done','core exact friend Farkle behavior')
text('Friend has initiated a game of Farkle! You can PLAY FARKLE within the next thirty seconds to join.');check(sent[#sent]=='PLAY FARKLE','core Farkle join')
command('off');check(not c.minigames.poker and not c.minigames.farkle,'global cv2 off disarms games')
command('games on');c.mode='BASH';s.mode='BASH';at=#sent;c.minigames.line('It is now your turn. Do you wish to check, raise, fold or allin?');check(#sent==at,'core combat pause')
c.mode='OFF';s.mode='OFF';handlers['sysDisconnectionEvent']();check(not c.minigames.poker and not c.minigames.farkle and not c.minigames.playing,'native disconnect disarms/reset')
realprint('PASS minigames actual-bootstrap '..n..' assertions')
