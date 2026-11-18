-- Synthetic replay/integration fixtures. No live sender or game connection.
local root=assert(arg[1]);local now=100;function getEpoch()return now end
local sent={};function send(cmd)sent[#sent+1]=cmd end
local S=dofile(root..'state.lua');local T=dofile(root..'tracker.lua');local B=dofile(root..'bashing.lua');B.bind(S)
local K=dofile(root..'monk.lua');K.bind(T);local R=dofile(root..'runner.lua');local E=dofile(root..'events.lua');E.bind(T)
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local function fresh(mode)
 now=now+1;local s=S.new();S.set_target(s,'dummy');S.sync_gmcp(s,{Char={Vitals={hp='100',maxhp='100',balance='1',equilibrium='1',left_arm='1',right_arm='1'}}});s.mode=mode or 'FULL_AUTO'
 local r=R.new(s,K);r.mode=s.mode;return s,r
end
local function observe(s,kind,extra)
 local e={kind=kind,target=s.target.name,source='test fixture',confidence=1};for k,v in pairs(extra or {})do e[k]=v end;return T.apply(s,e)
end
local s,r=fresh('BASH')
check(K.choose(s).command=='combo dummy scs spp spp','bashing must enter scorpion with two spear punches')
E.event(s,'You sink back into the menacing stance of the Scorpion.')
check(K.choose(s).command=='combo dummy sdk spp spp','confirmed scorpion should use regular bashing combo')
s.player.stance='tiger';check(K.choose(s).command=='combo dummy scs spp spp','non-scorpion stance not corrected')
check(not observe(s,'damage',{limb='left_leg',amount=10}) and s.target.limbs.left_leg==0,'bashing must not invent PvP trauma')
s,r=fresh();check(observe(s,'damage',{limb='ll',amount=12.5}),'damage rejected');check(s.target.limbs.left_leg==12.5,'damage amount wrong')
check(not s.target.broken.left_leg,'numeric trauma inferred broken state')
check(observe(s,'broken',{limb='ll',value=true}) and s.target.broken.left_leg,'observed broken not stored')
check(observe(s,'broken',{limb='ll',value=false}) and not s.target.broken.left_leg,'cure did not clear marker')
check(not T.apply(s,{kind='damage',target='other',limb='ll',amount=10}),'other actor contaminated target')
check(not T.apply(s,{kind='damage',target='dummy',limb='ll',amount=10,generation=999}),'old target generation accepted')
check(not observe(s,'damage',{limb='bad',amount=10}),'invalid limb accepted')
check(not observe(s,'damage',{limb='ll',amount=-10}),'negative damage accepted')
check(not observe(s,'limb',{limb='ll',amount=101}),'over 100 trauma accepted')
check(observe(s,'affliction',{name='paralysis',value=true}) and s.target.afflictions.paralysis,'enemy affliction not stored')
check(observe(s,'affliction',{name='paralysis',value=false}) and not s.target.afflictions.paralysis,'enemy cure not removed')
check(not observe(s,'affliction',{name='foo;quit',value=true}),'unsafe affliction accepted')
check(s.target.evidence['aff:paralysis'].source=='test fixture','missing evidence source')
s,r=fresh();check(K.choose(s).command=='combo dummy snk left hfp left hfp left','leg route wrong')
s.config.route='arms';check(K.choose(s).command=='combo dummy mnk left spp left spp left','arm route wrong')
s.config.route='head';check(K.choose(s).command=='combo dummy wwk ucp ucp','head route wrong')
s.config.route='torso';check(K.choose(s).command=='combo dummy sdk hkp hkp','torso route wrong')
s.config.route='legs';observe(s,'parry',{limb='left_leg'});check(K.choose(s).limb=='right_leg','parry not excluded')
now=now+9;check(K.choose(s).limb=='left_leg','expired parry remained certain')
observe(s,'parry',{limb='left_leg',confidence=.2});check(K.choose(s).limb=='left_leg','uncertain parry excluded limb')
observe(s,'parry',{limb='none'});check(s.target.parry_limb==nil,'parry clear failed')
s,r=fresh();observe(s,'mangled',{limb='head',value=true});observe(s,'prone',{value=true});check(K.choose(s).command=='axk dummy','axe predicate')
s,r=fresh();observe(s,'crippled',{limb='right_arm',value=true});observe(s,'prone',{value=true});check(K.choose(s).command=='bbt dummy','backbreaker must accept crippled arm too')
s,r=fresh();observe(s,'broken',{limb='left_arm',value=true});observe(s,'broken',{limb='right_arm',value=true});check(K.choose(s).command=='tnk dummy','thunderkick predicate')
s,r=fresh();observe(s,'broken',{limb='left_leg',value=true});check(K.choose(s).command=='swk dummy','sweep setup')
s,r=fresh();observe(s,'shield',{value=true});check(K.choose(s).command=='sck dummy','shield breaker')
s.player.left_arm_balance=false;s.player.right_arm_balance=false;check(R.tick(r),'kick blocked by unrelated arm balances')
s,r=fresh();observe(s,'rebounding',{value=true});check(K.choose(s).command=='','rebounding not respected')
s,r=fresh();for _,limb in ipairs({'left_arm','right_arm','left_leg','right_leg','torso','head'})do s.target.mangled[limb]=true end
check(K.choose(s).command=='','all limbs invalid should wait')
s,r=fresh('BASH');s.player.hp=20;check(not R.tick(r) and r.paused_health,'low HP pause missing')
s.player.hp=45;check(not R.tick(r),'health hysteresis missing');s.player.hp=65;check(R.tick(r),'health recovery did not resume')
s,r=fresh('BASH');s.player.prone=true;check(not R.tick(r),'prone player attacked')
s,r=fresh('BASH');s.player.afflictions.paralysis=true;check(not R.tick(r),'paralysed player attacked')
s,r=fresh('BASH');now=now+120;check(not R.watchdog(r) and r.mode=='BASH','idle GMCP was treated as a disconnected session')
check(R.tick(r),'quiet but connected session could not execute after idle')
s,r=fresh('BASH');now=now+120;s.connected=false;check(not R.tick(r) and r.mode=='OFF','idle-vitals fix allowed disconnected execution')
s,r=fresh('BASH');getConnectionInfo=function()return 'fixture',0,false end
check(not R.tick(r) and r.mode=='OFF','closed TCP transport allowed execution');getConnectionInfo=nil
s,r=fresh('BASH');check(R.tick(r),'initial send failed');local before=#sent;now=now+9;check(R.watchdog(r) and r.mode=='OFF' and #sent==before,'watchdog retried/spammed')
s,r=fresh('ASSIST');check(not R.tick(r) and r.pending,'assist not pending');S.set_target(s,'another');check(not R.approve(r),'old target approval accepted')
s,r=fresh('ASSIST');R.tick(r);observe(s,'shield',{value=true});check(not R.approve(r),'changed defence stale approval accepted')
s,r=fresh('BASH');r.sender=function()error('fake error')end;check(not R.tick(r) and r.mode=='OFF' and not r.waiting,'sender error left runner live')
s,r=fresh('BASH');B.add(s,'second');B.add(s,'third');check(not B.add(s,'second'),'duplicate queue accepted');check(not B.add(s,'x;quit'),'unsafe queue accepted');B.start(s);R.tick(r)
E.event(s,'You have slain dummy.');check(s.stop_reason=='target slain','selected kill unrecognised');s.stop_reason=nil;check(B.killed(s) and s.target.name=='second' and s.hunting.kills==1,'queue did not advance')
E.event(s,'You have slain unrelated.');check(not s.stop_reason,'unrelated kill stopped target')
check(B.next(s) and s.target.name=='third','next queue target wrong');check(not B.next(s) and s.stop_reason=='hunting queue complete','queue exhaustion not stopped')
s,r=fresh('BASH');S.set_target(s,'123');B.items(s,{location='room',items={{id=123,name='a training dummy',attrib='m'}}});check(s.target.display_name=='a training dummy','mob display name not bound')
E.event(s,'You have slain a training dummy.');check(s.target.dead,'numeric target kill not linked to display name')
s,r=fresh('BASH');S.set_target(s,'123');B.item_removed(s,{location='room',item=123});check(s.stop_reason and not s.target.dead,'room removal must stop, not assume kill')
s,r=fresh();E.event(s,'You are prone.');check(s.player.prone and not s.target.prone,'self prone polluted enemy');E.event(s,'You kip up.');check(not s.player.prone,'self recovery ignored')
E.event(s,'You have been slain by Enemy.');check(s.player.dead and s.stop_reason=='player death','player death not stopped')
s,r=fresh();E.event(s,'Someone says, "You have died."');check(not s.player.dead,'chat falsely caused death')
-- Real bootstrap callbacks with fake Mudlet surfaces and transports.
combat_v2=nil;gmcp={};local handlers={};local aliases={};local timers={};local realdofile=dofile
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function registerAnonymousEventHandler(event,fn) handlers[event]=fn;return event end
function killAnonymousEventHandler(id) handlers[id]=nil end
function tempAlias(pattern,fn) aliases[#aliases+1]=fn;return #aliases end
function killAlias(id) aliases[id]=nil end
function tempRegexTrigger(pattern,fn)return 99 end
function killTrigger()end
function tempTimer(delay,fn)timers[#timers+1]=fn;return #timers end
function killTimer(id)timers[id]=nil end
dofile=function(p) if p:match('/gui.lua$') then return {create=function()end,refresh=function()end} end;return realdofile(p)end
before=#sent;realdofile(root..'bootstrap.lua');check(#sent==before,'bootstrap sent')
local function command(arg) matches={'cv2 '..arg,arg};aliases[combat_v2.alias]() end
local function emit(event) assert(handlers[event],'missing handler '..event)(event) end
check(not combat_v2_config('health_pause',80),'invalid threshold ordering accepted')
check(combat_v2_config('health_pause',35) and combat_v2.current.config.health_pause==35,'config not applied')
check(not combat_v2_config('ack_timeout',0),'invalid timeout accepted')
check(combat_v2_config('estimate_trauma','off') and not combat_v2.current.config.estimate_trauma,'estimator toggle off failed')
check(combat_v2_config('estimate_trauma','on') and combat_v2.current.config.estimate_trauma,'estimator toggle on failed')
check(not combat_v2_config('estimate_trauma','maybe'),'invalid estimator toggle accepted')
local invalid_state=fresh();check(not observe(invalid_state,'prone',{value='off'}),'invalid observation value accepted')
check(combat_v2_set_route('arms'),'route not accepted');check(not combat_v2_set_route('bogus'),'invalid route accepted')
command('queue add 123');command('queue add 456');check(#combat_v2.current.hunting.queue==2,'queue alias failed')
command('queue clear');check(#combat_v2.current.hunting.queue==0,'queue clear failed')
combat_v2_set_target('Enemy');command('track aff asthma on');check(combat_v2.current.target.afflictions.asthma,'manual aff alias failed')
command('track aff asthma off');check(not combat_v2.current.target.afflictions.asthma,'manual aff remove failed')
command('track limb ll 23');check(combat_v2.current.target.limbs.left_leg==23,'manual trauma alias failed')
command('track crippled ll on');command('track prone on');check(combat_v2_propose().command=='bbt Enemy','manual state does not reach selector')
gmcp={Char={Afflictions={List={{name='asthma'},'paralysis'}}}};emit('gmcp.Char.Afflictions.List');check(combat_v2.current.player.afflictions.asthma and combat_v2.current.player.afflictions.paralysis,'GMCP list broken')
gmcp.Char.Afflictions.Remove={name='asthma'};emit('gmcp.Char.Afflictions.Remove');check(not combat_v2.current.player.afflictions.asthma,'GMCP named remove broken')
gmcp.Char.Afflictions.Remove={'paralysis'};emit('gmcp.Char.Afflictions.Remove');check(not next(combat_v2.current.player.afflictions),'GMCP list remove broken')
gmcp.Char.Afflictions.Add={name='fallen'};emit('gmcp.Char.Afflictions.Add');check(combat_v2.current.player.prone,'self GMCP fallen did not set prone')
gmcp.Char.Afflictions.Remove='fallen';emit('gmcp.Char.Afflictions.Remove');check(not combat_v2.current.player.prone,'self GMCP cure left prone sticky')
gmcp.Char.Defences={Add={name='rebounding'}};emit('gmcp.Char.Defences.Add');check(combat_v2.current.player.defences.rebounding,'GMCP defence add broken')
handlers['combat_v2.observation']('', 'affliction','Wrong','asthma',true,1);check(not combat_v2.current.target.afflictions.asthma,'integration wrong-target pollution')
handlers['combat_v2.observation']('', 'affliction','Enemy','asthma',true,1);check(combat_v2.current.target.afflictions.asthma,'integration observation missing')
for i=1,110 do S.record(combat_v2.current,'fixture',i)end;check(#combat_v2.current.history==100,'trace unbounded')
command('trace 2');check(#sent==before,'tracking/config/trace sent commands')
combat_v2.current.mode='BASH';combat_v2.mode='BASH';combat_v2.runner.mode='BASH';combat_v2.current.room.id=1;gmcp.Room={Info={num=2}};emit('gmcp.Room.Info');check(combat_v2.mode=='OFF','room change did not stop bashing')
combat_v2.current.connected=true;emit('sysDisconnectionEvent');check(not combat_v2.current.connected and combat_v2.mode=='OFF','disconnect not stopped')
gmcp.Char.Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1};combat_v2.current.vitals_at=nil
realdofile(root..'bootstrap.lua');check(#sent==before and combat_v2.mode=='OFF','reload sent or retained auto')
check(not combat_v2.current.connected and combat_v2.current.vitals_at==nil,'reload promoted cached GMCP into live connection')
print('PASS backend '..count..' assertions: evidence, routes, syntax, parry expiry, finishers, health hysteresis, watchdog, queue, identity, GMCP, command integration and diagnostics')
