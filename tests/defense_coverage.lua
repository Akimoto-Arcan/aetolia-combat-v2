-- Source-backed defense coverage. Pure fake state, sender and synthetic ink counts.
local root=assert(arg[1]);local B=dofile(root..'buffs.lua');local State=dofile(root..'state.lua')
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'fixture',0,true end
local n=0
local function check(v,msg)n=n+1;assert(v,msg or ('assertion '..n))end
local function fresh()
 local s=State.new();s.connected=true;B.set_class(s,'Monk');local p=s.player
 p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100;p.willpower=100;p.maxwillpower=100
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 local names={};for _,e in ipairs(B.catalog)do names[#names+1]=e.key end
 for _,g in ipairs({'kaido','telepathy','survival','vision','avoidance'})do B.set_group_known(s,g,names)end
 B.sync(s,'List',{});return s
end
local function row(s,k)for _,r in ipairs(B.rows(s))do if r.key==k then return r end end end
local function ink(s)
 B.text(s,'You have the following tattoos:')
 B.text(s,'Left arm:    Cloak        Uses left: 2')
 B.text(s,'Right leg:   Mindseye     Uses left: 2')
 for _,name in ipairs({'Boar','Moon','Moss','Owl','Mountain'})do B.text(s,'Head:        '..name..'         Active')end
 B.on_prompt(s)
end
local native=0;for _ in pairs(B.native_catalog)do native=native+1 end;check(native==12)
-- Every executable entry requires its own capability, canonical exact own evidence,
-- true post-dispatch prompt, and no duplicate send. Native courage has no client owner.
for _,e in ipairs(B.catalog)do
 local s=fresh();ink(s);local sent={};local function tick()return B.service(s,{},function(c)sent[#sent+1]=c end)end
 for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=k==e.key end
 check(not s.buffs.master and not s.buffs.sequence,'startup armed '..e.key)
 check(tick().busy==false and #sent==0,'startup sent '..e.key)
 if e.drain then check(e.default==false,'drain armed by default '..e.key)end
 if e.command and not B.native_catalog[e.key] then
  if e.depends then B.sync(s,'Add',e.depends)end
  if e.key=='immunity' then clock=clock+121 end -- unknown prior cooldown fence
  check(B.start(s));tick();check(sent[1]==e.command,'wrong owner/command '..e.key)
  tick();check(#sent==1,'duplicate '..e.key)
  B.text(s,'Reporter says, "You have gained the '..e.key..' defence."')
  check(not s.buffs.pending.confirmed,'speech accepted '..e.key)
  local id=e.ids and e.ids[1] or e.key
  B.text(s,'You have gained the '..id..' defence.')
  check(row(s,e.key).active==true,'canonical up '..e.key)
  check(s.buffs.pending~=nil,'gain invented recovery '..e.key)
  B.on_prompt(s);tick();check(s.buffs.pending==nil,'post-ack prompt did not settle '..e.key)
  B.text(s,'Your '..id..' defence has been stripped.')
  check(row(s,e.key).active==false,'canonical down '..e.key)
 else
  B.start(s);tick();check(#sent==0,'passive/native cast '..e.key)
 end
end
-- Every unavailable executable capability is skipped even if a saved wanted flag is true.
for _,e in ipairs(B.catalog)do
 if e.command and not B.native_catalog[e.key] then
  local s=fresh();for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=k==e.key end
  if e.tattoo then B.text(s,'You have the following tattoos:');B.on_prompt(s)
  else B.set_group_known(s,e.group,{});if e.also_group then B.set_group_known(s,e.also_group,{})end end
  local sent={};B.start(s);B.service(s,{},function(c)sent[#sent+1]=c end)
  check(#sent==0 and not s.buffs.pending,'unowned sender '..e.key)
  check(not B.toggle(s,e.key,true),'unowned toggle '..e.key)
 end
end
-- Kaido cannot infer Vision, Telepathy, Survival, Avoidance, or ink ownership.
do
 local s=fresh();B.invalidate(s);B.set_groups(s,{{name='Kaido',rank='Transcendent'}})
 check(s.buffs.known.immunity and s.buffs.known.toughness)
 for _,k in ipairs({'nightsight','insight','mindcloak','clarity','thirdeye','dodgemelee','cloak','mindseye','fitness','kai_recursion','numbness'})do check(not s.buffs.known[k],k..' inferred from Kaido')end
 B.set_groups(s,{{name='Kaido',rank='Inept'},{name='Vision',rank='Transcendent'},{name='Tattoos',rank='Transcendent'}})
 check(not s.buffs.known.immunity and s.buffs.known.nightsight)
 check(not s.buffs.known.cloak and not s.buffs.known.mindseye)
 B.set_group_known(s,'vision',{});B.set_groups(s,{{name='Vision',rank='Transcendent'}})
 check(not s.buffs.known.nightsight,'rank overrode precise empty List')
 B.set_group_known(s,'telepathy',{'Cloak','Insight'});check(s.buffs.known.mindcloak and s.buffs.known.insight and not s.buffs.known.cloak)
 B.set_groups(s,{{name='Telepathy',rank='Inept'},{name='Vision',rank='Transcendent'}})
 check(not s.buffs.known.mindcloak and not s.buffs.known.insight,'fresh lower group retained old precise capability')
 check(not s.buffs.known.nightsight,'fresh group overrode restrictive precise Vision List')
 check(not B.toggle(s,'immunity',true),'not learned control armed')
end
-- Exact own additions and removal aliases from the reviewed source.
do
 local s=fresh()
 local cases={
  {'immunity','Your blood is steeled against poisons.','Your blood boils as it throws off the effects of the venom rushing through your veins.'},
  {'mindcloak','You will now begin to concentrate on cloaking your telepathy.','You allow the mindcloak to drop.'},
  {'clarity','Your mind is filled with clarity.','Your clarity of mind has been corrupted.'},
  {'selfishness','You rub your hands together greedily.','A feeling of generosity spreads throughout you.'},
  {'alertness','You prick up your ears.','You cease your watchful alertness.'},
  {'telesense','You attune your mind to tampering from telepathy.','You cease to concentrate your mind on mindlock attempts.'},
  {'hypersight','You are utilising hypersight.','You cease to concentrate on hypersight.'}
 }
 for _,c in ipairs(cases)do B.text(s,c[2]);check(row(s,c[1]).active==true);B.text(s,c[3]);check(row(s,c[1]).active==false)end
 B.sync(s,'Add','kaido_immunity');check(row(s,'immunity').active==true);B.sync(s,'Remove','kai_immunity');check(row(s,'immunity').active==false)
end
-- Immunity cooldown begins at dispatch, not loss; repeated lists cannot extend it.
do
 clock=100;local s=fresh();clock=221;local sent={};for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=k=='immunity'end
 B.master(s,true);local function tick()return B.service(s,{},function(c)sent[#sent+1]=c end)end
 tick();check(sent[1]=='immunity');clock=223;B.sync(s,'Add','kaido_immunity');B.on_prompt(s);tick()
 check(s.buffs.cooldown.immunity==341,'ACK moved activation clock')
 clock=300;B.sync(s,'List',{'kaido_immunity'});check(s.buffs.cooldown.immunity==341,'List extended cooldown')
 B.text(s,'Your blood boils as it throws off the effects of the venom rushing through your veins.');tick();check(#sent==1)
 clock=340;tick();check(#sent==1);clock=342;tick();check(#sent==2)
 -- Generic text cannot identify which controller's command was rejected.
 B.text(s,'You must regain balance first.');check(s.buffs.pending and not s.buffs.fault and s.buffs.cooldown.immunity==462,'unattributed rejection erased committed action/cooldown')
 tick();check(#sent==2,'rejection immediate retry')
end
-- Fresh event provenance, zero/string encodings and newer strips defeat cached flags.
do
 local s=fresh();B.vitals(s,{blind='1',deaf=1});check(row(s,'blindness').active and row(s,'deafness').active)
 B.sync(s,'List',{});check(row(s,'blindness').active and row(s,'deafness').active,'List erased fresh Vitals positives')
 B.text(s,'Your blind defence has been stripped.');check(row(s,'blindness').active==false)
 B.sync(s,'List',{});check(row(s,'blindness').active==false,'old flags resurrected strip')
 B.vitals(s,{blind='0',deaf=0});check(row(s,'blindness').active==false and row(s,'deafness').active==false)
 B.affliction_flags(s,'Add',{name='blind'});check(row(s,'blindness').active==true)
 B.affliction_flags(s,'Remove',{'blind'});check(row(s,'blindness').active==false)
 B.affliction_flags(s,'List',{'blind'});B.sync(s,'List',{});check(row(s,'blindness').active==true,'DefList erased independent fresh Afflictions positive')
 check(s.buffs.flag_sources.blindness=='afflictions')
 B.affliction_flags(s,'List',{});check(row(s,'blindness').active==false,'new empty Afflictions List replayed old positive')
 B.vitals(s,{blind=1});B.affliction_flags(s,'List',{});check(row(s,'blindness').active==true,'Afflictions absence erased independent Vitals positive')
 B.text(s,'Your blind defence has been stripped.');B.sync(s,'List',{});check(row(s,'blindness').active==false)
 local unknown=fresh();unknown.buffs.defs_known=false;B.vitals(unknown,{blind=0,deaf='0'})
 check(row(unknown,'blindness').active==false and row(unknown,'deafness').active==false,'fresh zero required unrelated full DefList')
end
-- Catalog-version fencing preserves unresolved request and restoration memory.
do
 local s=fresh();local b=s.buffs;b.native_schema=17;b.native_priorities={speed=3};b.native_last_active={speed=3};b.native_pending={speed=26}
 B.state(s);check(b.native_pending.speed==26 and B.native_enable_priority(s,'speed')==3 and B.native_priority(s,'speed')==nil)
 B.text(s,"You have set the 'courage' defence to the 3 priority.");check(B.native_priority(s,'courage')==nil,'ACK bypassed expanded-catalog readback')
 B.text(s,'Your defense priorities:');for i=1,24 do B.text(s,i..':')end;B.text(s,'Defs with priority 26 are ignored.');check(B.native_priority(s,'blindness')==nil)
 B.text(s,'Your defense priorities:');for i=1,25 do B.text(s,i..': '..(i==2 and 'blindness, deafness, insulation, temperance, venom_resistance' or ''))end;B.text(s,'Defs with priority 26 are ignored.')
 for _,k in ipairs({'blindness','deafness','insulation','temperance','venom_resistance'})do check(B.native_priority(s,k)==nil and not B.native_catalog[k] and not row(s,k).required)end
 check(B.native_priority(s,'speed')==26)
end
-- Tattoo ink is fresh report capability, never rank, saved preference or active intent.
do
 local s=fresh();check(not B.availability(s,'cloak'));ink(s);check(B.availability(s,'cloak') and B.availability(s,'mindseye'))
 B.sync(s,'List',{});for _,k in ipairs({'boar','moon','moss','owl','mountain'})do check(row(s,k).active and row(s,k).availability=='PASSIVE')end
 check(not B.toggle(s,'shielded',true) and not B.toggle(s,'starburst',true))
 check(row(s,'recognition').passive and not B.toggle(s,'recognition',true))
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Cloak Uses left: 0');B.on_prompt(s)
 check(not B.availability(s,'cloak') and not B.availability(s,'mindseye'),'new report failed to revoke ink')
 ink(s);B.set_class(s,'Shaman');check(not B.availability(s,'cloak') and next(s.buffs.tattoos)==nil)
end
-- Conservative Clarity gate: no activation while any unresolved affliction exists.
do
 local s=fresh();for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=k=='clarity'end
 s.player.afflictions.dementia=true;B.start(s);local sent={};B.service(s,{},function(c)sent[#sent+1]=c end)
 check(#sent==0 and not s.buffs.pending)
 s.player.afflictions={};B.start(s);B.service(s,{},function(c)sent[#sent+1]=c end);check(sent[1]=='clarity')
end
print('PASS defense coverage '..n..' assertions: all catalog owners, canonical own evidence, group/ink revocation, activation cooldown/rejection, native migration, fresh blind/deaf provenance, passive/hazard gates')
