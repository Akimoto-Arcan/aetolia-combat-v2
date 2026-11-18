-- Offline actual-bootstrap tests. No real Mudlet/network or preference writes.
local root=assert(arg[1]);local realdofile=dofile;local clock=100
local handlers,aliases,timers,sent={},{},{},{};local serial=0;local prompt
local output={};local realprint=print;print=function(...)output[#output+1]=table.concat({...},' ')end
function getEpoch()return clock end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,true end
function registerAnonymousEventHandler(name,fn)handlers[name]=fn;return name end
function killAnonymousEventHandler(name)handlers[name]=nil end
function tempRegexTrigger(_,fn)serial=serial+1;return serial end
function killTrigger()end
function tempPromptTrigger(fn)prompt=fn;serial=serial+1;return serial end
function tempAlias(pattern,fn)aliases[pattern]=fn;return pattern end
function killAlias(pattern)aliases[pattern]=nil end
function tempTimer(delay,fn)serial=serial+1;timers[serial]={at=clock+delay,fn=fn};return serial end
function killTimer(id)timers[id]=nil end
function send(command)sent[#sent+1]=command end
function sendGMCP()end
local shown=0
function dofile(path)
 if path:match('/gui.lua$')then return {create=function()end,refresh=function()end,show_defenses=function()shown=shown+1;return true end}end
 return realdofile(path)
end
-- Preference IO is a deliberately in-memory test adapter.
local nativeio=io;local rename=os.rename;local store={};local payload
io=setmetatable({open=function(path,mode)
 if not path:match('defup%-settings%.json')then return nativeio.open(path,mode)end
 if mode=='r' and not store[path]then return nil,'missing' end
 return {read=function()return store[path]end,write=function(_,value)store[path]=value;return true end,close=function()return true end}
end},{__index=nativeio})
os.rename=function(a,b)if a:match('defup%-settings%.json%.new$')then store[b]=store[a];store[a]=nil;return true end;return rename(a,b)end
yajl={to_string=function(value)payload=value;return 'fixture-json'end,to_value=function(text)assert(text=='fixture-json');return payload end}
gmcp={Char={Status={class='Monk'},Name={name='Fixture'},Skills={Groups={{name='Kaido',rank='Transcendent 100%'}}},Vitals={hp=100,maxhp=100,mp=100,maxmp=100,wp=100,maxwp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,stance='scorpion'}},Room={Info={num=1,area='Fixture Hunt'},Players={}}}
dofile(root..'bootstrap.lua')
local c=combat_v2;local s=c.current;local M=c.buffs;local n=0
local function check(ok,why)assert(ok,why);n=n+1 end
local function tick()clock=clock+1;combat_v2_tick()end
local function only(key)for _,e in ipairs(M.catalog)do s.buffs.wanted[e.key]=e.key==key end end
local function def(kind,data)gmcp.Char.Defences=gmcp.Char.Defences or{};gmcp.Char.Defences[kind]=data;handlers['gmcp.Char.Defences.'..kind]()end
check(#sent==0 and not s.buffs.master and not s.buffs.sequence,'bootstrap armed or cast buffs')
handlers['gmcp.Char.Vitals']() -- genuine fresh-session event, not cached login evidence
check(aliases[ [[^defup(?:\s+(.*))?$]] ] and aliases[ [[^defkeep(?:\s+(.*))?$]] ],'plain aliases missing')
check(combat_v2_buffs('show') and shown==1 and #sent==0,'manager opening sent commands')
only('toughness');def('List',{})
check(combat_v2_buffs('start'),'manual defup refused')
check(sent[#sent]=='toughness' and s.buffs.pending,'one-shot defup did not commit selected ability')
local before=#sent;def('Add',{name='toughness'})
check(s.buffs.pending and #sent==before,'defense Add released action before prompt')
gmcp.Char.Vitals.equilibrium=0;handlers['gmcp.Char.Vitals']();prompt()
check(s.buffs.pending and #sent==before,'fresh prompt invented equilibrium recovery')
gmcp.Char.Vitals.equilibrium=1;handlers['gmcp.Char.Vitals']();prompt();tick()
check(not s.buffs.pending and not s.buffs.sequence and not s.buffs.master,'one-shot did not complete independently of upkeep')
check(c.mode=='OFF' and c.runner.mode=='OFF','manual defup enabled combat')
only('regeneration');check(combat_v2_buffs('keep','regeneration on'),'per-defense opt-in failed')
check(s.buffs.master and s.buffs.wanted.regeneration and sent[#sent]=='regeneration on','draining defense not explicitly armed')
check(payload and payload.version==1 and payload.wanted.regeneration==true and payload.master==nil and payload.pending==nil,'preferences persisted live authorization')
before=#sent;check(combat_v2_buffs('keep','regeneration off'),'per-defense off failed')
check(not s.buffs.wanted.regeneration and #sent==before and s.buffs.pending,'off discarded or bypassed committed activation')
def('Add',{name='regeneration'});prompt();tick()
check(sent[#sent]=='regeneration off','resource toggle did not send verified cancellation')
def('Remove',{'regeneration'});prompt();tick()
check(not s.buffs.pending,'cancel acknowledgement did not release barrier')
check(payload.wanted.regeneration==false,'per-defense off preference not saved')
before=#sent;check(combat_v2_buffs('keep','off') and not s.buffs.master and #sent==before,'global pause sent unexpected cancellation')
check(not combat_v2_buffs('keep','regeneration;quit on') and #sent==before,'unvalidated command escaped defense selector')
combat_v2_buffs('stop');check(not M.has_work(s),'stop left routine/upkeep armed')
check(combat_v2_buffs('save') and #sent==before,'save armed or cast defenses')
combat_v2_set_mode('SHADOW');check(not combat_v2_buffs('start') and not combat_v2_buffs('keep','on'),'SHADOW allowed automatic buffs')
combat_v2_stop();gmcp.Char.Status.class='Shaman';tick();check(not combat_v2_buffs('start') and #sent==before,'wrong class allowed defup')
-- Ownership regressions use the real registered bootstrap handlers.
gmcp.Char.Status.class='Monk';gmcp.Char.Skills.List=nil;tick()
check(s.buffs.known.weathering==nil,'class change reused cached Transcendent ownership')
local function skills(kind,data)
 gmcp.Char.Skills[kind]=data
 check(type(handlers['gmcp.Char.Skills.'..kind])=='function','owned Skills.'..kind..' handler missing')
 handlers['gmcp.Char.Skills.'..kind]()
end
local function group(rank)return {{name='Kaido',rank=rank}}end
skills('Groups',group('Transcendent 100%'))
check(s.buffs.known.weathering==true,'fresh Transcendent group did not infer ownership')
-- Same table mutated by GMCP must count as fresh when its owned event arrives.
gmcp.Char.Skills.Groups[1].rank='Inept';skills('Groups',gmcp.Char.Skills.Groups)
check(s.buffs.known.weathering==nil,'fresh lower rank retained inferred ownership')
skills('List',{group='Kaido',list={}})
check(s.buffs.known_ready and next(s.buffs.known)==nil,'empty Kaido list was not authoritative')
only('weathering');def('List',{});before=#sent;combat_v2_buffs('start');tick()
check(#sent==before and not s.buffs.pending,'restrictive ownership still sent weathering')
-- In either event order a List is more precise than a cached/inferred rank.
for _,order in ipairs({'GroupsFirst','ListFirst'})do
 gmcp.Char.Status.class='Shaman';tick();gmcp.Char.Status.class='Monk';tick()
 local groups=group('Transcendent 100%');local list={group='Kaido',list={}}
 if order=='GroupsFirst'then skills('Groups',groups);skills('List',list)
 else skills('List',list);skills('Groups',groups)end
 tick();combat_v2_buffs('status');tick()
 check(s.buffs.known_ready and next(s.buffs.known)==nil,order..' cached group overrode restrictive List')
 skills('Groups',group('Inept'))
 check(s.buffs.known_ready and next(s.buffs.known)==nil,order..' lower group overrode precise empty List')
 list.list={'Weathering'};skills('List',list)
 check(s.buffs.known.weathering==true and s.buffs.known.toughness==nil,'fresh in-place List did not replace known set')
 list.list={};skills('List',list);tick()
 check(next(s.buffs.known)==nil,'fresh in-place empty List retained learned abilities')
end
-- A replaced payload seen without its event is consumed once, never every tick.
gmcp.Char.Skills.List={group='Kaido',list={'Weathering'}};tick()
check(s.buffs.known.weathering==true,'new List identity not consumed')
gmcp.Char.Skills.Groups=group('Transcendent 100%');tick()
check(s.buffs.known.toughness==nil,'new group identity overrode precise List')
-- Disconnect revokes ownership and old prompt/confirmation, retaining the barrier.
M.reset(s);only('weathering');def('List',{});combat_v2_buffs('start')
check(s.buffs.pending and sent[#sent]=='weathering','disconnect barrier fixture failed')
M.sync(s,'Add','weathering');M.on_prompt(s);local pending=s.buffs.pending
handlers['sysDisconnectionEvent']()
check(not s.buffs.master and not s.buffs.sequence and next(s.buffs.known)==nil and not s.buffs.known_ready,'disconnect retained learned authorization')
check(s.buffs.pending==pending and not pending.prompt_ready and pending.prompt==nil and not pending.confirmed,'disconnect retained old confirmation/readiness')
before=#sent;tick();handlers['gmcp.Char.Vitals']();tick()
check(next(s.buffs.known)==nil and not s.buffs.known_ready and #sent==before,'reconnect reused cached ownership or sent commands')
M.reset(s);skills('List',{group='Kaido',list={}})
check(s.buffs.known_ready and not s.buffs.master and not s.buffs.sequence and #sent==before,'fresh reconnect List armed or cast buffs')
print=realprint;print('PASS buffs integration '..n..' assertions: aliases, snapshots, prompt/EQ, opt-in/cancel, preferences, modes, class/session ownership and fresh skill events')
