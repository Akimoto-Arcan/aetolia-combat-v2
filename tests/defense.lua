local root=assert(arg[1]);local clock=100;function getEpoch()return clock end
local S=dofile(root..'state.lua');local D=dofile(root..'defense.lua');local R=dofile(root..'runner.lua');local K=dofile(root..'monk.lua');local M=dofile(root..'mental.lua')
M.bind_defense(D);R.bind_defense(D.hold)
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local sent={};local function send(v)sent[#sent+1]=v end
local function fresh()
 local s=S.new();S.set_target(s,'Fixture');s.mode='FULL_AUTO';s.connected=true
 local p=s.player;p.hp=100;p.maxhp=100;p.mana=3000;p.maxmana=3000;p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 s.policy={players_known=true,players={fixture=true}};return s
end
local s=fresh();D.text(s,'[FirstAid]: unable to eat: paralysis');check(not next(s.player.afflictions),'blocked cure inferred the wrong affliction cause')
check(D.state(s).blocked.eat.aff=='paralysis','blocked channel not recorded')
D.text(s,'A runed target dummy says, "I was afflicted with anorexia."');check(not next(s.player.afflictions),'enemy proxy polluted own defense')
D.text(s,'Fixture is afflicted with asthma.');check(not next(s.player.afflictions),'third party polluted own defense')
for _,k in ipairs({'anorexia','asthma','slickness','paralysis'})do D.text(s,'You are afflicted with '..k..'.');D.service(s,send)end
check(D.hold(s),'confirmed cure-lock did not hold offense')
check(D.state(s).phase=='cure-lock + paralysis','critical phase missing')
check(#sent==4,'elevations duplicated or omitted')
for _,v in ipairs(sent)do check(v:match('^firstaid elevate %a+$'),'guessed cure or unvalidated action sent')end
D.service(s,send);check(#sent==4,'same affliction episode spammed elevation')
D.text(s,'[FirstAid]: tree locked');check(D.state(s).blocked.tree.aff=='locked','tree unavailability not recorded')
D.text(s,'You have cured paralysis.');check(D.hold(s),'curing paralysis falsely cleared three-way lock')
D.text(s,'You have cured slickness.');check(not D.hold(s),'confirmed lock break failed to release hold')
D.text(s,'You are afflicted with slickness.');D.service(s,send);check(#sent==5,'new affliction episode did not re-arm elevation')
D.text(s,'You have discovered epilepsy.');check(s.player.afflictions.epilepsy,'discovered own hidden affliction not tracked')
D.text(s,'You are afflicted with lameness.');D.text(s,'Your lameness has transformed into sundering.');check(not s.player.afflictions.lameness and s.player.afflictions.sundering,'affliction transformation not reconciled')
check(not next(s.target.afflictions),'self observations polluted enemy state')
s=fresh();s.player.hp=40;check(D.hold(s),'45% survival threshold missing');s.player.hp=55;check(D.hold(s),'hysteresis resumed too early');s.player.hp=65;check(not D.hold(s),'65% survival recovery did not release')
s.player.prone=true;check(D.hold(s),'posture recovery not prioritized');s.player.prone=false;check(not D.hold(s),'posture recovery did not release')
for _,mode in ipairs({'OFF','SHADOW','ASSIST'})do s=fresh();s.mode=mode;s.player.afflictions.asthma=true;local n=#sent;D.service(s,send);check(#sent==n,mode..' auto-sent defense commands')end
s=fresh();s.connected=false;s.player.afflictions.asthma=true;local n=#sent;D.service(s,send);check(#sent==n,'disconnected defensive send')
s.connected=true;getConnectionInfo=function()return 'aetolia.com',23,false end;D.service(s,send);check(#sent==n,'closed TCP defensive send');getConnectionInfo=nil
s=fresh();s.training_battle_ended=true;s.player.afflictions.asthma=true;n=#sent;D.service(s,send);check(#sent==n,'training-end defense sends continued')
s=fresh();s.player.afflictions.asthma=true;D.service(s,function()error('fixture transport failure')end);check(D.hold(s) and D.state(s).fault,'defense sender failure did not fail closed');D.reset(s);check(not D.state(s).fault and not D.state(s).requested.asthma,'explicit reset did not clear failed request')
s=fresh();s.player.mana=2000;check(not D.mana_safe(s,1000),'Blackout spent healing reserve');s.player.mana=2200;check(D.mana_safe(s,1000),'safe mana incorrectly blocked')
s=fresh();s.player.afflictions={anorexia=true,asthma=true,slickness=true};local r=R.new(s,K);r.mode='FULL_AUTO';r.sender=send;n=#sent
check(not R.execute(r,{command='bbt Fixture',requires={balance=true,equilibrium=true}},true) and #sent==n,'direct executor bypassed cure-lock hold')
M.state(s);clock=clock+1;M.tick(s,send);check(#sent==n,'mental channel bypassed cure-lock hold')
s=fresh();M.state(s);clock=clock+1;M.text(s,'Your telepathic efforts are successful, and the mind of Fixture is locked with your own.');s.player.mana=2000;n=#sent;M.tick(s,send);check(#sent==n and not s.mental.eq_pending,'Blackout bypassed healing mana reserve')
s=fresh();M.state(s);clock=clock+1;s.player.kai=50;s.player.defences.kai_trance=true;s.target.restoration={active=true,started=clock-.5};s.mental.status='acquiring';s.mental.started=clock;n=#sent;M.tick(s,send);check(#sent==n,'Kai Cripple spent reserved 20 Kai');s.player.kai=60;M.tick(s,send);check(sent[#sent]=='kai cripple Fixture','affordable Kai Cripple blocked after reserve')
s=fresh();s.connected=false;n=#sent;check(not D.audit(s,send) and not D.setup(s,send) and #sent==n,'offline setup/audit sent commands')
s=fresh();s.mode='OFF';n=#sent;check(D.audit(s,send) and #sent>n,'explicit read-only audit unavailable in OFF')
for _,class in ipairs({'Monk','mOnK','Archivist','ARCHIVIST','Shaman',''})do
 s=fresh();s.mode='OFF';s.player.class=class;s.player.guild=class:lower()=='monk'and'Archivists'or'Monks';n=#sent
 local prior=class:lower()=='monk' and {'ab kaido heal','ab kaido transmute','ab kaido vitality','ab kaido numbness','ab kaido immunity','ab tekura kipup'}or class:lower()=='archivist'and{'ab geometrics','ab numerology','ab bioessence'}or{}
 local expected={'firstaid','firstaid priority list','firstaid elevations','defences'}
 for _,cmd in ipairs(prior)do expected[#expected+1]=cmd end
 check(D.audit(s,send) and #sent-n==#expected,'class audit count '..class)
 for i,cmd in ipairs(expected)do check(sent[n+i]==cmd,'class audit selection '..class..' '..cmd)end
 check(s.mode=='OFF' and not s.defense,'read-only audit armed defense or offense')
end
check(not D.audit(s,function()return false end),'false-return audit transport failure hidden')
n=#sent;check(D.setup(s,send) and #sent>n and sent[#sent]=='firstaid','setup did not request exact readback')
local expected_setup={'firstaid on','firstaid curing on','firstaid heal health on','firstaid heal mana on','firstaid use anabiotic on','firstaid auto stand on','firstaid auto wake on','firstaid use focus on','firstaid use tree on','firstaid vitals priority health','firstaid forcehealth 50','firstaid forcemana 20','firstaid slickness pill on','firstaid'}
check(#sent-n==#expected_setup,'common setup changed command count')
for i,cmd in ipairs(expected_setup)do check(sent[n+i]==cmd,'common setup changed '..cmd)end
for i=n+1,#sent do check(not sent[i]:find('priority reset',1,true) and not sent[i]:find('cureset',1,true),'setup overwrote priorities/cureset')end
check(D.state(s).setup=='requested; server readback required','unconfirmed setup falsely declared verified')
local slick_setup=false;for i=n+1,#sent do if sent[i]=='firstaid slickness pill on' then slick_setup=true end end;check(slick_setup,'setup omitted verified alternate slickness cure')
-- Replay the observed defeat sequence: locked, native cure failures, falling HP,
-- failed tree, mental focus curing a different affliction, then training reset.
s=fresh();for _,k in ipairs({'anorexia','asthma','slickness','paralysis'})do D.text(s,'You are afflicted with '..k..'.')end
for _,hp in ipairs({57,43,29,15,9})do s.player.hp=hp;D.text(s,'[FirstAid]: tree locked');D.text(s,'[FirstAid]: unable to smoke: slickness');check(D.hold(s),'loss replay resumed offense while locked')end
D.text(s,'You have cured stupidity.');check(D.hold(s),'unrelated focus cure falsely broke lock')

s=fresh();s.player.afflictions={asthma=true,slickness=true,anorexia=true};n=#sent;local reentrant
reentrant=function(cmd)send(cmd);D.service(s,reentrant)end
D.service(s,reentrant);check(#sent==n+3,'reentrant delivery duplicated elevations')
s=fresh();check(not D.audit(s,function()error('read-only transport failure')end),'audit transport failure was hidden')
check(not D.setup(s,function()error('setup transport failure')end) and D.state(s).setup=='partial request; server readback required','partial setup falsely declared success')
-- Reproduce the real BASH stall: native healing below the old resume threshold
-- must not disable pressure. Only health-only holds are bypassed, never incapacity.
R.bind_policy(function()return true end)
for _,hp in ipairs({37,55,61,29,19,3})do
 s=fresh();s.mode='BASH';s.player.stance='scorpion';s.player.hp=hp
 D.state(s).low_health=true
 check(not D.hold(s),'health-only BASH pause survived at '..hp..'%')
 check(D.state(s).low_health,'low-health warning was lost')
 local br=R.new(s,K);br.mode='BASH';br.sender=send;br.paused_health=true;n=#sent
 check(R.execute(br,R.propose(br)) and #sent==n+1,'BASH executor retained old health latch at '..hp..'%')
 check(sent[#sent]=='combo Fixture spk ucp ucp' and not br.paused_health,'BASH changed recipe or retained stale pause')
end
local function bash_block(change,msg)
 s=fresh();s.mode='BASH';s.player.stance='scorpion';s.player.hp=3;change(s)
 local br=R.new(s,K);br.mode='BASH';br.sender=send;n=#sent
 check(not R.execute(br,{name='bash_strike',command='combo Fixture spk ucp ucp'}) and #sent==n,msg)
end
bash_block(function(x)x.player.afflictions.paralysis=true end,'low-HP BASH bypassed paralysis')
bash_block(function(x)x.player.afflictions.asleep=true end,'low-HP BASH bypassed sleep')
bash_block(function(x)x.player.afflictions.unconsciousness=true end,'low-HP BASH bypassed unconsciousness')
bash_block(function(x)x.player.prone=true end,'low-HP BASH bypassed prone')
bash_block(function(x)x.player.afflictions={asthma=true,anorexia=true,slickness=true}end,'low-HP BASH bypassed cure-lock')
bash_block(function(x)x.player.hp=0 end,'low-HP BASH bypassed zero health')
bash_block(function(x)x.player.dead=true end,'low-HP BASH bypassed death')
bash_block(function(x)x.connected=false end,'low-HP BASH bypassed disconnect')
bash_block(function(x)x.player.balance=false end,'low-HP BASH bypassed balance')
bash_block(function(x)x.player.equilibrium=false end,'low-HP BASH bypassed equilibrium')
bash_block(function(x)x.player.left_arm_balance=false end,'low-HP BASH bypassed arm balance')
bash_block(function(x)x.player.mounted=471247 end,'low-HP BASH bypassed mounted block')
R.bind_policy(function()return false,'fixture denied' end)
bash_block(function()end,'low-HP BASH bypassed target/player/area policy')
R.bind_policy(nil)
-- PvP keeps both survival gates. The new rule is BASH-only.
s=fresh();s.player.hp=25;local pr=R.new(s,K);pr.mode='FULL_AUTO';pr.sender=send;n=#sent
check(D.hold(s) and not R.execute(pr,{command='bbt Fixture'}) and #sent==n,'BASH health policy leaked into PvP')
print('PASS defense '..count..' assertions: own-state ingestion, early blocker elevations, cure-lock hold, hysteresis, mode/TCP gates, mana/Kai reserves, setup readback and loss replay')
