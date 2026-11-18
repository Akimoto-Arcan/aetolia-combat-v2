-- Offline actual-bootstrap tests. No real Mudlet/network or preference writes.
local root=assert(arg[1]);local realdofile=dofile;local clock=100
local handlers,aliases,timers,sent={},{},{},{};local serial=0;local prompt;local triggers={}
local output={};local realprint=print;print=function(...)output[#output+1]=table.concat({...},' ')end
function getEpoch()return clock end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,true end
local event_listeners,event_serial,event_handler_table={},0,nil
function registerAnonymousEventHandler(event,fn)
 if event_handler_table~=handlers then event_listeners={};event_handler_table=handlers end
 event_serial=event_serial+1;local id=event_serial;event_listeners[id]={event,fn}
 handlers[event]=function(...)
  local ids={};for k,v in pairs(event_listeners)do if v[1]==event then ids[#ids+1]=k end end;table.sort(ids)
  for _,k in ipairs(ids)do local item=event_listeners[k];if item then item[2](...)end end
 end
 return id
end
function killAnonymousEventHandler(id)
 local item=event_listeners[id];event_listeners[id]=nil
 if item then local any=false;for _,v in pairs(event_listeners)do if v[1]==item[1]then any=true end end;if not any then handlers[item[1]]=nil end end
end
function tempRegexTrigger(_,fn)serial=serial+1;triggers[serial]=fn;return serial end
local prompt_callbacks={}
function killTrigger(id)triggers[id]=nil;prompt_callbacks[id]=nil end
function tempPromptTrigger(fn)
 serial=serial+1;prompt_callbacks[serial]=fn
 prompt=function(...)
  local ids={};for id in pairs(prompt_callbacks)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local callback=prompt_callbacks[id];if callback then callback(...)end end
 end
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
local function text(value)line=value;triggers[c.line_trigger]();line=nil end
local function priority_rows(entries)
 for i=1,25 do text(i..': '..(entries[i]or''))end
end
local function priorities(entries)
 text('Your defense priorities:');priority_rows(entries);text('Defs with priority 26 are ignored.')
end
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
-- Native generic upkeep has one owner; configure only on explicit validated action.
priorities({[1]='fangbarrier, insomnia',[2]='arcane',[3]='speed, courage',[4]='levitation'})
check(M.native_priority(s,'arcane')==2,'native priority readback did not populate backend')
before=#sent;local arming=s.buffs.master
check(combat_v2_buffs('native','arcane off'),'native OFF refused')
check(sent[before+1]=='firstaid priority defence arcane 26' and sent[before+2]=='firstaid priority defence list','native OFF did not use verified priority26/readback')
check(M.native_priority(s,'arcane')==nil and M.native_enable_priority(s,'arcane')==2 and s.buffs.master==arming,'native request retained proof or armed class upkeep')
priorities({[1]='fangbarrier, insomnia',[3]='speed, courage'})
check(M.native_priority(s,'arcane')==26,'native OFF readback not authoritative')
before=#sent;check(combat_v2_buffs('keep','arcane on'),'defkeep generic did not route to FIRSTAID')
check(sent[before+1]=='firstaid priority defence arcane 2','native reenable lost previously known priority')
text("You have set the 'arcane' defence to the 2 priority.")
before=#sent
check(not combat_v2_buffs('native','arcane;quit on') and not combat_v2_buffs('native','weathering on') and not combat_v2_buffs('native','arcane maybe') and #sent==before,'invalid native key/action sent commands')
c.mode='SHADOW';c.runner.mode='SHADOW';s.mode='SHADOW'
check(not combat_v2_buffs('native','arcane off') and #sent==before,'SHADOW configured native upkeep')
c.mode='OFF';c.runner.mode='OFF';s.mode='OFF'
-- Exercise the actual native callback and registered text trigger, not a copied dispatcher.
for _,failure in ipairs({'false','throw'})do
 for _,stage in ipairs({'write','readback'})do
  priorities({[3]='speed'})
  text('Your defense priorities:');priority_rows({[3]='speed'})
  local calls=0
  c.buff_sender=function(command)
   calls=calls+1
   if calls==1 then check(M.native_priority(s,'speed')==nil,'write dispatched before uncertainty marker')end
   if (stage=='write'and calls==1)or(stage=='readback'and calls==2)then
    if failure=='throw'then error('offline transport failure')else return false end
   end
   send(command)
  end
  check(not combat_v2_buffs('native','speed off'),'failed transport reported success')
  check(calls==(stage=='write'and 1 or 2),'unexpected retry or missing readback')
  check(M.native_priority(s,'speed')==nil and M.native_enable_priority(s,'speed')==3,'uncertain write retained usable old proof')
  text('Defs with priority 26 are ignored.')
  check(M.native_priority(s,'speed')==nil,'old transaction resolved pending write')
  local count=#sent
  check(not combat_v2_buffs('native','speed on')and #sent==count,'uncertain write allowed another configuration')
  priorities({[3]='speed'})
  check(M.native_priority(s,'speed')==nil,'conflicting late readback resolved write')
  text('Your defense priorities:');text('1: arcane');text('Defs with priority 26 are ignored.')
  check(M.native_priority(s,'speed')==nil,'incomplete readback resolved write')
  if stage=='write'then text("You have set the 'speed' defence to the 26 priority.")else priorities({})end
  check(M.native_priority(s,'speed')==26,'fresh authoritative evidence did not resolve write')
  c.buff_sender=nil;count=#sent
  check(combat_v2_buffs('native','speed on')and sent[count+1]=='firstaid priority defence speed 3','confirmed OFF could not restore last-active priority')
  text("You have set the 'speed' defence to the 3 priority.")
 end
end
-- A delayed own ACK for old priority3 cannot acknowledge an unresolved OFF26.
for _,listing in ipairs({false,true})do
 priorities({[3]='speed',[4]='courage'})
 check(combat_v2_buffs('native','speed off'),'conflicting ACK fixture OFF refused')
 check(M.native_priority(s,'speed')==nil and s.buffs.native_pending.speed==26,'OFF did not retain uncertainty')
 if listing then text('Your defense priorities:');priority_rows({[3]='speed',[5]='courage'})end
 text("You have set the 'speed' defence to the 3 priority.")
 check(M.native_priority(s,'speed')==nil and s.buffs.native_pending.speed==26,'older own ACK resolved pending OFF')
 check(M.native_enable_priority(s,'speed')==3,'older own ACK lost restoration memory')
 before=#sent
 check(not combat_v2_buffs('native','speed on')and #sent==before,'older own ACK allowed second native write')
 if listing then
  text('Defs with priority 26 are ignored.')
  check(M.native_priority(s,'speed')==nil and s.buffs.native_pending.speed==26,'old ACK/list footer cleared pending OFF')
  check(M.native_priority(s,'courage')==4,'conflicting own ACK failed to fence old listing')
  check(not combat_v2_buffs('native','speed on')and #sent==before,'old footer allowed second native write')
 end
 text("You have set the 'speed' defence to the 26 priority.")
 check(M.native_priority(s,'speed')==26 and not s.buffs.native_pending.speed,'matching own ACK did not resolve OFF')
 before=#sent
 check(combat_v2_buffs('native','speed on')and #sent==before+2 and sent[before+1]=='firstaid priority defence speed 3'and sent[before+2]=='firstaid priority defence list','confirmed OFF did not restore priority3/readback')
 text("You have set the 'speed' defence to the 3 priority.")
 check(M.native_priority(s,'speed')==3,'restored ON did not confirm')
end
priorities({[3]='speed'});text('Your defense priorities:');priority_rows({[3]='speed'})
text("You have set the 'speed' defence to the 26 priority.");text('Defs with priority 26 are ignored.')
check(M.native_priority(s,'speed')==26,'old full listing overwrote interleaved own ACK')
before=#sent
local wasconnected=s.connected;s.connected=false
check(not combat_v2_buffs('native','arcane off') and #sent==before,'disconnected native request escaped gate');s.connected=wasconnected
before=#sent
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
-- Bootstrap-owned Flurry lifecycle hooks must not survive manual scope changes.
local previous_cancel=c.monk.cancel_flurry;local cancelled={}
c.monk.cancel_flurry=function(_,why)cancelled[why or "runner stop"]=true end
combat_v2_set_mode('SHADOW');check(cancelled['mode changed'],'mode transition omitted Flurry cancellation')
combat_v2_set_target('Lifecycle');check(cancelled['manual target changed'],'manual retarget omitted Flurry cancellation')
gmcp.Room.Info={num=2,area='Fixture Hunt'};handlers['gmcp.Room.Info']();check(cancelled['room changed'],'room transition omitted Flurry cancellation')
handlers['sysDisconnectionEvent']();check(cancelled.disconnect,'disconnect omitted Flurry cancellation')
combat_v2_stop();check(cancelled.OFF,'OFF omitted Flurry cancellation')
combat_v2_reset_wait();check(cancelled["reviewed reset"],"reviewed reset omitted Flurry cancellation")
c.monk.cancel_flurry=previous_cancel
print=realprint;print('PASS buffs integration '..n..' assertions: aliases, snapshots, prompt/EQ, opt-in/cancel, preferences, modes, class/session ownership and fresh skill events')
