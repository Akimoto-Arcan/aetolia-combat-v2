-- Offline actual-bootstrap tests. No real Mudlet/network or preference writes.
local root=assert(arg[1]);local realdofile=dofile;local clock=100
local handlers,aliases,timers,sent={},{},{},{};local serial=0;local prompt;local triggers={}
local output={};local realprint=print;print=function(...)output[#output+1]=table.concat({...},' ')end
function getEpoch()return clock end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,true end
local registrations={}
function registerAnonymousEventHandler(name,fn)
 serial=serial+1;registrations[serial]={name=name,fn=fn}
 handlers[name]=function(...)
  local current={};for id,h in pairs(registrations)do if h.name==name then current[#current+1]={id=id,fn=h.fn}end end
  table.sort(current,function(a,b)return a.id<b.id end)
  for _,h in ipairs(current)do if registrations[h.id]then h.fn(...)end end
 end
 return serial
end
function killAnonymousEventHandler(id)registrations[id]=nil end
function tempRegexTrigger(_,fn)serial=serial+1;triggers[serial]=fn;return serial end
local prompts={}
local function multicast(callbacks,...)
 local current={};for id,fn in pairs(callbacks)do current[#current+1]={id=id,fn=fn}end
 table.sort(current,function(a,b)return a.id<b.id end)
 for _,h in ipairs(current)do if callbacks[h.id]then h.fn(...)end end
end
function killTrigger(id)triggers[id]=nil;prompts[id]=nil end
function tempPromptTrigger(fn)
 serial=serial+1;prompts[serial]=fn
 prompt=function()multicast(prompts)end
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
local function text(value)line=value;multicast(triggers);line=nil end
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
c.runner.transport_commit={finished=true,failed=true};combat_v2_reset_wait();check(c.runner.transport_commit==nil,"reviewed reset retained transport barrier");check(cancelled["reviewed reset"],"reviewed reset omitted Flurry cancellation")
c.monk.cancel_flurry=previous_cancel
-- Shared-controller arbitration uses the real bootstrap, runner and public controls.
local function transport_fixture()
 clock=clock+20;c.buff_sender=nil;c.mental_sender=nil
 c.current=c.state.new();gmcp.Char.Status.class='Monk'
 gmcp.Char.Skills={Groups=group('Transcendent 100%')}
 gmcp.Char.Vitals={hp=100,maxhp=100,mp=10000,maxmp=10000,wp=100,maxwp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,stance='scorpion'}
 gmcp.Room={Info={num=1,area='Fixture Hunt'},Players={}}
 dofile(root..'bootstrap.lua');s=c.current;M=c.buffs
 handlers['gmcp.Char.Vitals']();def('List',{});only('toughness')
 c.state.set_target(s,'123')
 s.policy.area='fixture hunt';s.policy.areas={['fixture hunt']=true};s.policy.areas_loaded=true
 s.policy.players={};s.policy.players_known=true;s.policy.players_room=s.room.id
 s.room.items['123']={id='123',name='a fixture monster',attrib='m'}
 s.hunting.verified_generation=s.target_generation
 local seen=0;local id=registerAnonymousEventHandler('gmcp.Char.Vitals',function()seen=seen+1 end)
 handlers['gmcp.Char.Vitals']();killAnonymousEventHandler(id)
 check(seen==1 and s.connected,'multicast fixture replaced bootstrap vitals ingestion')
 c.mode='BASH';s.mode='BASH';c.runner.mode='BASH'
end
local function mental_ready()
 combat_v2_set_target('Fixture');s.policy.players={fixture=true};s.policy.players_known=true
 local m=c.mental.state(s);m.status='locked';m.target='Fixture';m.lock_target='Fixture';m.last_blackout=-1000;m.retry_at=0
 return m
end
local function sends_of(command,from)
 local count=0;for i=(from or 0)+1,#sent do if sent[i]==command then count=count+1 end end;return count
end
local function class_sends()
 local count=0;for _,h in ipairs(s.history)do if h.kind=='buff_send'then count=count+1 end end;return count
end
for _,failure in ipairs({'false','throw'})do
 transport_fixture();local first=#sent
 c.runner.sender=function(command)send(command);if failure=='throw'then error('offline unknown attack')end;return false end
 local ok=c.runner_module.tick(c.runner);local commit=c.runner.transport_commit
 check(not ok and commit and commit.sent==false and commit.failed and c.runner.fault,'normal failure fixture did not retain unknown commit: '..tostring(c.runner.status)..' / '..tostring(commit and commit.sent)..' / '..tostring(commit and commit.failed))
 local m=mental_ready();combat_v2_set_mode('FULL_AUTO');tick()
 check(not m.eq_pending and sends_of('mind blackout',first)==0 and c.runner.transport_commit==commit,'FULL_AUTO escaped retained failed normal transport')
 -- Native recovery still ingests while the shared hold prevents new mental casts.
 m.eq_pending=clock;m.eq_snapshot=s.recoveries.equilibrium or 0
 text('You have recovered equilibrium.');tick()
 check(not m.eq_pending and c.runner.transport_commit==commit and sends_of('mind blackout',first)==0,'interlock blocked mental EQ bookkeeping or allowed dispatch')
 combat_v2_stop();check(c.runner.transport_commit==commit and not c.runner.fault and not c.runner.waiting,'STOP lost unknown transport or failed to expose defup bypass fixture')
 local history=class_sends();combat_v2_buffs('start');tick()
 check(sends_of('toughness',first)==0 and not s.buffs.pending and class_sends()==history,'STOP + defup escaped transport barrier or invented buff commit')
 combat_v2_buffs('stop');combat_v2_buffs('keep','regeneration off');tick()
 check(s.buffs.cancel.regeneration and sends_of('regeneration off',first)==0 and not s.buffs.pending and class_sends()==history,'explicit defense OFF bypassed transport barrier')
 combat_v2_buffs('stop');local audit=#sent
 check(combat_v2_buffs('audit'),'held transport blocked read-only audit')
 check(#sent==audit+4 and sent[audit+1]=='ab kaido'and sent[audit+2]=='defences'and sent[audit+3]=='firstaid'and sent[audit+4]=='firstaid priority defence list','held audit changed native/read-only requests')
 def('Add',{name='regeneration'});priorities({[3]='speed'})
 check(s.buffs.have.regeneration and M.native_priority(s,'speed')==3 and c.runner.transport_commit==commit and class_sends()==history,'held audit ingestion altered barrier or dispatched class action')
 combat_v2_set_curing(true);check(sent[#sent]=='firstaid curing on' and c.runner.transport_commit==commit,'transport hold disabled native curing')
 -- Automatic read-only discovery also remains possible: the interlock lives
 -- after queries, not at the service entry or native ingestion boundary.
 s.buffs.known_ready=false;s.buffs.known={};local queries=#sent
 combat_v2_buffs('start')
 check(#sent==queries+1 and sent[#sent]=='ab kaido' and not s.buffs.pending,'held upkeep blocked read-only skill discovery or invented commit')
 skills('List',{group='Kaido',list={'Toughness','Regeneration'}})
 s.buffs.defs_known=false;queries=#sent;tick()
 check(#sent==queries+1 and sent[#sent]=='defences' and not s.buffs.pending,'held upkeep blocked read-only defense discovery or invented commit')
 def('List',{});tick()
 check(not s.buffs.query and not s.buffs.pending and sends_of('toughness',first)==0 and c.runner.transport_commit==commit,'snapshot response bypassed transport hold')
 combat_v2_buffs('stop')
 combat_v2_reset_wait();check(not c.runner.transport_commit,'explicit reviewed reset did not clear shared barrier')
 combat_v2_buffs('start');check(sent[#sent]=='toughness' and s.buffs.pending,'reviewed reset did not restore public defup')
end
-- Sender callbacks may re-enter both public controllers before the outer transport
-- returns. Neither STOP nor fresh READY nor recovery proves that send's outcome.
for _,outcome in ipairs({'true','false','throw'})do
 transport_fixture();local first=#sent;local retained;local m;local callback_complete=false
 c.runner.sender=function(command)
  send(command);retained=c.runner.transport_commit
  check(retained and retained.sent==nil and not retained.failed,'reentry did not occur inside unfinished transport')
  m=mental_ready();combat_v2_set_mode('FULL_AUTO')
  check(not m.eq_pending and sends_of('mind blackout',first)==0,'unfinished sender reentry dispatched mental action')
  combat_v2_stop();local history=class_sends();combat_v2_buffs('start');tick()
  combat_v2_buffs('keep','regeneration off')
  check(not s.buffs.pending and sends_of('toughness',first)==0 and sends_of('regeneration off',first)==0 and class_sends()==history,'unfinished sender reentry dispatched class activation/OFF')
  check(c.runner.transport_commit==retained,'reentrant STOP/mode/tick erased unfinished transport')
  combat_v2_buffs('stop');callback_complete=true
  if outcome=='throw'then error('offline reentrant send failure')end
  return outcome=='true'
 end
 local ok=c.runner_module.tick(c.runner)
 check(callback_complete,'runner swallowed a failing reentrant callback assertion: '..tostring(c.runner.status))
 if outcome=='true'then
  check(ok and not c.runner.transport_commit and retained.sent and not retained.failed,'successful finished transport remained held')
  check(not M.transport_held({transport_commit=retained}),'successful finished commit record falsely blocks controllers')
  -- Real recovery gates are retained: only now, after sender completion, allow
  -- mental dispatch with current readiness and the confirmed selected lock.
  combat_v2_set_mode('FULL_AUTO')
  check(sends_of('mind blackout',first)==1 and m.eq_pending,'successful transport prevented ordinary eligible mental cast')
 else
  check(not ok and c.runner.transport_commit==retained and retained.failed,'failed reentrant transport released without review')
  combat_v2_set_mode('FULL_AUTO');combat_v2_stop();combat_v2_buffs('start');tick()
  check(sends_of('mind blackout',first)==0 and sends_of('toughness',first)==0 and not s.buffs.pending,'failed reentry escaped after sender returned')
  combat_v2_buffs('stop');combat_v2_reset_wait();mental_ready();combat_v2_set_mode('FULL_AUTO')
  check(sends_of('mind blackout',first)==1,'reviewed reset did not restore eligible mental cast')
 end
end
-- Lazy GLOBE attachment must multicast alongside the real core handlers.
local globe_failure='You do not have the power to summon forth an elemental.'
local globe_success='You concentrate on the raw elemental energy flowing about your body, coalescing some of its potential into a massive elemental.'
local globe_drain='As you place a hand upon the globe, the energy within surges in response. Tendrils of energy quickly escape their prison, infusing your body with the element of water.'
local function globe_resources(first)
 return sends_of('drain globe',first)+sends_of('summon elemental',first)
end
local function globe_empty()
 combat_v2_stop();c.runner.sender=send;c.state.set_target(s,'')
 combat_v2_set_mode('BASH')
 gmcp.Char.Items={List={location='room',items={}}};handlers['gmcp.Char.Items.List']()
 s.hunting.ih={active=false,pending=false,responded=true,room_id=s.room.id,start_version=(s.room.item_version or 0)-1}
 s.hunting.watch={room_id=s.room.id,checked_version=s.room.item_version}
 check(c.policy.allowed(s) and c.runner_module.ready(c.runner) and not c.runner.waiting and not c.runner.fault,'GLOBE transport fixture has an unrelated hold')
end
local function globe_start()
 check(combat_v2_globe('on'),'public GLOBE arm refused')
 text(globe_failure);prompt()
end
local function globe_probe()
 text('This globe is infused with water and can be drained another 2 times.');prompt()
end
local function globe_ack()
 text(globe_drain);def('Add',{name='water_infused'});def('Add',{name='toughness'});prompt()
end
local function globe_finish()text(globe_success);prompt()end
-- First prove that the same real hook path can consume resources when permitted.
transport_fixture();globe_empty();local first=#sent
check(not c.elementals.state(c).attached,'GLOBE attached before explicit opt-in')
globe_start();globe_probe();globe_ack();globe_finish()
check(sends_of('probe globe',first)==1 and globe_resources(first)==2 and not c.elementals.state(c).pending,'actual-bootstrap multicast GLOBE happy path was inert')
check(s.buffs.have.toughness and s.room.item_version>0,'GLOBE replaced core defence/item ingestion')
for _,outcome in ipairs({'false','throw'})do
 transport_fixture();first=#sent
 c.runner.sender=function(command)send(command);if outcome=='throw'then error('offline GLOBE physical failure')end;return false end
 local ok=c.runner_module.tick(c.runner);local commit=c.runner.transport_commit
 check(not ok and commit and commit.failed and commit.sent==false,'GLOBE failed physical fixture did not commit normal attack')
 globe_empty();check(c.runner.transport_commit==commit,'public STOP/BASH lost failed physical transport')
 globe_start();globe_probe();globe_ack();globe_finish()
 check(globe_resources(first)==0 and c.runner.transport_commit==commit,'GLOBE bypassed failed physical transport after STOP/BASH '..outcome)
 check(s.buffs.have.toughness,'held GLOBE prevented native defence ingestion')
 combat_v2_set_curing(true);check(sent[#sent]=='firstaid curing on' and c.runner.transport_commit==commit,'held GLOBE prevented native curing')
 combat_v2_globe('off');text(globe_failure);globe_probe();globe_ack();globe_finish();tick()
 check(not c.elementals.state(c).armed and globe_resources(first)==0 and c.runner.transport_commit==commit,'late GLOBE/OFF events rearmed or cleared failed transport')
end
for _,outcome in ipairs({'true','false','throw'})do
 transport_fixture();first=#sent;local complete=false;local retained
 c.runner.sender=function(command)
  send(command);retained=c.runner.transport_commit
  check(retained and retained.sent==nil,'GLOBE reentry fixture missed unfinished sender')
  globe_empty();globe_start();globe_probe();globe_ack();globe_finish()
  check(globe_resources(first)==0 and c.runner.transport_commit==retained,'unfinished sender + STOP/BASH dispatched GLOBE resources '..outcome)
  complete=true;if outcome=='throw'then error('offline unfinished GLOBE failure')end;return outcome=='true'
 end
 local ok=c.runner_module.tick(c.runner)
 check(complete,'runner swallowed failing GLOBE reentry callback assertion: '..tostring(c.runner.status))
 check(ok==(outcome=='true') and globe_resources(first)==0,'GLOBE reentry outcome or dispatch was wrong')
 if outcome=='true'then
  check(not c.runner.transport_commit and retained.sent,'successful GLOBE reentry remained transport-held')
  prompt();globe_probe();globe_ack();globe_finish()
  check(globe_resources(first)==2 and not c.elementals.state(c).pending,'successful finished sender did not restore ordinary GLOBE recovery')
 else
  check(c.runner.transport_commit==retained and retained.failed,'failed GLOBE reentry lost shared barrier')
  globe_probe();globe_ack();globe_finish()
  check(globe_resources(first)==0 and c.runner.transport_commit==retained,'finished failed sender allowed late GLOBE consumption')
 end
end
for _,external in ipairs({false,true})do
 transport_fixture();globe_empty();first=#sent;globe_start();globe_probe()
 if external then text(globe_drain)else globe_ack()end
 local pending=c.elementals.state(c).pending;local before=globe_resources(first)
 -- Commit another real normal action while the helper is awaiting its ACK.
 c.state.set_target(s,'123');s.room.items['123']={id='123',name='a fixture monster',attrib='m'}
 s.hunting.verified_generation=s.target_generation;s.hunting.watch=nil
 c.runner.sender=function(command)send(command);return false end
 check(not c.runner_module.execute(c.runner,c.runner_module.propose(c.runner)),'completion fixture failed to retain physical transport')
 local commit=c.runner.transport_commit
 check(commit and commit.failed,'completion fixture had no shared transport barrier')
 c.runner.sender=send;text(globe_success)
 check(c.elementals.state(c).pending==pending,'completion settled without post-success prompt')
 -- Next BASH offense can be busy; settlement is still bookkeeping, not dispatch.
 c.runner.waiting=true;s.player.balance=false;prompt()
 check(not c.elementals.state(c).pending and not c.elementals.state(c).committed and c.elementals.state(c).armed,'held physical transport prevented committed GLOBE settlement '..tostring(external))
 check(globe_resources(first)==before and c.runner.transport_commit==commit,'GLOBE settlement sent or cleared physical transport')
end
print=realprint;print('PASS buffs integration '..n..' assertions: aliases, snapshots, prompt/EQ, native priorities, ownership, shared transport arbitration, actual-bootstrap reentry, GLOBE and reviewed reset')
