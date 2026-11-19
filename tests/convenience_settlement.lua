-- Offline composed controllers: real modules, fake Mudlet, no native transport.
local root=assert(arg[1]);local S=dofile(root..'state.lua');local T=dofile(root..'travel.lua');local Boot=dofile(root..'travel_boot.lua')
local n=0;local function check(x,msg)n=n+1;assert(x,msg or ('check '..n))end
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'offline',0,true end
function getMudletHomeDir()return '__offline_no_profile__'end
local id=0;local function hook()id=id+1;return id end
for _,k in ipairs({'tempAlias','tempRegexTrigger','tempPromptTrigger','tempTimer','registerAnonymousEventHandler'})do _G[k]=hook end
for _,k in ipairs({'killAlias','killTrigger','killTimer','killAnonymousEventHandler'})do _G[k]=function()end end
local function fixture()
 clock=100
 local B=dofile(root..'buffs.lua');local E=dofile(root..'elementals.lua');local C=dofile(root..'containers.lua');local R=dofile(root..'runner.lua')
 local s=S.new();s.connected=true;s.mode='BASH';s.room.id=100;s.room.item_version=1
 local p=s.player;p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100;p.mounted=false
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 B.set_class(s,'Monk');B.sync(s,'List',{});for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=false end
 s.hunting.ih={room_id=100,responded=true,start_version=0};s.hunting.watch={room_id=100}
 local sent={};local r=R.new(s,{});r.mode='BASH';local recovery={};r.recovery=recovery
 r.sender=function(cmd)sent[#sent+1]=cmd end
 local c={mode='BASH',current=s,runner=r,runner_module=R,mental={bind_defense=function()end},defense={plan=function()return {hold=false}end,hold=function()return false end},policy={allowed=function()return true end},state=S,buffs=B,elementals=E,containers=C,travel_module=T,tattoo_module={attach=function()return true end},travel_sender=r.sender}
 function combat_v2_set_mode()error('recall must not STOP BASH')end
 check(Boot.attach(c));local t=c.travel;t.room(100);t.vitals(0);t.state.mount='17';t.items(100,{{id='17'}},true,1)
 local function missing()t.items(100,{},true,2);check(t.state.recall_due and not t.state.pending,'reservation not held')end
 local function unchanged()check(r.recovery==recovery and not r.waiting,'root recovery mutated')end
 return c,sent,missing,unchanged
end
local firefly='You touch the firefly tattoo and suddenly your surroundings are alight.'
local function fire(c)
 local B,s=c.buffs,c.current
 B.text(s,'You have the following tattoos:');B.text(s,'Head: firefly Uses left: 2');B.on_prompt(s);check(B.toggle(s,'firefly',true));B.service(s,c.runner,c.runner.sender)
 check(s.buffs.pending and s.buffs.pending.key=='firefly')
end
-- Exact reported deadlock. No test writes/clears buff pending.
do
 local c,sent,missing,unchanged=fixture();local B,s=c.buffs,c.current
 fire(c);check(sent[1]=='touch firefly');missing();check(c.runner_module.defense(s));check(not c.defense.plan(s).hold)
 B.text(s,firefly);B.service(s,c.runner,c.runner.sender);check(s.buffs.pending,'ACK invented prompt');unchanged()
 s.player.equilibrium=false;B.on_prompt(s);B.service(s,c.runner,c.runner.sender);check(s.buffs.pending)
 s.player.equilibrium=true;B.service(s,c.runner,c.runner.sender);check(s.buffs.pending,'old prompt became recovery')
 B.on_prompt(s);B.service(s,c.runner,c.runner.sender);check(not s.buffs.pending);unchanged();c.travel.tick();check(sent[2]=='recall 17' and #sent==2)
 c.travel.tick();check(#sent==2);unchanged()
end
-- A pre-existing physical wait survives convenience bookkeeping until a real
-- readiness loss/recovery edge is delivered to the real runner.
do
 local c,sent,missing=fixture();fire(c);c.runner.waiting=true;c.runner.waiting_requires={balance=true};c.runner.recovery_snapshot={balance=0}
 local snapshot=c.runner.recovery_snapshot;missing();local B,s=c.buffs,c.current
 B.text(s,firefly);B.on_prompt(s);B.service(s,c.runner,c.runner.sender)
 check(not s.buffs.pending and c.runner.waiting and c.runner.recovery_snapshot==snapshot)
 c.travel.tick();check(#sent==1,'recall bypassed existing physical wait')
 c.runner_module.update_balance(c.runner);check(c.runner.waiting,'cached ready released root')
 s.player.balance=false;c.runner_module.update_balance(c.runner);check(c.runner.waiting)
 s.player.balance=true;c.runner_module.update_balance(c.runner);check(not c.runner.waiting)
 c.travel.tick();check(sent[2]=='recall 17' and c.runner.recovery_snapshot==snapshot)
end
-- Every hold permits own settlement but forbids new activation and queued OFF.
for _,kind in ipairs({'due','followfault','recall','ink','dispatch','fault','route'})do
 local c,sent,missing=fixture();local B,s=c.buffs,c.current;fire(c);missing()
 if kind=='followfault'then c.travel_owner.follow_fault='unknown'
 elseif kind=='recall'then c.travel_owner.pending={kind='recall'}
 elseif kind=='ink'then c.tattoo_owner={txn={}}
 elseif kind=='dispatch'then c.travel_owner.dispatching=true
 elseif kind=='fault'then c.travel_owner.fault='unknown'
 elseif kind=='route'then c.travel_owner.route={}end
 B.text(s,firefly);B.on_prompt(s);B.service(s,c.runner,c.runner.sender);check(not s.buffs.pending,'settlement blocked '..kind)
 s.buffs.cancel.cloak=true;B.master(s,true);for i=1,3 do B.service(s,c.runner,c.runner.sender)end
 check(#sent==1,'suppressed OFF/activation '..kind)
 check(Boot.service_policy(c)==(kind=='due' and 'continue' or 'settle'))
end
local failure='You do not have the power to summon forth an elemental.'
local success='You concentrate on the raw elemental energy flowing about your body, coalescing some of its potential into a massive elemental.'
local drain='As you place a hand upon the globe, the energy within surges in response. Tendrils of energy quickly escape their prison, infusing your body with the element of water.'
local function committed(c)
 local E=c.elementals;check(E.arm(c,true));E.text(c,failure);E.service(c);E.text(c,'This globe can be drained another 3 times.');E.prompt(c);E.service(c)
 check(E.state(c).committed and E.state(c).pending.phase=='drain')
end
for _,kind in ipairs({'due','followfault','recall','ink','route'})do
 local c,sent,missing,unchanged=fixture();local E=c.elementals;committed(c);missing()
 if kind=='followfault'then c.travel_owner.follow_fault='unknown' elseif kind=='recall'then c.travel_owner.pending={kind='recall'} elseif kind=='ink'then c.tattoo_owner={txn={}} elseif kind=='route'then c.travel_owner.route={}end
 E.text(c,drain);E.service(c);check(#sent==2,'drain ACK invented prompt');E.prompt(c);E.service(c)
 if kind=='due'then
  check(sent[3]=='summon elemental' and #sent==3);E.text(c,success);E.prompt(c);c.current.player.balance=false;E.service(c);check(not E.state(c).committed and not E.state(c).pending)
  c.current.player.balance=true;c.travel.tick();check(sent[4]=='recall 17' and #sent==4)
 else
  check(#sent==2 and E.state(c).committed,'physical continuation under '..kind)
  -- Real external trigger completion can settle the already owned drain.
  E.text(c,success);E.prompt(c);E.service(c);check(not E.state(c).pending and not E.state(c).committed)
 end
 unchanged()
end
-- Already-issued SUMMON settles under every hold, even when BASH has spent
-- balances against its new NPC before service runs.
for _,kind in ipairs({'due','followfault','recall','ink'})do
 local c,sent,missing=fixture();local E=c.elementals;committed(c);E.text(c,drain);E.prompt(c);E.service(c);check(sent[3]=='summon elemental');missing()
 if kind=='followfault'then c.travel_owner.follow_fault='unknown' elseif kind=='recall'then c.travel_owner.pending={kind='recall'} elseif kind=='ink'then c.tattoo_owner={txn={}}end
 E.text(c,success);E.service(c);check(E.state(c).pending,'SUMMON ACK invented recovery')
 E.prompt(c);c.current.player.balance=false;E.service(c)
 check(not E.state(c).pending and not E.state(c).committed and #sent==3,'SUMMON settlement blocked '..kind)
end
-- Fresh ordinary kill/failure intent cannot acquire a probe/drain during reservation.
for _,phase in ipairs({'failure','kill'})do
 local c,sent=fixture();local E=c.elementals;check(E.arm(c,true));c.travel_owner.recall_due=true
 E.text(c,phase=='failure' and failure or 'You have slain a massive elemental.');E.service(c);check(#sent==0)
end
-- False/throwing reentrant continuation cannot release unknown physical transport.
for _,failuremode in ipairs({'false','throw','opaque'})do
 local c,sent,missing=fixture();local E=c.elementals;committed(c);missing();local g=E.state(c)
 if failuremode=='opaque'then g.pending.phase='unknown';E.service(c);check(g.committed and #sent==2)
 else
  E.text(c,drain);E.prompt(c)
  E.service(c,function(cmd)sent[#sent+1]=cmd;E.text(c,success);E.prompt(c);E.service(c);if failuremode=='throw'then error('offline')end;return false end)
  check(g.fault and g.committed and g.pending);E.service(c);check(g.committed and #sent==3)
 end
 c.travel.tick();check(not c.travel_owner.pending,'unknown transport allowed recall')
end
-- Native container frames establish an existing pipe fill, then readback/light.
local function pipeframe(C,c,count,lit)
 C.text(c,'Pipe           Herb                     Puffs     Decay     Lit');C.text(c,'-------------------')
 C.text(c,'pipe101      '..(count==0 and 'empty' or 'a reishi mushroom')..'       '..count..'       A       '..lit)
 C.text(c,'-------------------');C.prompt(c)
end
local function auditpipe(c,count,lit)
 local C=c.containers;check(C.audit(c,function()end,'pipe'));pipeframe(C,c,count,lit)
end
for _,kind in ipairs({'due','followfault','recall','ink','gone','midstate','timeout','false','throw'})do
 local c,sent=fixture();local C=c.containers;c.supplies_quiet=true;c.containers_connected=function()return true end;c.containers_clock=function()return clock end
 c.supplies={state=function()return {stocks={['ic:reishi']={count=100,at=clock}}}end}
 auditpipe(c,10,'Yes');auditpipe(c,0,'No');check(C.service(c,c.runner.sender));check(sent[1]=='put reishi in pipe101')
 auditpipe(c,10,'No');local b=c.containers_data.barrier;check(b and b.phase=='needs light')
 c.travel_owner.recall_due=true
 if kind=='followfault'then c.travel_owner.follow_fault='unknown' elseif kind=='recall'then c.travel_owner.pending={kind='recall'} elseif kind=='ink'then c.tattoo_owner={txn={}}end
 if kind=='gone'then auditpipe(c,10,'Yes');check(not c.containers_data.barrier)
 elseif kind=='timeout'then check(C.audit(c,function()end,'pipe'));clock=clock+20 end
 if kind=='midstate'then
  -- Finish the outstanding targeted readback, then inject genuine newer frames
  -- during state evaluation: old action resolved, same pipe empty again.
  C.service(c,c.runner.sender);pipeframe(C,c,10,'No')
  local original=C.state
  C.state=function(context)
   C.state=original;auditpipe(c,10,'Yes');auditpipe(c,0,'No');return original(context)
  end
 end
 local function sender(cmd)
  sent[#sent+1]=cmd;C.service(c,c.runner.sender)
  if kind=='throw'then error('offline')end;if kind=='false'then return false end
 end
 C.service(c,sender)
 -- Existing fill requests its one targeted readback before LIGHT.
 if c.containers_data.sources.pipe.pending then pipeframe(C,c,10,'No') end
 C.service(c,sender)
 if kind=='due'then
  check(sent[2]=='light pipes' and #sent==2);auditpipe(c,10,'Yes');check(not c.containers_data.barrier);C.service(c,sender);check(#sent==2,'new fill after settlement')
 elseif kind=='false' or kind=='throw'then check(c.containers_data.barrier.fault and #sent==2);C.service(c,sender);check(#sent==2)
 else check(#sent==1,'unexpected container continuation '..kind)end
 if kind=='timeout'then check(c.containers_data.quarantine=='response timeout');C.service(c,sender);check(c.containers_data.quarantine=='response timeout')end
end
-- Lunch drain owns a lease, not permission to LIGHT: only the exact old
-- transaction's one native list may proceed. No stock/usage discovery leaks.
local function settling()
 local c,sent=fixture();local C=c.containers
 c.supplies_quiet=true;c.containers_connected=function()return true end;c.containers_clock=function()return clock end
 c.supplies={state=function()return {stocks={['ic:reishi']={count=100,at=clock}}}end}
 auditpipe(c,10,'Yes');auditpipe(c,0,'No');check(C.service(c,c.runner.sender));check(sent[1]=='put reishi in pipe101')
 local b=c.containers_data.barrier;check(b and b.query_due and b.phase=='waiting')
 c.lunch_boot=dofile(root..'lunch_boot.lua');c.lunch_duty={busy=true,active=true,phase='drain',lease=0}
 check(Boot.service_policy(c)=='settle')
 return c,sent,b
end
do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries={}
 d.querySender=function(cmd)queries[#queries+1]=cmd;C.service(c,c.runner.sender)end
 d.sources.vial.stock_due='fluidcache';d.sources.vial.usage_readback='needed';d.use_due=0
 C.service(c,c.runner.sender)
 check(#queries==1 and queries[1]=='pipelist','Lunch settlement stranded committed PUT targeted readback')
 check(d.barrier==b and not b.query_due and d.sources.pipe.pending and not d.stock_needed)
 C.service(c,c.runner.sender);check(#queries==1 and #sent==1,'nested/duplicate settlement dispatch')
 pipeframe(C,c,10,'No');check(d.barrier==b and b.phase=='needs light')
 C.service(c,c.runner.sender);check(#queries==1 and #sent==1,'settlement issued LIGHT/discovery')
 -- Positive, already-lit native readback may settle the barrier without LIGHT.
 check(C.audit(c,function()end,'pipe'));pipeframe(C,c,10,'Yes');check(not d.barrier)
 C.service(c,c.runner.sender);check(#queries==1 and #sent==1 and not d.stock_needed)
end
for _,kind in ipairs({'unknown','runnerunknown','fault','quarantine','none','pending','frame','notdue','badkind','opaque','offline','dispatch','actions','nosender'})do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries=0
 d.querySender=function()queries=queries+1 end
 if kind=='unknown'then c.transport_unknown=true
 elseif kind=='runnerunknown'then c.runner.transport_unknown=true
 elseif kind=='fault'then b.fault='refill transport unresolved'
 elseif kind=='quarantine'then d.quarantine='response timeout'
 elseif kind=='none'then d.barrier=nil;d.sources.pipe.usage_readback='needed'
 elseif kind=='pending'then d.sources.vial.pending=true;d.sources.vial.sent_at=clock
 elseif kind=='frame'then d.sources.vial.frame={}
 elseif kind=='notdue'then b.query_due=false
 elseif kind=='badkind'then b.kind='invalid'
 elseif kind=='opaque'then b.phase='unknown'
 elseif kind=='offline'then c.containers_connected=function()return false end
 elseif kind=='dispatch'then d.dispatching=true
 elseif kind=='actions'then d.action_dispatching=true
 elseif kind=='nosender'then d.querySender=nil end
 C.service(c,c.runner.sender);check(queries==0 and #sent==1,'unsafe settlement query '..kind)
 check((kind=='none' and d.barrier==nil) or (kind~='none' and d.barrier==b),'settlement erased barrier '..kind)
 if kind=='quarantine'then check(d.quarantine=='response timeout')end
end
for _,failuremode in ipairs({'false','throw'})do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries=0
 local sender=function(cmd)
  queries=queries+1;check(cmd=='pipelist');C.service(c,c.runner.sender)
  pipeframe(C,c,10,'Yes')
  if failuremode=='throw'then error('offline readback failure')end;return false
 end
 d.querySender=sender;C.service(c,c.runner.sender)
 check(queries==1 and #sent==1 and d.barrier==b and d.quarantine=='query transport failed','readback transport failure released barrier')
 C.service(c,c.runner.sender);check(queries==1 and d.barrier==b and d.querySender==sender)
end
-- Source callbacks can settle/replace barriers or revoke a session inside audit.
for _,where in ipairs({'state','clock','auditclock','connected','auditconnected','session'})do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries=0;local replacement={kind='pipe',id='pipe101',type='reishi',phase='waiting',at=clock,query_due=true}
 d.querySender=function()queries=queries+1 end
 if where=='state'then
  local old=C.state;C.state=function(owner)d.barrier=replacement;return old(owner)end
 elseif where=='clock'then c.containers_clock=function()d.barrier=replacement;return clock end
 elseif where=='connected'then c.containers_connected=function()d.barrier=replacement;return true end
 elseif where=='session'then c.containers_connected=function()c.current=S.new();return true end
 else
  local old=C.audit;C.audit=function(owner,sender,kind)
   if where=='auditclock'then c.containers_clock=function()d.barrier=replacement;return clock end
   else c.containers_connected=function()d.barrier=replacement;return true end end
   return old(owner,sender,kind)
  end
 end
 C.service(c,c.runner.sender);check(queries==0 and #sent==1,'stale barrier/session sent readback '..where)
 check(d.barrier==(where=='session' and b or replacement),'stale settlement erased replacement '..where)
end
-- Synchronous successful frames may settle, but cannot fall through into
-- another fill, including with legacy usage discovery explicitly selected.
for _,quietmode in ipairs({true,false})do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries=0
 c.supplies_quiet=quietmode;d.use_due=0
 local sender=function(cmd)
  queries=queries+1;check(cmd=='pipelist');C.service(c,c.runner.sender)
  pipeframe(C,c,10,'Yes');C.service(c,c.runner.sender)
 end
 d.querySender=sender
 check(not C.service(c,c.runner.sender));check(queries==1 and #sent==1 and not d.barrier and d.querySender==sender)
 C.service(c,c.runner.sender);check(queries==1 and #sent==1,'settled query fell through to new work')
end
-- Sole Recall reservation retains the existing continuation lane unchanged.
do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries={}
 c.lunch_duty=nil;c.travel_owner.recall_due=true;check(Boot.service_policy(c)=='continue')
 d.querySender=function(cmd)queries[#queries+1]=cmd;C.service(c,c.runner.sender)end
 C.service(c,c.runner.sender);check(#queries==1 and queries[1]=='pipelist' and #sent==1)
 pipeframe(C,c,10,'No');C.service(c,c.runner.sender);check(sent[2]=='light pipes' and #sent==2)
end
-- The final transport guard must reject changes introduced by audit itself.
for _,change in ipairs({'fault','quarantine','phase','kind','offline','unknown','session','gone'})do
 local c,sent,b=settling();local C=c.containers;local d=c.containers_data;local queries=0
 d.querySender=function()queries=queries+1 end
 local audit=C.audit;C.audit=function(owner,sender,kind)
  if change=='fault'then b.fault='unknown transport'
  elseif change=='quarantine'then d.quarantine='retained quarantine'
  elseif change=='phase'then b.phase='unknown'
  elseif change=='kind'then b.kind='vial'
  elseif change=='offline'then c.containers_connected=function()return false end
  elseif change=='unknown'then c.transport_unknown=true
  elseif change=='session'then c.current=S.new()
  elseif change=='gone'then d.barrier=nil end
  return audit(owner,sender,kind)
 end
 C.service(c,c.runner.sender);check(queries==0 and #sent==1,'audit bypassed identity/transport guard '..change)
 check(change=='gone' and d.barrier==nil or change~='gone' and d.barrier==b)
 if change=='fault'then check(b.fault=='unknown transport')end
 if change=='quarantine'then check(d.quarantine=='retained quarantine')end
end
print('convenience settlement: '..n..' checks passed; real controllers, fake transports')
