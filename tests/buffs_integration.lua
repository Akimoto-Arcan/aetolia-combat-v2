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
-- Narrow bootstrap contract probe for parallel development: never opens buffs.lua.
-- This verifies API routing/provenance only, NOT backend ownership or execution.
local contract_only=arg[2]=='class-contract'
local contract_calls={groups={},lists={},invalidations=0}
local contract={catalog={}}
function contract.state(s)s.buffs=s.buffs or {master=false,known={},have={}};return s.buffs end
function contract.stop(s)contract.state(s).master=false end
function contract.invalidate(s)contract_calls.invalidations=contract_calls.invalidations+1 end
function contract.set_class(s,name)contract.state(s).class=name:lower()end
function contract.supported_class(name)return name:lower()=='monk'or name:lower()=='archivist'end
function contract.audit_groups(name)
 if name:lower()=='monk'then return {'kaido','telepathy','survival','vision','avoidance'}end
 if name:lower()=='archivist'then return {'geometrics','numerology','bioessence','survival','vision','avoidance'}end
 return {}
end
function contract.set_groups(s,data)contract_calls.groups[#contract_calls.groups+1]={class=s.player.class,data=data}end
function contract.set_group_known(s,group,list)contract_calls.lists[#contract_calls.lists+1]={class=s.player.class,group=group,list=list}end
function contract.vitals()end
function dofile(path)
 if contract_only and path:match('/buffs.lua$')then return contract end
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
gmcp={Char={Status={class='Monk',guild='Archivists'},Name={name='Fixture'},Skills={Groups={{name='Kaido',rank='Transcendent 100%'}}},Vitals={hp=100,maxhp=100,mp=100,maxmp=100,wp=100,maxwp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,stance='scorpion'}},Room={Info={num=1,area='Fixture Hunt'},Players={}}}
dofile(root..'bootstrap.lua')
local c=combat_v2;local s=c.current;local M=c.buffs;local n=0
local function check(ok,why)assert(ok,why);n=n+1 end
if contract_only then
 -- Keep this probe focused on bootstrap, without simulating a backend service.
 combat_v2_tick=function()c.buff_snapshot()end
 s.connected=true
 check(s.player.class=='Monk' and s.buffs.class=='monk','guild became actual class')
 check(#contract_calls.groups==0 and #contract_calls.lists==0,'startup consumed cached ownership')
 local function event(kind)handlers['gmcp.Char.Skills.'..kind]()end
 event('Groups');check(#contract_calls.groups==1,'fresh Monk Groups not routed')
 gmcp.Char.Skills.List={group='Kaido',list={'Toughness'}};event('List')
 check(#contract_calls.lists==1,'fresh Monk List not routed')
 local pending={confirmed=true,prompt=1,prompt_ready=true};s.buffs.pending=pending
 for _,class in ipairs({'Archivist','Monk','Archivist'})do
  local groups,lists=#contract_calls.groups,#contract_calls.lists
  gmcp.Char.Status.class=class;handlers['gmcp.Char.Status']()
  check(s.player.class==class and #contract_calls.groups==groups and #contract_calls.lists==lists,'class event reused cached ownership')
  check(s.buffs.pending==pending and not pending.confirmed and pending.prompt==nil and not pending.prompt_ready,'class event erased commit or retained readiness')
  for _,order in ipairs({'GroupsFirst','ListFirst'})do
   gmcp.Char.Skills.Groups[1].name=class=='Monk'and'Kaido'or'Vision'
   gmcp.Char.Skills.List.group=class=='Monk'and'Kaido'or'Vision'
   gmcp.Char.Skills.List.list={'Nightsight'}
   if order=='GroupsFirst'then event('Groups');event('List')else event('List');event('Groups')end
   check(contract_calls.groups[#contract_calls.groups].class==class and contract_calls.lists[#contract_calls.lists].class==class,'fresh in-place payload routed under wrong class')
   check(#contract_calls.groups==groups+1 and #contract_calls.lists==lists+1,'in-place event lost or duplicated')
   groups,lists=#contract_calls.groups,#contract_calls.lists
   c.buff_snapshot();c.buff_snapshot()
   check(#contract_calls.groups==groups and #contract_calls.lists==lists,'poll replayed consumed payloads')
  end
  local start=#sent;local runner=c.runner;runner.waiting=true;runner.pending={fixture=true};local target=s.target
  local mode=class=='Monk'and'BASH'or'OFF';c.mode=mode;s.mode=mode;runner.mode=mode
  check(combat_v2_buffs('audit'),'contract class audit failed')
  local expected=contract.audit_groups(class)
  check(#sent-start==#expected+4,'class audit query count')
  for i,group in ipairs(expected)do check(sent[start+i]=='ab '..group,'class audit group mismatch')end
  for i,cmd in ipairs({'tattoos','defences','firstaid','firstaid priority defence list'})do check(sent[start+#expected+i]==cmd,'common audit query mismatch')end
  for i=#s.history-#expected-3,#s.history do check(s.history[i].kind=='buff_audit','read-only command recorded as send')end
  check(c.runner==runner and runner.waiting and runner.pending.fixture and s.target==target and c.mode==mode and s.mode==mode and runner.mode==mode and not s.buffs.master,'audit changed executor/intent')
 end
 c.mode='OFF';s.mode='OFF';c.runner.mode='OFF'
 gmcp.Char.Status.class='Shaman';handlers['gmcp.Char.Status']();local groups,lists=#contract_calls.groups,#contract_calls.lists
 event('Groups');event('List');check(#contract_calls.groups==groups and #contract_calls.lists==lists,'unsupported class received ownership data')
 gmcp.Char.Status.class=nil;handlers['gmcp.Char.Status']();check(s.player.class=='' and s.buffs.class=='','missing actual class retained authorization')
 c.buff_sender=function()return false end;check(not combat_v2_buffs('audit'),'false audit transport reported success')
 c.buff_sender=function()error('offline audit failure')end;check(not combat_v2_buffs('audit'),'throwing audit transport reported success')
 print=realprint;print('PASS bootstrap class-contract '..n..' assertions (stub routing/provenance only; no backend artifacts loaded)')
 return
end
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
check(not s.buffs.known.toughness,'bootstrap trusted cached Groups before a fresh event')
handlers['gmcp.Char.Skills.Groups']()
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
check(combat_v2_buffs('native','arcane off') and #sent==before+2 and c.mode=='SHADOW' and s.mode=='SHADOW','SHADOW native configuration enabled offense or was refused')
text("You have set the 'arcane' defence to the 26 priority.");before=#sent
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
combat_v2_set_mode('SHADOW');check(combat_v2_buffs('start') and combat_v2_buffs('keep','on') and c.mode=='SHADOW' and c.runner.mode=='SHADOW','defense controls failed to preserve SHADOW offense mode')
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
-- New multi-group and fresh-event provenance through actual bootstrap handlers.
M.reset(s);combat_v2_stop();handlers['gmcp.Char.Vitals']();before=#sent
skills('Groups',{{name='Kaido',rank='Transcendent'},{name='Vision',rank='Transcendent'},{name='Telepathy',rank='Transcendent'},{name='Survival',rank='Transcendent'},{name='Avoidance',rank='Transcendent'},{name='Tattoos',rank='Transcendent'}})
check(s.buffs.known.nightsight and s.buffs.known.insight and s.buffs.known.clarity and s.buffs.known.dodgemelee and s.buffs.known.divertmelee,'fresh curated group inference missing')
check(not s.buffs.known.cloak and not s.buffs.known.mindseye and not s.buffs.known.fitness and not s.buffs.known.kai_recursion,'rank inferred ink or deprecated Kaido')
skills('List',{group='Vision',list={}})
check(not s.buffs.known.nightsight and s.buffs.known.insight and s.buffs.known.clarity,'Vision revocation affected wrong group')
tick();check(not s.buffs.known.nightsight,'cached Groups revived precise empty Vision')
skills('List',{group='Telepathy',list={'Cloak','Insight'}})
check(s.buffs.known.mindcloak and not s.buffs.known.cloak,'Telepathy Cloak became tattoo capability')
text('You have the following tattoos:');text('Head: Boar Active');text('Left arm: Cloak Uses left: 2');text('Right leg: Mindseye Uses left: 2');prompt()
check(M.availability(s,'cloak') and M.availability(s,'mindseye'),'actual TATTOOS/prompt did not populate ownership')
local function defense_row(key)for _,r in ipairs(M.rows(s))do if r.key==key then return r end end end
def('List',{});check(defense_row('boar').active==true and defense_row('boar').availability=='PASSIVE','active tattoo became phantom missing')
gmcp.Char.Vitals.blind='1';gmcp.Char.Vitals.deaf='1';handlers['gmcp.Char.Vitals']()
check(defense_row('blindness').active and defense_row('deafness').active,'actual fresh blind/deaf Vitals not ingested')
def('List',{});check(defense_row('blindness').active,'DefList absence erased fresh blind flag')
text('Your blind defence has been stripped.');tick();tick()
check(defense_row('blindness').active==false,'cached Vitals tick resurrected strip')
def('List',{});check(defense_row('blindness').active==false,'cached Vitals positivity survived newer strip')
gmcp.Char.Vitals.blind='0';gmcp.Char.Vitals.deaf='0';handlers['gmcp.Char.Vitals']()
check(defense_row('blindness').active==false and defense_row('deafness').active==false,'zero flags are truthy')
check(not s.buffs.master and not s.buffs.sequence and #sent==before,'read-only group/ink/Vitals discovery armed or sent')
for _,entry in ipairs(M.catalog)do if entry.drain and entry.key~='regeneration' then check(not s.buffs.wanted[entry.key],'new drain default ON')end end
handlers['sysDisconnectionEvent']();check(next(s.buffs.tattoos)==nil and not s.buffs.known.mindcloak,'disconnect reused ink/group ownership')
-- Explicit self-defense preparation in SHADOW never authorizes offense or changes mode.
handlers['gmcp.Char.Vitals']();skills('List',{group='Kaido',list={'Toughness'}})
combat_v2_set_mode('SHADOW');only('toughness');def('List',{});before=#sent
check(combat_v2_buffs('start') and sent[before+1]=='toughness' and #sent==before+1,'SHADOW self preparation did not dispatch only its defense')
check(c.mode=='SHADOW' and s.mode=='SHADOW' and c.runner.mode=='SHADOW','defup changed offense mode')
def('Add','toughness');prompt();tick()
check(not s.buffs.pending and c.mode=='SHADOW' and #sent==before+1,'SHADOW defense ACK activated offense')
combat_v2_buffs('stop');check(c.mode=='SHADOW','stopping upkeep changed offense mode')
-- Bootstrap-owned Flurry lifecycle hooks must not survive manual scope changes.
combat_v2_stop() -- reset only this offline fixture before testing an actual mode transition
local previous_cancel=c.monk.cancel_flurry;local cancelled={}
c.monk.cancel_flurry=function(_,why)cancelled[why or "runner stop"]=true end
combat_v2_set_mode('SHADOW');check(cancelled['mode changed'],'mode transition omitted Flurry cancellation')
combat_v2_set_target('Lifecycle');check(cancelled['manual target changed'],'manual retarget omitted Flurry cancellation')
gmcp.Room.Info={num=2,area='Fixture Hunt'};handlers['gmcp.Room.Info']();check(cancelled['room changed'],'room transition omitted Flurry cancellation')
handlers['sysDisconnectionEvent']();check(cancelled.disconnect,'disconnect omitted Flurry cancellation')
combat_v2_stop();check(cancelled.OFF,'OFF omitted Flurry cancellation')
combat_v2_reset_wait();check(cancelled["reviewed reset"],"reviewed reset omitted Flurry cancellation")
c.monk.cancel_flurry=previous_cancel
before=#sent
for _,k in ipairs({'blindness','deafness','insulation','temperance','venom_resistance'})do
 check(not combat_v2_buffs('native',k..' on'),'false native owner accepted '..k)
end
check(#sent==before,'unsupported native configuration sent')
-- Composed-backend acceptance: actual class is Monk despite Archivists guild.
-- Parent runs this normal path only after the parallel backend is complete.
combat_v2_stop();M.reset(s);gmcp.Char.Status.class='Monk';handlers['gmcp.Char.Status']();handlers['gmcp.Char.Vitals']()
check(s.player.class=='Monk' and M.state(s).class=='monk','guild Archivists overrode actual Monk class')
local native_expected={courage=true,density=true,fangbarrier=true,insomnia=true,levitation=true,rebounding=true,waterbreathing=true,instawake=true,arcane=true,harmony=true,speed=true,vigor=true}
local native_count=0
for key in pairs(M.native_catalog)do native_count=native_count+1;check(native_expected[key],'unexpected native setter '..key)end
check(native_count==12,'native twelve schema changed')
for _,order in ipairs({'GroupsFirst','ListFirst'})do
 -- Seed a precise Monk list and independent native/ink/DEF observations.
 skills('Groups',{{name='Kaido',rank='Transcendent'},{name='Vision',rank='Transcendent'},{name='Survival',rank='Transcendent'}})
 skills('List',{group='Kaido',list={'Weathering','Regeneration'}})
 priorities({[3]='speed'});def('List',{})
 text('You have the following tattoos:');text('Left arm: Cloak Uses left: 2');prompt()
 check(s.buffs.known.weathering and M.native_priority(s,'speed')==3 and M.availability(s,'cloak'),'class freshness fixture failed')
 local start=#sent
 gmcp.Char.Status.class='Archivist';handlers['gmcp.Char.Status']();tick()
 check(s.player.class=='Archivist' and not s.buffs.known.weathering and not s.buffs.master and not s.buffs.sequence and #sent==start,'Archivist switch reused Monk authorization or armed execution')
 check(M.native_priority(s,'speed')==nil and next(s.buffs.tattoos)==nil and not s.buffs.defs_known,'class switch reused native/ink/DEF evidence')
 -- Fresh but foreign Groups/List must not grant Kaido to an Archivist.
 local groups={{name='Kaido',rank='Transcendent'},{name='Vision',rank='Transcendent'},{name='Survival',rank='Transcendent'}}
 local list={group='Kaido',list={'Weathering','Regeneration'}}
 if order=='GroupsFirst'then skills('Groups',groups);skills('List',list)else skills('List',list);skills('Groups',groups)end
 check(not s.buffs.known.weathering and not M.availability(s,'weathering'),'fresh foreign Kaido granted Archivist ownership')
 -- Injected legacy ownership/active state cannot authorize a foreign OFF cast.
 s.buffs.known.regeneration=true;s.buffs.have.regeneration=true;s.buffs.wanted.regeneration=true
 M.toggle(s,'regeneration',false);tick()
 check(#sent==start and not s.buffs.pending,'foreign injected OFF sent a Monk cancellation')
 s.buffs.known.regeneration=nil;s.buffs.have.regeneration=nil
 -- In-place current-class shared Lists are consumed by their registered events.
 list.group='Vision';list.list={'Nightsight'};skills('List',list)
 check(M.availability(s,'nightsight'),'Archivist shared Vision unavailable')
 list.group='Survival';list.list={'Clarity'};skills('List',list)
 check(M.availability(s,'clarity'),'Archivist shared Survival unavailable')
 priorities({[3]='speed'});def('List',{})
 text('You have the following tattoos:');text('Left arm: Cloak Uses left: 2');prompt()
 check(M.native_priority(s,'speed')==3 and M.availability(s,'cloak') and s.buffs.defs_known,'fresh Archivist native/ink/DEF reports ignored')
 for key in pairs(native_expected)do check(M.native_priority(s,key)==(key=='speed'and 3 or 26),'native priority choices altered for '..key)end
 for _,row in ipairs(M.rows(s))do
  if row.owner=='ARCHIVIST'then check(row.control~='class'or row.can_toggle==false or row.available==false,'unvalidated Archivist row exposed an executable toggle')end
 end
 gmcp.Char.Status.class='Monk';handlers['gmcp.Char.Status']();tick()
 check(not s.buffs.known.weathering and not s.buffs.known.clarity and not M.availability(s,'cloak') and M.native_priority(s,'speed')==nil,'return to Monk reused cached class evidence')
 -- A fresh in-place List can restore only its explicitly observed current class.
 list.group='Kaido';list.list={'Weathering'};skills('List',list)
 check(s.buffs.known.weathering and not s.buffs.known.regeneration,'fresh return-to-Monk List failed or broadened ownership')
 check(#sent==start and c.mode=='OFF' and c.runner.mode=='OFF' and not s.buffs.master,'class discovery sent casts or enabled execution')
end
print=realprint;print('PASS buffs integration '..n..' assertions: aliases, snapshots, prompt/EQ, opt-in/cancel, preferences, modes, class/session ownership and fresh skill events')
