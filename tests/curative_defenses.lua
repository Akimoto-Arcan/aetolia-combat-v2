-- Current-mechanic correction: legacy self-blind/deaf are NOT safe upkeep.
-- Current Mindseye is one-time sensory protection, not vision while blind.
-- No live/network/IO. Counts below are synthetic offline fixture data only.
local root=assert(arg[1]);local B=dofile(root..'buffs.lua');local S=dofile(root..'state.lua')
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'fixture',0,true end
local n=0;local function check(v,why)n=n+1;assert(v,why or ('assertion '..n))end
local function row(s,k)for _,v in ipairs(B.rows(s))do if v.key==k then return v end end end
local function fresh()
 local s=S.new();s.connected=true;B.set_class(s,'Monk');local p=s.player
 p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100;p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 B.set_known(s,{});B.sync(s,'List',{});B.vitals(s,{blind=0,deaf=0,herb='1'})
 for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=false end
 local sent={};local runner={waiting=false,recovery={identity=true}};local recovery=runner.recovery
 local function tick()local x=B.service(s,runner,function(cmd)sent[#sent+1]=cmd end);check(runner.recovery==recovery and not runner.waiting,'mutated runner');return x end
 return s,sent,tick
end
-- Actual native denials win over the previous17-defense assumption.
do
 local s=S.new();local b=B.state(s)
 check(b.wanted.mindseye==true and not b.master and not b.sequence,'Mindseye default armed execution')
 check(row(s,'mindseye').required and not row(s,'mindseye').available,'required protection invented ink')
 check(b.wanted.blindness==nil and b.wanted.deafness==nil,'self-afflicted default survived')
end
do
 local s,sent,tick=fresh();local count=0;for _ in pairs(B.native_catalog)do count=count+1 end;check(count==12)
 for _,k in ipairs({'blindness','deafness','insulation','temperance','venom_resistance'})do
  check(not B.native_catalog[k]);check(not B.native_request(s,k,8));check(B.native_priority(s,k)==nil)
  check(row(s,k).control=='observed' and not row(s,k).available and not row(s,k).required)
  check(not B.toggle(s,k,true))
 end
 for _,k in ipairs({'blindness','deafness'})do
  check(row(s,k).owner=='SELF-AFFLICTED' and row(s,k).wanted==nil)
  check(row(s,k).availability:match('CURRENT MECHANIC PROOF'))
  s.buffs.wanted[k]=true -- malicious/stale saved intent cannot add an executor
 end
 B.master(s,true);for i=1,8 do clock=clock+20;tick()end
 check(#sent==0 and not s.buffs.pending and not s.buffs.fault,'self-affliction attempted')
 check(B.curative_catalog==nil and B.curative_policy_seed==nil,'obsolete curative engine survived')
end
-- Mindseye may be used when actual ink is verified; it must never authorize EAT.
do
 local s,sent,tick=fresh();B.text(s,'You have the following tattoos:')
 B.text(s,'Right leg:   Mindseye     Uses left: 2');B.on_prompt(s)
 check(B.toggle(s,'mindseye',true));tick();check(sent[1]=='touch mindseye')
 B.text(s,'Touching the mindseye tattoo, your senses are suddenly heightened.')
 s.player.equilibrium=false;B.on_prompt(s);tick();check(s.buffs.pending,'Mindseye EQ manufactured')
 s.player.equilibrium=true;B.on_prompt(s);tick();check(not s.buffs.pending and row(s,'mindseye').active)
 check(row(s,'mindseye').label:match('one%-time sensory protection'))
 s.buffs.wanted.blindness=true;s.buffs.wanted.deafness=true
 -- Actual one-time protection consumption arrives through own Remove, not an
 -- assumption that blindness has become a beneficial maintained defense.
 B.sync(s,'Remove','mindseye');B.vitals(s,{blind='0',deaf=0});B.master(s,false);tick()
 check(not row(s,'mindseye').active and not row(s,'blindness').active)
 for _,cmd in ipairs(sent)do check(not cmd:match('eat ') and not cmd:match('outc ') and not cmd:match('firstaid priority'))end
end
-- Native sensory cure/loss lines remain observable without an upkeep fight.
do
 local s,sent,tick=fresh();B.text(s,'Your eyes dim as you lose your sight.');check(row(s,'blindness').active)
 B.text(s,'You have cured blindness.');B.vitals(s,{blind=0});check(not row(s,'blindness').active)
 B.text(s,'The world around fades to silence as you lose your hearing.');check(row(s,'deafness').active)
 B.text(s,'You have cured deafness.');B.vitals(s,{deaf=0});check(not row(s,'deafness').active)
 B.master(s,true);tick();check(#sent==0,'fought native cure')
end
-- Unknown prior Immunity cooldown waits120s after the first fresh snapshot.
do
 local s,sent,tick=fresh();B.set_known(s,{'Immunity'});s.buffs.wanted.immunity=true
 local initial=clock;B.master(s,true);tick();check(#sent==0)
 clock=initial+119;tick();check(#sent==0);clock=initial+121;tick();check(sent[1]=='immunity')
 B.text(s,'Your blood is steeled against poisons.');B.on_prompt(s);tick()
 check(s.buffs.cooldown.immunity==initial+241)
 B.sync(s,'Remove','kaido_immunity');clock=initial+200;B.sync(s,'List',{});tick();check(#sent==1,'snapshot/loss reset cooldown')
end
-- Independently reproduced orderings: report/consumption, unattributed rejection,
-- and passive status precedence. All use the same real public event entry points.
local function report(s,k,count)
 B.text(s,'You have the following tattoos:');B.text(s,'Head: '..k..' Uses left: '..count)
end
for _,afterDebitRow in ipairs({false,true})do
 local s,sent,tick=fresh();report(s,'Mindseye',1);B.on_prompt(s)
 B.toggle(s,'mindseye',true)
 B.text(s,'You have the following tattoos:')
 if not afterDebitRow then B.text(s,'Head: Mindseye Uses left: 1')end
 tick();check(sent[1]=='touch mindseye')
 if afterDebitRow then B.text(s,'Head: Mindseye Uses left: 1')end
 B.text(s,'Touching the mindseye tattoo, your senses are suddenly heightened.')
 B.on_prompt(s);tick();check(not s.buffs.pending)
 B.sync(s,'Remove','mindseye');clock=clock+3;tick()
 check(#sent==1 and not B.availability(s,'mindseye'),'pre-debit report resurrected spent ink')
end
-- A report opened during unresolved consumption cannot prove it includes that
-- debit, even if its header is newer than dispatch and its rows say one remains.
do
 local s,sent,tick=fresh();report(s,'Mindseye',1);B.on_prompt(s)
 B.toggle(s,'mindseye',true);tick();report(s,'Mindseye',1)
 B.text(s,'You use Tattoos Mindseye.');B.text(s,'You have gained the mindseye defence.')
 B.on_prompt(s);tick();B.sync(s,'Remove','mindseye');clock=clock+3;tick()
 check(#sent==1 and not B.availability(s,'mindseye'),'unresolved debit report granted ink')
 -- Only a new post-settlement report can grant new ink.
 report(s,'Mindseye',2);B.on_prompt(s);tick();check(#sent==2)
 B.text(s,'You use Tattoos Mindseye.');B.text(s,'You have gained the mindseye defence.')
 check(s.buffs.tattoos.mindseye.charges==1,'own two-line ACK double debited')
end
for _,line in ipairs({'Touching the mindseye tattoo, your senses are suddenly heightened.','You use Tattoos Mindseye.','You have gained the mindseye defence.'})do
 local s,sent,tick=fresh();report(s,'Mindseye',1);B.on_prompt(s)
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Mindseye Uses left: 1')
 B.text(s,line);B.text(s,'You have gained the mindseye defence.');B.on_prompt(s)
 B.sync(s,'Remove','mindseye');B.master(s,true);s.buffs.wanted.mindseye=true;tick()
 check(#sent==0 and not B.availability(s,'mindseye'),'external activation retained last charge: '..line)
 B.set_groups(s,{{name='Tattoos',rank='Transcendent'}});tick();check(#sent==0,'rank restored spent ink')
end
-- The shared ink fence covers Cloak too, and an unrelated report may not
-- replenish a Mindseye budget while its own operation is unresolved.
do
 local s,sent,tick=fresh();report(s,'Cloak',1);B.on_prompt(s);B.toggle(s,'cloak',true)
 report(s,'Cloak',1);tick();check(sent[1]=='touch cloak')
 B.text(s,'You caress the tattoo and immediately you feel a cloak of protection surround you.')
 B.on_prompt(s);tick();B.sync(s,'Remove','cloak');clock=clock+3;tick()
 check(#sent==1 and not B.availability(s,'cloak'),'Cloak stale ink resurrected')
 report(s,'Cloak',1);B.on_prompt(s)
 B.text(s,'You caress the tattoo and immediately you feel a cloak of protection surround you.')
 B.sync(s,'Remove','cloak');tick();check(#sent==1 and not B.availability(s,'cloak'),'external Cloak retained ink')
end
do
 local s,sent,tick=fresh();report(s,'Mindseye',1);B.on_prompt(s);B.toggle(s,'mindseye',true);tick()
 report(s,'Cloak',2);B.text(s,'Head: Mindseye Uses left: 1');B.on_prompt(s)
 B.sync(s,'Add','mindseye');B.on_prompt(s);tick();B.sync(s,'Remove','mindseye');clock=clock+3;tick()
 check(#sent==1 and not B.availability(s,'mindseye'),'unrelated newer report replenished unresolved debit')
end
for _,confirmed in ipairs({false,true})do
 for _,line in ipairs({'You must regain balance first.','You must regain equilibrium first.','You do not possess that ability.'})do
  local s,sent,tick=fresh();B.set_known(s,{'Immunity'});s.buffs.wanted.immunity=true
  clock=clock+121;B.master(s,true);tick();check(sent[1]=='immunity')
  if confirmed then B.sync(s,'Add','kaido_immunity')end
  local p=s.buffs.pending;local cd=s.buffs.cooldown.immunity;s.player.equilibrium=false
  B.text(s,line);check(tick().busy and s.buffs.pending==p and s.buffs.cooldown.immunity==cd,'generic reply erased commit')
  s.player.equilibrium=true;tick();check(s.buffs.pending==p,'cached readiness released commit')
  if not confirmed then B.sync(s,'Add','kaido_immunity')end
  B.on_prompt(s);tick();check(not s.buffs.pending,'authoritative ACK and fresh ready prompt failed to settle')
 end
end
do
 local s,sent,tick=fresh()
 -- Removal must fence even the first report, including a row delivered later.
 s.buffs.defs_known=false
 B.text(s,'You have the following tattoos:');B.sync(s,'Remove','boar')
 B.text(s,'Head: Boar Active');B.on_prompt(s)
 check(row(s,'boar').active==false,'first in-flight tattoo report overrode newer removal')
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Boar Active');B.on_prompt(s)
 B.sync(s,'List',{});check(row(s,'boar').active,'unrelated absence erased passive tattoo')
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Boar Active')
 B.sync(s,'Remove','boar');check(row(s,'boar').active==false,'new Remove lost to old Active')
 B.on_prompt(s);check(row(s,'boar').active==false,'old transaction replayed Active')
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Boar Active');B.on_prompt(s)
 check(row(s,'boar').active,'new report could not restore passive Active')
 B.sync(s,'List',{});check(row(s,'boar').active and #sent==0)
end
print('PASS current sensory safety '..n..' assertions: native12, no legacy self-affliction, current one-time Mindseye, native curing untouched, conservative Immunity cooldown')
