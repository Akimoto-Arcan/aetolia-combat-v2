-- Replay fixtures match actual pattern templates in Fallout and AC2.2 exports.
-- Actor names and sequences here are synthetic; legacy trauma numbers are estimates.
local root=assert(arg[1]);local clock=100;function getEpoch()return clock end
local S=dofile(root..'state.lua');local T=dofile(root..'tracker.lua');local E=dofile(root..'events.lua');E.bind(T)
local K=dofile(root..'monk.lua');K.bind(T);local R=dofile(root..'runner.lua');R.bind_policy(function()return true end);local B=dofile(root..'bashing.lua');B.bind(S)
local sent={};function send(v)sent[#sent+1]=v end
local count=0;local function check(ok,msg)assert(ok,msg);count=count+1 end
local function fresh(mode)
 clock=clock+1;local s=S.new();S.set_target(s,'Enemy');s.mode=mode or 'FULL_AUTO';S.sync_gmcp(s,{Char={Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1}}});return s
end
local function lines(s,... )for _,line in ipairs({...})do E.event(s,line)end end
local s=fresh();lines(s,'You use Tekura Spear on Enemy.','You connect to the left arm!')
check(math.abs(s.target.limbs.left_arm-5.49)<.001,'spear damage estimate not correlated')
check(s.target.evidence['limb:left_arm'].confidence==.65,'estimate incorrectly marked certain')
check(not s.target.broken.left_arm,'estimated trauma invented a break')
E.event(s,'You connect to the left arm!');check(s.target.limbs.left_arm==5.49,'duplicate unscoped connection counted twice')
s=fresh();s.player.stance='tiger';lines(s,'You form a spear hand and stab out towards Enemy.','You connect to the right arm!');check(s.target.limbs.right_arm==6.6,'tiger estimate not selected')
s=fresh();lines(s,'You pump out at Enemy with a powerful side kick.','You connect to the torso!');check(s.target.limbs.torso==8.99,'sidekick torso correlation')
s=fresh();lines(s,'You use Tekura Spear on Other.','You connect to the left arm!');check(s.target.limbs.left_arm==0,'other target opener contaminated damage')
s=fresh();lines(s,'Other forms a spear hand and stabs out towards Enemy.','You connect to the left arm!');check(s.target.limbs.left_arm==0,'third party opener accepted')
s=fresh();E.event(s,'You use Tekura Spear on Enemy.');clock=clock+3;E.event(s,'You connect to the left arm!');check(s.target.limbs.left_arm==0,'expired context consumed hit')
s=fresh();E.event(s,'You use Tekura Spear on Enemy.');S.set_target(s,'Other');E.event(s,'You connect to the left arm!');check(s.target.limbs.left_arm==0,'target switch retained hit context')
s=fresh();lines(s,'You use Tekura Spear on Enemy.','Enemy parries the attack on his left arm with a deft maneuver.','You connect to the left arm!');check(s.target.parry_limb=='left_arm' and s.target.limbs.left_arm==0,'parry did not block damage')
s=fresh();E.event(s,'Enemy parries the attack on his left leg with a deft maneuver.');check(s.target.parry_limb==nil,'parry without our attack context accepted')
s=fresh();lines(s,'You use Tekura Snapkick on Enemy.','Other parries the attack on his left leg with a deft maneuver.','You connect to the left leg!');check(not s.target.parry_limb and s.target.limbs.left_leg==0,'other defender context not discarded')
s=fresh();lines(s,'You use Tekura Hammerfist on Enemy.','Stepping quickly out of the way, Enemy dodges the attack.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'dodge still counted as a hit')
s=fresh();lines(s,'You use Tekura Snapkick on Enemy.','You miss your strike by mere inches.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'miss still counted as a hit')
s=fresh();lines(s,'You use Tekura Spear on Enemy.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'spear connected to an unsupported leg')
s=fresh();lines(s,'You use Tekura Spear on Enemy.','You connect to an obscured limb!');check(s.target.limbs.left_arm==0 and s.target.limbs.right_arm==0,'hidden hit side guessed')
s=fresh();s.config.estimate_trauma=false;lines(s,'You use Tekura Spear on Enemy.','You connect to the left arm!');check(s.target.last_hit.limb=='left_arm' and s.target.limbs.left_arm==0,'estimate off ignored')
s=fresh('BASH');lines(s,'You use Tekura Spear on Enemy.','You connect to the left arm!');check(s.target.limbs.left_arm==0,'bashing contaminated PvP damage')
s=fresh();lines(s,'You discern that Enemy has been afflicted with paralysis.');check(s.target.afflictions.paralysis,'discern gain not parsed')
lines(s,'You discern that Other has cured the effects of paralysis.');check(s.target.afflictions.paralysis,'other target cure applied')
lines(s,'You discern that Enemy has cured the effects of paralysis.');check(not s.target.afflictions.paralysis,'discern cure not parsed')
lines(s,'You discern that Enemy has been afflicted with left leg broken.');check(s.target.broken.left_leg and s.target.afflictions.left_leg_broken,'observed broken state not normalized')
lines(s,'You discern that Enemy has cured the effects of a broken left leg.');check(not s.target.broken.left_leg and not s.target.afflictions.left_leg_broken,'alternate cure word order not normalized')
lines(s,'You connect and send Enemy sprawling to the floor.');check(s.target.prone and s.target.afflictions.fallen,'sweep prone not parsed')
s.target.broken.left_leg=true;lines(s,'Enemy stands up and stretches his arms out wide.');check(not s.target.prone and s.target.broken.left_leg,'stand should not magically cure limb damage')
lines(s,'Enemy is knocked to the ground.','Enemy uses Tekura Kipup.');check(not s.target.prone,'enemy kipup not parsed')
s=fresh();lines(s,'A nearly invisible magical shield forms around Enemy.');check(s.target.shield and K.choose(s).command=='sck Enemy','shield gain not reaching selector')
lines(s,"Enemy's magical shield is sheared straight through.");check(not s.target.shield,'scythekick confirmation did not clear shield')
lines(s,'You suddenly perceive the vague outline of an aura of rebounding around Enemy.');check(s.target.rebounding and K.choose(s).command=='','rebounding gain not respected')
lines(s,"Enemy's aura of rebounding is pierced and shredded under the attack.");check(not s.target.rebounding,'rebounding loss not parsed')
s=fresh();lines(s,'You use Tekura Spear on Enemy.','The attack rebounds back onto you!','You connect to the left arm!');check(s.target.rebounding and s.target.limbs.left_arm==0,'rebound did not cancel hit')
s=fresh();lines(s,"You can find no such target as 'Other'.");check(not s.stop_reason,'other missing target stopped current target')
lines(s,"You can find no such target as 'Enemy'.");check(s.stop_reason=='target unavailable','target unavailable not recognized')
s=fresh('BASH');S.set_target(s,'123');s.target.display_name='a training dummy';B.add(s,'456');s.room.items['456']={name='a training dummy'};B.start(s)
local r=R.new(s,K);r.mode='BASH';R.tick(r);lines(s,'Having slain a training dummy, you retrieve the corpse.');check(s.target.dead,'corpse retrieval kill not recognized')
B.killed(s);lines(s,'You have slain a training dummy.');check(not s.target.dead and not s.stop_reason,'duplicate kill advanced untouched next mob')
s=fresh('BASH');S.set_target(s,'999');B.start(s);local numeric_runner=R.new(s,K);numeric_runner.mode='BASH';R.tick(numeric_runner);lines(s,'You have slain a training dummy.');check(s.target.dead and s.target.display_name=='a training dummy','pending numeric target kill not correlated when room GMCP absent')
s=fresh('BASH');S.set_target(s,'999');B.start(s);lines(s,'You have slain a training dummy.');check(not s.target.dead,'numeric target without an attack adopted unrelated kill')
s=fresh('BASH');S.set_target(s,'999');B.start(s);numeric_runner=R.new(s,K);numeric_runner.mode='BASH';R.tick(numeric_runner);clock=clock+3;lines(s,'You have slain a training dummy.');check(not s.target.dead,'expired numeric pending kill accepted')
s=fresh('BASH');s.player.stance='scorpion';r=R.new(s,K);r.mode='BASH';R.tick(r);local before=#sent;clock=clock+1
lines(s,'You have recovered balance on your left arm.');R.tick(r);check(#sent==before,'left arm alone released full combo wait')
lines(s,'You have recovered balance on your legs.');R.tick(r);check(#sent==before,'legs alone manufactured right arm recovery')
lines(s,'You have recovered balance on your right arm.');R.tick(r);check(#sent==before+1,'real balance text did not release wait')
s=fresh();s.player.balance=false;s.player.left_arm_balance=false;s.player.right_arm_balance=false;lines(s,'You have recovered balance on all limbs.');check(s.player.balance and not s.player.left_arm_balance and not s.player.right_arm_balance,'all-limb text conflated arm channels')
s=fresh('BASH');r=R.new(s,K);r.mode='BASH';R.tick(r);clock=clock+1;lines(s,"A dizzying beam of energy strikes you as your attack rebounds off of Enemy's shield.");check(R.tick(r) and sent[#sent]=='sck Enemy','explicit shield rejection did not permit safe shield-break recovery')
s=fresh('BASH');lines(s,'You are in the Tiger stance.');check(K.choose(s).command=='scs','non-scorpion opening not enforced')
lines(s,'You sink back into the menacing stance of the Scorpion.');check(K.choose(s).command=='combo Enemy spk spp spp','scorpion confirmation not used')
s.player.prone=true;lines(s,'Making a call to your own, you kip yourself up and sink back into the Scorpion stance.');check(s.player.stance=='scorpion' and not s.player.prone,'scorpion kipup not recognized')

-- Regression from the observed dummy session: command alias differs from server display name.
s=fresh();S.set_target(s,'dummy');s.room.items={['111']={name='a battered training dummy',attrib='m'},['222']={name='a runed target dummy',attrib=''}}
r=R.new(s,K);r.mode='FULL_AUTO';check(R.tick(r),'dummy test attack was not staged')
lines(s,'You use Tekura Snapkick on a battered training dummy.','You let fly at a battered training dummy with a snap kick.','You connect to the left leg!',
 'You use Tekura Hammerfist on a battered training dummy.','You ball up one fist and hammerfist a battered training dummy.','You connect to the left leg!',
 'You use Tekura Hammerfist on a battered training dummy.','You ball up one fist and hammerfist a battered training dummy.','You connect to the left leg!')
check(s.target.display_name=='a battered training dummy','own alias attack did not bind the verified room NPC name')
check(math.abs(s.target.limbs.left_leg-(s.config.kick_trauma+2*s.config.punch_trauma))<.001,'dummy combo did not track three confirmed hits')
check(K.select_limb(s)=='right_leg','updated dummy limb estimate did not redirect route')
check(s.target.evidence['limb:left_leg'].confidence==.65 and not s.target.broken.left_leg,'dummy estimates fabricated an authoritative break')
s=fresh();S.set_target(s,'dummy');s.room.items={['111']={name='a battered training dummy',attrib='m'}}
lines(s,'You use Tekura Snapkick on a battered training dummy.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'alias binding without pending engine attack was accepted')
r=R.new(s,K);r.mode='FULL_AUTO';R.tick(r);clock=clock+3
lines(s,'You use Tekura Snapkick on a battered training dummy.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'expired alias attack was bound')
s=fresh();S.set_target(s,'dummy');s.room.items={['111']={name='a battered training dummy',attrib='m'},['222']={name='another training dummy',attrib='m'}}
r=R.new(s,K);r.mode='FULL_AUTO';R.tick(r);lines(s,'You use Tekura Snapkick on a battered training dummy.','You connect to the left leg!')
check(s.target.limbs.left_leg==0 and not s.target.display_name,'ambiguous alias was guessed')
s=fresh();S.set_target(s,'dummy');s.room.items={['111']={name='a battered training dummy',attrib='mx'}}
r=R.new(s,K);r.mode='FULL_AUTO';R.tick(r);lines(s,'You use Tekura Snapkick on a battered training dummy.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'protected room NPC used to bind alias')
s=fresh();S.set_target(s,'Ann');s.room.items={['111']={name='Joann',attrib='m'}}
r=R.new(s,K);r.mode='FULL_AUTO';R.tick(r);lines(s,'You use Tekura Snapkick on Joann.','You connect to the left leg!');check(s.target.limbs.left_leg==0,'partial-word alias bound a different target')

-- Confirmed injury and posture drive both enemy-affliction display and finisher selection.
s=fresh();lines(s,"Enemy's left leg breaks from all the damage.")
check(s.target.broken.left_leg and s.target.crippled.left_leg,'named break did not establish incapacitated leg')
check(s.target.afflictions.left_leg_broken and s.target.afflictions.left_leg_crippled,'confirmed injury absent from enemy afflictions')
check(K.choose(s).name=='sweep','confirmed leg injury did not select sweep')
lines(s,'You connect and send Enemy sprawling to the floor.')
check(s.target.prone and s.target.afflictions.prone and s.target.afflictions.fallen,'prone aliases not synchronized')
check(K.choose(s).command=='bbt Enemy','confirmed injury and knockdown did not select BBT')
lines(s,'Enemy stands up and stretches his arms out wide.')
check(not s.target.prone and not s.target.afflictions.prone and not s.target.afflictions.fallen,'standing left stale prone afflictions')
check(s.target.crippled.left_leg and s.target.broken.left_leg,'standing falsely cured a limb')
lines(s,'You discern that Enemy has cured the effects of a crippled left leg.','You discern that Enemy has cured the effects of a broken left leg.')
check(not s.target.crippled.left_leg and not s.target.broken.left_leg and not s.target.afflictions.left_leg_crippled,'confirmed cures left stale limb flags')
s=fresh();lines(s,"Other's left leg breaks from all the damage.",'You connect and send Other sprawling to the floor.')
check(not s.target.crippled.left_leg and not s.target.prone,'other target injury contaminated selected enemy')
s=fresh();lines(s,"Enemy's right arm is badly crippled under the handaxe.")
check(s.target.crippled.right_arm and s.target.afflictions.right_arm_crippled,'explicit cripple message not tracked')
s=fresh();lines(s,"Enemy's left leg breaks in half.");check(s.target.crippled.left_leg and not s.target.broken.left_leg,'simple cripple tier conflated with restoration break')
s=fresh();lines(s,"Enemy's head has been beaten into uselessness.",'Enemy is knocked to the ground.')
check(s.target.mangled.head and s.target.afflictions.head_mangled and K.choose(s).name=='axe_execute','confirmed mangled head/prone did not select Axe')
s=fresh();S.set_target(s,'dummy');s.target.display_name='a battered training dummy'
lines(s,'A battered training dummy buckles to the ground with a shuddering fall.')
check(s.target.prone and s.target.afflictions.prone,'actual dummy collapse not tracked')
check(not next(s.target.crippled),'dummy collapse invented crippled limbs')
lines(s,'A battered training dummy lifts itself upright from the ground.')
check(not s.target.prone and not s.target.afflictions.fallen,'actual dummy upright did not clear posture')
s=fresh();lines(s,'You discern that Enemy has been afflicted with prone.','You discern that Enemy has cured the effects of fallen.')
check(not s.target.prone and not s.target.afflictions.prone,'cross-name prone/fallen cure failed')
s=fresh('BASH');lines(s,"Enemy's left leg breaks from all the damage.",'Enemy is knocked to the ground.')
check(not s.target.crippled.left_leg and not s.target.afflictions.left_leg_crippled and not s.target.prone,'BASH ingested PvP injury state')

s=fresh();s.room.id=7;s.training={enabled=true,target=s.target.name,generation=s.target_generation,room=7}
lines(s,'A runed target dummy says, "My left leg took 9.00% damage. It is now at 9.00% total."','A runed target dummy says, "My left leg took 5.50% damage. It is now at 14.50% total."')
check(s.target.limbs.left_leg==14.5 and s.target.evidence['limb:left_leg'].confidence==1,'explicit training total did not override estimates')
lines(s,'A runed target dummy says, "I was afflicted with left_leg_broken."','A runed target dummy says, "I was afflicted with left_leg_crippled."')
check(s.target.broken.left_leg and s.target.crippled.left_leg,'training proxy injury did not reach flags')
lines(s,'Enemy presses a restoration poultice against his left leg, rubbing the poultice into his flesh.')
check(s.target.restoration and s.target.restoration.active and s.target.restoration.limb=='left_leg','restoration application not tracked')
check(s.target.broken.left_leg,'application falsely claimed instant cure')
lines(s,'A runed target dummy says, "I was cured of left_leg_broken."','A runed target dummy says, "I was cured of left_leg_crippled."')
check(not s.target.broken.left_leg and not s.target.crippled.left_leg and not s.target.afflictions.left_leg_crippled and not s.target.restoration.active,'explicit training cures left stale injuries')
lines(s,'A runed target dummy says, "My left leg took 9.00% damage. It is now at 9.00% total."');check(s.target.limbs.left_leg==9,'reported post-restoration total did not lower old damage')
S.set_target(s,'Other');lines(s,'A runed target dummy says, "I was afflicted with left_leg_crippled."');check(not s.target.crippled.left_leg,'training trust leaked to another target')
s=fresh();lines(s,'A runed target dummy says, "I was afflicted with left_leg_crippled."');check(not s.target.crippled.left_leg,'unconfigured speech granted combat evidence')
s=fresh();lines(s,"Enemy's left leg breaks from all the damage.");r=R.new(s,K);r.mode='FULL_AUTO';check(R.tick(r) and s.target.sweep_attempted,'sweep send not remembered')
lines(s,'You connect and send Enemy sprawling to the floor.');check(K.choose(s).name=='backbreaker','sweep guard suppressed valid BBT')
lines(s,'Enemy stands up and stretches his arms out wide.');check(K.choose(s).name~='sweep','stood-up enemy caused endless repeated sweep')
lines(s,'You discern that Enemy has cured the effects of a crippled left leg.','You discern that Enemy has been afflicted with a crippled left leg.');check(not s.target.sweep_attempted and K.choose(s).name=='sweep','new confirmed cripple did not rearm sweep setup')
s=fresh();lines(s,"The dummy's eyes dim as it ceases fighting.")
check(s.training_battle_ended and s.stop_reason=='training battle ended','training reset did not terminate match')
check(not s.player.dead,'training reset falsely declared character dead')
s=fresh();s.room.id=7;s.training={enabled=true,target=s.target.name,generation=s.target_generation,room=7}
lines(s,'A runed target dummy says, "I have triumphed in battle!"')
check(s.training_battle_ended and s.stop_reason=='training battle ended','reported training defeat ignored')

-- Prompts/blank lines never replace meaningful debug history; parsing still runs.
s=fresh();E.event(s,'You use Tekura Spear on Enemy.');local last=s.last_event;local size=#s.recent_events
for _,prompt in ipairs({'H:3475 (82%) M:2934 (100%) End:86% Will:100% Sandstorm: Soul:100% XP:30.80% [s e-]','4394h, 2934m e-','HP: 4394 (100%) MP: 2934 (100%)','[STANCE: SCORPION] [Kai: 0]','  ',string.char(27)..'[32mH:123 (50%) M:456 (50%)'..string.char(27)..'[0m'})do E.event(s,prompt);check(s.last_event==last and #s.recent_events==size,'prompt/blank overwrote event history')end
E.event(s,'custom prompt with no known format',true);check(s.last_event==last,'native prompt metadata was ignored')
local previous=isPrompt;isPrompt=function()return true end;E.event(s,'another custom prompt');check(s.last_event==last,'live Mudlet prompt flag was ignored');isPrompt=previous
local eq=s.recoveries.equilibrium or 0;E.event(s,'You have recovered equilibrium.',true);check(s.recoveries.equilibrium==eq+1 and s.last_event==last,'display filter suppressed combat parsing')
E.event(s,'You use Tekura Spear on Enemy.');E.event(s,'H:100 (100%) M:100 (100%)');E.event(s,'You connect to the left arm!');check(s.target.limbs.left_arm>0 and s.last_event=='You connect to the left arm!','prompt handling broke hit correlation')
for i=1,25 do E.event(s,'Meaningful fixture event '..i)end
check(#s.recent_events==20 and s.recent_events[1].text=='Meaningful fixture event 25' and s.recent_events[20].text=='Meaningful fixture event 6','event history unbounded or out of order')
check(s.recent_events[1].time==clock,'event timestamp did not use observed time')

print('PASS combat-text '..count..' assertions: sourced message correlation, estimates, parry/miss/hidden-hit guards, actor identity, affliction cures, shield, rebounding, independent balance events, duplicate kills and scorpion opening')
