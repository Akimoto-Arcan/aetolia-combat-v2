-- Pure fake replay tests; no game, network, deployment or profile access.
local root=(arg and arg[1]) or 'combat_v2/'
local E=dofile(root..'elementals.lua')
local State=dofile(root..'state.lua')
local Runner=dofile(root..'runner.lua')
local Defense=dofile(root..'defense.lua')
local Policy=dofile(root..'policy.lua')
local clock,tcp=100,true
getEpoch=function() return clock end
getConnectionInfo=function() return 'fake',0,tcp end
local failure='You do not have the power to summon forth an elemental.'
local success='You concentrate on the raw elemental energy flowing about your body, coalescing some of its potential into a massive elemental.'
local drain='As you place a hand upon the globe, the energy within surges in response. Tendrils of energy quickly escape their prison, infusing your body with the element of water.'
local count,checks=0,0
local function eq(a,b,msg) checks=checks+1;assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count=count+1;print('PASS '..name) end
local function fixture()
 clock=100;tcp=true
 local s=State.new();s.mode='BASH';s.connected=true;s.room.id=123;s.room.area='fake area';s.room.item_version=1
 local p=s.player;p.hp=1000;p.maxhp=1000;p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 s.hunting.ih={active=false,pending=false,responded=true,room_id=123,start_version=0}
 s.hunting.watch={room_id=123,checked_version=1}
 Policy.init(s);s.policy.area='fake area';s.policy.areas_loaded=true;s.policy.areas['fake area']=true;Policy.players(s,{})
 local sent={};local r=Runner.new(s,{});r.mode='BASH';r.sender=function(cmd) sent[#sent+1]=cmd end
 local c={current=s,mode='BASH',runner=r,runner_module=Runner,defense=Defense,policy=Policy,state=State}
 return c,sent
end
local function tick(c) return E.service(c) end
local function start(c) eq(E.arm(c,true),true);E.text(c,failure);tick(c) end
local function probe(c,n) E.text(c,'This globe is infused with water and can be drained another '..tostring(n or 3)..' times.');E.prompt(c);tick(c) end
local function ack(c) E.text(c,drain);E.prompt(c);tick(c) end
local function finish(c) E.text(c,success);E.prompt(c);tick(c) end

test('default OFF, no initial summon or own-kill loop',function()
 local c,sent=fixture();E.text(c,failure);tick(c);eq(#sent,0);eq(E.state(c).armed,false)
 E.arm(c,true);tick(c);E.text(c,'You have slain a massive elemental.');tick(c);eq(#sent,0)
 E.text(c,'Someone says, "'..failure..'"');tick(c);eq(#sent,0)
end)
test('exact finite probe drain summon; duplicate failures ignored',function()
 local c,sent=fixture();start(c);eq(sent[1],'probe globe')
 for i=1,20 do E.text(c,failure);tick(c) end;eq(#sent,1)
 probe(c,2);eq(sent[2],'drain globe');ack(c);eq(sent[3],'summon elemental');finish(c)
 eq(#sent,3);eq(E.state(c).pending,nil);eq(E.state(c).armed,true)
 for i=1,10 do tick(c) end;eq(#sent,3)
 local history=c.current.history;eq(history[#history].kind,'elemental_recovery')
end)
test('fresh prompt after ACK, readiness and no timer-forged recovery',function()
 local c,sent=fixture();start(c);E.prompt(c)
 E.text(c,'This globe is infused with water and can be drained another 3 times.');tick(c);eq(#sent,1)
 E.prompt(c);tick(c);eq(#sent,2);E.prompt(c);E.text(c,drain);tick(c);eq(#sent,2)
 c.current.player.balance=false;E.prompt(c);tick(c);eq(#sent,2)
 c.current.player.balance=true;tick(c);eq(#sent,2);E.prompt(c);tick(c);eq(#sent,3)
end)
test('mismatched ACK and speech never authorize consumption',function()
 local c,sent=fixture();start(c)
 E.text(c,'Someone says, "This globe is infused with water and can be drained another 3 times."');E.prompt(c);tick(c);eq(#sent,1)
 probe(c,3);E.text(c,'Someone says, "'..drain..'"');E.text(c,drain:gsub('water','lava'));E.prompt(c);tick(c);eq(#sent,2)
 E.text(c,drain);E.prompt(c);tick(c);E.text(c,'Someone says, "'..success..'"');E.prompt(c);tick(c);eq(E.state(c).pending.phase,'summon')
end)
test('probe zero permanently faults; no blind drain and rearm forbidden',function()
 local c,sent=fixture();start(c);probe(c,0);eq(#sent,1);eq(E.state(c).armed,false);eq(E.arm(c,true),false)
 E.text(c,failure);clock=clock+100;tick(c);eq(#sent,1)
end)
test('fresh count each independent cycle, finite globe exhausted',function()
 local c,sent=fixture();E.arm(c,true)
 -- Fake server fixture is the only source of counts; no cached counter in module.
 for n=3,1,-1 do
  E.text(c,failure);tick(c);eq(sent[#sent],'probe globe');probe(c,n);ack(c);finish(c)
 end
 eq(#sent,9);E.text(c,failure);tick(c);probe(c,0);eq(#sent,10);eq(E.state(c).armed,false)
end)
test('missing globe and malformed count fail closed',function()
 local c,sent=fixture();start(c);E.text(c,'I do not see that here.');tick(c);eq(#sent,1);eq(E.state(c).armed,false)
 c,sent=fixture();start(c);probe(c,5);eq(#sent,1);clock=clock+12;tick(c);eq(E.state(c).armed,false)
end)
test('native fresh Defence.Add ACK only, cached List ignored',function()
 local c,sent=fixture();start(c);probe(c,3)
 E.defence(c,'List',{{name='water_infused'}});E.prompt(c);tick(c);eq(#sent,2)
 E.defence(c,'Add',{name='lava_infused'});E.prompt(c);tick(c);eq(#sent,2)
 E.defence(c,'Add',{name='air_infused'});tick(c);eq(#sent,2);E.prompt(c);tick(c);eq(#sent,3)
end)
test('fresh living room Add success, never cached List inventory corpse or loyal',function()
 local c,sent=fixture();start(c);probe(c,3);ack(c)
 local payload={location='room',item={id=77,name='a massive elemental',attrib='m'}}
 E.item(c,'List',payload);eq(E.state(c).pending.ack,nil)
 payload.location='inv';E.item(c,'Add',payload);eq(E.state(c).pending.ack,nil)
 payload.location='room';payload.item.attrib='md';E.item(c,'Add',payload);eq(E.state(c).pending.ack,nil)
 payload.item.attrib='mx';E.item(c,'Add',payload);eq(E.state(c).pending.ack,nil)
 payload.item.attrib='m';E.item(c,'Add',payload);eq(E.state(c).pending.ack,true)
 E.prompt(c);tick(c);eq(E.state(c).pending,nil);eq(#sent,3)
end)
test('actual failed helper summon latches, never starts another drain',function()
 local c,sent=fixture();start(c);probe(c,3);ack(c);E.text(c,failure)
 eq(E.state(c).armed,false);eq(E.state(c).pending.phase,'summon');eq(E.state(c).committed,true)
 for i=1,20 do E.text(c,failure);tick(c) end
 eq(#sent,3);eq(E.arm(c,true),false)
 E.detach(c);local fresh=dofile(root..'elementals.lua');eq(fresh.arm(c,true),false);eq(fresh.state(c).pending.phase,'summon')
end)
local blockers={
 area=function(c)c.current.policy.areas_loaded=false end,
 players_unknown=function(c)c.current.policy.players_known=false end,
 player=function(c)Policy.players(c.current,{{name='Stranger'}})end,
 runner_wait=function(c)c.runner.waiting=true end,
 runner_fault=function(c)c.runner.fault='fault' end,
 runner_pending=function(c)c.runner.pending={} end,
 balance=function(c)c.current.player.balance=false end,
 eq=function(c)c.current.player.equilibrium=false end,
 left_arm=function(c)c.current.player.left_arm_balance=false end,
 right_arm=function(c)c.current.player.right_arm_balance=false end,
 buff=function(c)c.current.buffs={pending={}}end,
 mental=function(c)c.current.mental={eq_pending={}}end,
 walker=function(c)c.current.walker={pending={}}end,
 paralysis=function(c)c.current.player.afflictions.paralysis=true end,
 prone=function(c)c.current.player.prone=true end,
 curelock=function(c)local a=c.current.player.afflictions;a.anorexia=true;a.asthma=true;a.slickness=true end,
 defense=function(c)c.defense={plan=function()return {hold=true}end}end,
 scan_active=function(c)c.current.hunting.ih.active=true end,
 scan_pending=function(c)c.current.hunting.ih.pending=true end,
 stale_empty=function(c)c.current.hunting.ih.responded=false;c.current.hunting.ih.start_version=1 end,
 no_scan=function(c)c.current.hunting.ih=nil end,
}
for name,block in pairs(blockers) do
 test('all sends gated: '..name,function()
  for phase=1,3 do
   local c,sent=fixture();E.arm(c,true)
   if phase==1 then block(c);E.text(c,failure)
   else E.text(c,failure);tick(c);if phase==3 then probe(c,3);E.text(c,drain);E.prompt(c) else E.text(c,'This globe is infused with water and can be drained another 3 times.');E.prompt(c) end;block(c) end
   local n=#sent;tick(c);eq(#sent,n);clock=clock+61;tick(c);eq(E.state(c).armed,false)
  end
 end)
end
for name,change in pairs({room=function(c)c.current.room.id=456 end,mode=function(c)c.mode='OFF' end,state_mode=function(c)c.current.mode='OFF'end,runner_mode=function(c)c.runner.mode='OFF'end,dead=function(c)c.current.player.hp=0 end,tcp=function()tcp=false end,connection=function(c)c.current.connected=false end}) do
 test('scope invalidation '..name,function()
  local c,sent=fixture();start(c);probe(c,3);change(c);E.text(c,drain);E.prompt(c);tick(c)
  eq(#sent,2);eq(E.state(c).armed,false);eq(E.state(c).committed,true);eq(E.state(c).pending.phase,'drain')
  c.current.room.id=123;c.mode='BASH';c.current.mode='BASH';c.runner.mode='BASH';c.current.player.hp=100;c.current.connected=true;tcp=true
  tick(c);E.text(c,failure);tick(c);eq(#sent,2)
 end)
end
test('new living target before drain cancels without charge',function()
 local c,sent=fixture();start(c);c.current.room.items['1']={name='a massive elemental',attrib='m'};probe(c,3)
 eq(#sent,1);eq(E.state(c).pending,nil);eq(E.state(c).committed,nil)
end)
test('empty classification excludes corpses loyal and non-monsters',function()
 local c,sent=fixture();c.current.room.items={a={name='a massive elemental',attrib='md'},b={name='a massive elemental',attrib='mx'},d={name='globe',attrib=''}}
 start(c);eq(sent[1],'probe globe');probe(c,3);eq(sent[2],'drain globe')
end)
test('unanswered protocol deadline does not blindly repeat',function()
 for stage=1,3 do
  local c,sent=fixture();start(c);if stage>=2 then probe(c,3) end;if stage>=3 then ack(c) end
  local n=#sent;clock=clock+12;tick(c);eq(#sent,n);eq(E.state(c).armed,false);eq(E.state(c).pending~=nil,true)
 end
end)
test('sender false or exception retained as uncertain commit',function()
 for _,sender in ipairs({function()return false end,function()error('fake send error')end}) do
  local c,sent=fixture();start(c);E.text(c,'This globe is infused with water and can be drained another 3 times.');E.prompt(c);E.service(c,sender)
  eq(E.state(c).armed,false);eq(E.state(c).committed,true);eq(E.state(c).pending.phase,'drain');eq(#sent,1)
 end
end)
test('reentrant fake sender cannot duplicate any phase',function()
 local c,sent=fixture()
 c.runner.sender=function(cmd)
  sent[#sent+1]=cmd
  if cmd=='probe globe' then E.text(c,'This globe is infused with water and can be drained another 3 times.')
  elseif cmd=='drain globe' then E.text(c,drain)
  elseif cmd=='summon elemental' then E.text(c,success) end
  E.prompt(c);E.service(c)
 end
 E.arm(c,true);E.text(c,failure)
 for i=1,10 do tick(c) end
 eq(table.concat(sent,'|'),'probe globe|drain globe|summon elemental');eq(E.state(c).pending,nil)
end)
test('reentrant recorder can revoke intent before sender',function()
 local c,sent=fixture();c.state={record=function() E.arm(c,false) end}
 start(c);eq(#sent,0);eq(E.state(c).armed,false);eq(E.state(c).pending,nil);eq(E.state(c).fault,nil)
end)
test('fake attach owns hooks; idle has no timer; off/detach preserves barrier',function()
 local c,sent=fixture();local nextid=0;local timers,callbacks,events={},{},{};local killed=0
 local function register(fn)nextid=nextid+1;callbacks[nextid]=fn;return nextid end
 tempRegexTrigger=function(_,fn)return register(fn)end;tempPromptTrigger=register
 tempAlias=function(_,fn)return register(fn)end
 registerAnonymousEventHandler=function(name,fn)events[name]=fn;return register(fn)end
 tempTimer=function(delay,fn)eq(delay,.25);local id=register(fn);timers[id]=fn;return id end
 killTimer=function(id)timers[id]=nil;callbacks[id]=nil;killed=killed+1 end
 killTrigger=function(id)callbacks[id]=nil end;killAlias=killTrigger;killAnonymousEventHandler=killTrigger
 E.attach(c);eq(E.state(c).armed,false);eq(next(timers),nil);eq(#sent,0)
 E.arm(c,true);E.text(c,failure);local id,fn=next(timers);eq(type(fn),'function');timers[id]=nil;callbacks[id]=nil;fn();eq(#sent,1)
 probe(c,3);eq(#sent,2);events.sysDisconnectionEvent();eq(E.state(c).armed,false);eq(next(timers),nil)
 E.detach(c);eq(next(callbacks),nil);eq(E.state(c).pending.phase,'drain');eq(killed>0,true)
 tempTimer=nil;tempRegexTrigger=nil;tempPromptTrigger=nil;tempAlias=nil;registerAnonymousEventHandler=nil
end)

test('successful summon settles even when BASH immediately consumes balances',function()
 local c,sent=fixture();start(c);probe(c,2);ack(c)
 E.text(c,success);c.runner.waiting=true;c.current.player.balance=false
 E.prompt(c);tick(c)
 eq(#sent,3);eq(E.state(c).pending,nil,'successful summon remained blocked behind next fight')
 eq(E.state(c).armed,true);clock=clock+65;tick(c);eq(E.state(c).fault,nil)
end)

test('new summon waits for recovery without pausing existing BASH offense',function()
 local c,sent=fixture();start(c);probe(c,2);c.current.player.hp=300;ack(c)
 eq(#sent,2,'spawned a new enemy at low health');eq(c.mode,'BASH')
 c.current.player.hp=800;tick(c);eq(sent[3],'summon elemental')
end)
test('globe off cancels uncommitted probe normally and can rearm',function()
 local c,sent=fixture();start(c);E.arm(c,false);eq(E.state(c).pending,nil);eq(E.state(c).fault,nil);eq(E.arm(c,true),true);eq(#sent,1)
end)
local function arrive(c)
 c.current.room.items['999']={name='an unexpected hostile',attrib='m'}
 c.current.room.item_version=c.current.room.item_version+1
end
local function leave(c)
 c.current.room.items['999']=nil
 c.current.room.item_version=c.current.room.item_version+1
end
test('NPC arriving after drain dispatch holds committed recovery until fresh empty and ready',function()
 local c,sent=fixture();start(c);probe(c,2);local pending=E.state(c).pending
 arrive(c);ack(c)
 eq(#sent,2);eq(E.state(c).pending,pending);eq(E.state(c).committed,true);eq(E.state(c).armed,true)
 eq(c.mode,'BASH');eq(c.runner.mode,'BASH')
 E.text(c,failure);tick(c);eq(#sent,2);eq(E.state(c).pending,pending)
 leave(c);c.current.hunting.ih.responded=false;c.current.hunting.ih.start_version=c.current.room.item_version
 tick(c);eq(#sent,2,'stale empty room authorized summon')
 c.current.room.item_version=c.current.room.item_version+1;c.current.player.balance=false
 tick(c);eq(#sent,2);c.current.player.balance=true;E.prompt(c);tick(c)
 eq(sent[3],'summon elemental');finish(c);eq(E.state(c).pending,nil)
end)
test('NPC arriving during health wait still blocks summon after healing',function()
 local c,sent=fixture();start(c);probe(c,2);c.current.player.hp=300;ack(c)
 arrive(c);c.current.player.hp=800;tick(c)
 eq(#sent,2);eq(E.state(c).pending.phase,'drain');eq(E.state(c).committed,true);eq(c.mode,'BASH')
 leave(c);tick(c);eq(sent[3],'summon elemental')
end)
test('occupied drain hold survives concurrent runner wait and actual recovery',function()
 local c,sent=fixture();start(c);probe(c,2);arrive(c)
 c.runner.waiting=true;c.current.player.balance=false;ack(c)
 eq(#sent,2);eq(E.state(c).pending.phase,'drain')
 c.runner.waiting=false;c.current.player.balance=true;E.prompt(c);tick(c)
 eq(#sent,2);eq(E.state(c).committed,true);eq(c.runner.mode,'BASH')
 leave(c);c.runner.waiting=true;tick(c);eq(#sent,2)
 c.runner.waiting=false;c.current.player.balance=false;tick(c);eq(#sent,2)
 c.current.player.balance=true;E.prompt(c);tick(c);eq(sent[3],'summon elemental')
end)
test('exact external summon after drain ACK settles only at its post-success prompt',function()
 local c,sent=fixture();start(c);probe(c,2);arrive(c);ack(c)
 local pending=E.state(c).pending
 E.text(c,'Someone says, "'..success..'"')
 E.item(c,'List',{location='room',item={id=77,name='a massive elemental',attrib='m'}})
 E.item(c,'Add',{location='room',item={id=77,name='a massive elemental',attrib='m'}})
 E.prompt(c);tick(c);eq(E.state(c).pending,pending);eq(#sent,2)
 E.text(c,success);tick(c)
 eq(E.state(c).pending,pending);eq(E.state(c).committed,true);eq(#sent,2)
 -- No helper SUMMON, even if the room becomes empty before the next prompt.
 leave(c);tick(c);eq(#sent,2);eq(E.state(c).pending,pending)
 c.runner.waiting=true;c.current.player.balance=false;E.prompt(c);tick(c)
 eq(E.state(c).pending,nil);eq(E.state(c).committed,nil);eq(E.state(c).armed,true);eq(#sent,2)
 clock=clock+65;tick(c);eq(E.state(c).fault,nil)
 c.runner.waiting=false;c.current.player.balance=true
 E.text(c,failure);tick(c);eq(sent[3],'probe globe');probe(c,1);ack(c);finish(c)
 eq(#sent,5);eq(E.state(c).pending,nil);eq(E.state(c).armed,true)
end)
test('external success before drain ACK cannot settle or authorize a blind retry',function()
 local c,sent=fixture();start(c);probe(c,2);arrive(c)
 E.text(c,success);E.prompt(c);tick(c)
 eq(E.state(c).pending.phase,'drain');eq(E.state(c).pending.ack,nil);eq(E.state(c).committed,true);eq(#sent,2)
 ack(c);eq(#sent,2);eq(E.state(c).pending.phase,'drain')
 E.prompt(c);tick(c);eq(E.state(c).pending.phase,'drain')
 E.text(c,success);tick(c);eq(E.state(c).pending.phase,'drain')
 E.prompt(c);tick(c);eq(E.state(c).pending,nil);eq(#sent,2)
end)
-- Real physical execution, not a hand-seeded runner.waiting/fault approximation.
local Monk=dofile(root..'monk.lua')
local Buffs=dofile(root..'buffs.lua')
local function physical(c,sent,callback)
 local s,r=c.current,c.runner;r.monk=Monk;s.player.stance='scorpion'
 State.set_target(s,'123');s.room.items['123']={id='123',name='a fixture monster',attrib='m'}
 s.hunting.verified_generation=s.target_generation
 Runner.bind_policy(Policy.allowed)
 r.sender=function(cmd)sent[#sent+1]=cmd;return callback(r.transport_commit)end
 return Runner.execute(r,Runner.propose(r))
end
local function empty_rearm(c)
 Runner.stop(c.runner);c.mode='BASH';c.current.mode='BASH';c.runner.mode='BASH'
 c.current.room.items={};c.current.hunting.ih={active=false,pending=false,responded=true,room_id=123,start_version=0}
 c.current.hunting.watch={room_id=123,checked_version=c.current.room.item_version}
end
local function resource_count(sent)
 local n=0;for _,cmd in ipairs(sent)do if cmd=='drain globe' or cmd=='summon elemental'then n=n+1 end end;return n
end
for _,binding in ipairs({'shared','older','absent'})do
 for _,outcome in ipairs({'false','throw'})do
  test('real failed normal transport + STOP/BASH/GLOBE '..outcome..' '..binding,function()
   local c,sent=fixture();c.buffs=binding=='shared' and Buffs or (binding=='older' and {} or nil)
   eq(physical(c,sent,function()if outcome=='throw'then error('offline physical failure')end;return false end),false)
   local commit=c.runner.transport_commit;eq(commit.failed,true);eq(commit.sent,false)
   empty_rearm(c);eq(c.runner.fault,nil);eq(c.runner.waiting,false)
   -- A safe fake sender must not be reached for any consuming resource action.
   c.runner.sender=function(cmd)sent[#sent+1]=cmd end
   start(c);probe(c,2);ack(c);finish(c)
   eq(resource_count(sent),0);eq(c.runner.transport_commit,commit)
   E.arm(c,false);E.text(c,failure);E.prompt(c);tick(c)
   eq(E.state(c).armed,false);eq(resource_count(sent),0);eq(c.runner.transport_commit,commit)
  end)
 end
end
for _,outcome in ipairs({'true','false','throw'})do
 test('real unfinished sender reentry + nested STOP/BASH/GLOBE '..outcome,function()
  local c,sent=fixture();c.buffs=Buffs;local entered=false;local retained
  local ok=physical(c,sent,function(commit)
   retained=commit;eq(commit.sent,nil);empty_rearm(c)
   start(c);probe(c,2);ack(c);finish(c)
   eq(resource_count(sent),0);eq(c.runner.transport_commit,commit);entered=true
   if outcome=='throw'then error('offline nested failure')end;return outcome=='true'
  end)
  eq(entered,true,'runner swallowed callback assertion');eq(ok,outcome=='true')
  eq(resource_count(sent),0)
  if outcome=='true'then
   eq(c.runner.transport_commit,nil);eq(retained.sent,true)
   c.runner.sender=function(cmd)sent[#sent+1]=cmd end
   tick(c);probe(c,2);ack(c);finish(c);eq(resource_count(sent),2)
  else
   eq(c.runner.transport_commit,retained);eq(retained.failed,true)
   empty_rearm(c);c.runner.sender=function(cmd)sent[#sent+1]=cmd end
   probe(c,2);ack(c);finish(c);eq(resource_count(sent),0)
  end
 end)
end
for _,phase in ipairs({'probe','drain'})do
 test('retained failed physical transport blocks new resource dispatch after '..phase..' ACK',function()
  local c,sent=fixture();start(c);if phase=='drain'then probe(c,2)end
  eq(physical(c,sent,function()return false end),false);local commit=c.runner.transport_commit
  empty_rearm(c);c.runner.sender=function(cmd)sent[#sent+1]=cmd end
  local before=resource_count(sent)
  if phase=='probe'then probe(c,2)else ack(c)end
  eq(resource_count(sent),before);eq(E.state(c).pending.phase,phase);eq(E.state(c).pending.ack,true)
  eq(c.runner.transport_commit,commit)
 end)
end
for _,external in ipairs({false,true})do
 test('already committed completion settles while real physical transport held '..tostring(external),function()
  local c,sent=fixture();c.buffs=Buffs;start(c);probe(c,2)
  if external then E.text(c,drain)else ack(c)end
  local pending=E.state(c).pending;local before=resource_count(sent)
  eq(physical(c,sent,function()return false end),false);local commit=c.runner.transport_commit
  empty_rearm(c);c.runner.sender=function(cmd)sent[#sent+1]=cmd end
  E.text(c,success);tick(c);eq(E.state(c).pending,pending)
  c.runner.waiting=true;c.current.player.balance=false;E.prompt(c);tick(c)
  eq(E.state(c).pending,nil);eq(E.state(c).committed,nil);eq(E.state(c).armed,true)
  eq(resource_count(sent),before);eq(c.runner.transport_commit,commit)
 end)
end
-- A successful finish record retained by an older caller is not an unknown send.
test('successful finished transport metadata does not falsely hold standalone GLOBE',function()
 local c,sent=fixture();c.runner.transport_commit={sent=true,failed=false}
 start(c);probe(c,2);ack(c);finish(c);eq(resource_count(sent),2)
end)
print(string.format('elementals: %d tests, %d assertions passed',count,checks))
