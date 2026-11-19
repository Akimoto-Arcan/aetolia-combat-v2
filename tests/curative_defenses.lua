-- Explicit sensory intent needs current cure-ignore and actual resource proof.
-- Current Mindseye is one-time sensory protection, not vision while blind.
-- No live/network/IO. Counts below are synthetic offline fixture data only.
-- Historical algorithm regression only; production retirement is independently
-- proved against the unmodified module in sensory_retirement.lua and integration.
local root=assert(arg[1]);local B=dofile((arg[0]:match('^(.*/)') or '')..'legacy_sensory_fixture.lua')(root..'buffs.lua');local S=dofile(root..'state.lua')
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
 check(b.wanted.blindness==false and b.wanted.deafness==false,'sensory default armed')
end
do
 local s,sent,tick=fresh();local count=0;for _ in pairs(B.native_catalog)do count=count+1 end;check(count==12)
 for _,k in ipairs({'blindness','deafness','insulation','temperance','venom_resistance'})do
  check(not B.native_catalog[k]);check(not B.native_request(s,k,8));check(B.native_priority(s,k)==nil)
  check(row(s,k).control==((k=='blindness' or k=='deafness') and 'class' or 'observed') and not row(s,k).available and not row(s,k).required)
  check(not B.toggle(s,k,true))
 end
 for _,k in ipairs({'blindness','deafness'})do
  check(row(s,k).owner=='CURATIVE' and row(s,k).wanted==false)
  check(row(s,k).availability:match('fresh sensory'))
  s.buffs.wanted[k]=true -- malicious/stale saved intent cannot add an executor
 end
 B.master(s,true);for i=1,8 do clock=clock+20;tick()end
 check(#sent==0 and not s.buffs.pending and not s.buffs.fault,'self-affliction attempted')
 check(#B.curative_catalog==17 and B.curative_policy_seed==nil,'official and intentional catalogs')
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
-- Official curative index is coverage metadata, not manufacturing permission.
for _,class in ipairs({'Monk','Archivist'}) do
 local s=fresh();B.set_class(s,class);B.sync(s,'List',{})
 local count,herbal,apo,seen=0,0,0,{}
 for _,e in ipairs(B.curative_catalog) do
  count=count+1;check(not seen[e.key] and row(s,e.key),'curative missing/duplicate '..e.key);seen[e.key]=true
  check(not e.command and e.class=='shared','curative sender/class restriction')
  if e.source=='Herbalism' then herbal=herbal+1 else apo=apo+1 end
  check(row(s,e.key).owner==e.owner,'curative owner '..e.key)
 end
 check(count==17 and herbal==11 and apo==6)
 check(not B.set_group_known(s,'herbalism',{'Somnium'}),'manufacturing became consumption capability')
 B.text(s,'Your mind is filled with distant thoughts.');check(row(s,'daydream').active)
 B.text(s,'Your mind focuses back on the tasks at hand.');check(row(s,'daydream').active==false)
 check(row(s,'daydream').owner=='CURATIVE MANUAL' and row(s,'daydream').control=='observed')
 check(not B.toggle(s,'daydream',true) and not B.toggle(s,'daydream',false))
 B.text(s,'Your resistance to damage by poison has been increased.')
 check(row(s,'antivenin').active and not row(s,'venom_resistance').active and not B.availability(s,'antivenin'))
end
local function context(s)
 return {class=s.buffs.class,epoch=s.buffs.sensory_epoch or 0,observed_at=clock,herb='1',priorities={blindness=26,deafness=26},stocks={amaurosis=2,ototoxin=2},eating_allowed=true,curing_clear=true,barriers_clear=true}
end
local function arm(s,k)
 check(B.set_sensory_context(s,context(s)));check(B.select_sensory(s,k,true));check(not s.buffs.master);check(B.master(s,true))
end
for _,class in ipairs({'Monk','Archivist'}) do
 for _,goal in ipairs({'blindness','deafness'}) do
  local s,sent,tick=fresh();B.set_class(s,class);B.sync(s,'List',{});B.vitals(s,{herb=1,blind=0,deaf=0})
  arm(s,goal);tick();local pill=goal=='blindness' and 'amaurosis' or 'ototoxin'
  check(#sent==2 and sent[1]=='outc '..pill and sent[2]=='eat '..pill,'independent recipe')
  check(not row(s,goal).active,'send manufactured sensory status');local p=s.buffs.pending
  tick();check(#sent==2 and s.buffs.pending==p)
  B.on_prompt(s);B.vitals(s,{[goal=='blindness' and 'blind' or 'deaf']=1});tick();check(s.buffs.pending==p,'pre-confirm prompt released')
  B.on_prompt(s);tick();check(s.buffs.pending==p,'cached herb ready released')
  B.vitals(s,{herb=0});B.on_prompt(s);tick();check(s.buffs.pending==p)
  B.vitals(s,{herb=1});tick();check(s.buffs.pending==p,'recovery without prompt released')
  B.on_prompt(s);tick();check(not s.buffs.pending and #sent==2)
  B.sync(s,'List',{});check(row(s,goal).active,'DEF absence erased positive')
  check(B.select_sensory(s,goal,false));tick();check(#sent==2,'OFF sent cure/policy')
 end
end
-- Tracked metadata never aliases a mutable parent table and never converts
-- the actual historical stock timestamp into the fresh herb/context time.
local function tracked_context(s)
 local c=context(s);c.stock_evidence={}
 for _,pill in ipairs({'amaurosis','ototoxin'})do
  c.stock_evidence[pill]={mode='tracked_ic_v1',tracked=true,count=2,source='ic',observed_at=clock-7200,version=7,owner_id='fixture-owner',session=1}
 end
 return c
end
do
 local s,sent,tick=fresh();local c=tracked_context(s)
 check(B.set_sensory_context(s,c));local proof=s.buffs.sensory_context
 check(proof.stock_evidence~=c.stock_evidence and proof.stock_evidence.amaurosis~=c.stock_evidence.amaurosis,'tracked proof retained mutable parent')
 for k in pairs(c.stock_evidence.amaurosis)do c.stock_evidence.amaurosis[k]=nil end
 c.stocks.amaurosis=0;c.priorities.blindness=1
 check(proof.stock_evidence.amaurosis.observed_at==clock-7200 and proof.stock_evidence.amaurosis.version==7 and B.select_sensory(s,'blindness',true),'tracked copied evidence mutated')
 B.master(s,true);tick();check(#sent==2 and sent[2]=='eat amaurosis','tracked standalone contract could not dispatch')
end
-- Shared zero facts are valid evidence, not permission for the depleted goal.
for _,tracked in ipairs({false,true})do
 for _,counts in ipairs({{0,10},{10,0},{0,0}})do
  local s,sent,tick=fresh();local c=tracked and tracked_context(s)or context(s)
  for i,pill in ipairs({'amaurosis','ototoxin'})do
   c.stocks[pill]=counts[i];if tracked then c.stock_evidence[pill].count=counts[i]end
  end
  check(B.set_sensory_context(s,c),'authoritative zero rejected shared context')
  for i,goal in ipairs({'blindness','deafness'})do
   local funded=counts[i]>0
   check(B.sensory_ready(s,goal)==funded,'cross-goal stock readiness')
   check(B.select_sensory(s,goal,true)==funded,'cross-goal stock selection')
   if not funded then s.buffs.wanted[goal]=true;s.buffs.sensory_optin[goal]=true end
  end
  B.master(s,true);tick();tick()
  local pill=counts[1]>0 and 'amaurosis'or 'ototoxin'
  check(#sent==(counts[1]+counts[2]>0 and 2 or 0),'zero goal dispatched or funded goal starved')
  if #sent>0 then check(sent[1]=='outc '..pill and sent[2]=='eat '..pill,'asymmetric recipe')end
 end
end
for _,mutate in ipairs({
 function(c)c.stock_evidence=true end,
 function(c)c.stock_evidence.amaurosis=nil end,
 function(c)c.stock_evidence.amaurosis.mode='carried' end,
 function(c)c.stock_evidence.amaurosis.tracked='true' end,
 function(c)c.stock_evidence.amaurosis.count=3 end,
 function(c)c.stock_evidence.amaurosis.observed_at=clock+1 end,
 function(c)c.stock_evidence.amaurosis.observed_at=-math.huge end,
 function(c)c.stock_evidence.amaurosis.version=0 end,
 function(c)c.stock_evidence.amaurosis.version=0/0 end,
 function(c)c.stock_evidence.amaurosis.owner_id={} end,
 function(c)c.stock_evidence.amaurosis.owner_id='different' end,
 function(c)c.stock_evidence.amaurosis.session=2 end,
 function(c)c.stock_evidence.amaurosis.source='cached GMCP' end,
 function(c)c.observed_at=clock-6 end
})do
 local s,sent,tick=fresh();local c=tracked_context(s);mutate(c)
 check(not B.set_sensory_context(s,c) and not s.buffs.sensory_context,'invalid tracked schema accepted')
 tick();check(#sent==0,'invalid tracked schema dispatched')
end
-- Short-lived copied evidence; no truthiness, manufacture, stale or injected intent.
for _,mutate in ipairs({
 function(s,c)c.priorities.blindness=nil end,function(s,c)c.priorities.blindness=3 end,
 function(s,c)c.priorities.blindness='26' end,function(s,c)c.stocks.amaurosis=0 end,
 function(s,c)c.stocks.amaurosis=nil end,function(s,c)c.stocks.amaurosis=-1 end,
 function(s,c)c.herb='0' end,function(s,c)c.eating_allowed=false end,
 function(s,c)c.curing_clear=false end,function(s,c)c.barriers_clear=false end,
 function(s,c)c.observed_at=clock-6 end,function(s,c)c.class='archivist' end,
 function(s,c)c.epoch=c.epoch+1 end,function(s,c)s.player.afflictions.anorexia=true end,
 function(s,c)s.player.afflictions.poison=true end,function(s,c)s.player.afflictions.stupidity=true end,
 function(s,c)s.mental={eq_pending={}} end,function(s,c)s.walker={pending={}} end
}) do
 local s,sent,tick=fresh();arm(s,'blindness');local c=context(s);mutate(s,c);B.set_sensory_context(s,c)
 check(not B.sensory_ready(s,'blindness'),'invalid proof was accepted independently of opt-in')
 check(s.buffs.sensory_optin.blindness,'proof matrix lost the independent opt-in precondition')
 tick();check(#sent==0,'revoked proof sent after valid opt-in')
end
for _,scenario in ipairs({'master','herb','stale','class','invalidate','runner','hold','copy','policy'})do
 local s,sent,tick=fresh();arm(s,'blindness')
 if scenario=='master' then B.master(s,false)
 elseif scenario=='herb' then B.vitals(s,{herb=0})
 elseif scenario=='stale' then clock=clock+6
 elseif scenario=='class' then B.set_class(s,'Archivist');B.master(s,true)
 elseif scenario=='invalidate' then B.invalidate(s);B.master(s,true)
 elseif scenario=='copy' then local c=context(s);c.priorities.blindness=3;B.set_sensory_context(s,c);c.priorities.blindness=26
 elseif scenario=='policy' then B.set_sensory_context(s,nil)
 end
 if scenario=='runner' then B.service(s,{waiting=true},function(c)sent[#sent+1]=c end)
 elseif scenario=='hold' then B.service(s,{},function(c)sent[#sent+1]=c end,true)
 else tick()end
 check(#sent==0,'unsafe gate '..scenario)
end
-- Every sender outcome preserves the committed barrier; first failure skips EAT.
for _,failAt in ipairs({1,2})do for _,throws in ipairs({false,true})do
 local s,sent=fresh();arm(s,'blindness')
 -- local recursive function binding is explicit for Lua5.1.
 local f;f=function(cmd)
  sent[#sent+1]=cmd;check(B.service(s,{},f).busy)
  if #sent==failAt then if throws then error('synthetic transport')else return false end end
 end
 check(B.service(s,{},f).busy);local p=s.buffs.pending;check(p and p.send_failed and #sent==failAt)
 B.vitals(s,{blind=1,herb=0});B.vitals(s,{herb=1});B.on_prompt(s)
 B.stop(s);clock=clock+20;check(B.service(s,{},f).busy and s.buffs.pending==p and #sent==failAt)
end end
-- Both selected goals serialize, requiring new stock proof after first consumption.
do
 local s,sent,tick=fresh();arm(s,'blindness');check(B.select_sensory(s,'deafness',true));tick();local p=s.buffs.pending
 B.vitals(s,{blind=1});B.on_prompt(s);tick();check(#sent==2 and s.buffs.pending==p)
 B.vitals(s,{herb=0});B.vitals(s,{herb=1});B.on_prompt(s);tick();tick();check(#sent==2)
 check(B.set_sensory_context(s,context(s)));tick();check(#sent==4 and sent[3]=='outc ototoxin' and sent[4]=='eat ototoxin')
end
-- Synchronous full recovery cannot let either nested call escape dispatch.
do
 local s,sent=fresh();arm(s,'blindness');local f
 f=function(c)
  sent[#sent+1]=c
  if c=='eat amaurosis' then B.vitals(s,{blind=1,herb=0});B.vitals(s,{herb=1});B.on_prompt(s)end
  check(B.service(s,{},f).busy)
 end
 B.service(s,{},f);check(#sent==2 and s.buffs.pending);B.service(s,{},f);check(not s.buffs.pending and #sent==2)
end
for _,flag in ipairs({true,1,'1'})do
 local s=fresh();B.vitals(s,{blind=flag,deaf=flag});B.sync(s,'List',{});check(row(s,'blindness').active and row(s,'deafness').active)
end
-- Independent policies: proof for deafness never permits blindness.
do
 local s,sent,tick=fresh();local c=context(s);c.priorities.blindness=3
 check(B.set_sensory_context(s,c));check(not B.select_sensory(s,'blindness',true));check(B.select_sensory(s,'deafness',true));B.master(s,true);tick()
 check(sent[1]=='outc ototoxin' and #sent==2)
end
-- Adversarial callbacks between prepare/eat revoke permission without eating.
for _,reason in ipairs({'off','stop','hold','class','policy','stock','herb','flag','runner','mental','walker','affliction','health','mana'})do
 local s,sent=fresh();arm(s,'blindness');local runner={};local f
 f=function(c)
  sent[#sent+1]=c
  if c=='outc amaurosis' then
   if reason=='off' then B.select_sensory(s,'blindness',false)
   elseif reason=='stop' then B.stop(s)
   elseif reason=='hold' then B.set_sensory_context(s,nil)
   elseif reason=='class' then B.set_class(s,'Archivist')
   elseif reason=='policy' then local ctx=context(s);ctx.priorities.blindness=3;B.set_sensory_context(s,ctx)
   elseif reason=='stock' then local ctx=context(s);ctx.stocks.amaurosis=0;B.set_sensory_context(s,ctx)
   elseif reason=='herb' then B.vitals(s,{herb=0})
   elseif reason=='flag' then B.vitals(s,{blind=1})
   elseif reason=='runner' then runner.waiting=true
   elseif reason=='mental' then s.mental={eq_pending={}}
   elseif reason=='walker' then s.walker={pending={}}
   elseif reason=='affliction' then s.player.afflictions.anorexia=true
   elseif reason=='health' then s.player.hp=1
   elseif reason=='mana' then s.player.mana=1 end
   check(B.service(s,runner,f).busy)
  end
 end
 check(B.service(s,runner,f).busy);check(#sent==1 and s.buffs.pending and s.buffs.pending.send_failed,'intervening '..reason..' ate anyway')
end
-- Unknown status and expired policy cannot be upgraded by view/audit/reload.
for _,bad in ipairs({'unknown',2,''})do
 local s,sent,tick=fresh();arm(s,'blindness');B.vitals(s,{blind=bad});tick();check(#sent==0 and not s.buffs.sensory_context,'malformed sensory flag retained proof')
end
do
 local s,sent,tick=fresh();arm(s,'blindness');B.vitals(s,{blind=1});B.set_sensory_context(s,nil)
 check(row(s,'blindness').active);B.rows(s);B.audit_groups('Monk');dofile(root..'buffs.lua');tick();check(#sent==0)
 B.vitals(s,{blind=0});tick();check(#sent==0)
end
-- Newer loss after confirmation revokes settlement, not just the visible row.
do
 local s,sent,tick=fresh();arm(s,'blindness');tick();local p=s.buffs.pending
 B.vitals(s,{blind=1,herb=0});B.vitals(s,{herb=1});B.on_prompt(s);B.vitals(s,{blind=0});tick()
 check(s.buffs.pending==p and #sent==2,'newer loss did not revoke confirmation')
 clock=clock+20;tick();check(s.buffs.pending==p and #sent==2,'timeout retried')
end
-- Every later loss/unknown herb cycle requires new recovery AND a later prompt.
for _,h in ipairs({0,'unknown'})do
 local s,sent,tick=fresh();arm(s,'blindness');tick();local p=s.buffs.pending
 B.vitals(s,{blind=1,herb=0});B.vitals(s,{herb=1});B.on_prompt(s)
 B.vitals(s,{herb=h});tick();check(s.buffs.pending==p,'later herb uncertainty settled')
 B.vitals(s,{herb=0});B.vitals(s,{herb=1});tick();check(s.buffs.pending==p,'old ready prompt crossed a new herb cycle')
 B.on_prompt(s);tick();check(not s.buffs.pending and #sent==2,'fresh recovered prompt did not settle')
end
print('PASS legacy sensory algorithm fixture '..n..' assertions: native12, opt-in sensory transactions, resource/policy barriers, retained failed transport, one-time Mindseye, native curing untouched')
