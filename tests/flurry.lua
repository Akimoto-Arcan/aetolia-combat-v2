-- Offline only: no game, native sender, server queue, or timers granting balance.
local root=assert(arg[1]);local clock=100;function getEpoch()return clock end
local S=dofile(root..'state.lua');local T=dofile(root..'tracker.lua')
local K=dofile(root..'monk.lua');K.bind(T)
local E=dofile(root..'events.lua');E.bind(T)
local R=dofile(root..'runner.lua');R.bind_policy(function()return true end)
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local header='You feel an upsurge of martial power as you prepare to unleash a flurry of blows!'
local body='hfp, spp, hkp, snk, ucp, sdk, wwk, mnk, jbp, spk'
local tokens={'hfp','spp','hkp','snk','ucp','sdk','wwk','mnk','jbp','spk'}
local names={'Hammerfist','Spear','Hook','Snapkick','Uppercut','Sidekick','Whirlwind','Moonkick','Jab','Spinkick'}
local function fresh()
 clock=clock+10;local s=S.new();S.set_target(s,'Fixture');s.mode='BASH';s.room.id=123
 S.sync_gmcp(s,{Char={Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,stance='scorpion'}}})
 local r=R.new(s,K);r.mode='BASH';local sent={};r.sender=function(cmd)sent[#sent+1]=cmd end
 return s,r,sent
end
local function proc(s,b)E.event(s,header);E.event(s,'Flurry Combo: '..(b or body))end
local function ack(s,name,target)E.event(s,'You use Tekura '..name..' on '..(target or 'Fixture')..'.')end
local function recover(s,r)
 E.event(s,'You have recovered balance on your legs.')
 E.event(s,'You have recovered balance on your left arm.')
 E.event(s,'You have recovered balance on your right arm.')
 R.update_balance(r)
end
local s,r,sent=fresh()
check(K.choose(s).command=='combo Fixture spk spp spp','first normal must use SPP')
R.propose(r);R.propose(r);check(s.hunting.bash_variant==nil,'normal proposals advanced')
for i=1,4 do
 local punch=i%2==1 and 'spp' or 'ucp';local kick=i%2==1 and 'spk' or 'sdk'
 check(R.tick(r) and sent[#sent]=='combo Fixture '..kick..' '..punch..' '..punch,'normal alternation order')
 local variant=s.hunting.bash_variant
 R.propose(r);check(s.hunting.bash_variant==variant,'inflight proposal advanced')
 ack(s,kick=='spk' and 'Spinkick' or 'Sidekick');ack(s,punch=='spp' and 'Spear' or 'Uppercut');ack(s,punch=='spp' and 'Spear' or 'Uppercut')
 check(s.hunting.bash_variant==(i%2==1 and 2 or 1),'normal acknowledgements did not alternate')
 recover(s,r);clock=clock+.31
end
s,r,sent=fresh();proc(s)
check(K.flurry_active(s) and s.hunting.flurry.index==1,'trusted proc not active')
check(R.propose(r).command=='hfp Fixture' and R.propose(r).command=='hfp Fixture' and s.hunting.flurry.index==1,'pure proposals advanced proc')
local variant=s.hunting.bash_variant
for i=1,10 do
 local f=s.hunting.flurry
 check(R.tick(r) and sent[#sent]==tokens[i]..' Fixture','wrong ordered individual attack '..i)
 check(#sent==i and r.waiting,'blind queued Flurry commands')
 clock=clock+.2
 check(not R.tick(r) and #sent==i and f.index==i,'timer or proposal invented attack/recovery')
 ack(s,names[i],'Other');check(f.index==i,'wrong target acknowledged')
 E.event(s,'Someone says, "You use Tekura '..names[i]..' on Fixture."');check(f.index==i,'speech acknowledged')
 ack(s,names[i]);check(f.index==i+1,'own committed attack did not advance')
 ack(s,names[i]);check(f.index==i+1,'duplicate own header advanced twice')
 E.event(s,'You miss your strike by mere inches.')
 check(not R.tick(r) and #sent==i,'ack or miss invented balance recovery')
 -- All-limb/leg recovery alone must not manufacture arm recovery.
 E.event(s,'You have recovered balance on all limbs.');R.update_balance(r)
 check(r.waiting,'missing arm recovery released Flurry')
 recover(s,r);check(not r.waiting,'real per-channel recovery did not release')
end
check(not s.hunting.flurry and not K.flurry_active(s),'completed Flurry remained active')
check(s.hunting.bash_variant==variant and K.choose(s).command=='combo Fixture spk spp spp','Flurry changed normal alternation')
for _,v in pairs(s.target.limbs)do check(v==0,'Flurry updated PvP limb estimates')end
clock=clock+.31;check(R.tick(r) and sent[#sent]=='combo Fixture spk spp spp','normal did not resume')
-- A different server order must be followed literally, not the example above.
s,r,sent=fresh();proc(s,'spk, jbp, mnk, wwk, sdk, ucp, snk, hkp, spp, hfp')
check(R.tick(r) and sent[1]=='spk Fixture','dynamic order ignored')
-- Header arrives between proposals and second line; never send stale normal.
s,r,sent=fresh();local old=R.propose(r);E.event(s,header)
check(K.choose(s).command=='' and not R.execute(r,old) and #sent==0,'header latency permitted normal attack')
check(K.flurry_active(s),'pending valid capture did not hold new buff preparation')
clock=clock+.1;E.event(s,'Flurry Combo: '..body);check(K.choose(s).command=='hfp Fixture','second line did not complete framing')
ack(s,'Hammerfist');check(s.hunting.flurry.index==1,'manual uncommitted header consumed proc')
-- Remaining headers from the committed normal combo do not belong to new Flurry.
s,r,sent=fresh();check(R.tick(r),'normal dispatch failed');ack(s,'Spinkick');proc(s)
ack(s,'Spear');ack(s,'Spear');check(s.hunting.flurry.index==1,'old normal headers consumed new proc')
check(s.hunting.bash_variant==2,'normal completion lost during Flurry')
recover(s,r);clock=clock+.2;check(R.tick(r) and sent[#sent]=='hfp Fixture','old normal recovery blocked Flurry')
ack(s,'Hammerfist');recover(s,r);K.cancel_flurry(s)
check(K.choose(s).command=='combo Fixture sdk ucp ucp','normal position not preserved')
-- Orphan/quoted/unknown/malformed/injected orders fail closed.
for _,line in ipairs({'Flurry Combo: '..body,'NPC says, "'..header..'"','NPC says, "Flurry Combo: '..body..'"'})do
 s,r,sent=fresh();E.event(s,line);check(not s.hunting.flurry,'unframed or quoted proc trusted')
end
for _,b in ipairs({body..';quit',body:gsub('hfp','zzz'),body:gsub('spk','jpk'),body:gsub('spk','spp'),body:gsub(', spk',''),body..', hfp',body:gsub(', ',','),body:upper()})do
 s,r,sent=fresh();proc(s,b);check(not s.hunting.flurry and R.tick(r) and sent[1]=='combo Fixture spk spp spp','malformed order did not fall back: '..b)
end
s,r,sent=fresh();E.event(s,header);clock=clock+3;E.event(s,'Flurry Combo: '..body)
check(not s.hunting.flurry and R.tick(r) and sent[1]=='combo Fixture spk spp spp','expired framing did not fall back')
s,r,sent=fresh();E.event(s,header);clock=clock+100
check(R.tick(r) and not s.hunting.flurry_frame and sent[1]=='combo Fixture spk spp spp','no-text framing expiry permanently idled BASH')
s,r,sent=fresh();E.event(s,header);for i=1,9 do E.event(s,'unrelated line')end
check(not K.flurry_active(s) and R.tick(r) and sent[1]=='combo Fixture spk spp spp','line-bounded capture did not fall back')
-- Synchronous transport fakes prove commit is installed before dispatch.
s,r,sent=fresh();proc(s);r.sender=function(cmd)sent[#sent+1]=cmd;ack(s,'Hammerfist')end
check(R.tick(r) and s.hunting.flurry.index==2,'synchronous ack lost')
s,r,sent=fresh();proc(s);r.sender=function()ack(s,'Hammerfist');error('fake transport')end
check(not R.tick(r) and r.fault and r.waiting and s.hunting.flurry.index==1,'failed send advanced or dropped unknown commit barrier')
s,r,sent=fresh();proc(s);r.sender=function()return false end
check(not R.tick(r) and r.fault and r.waiting and s.hunting.flurry.index==1,'false sender result accepted')
s,r,sent=fresh();proc(s);check(R.tick(r),'rejection fixture send failed')
E.event(s,'You must regain balance first.');R.update_balance(r);ack(s,'Hammerfist')
check(not r.waiting and s.hunting.flurry.index==1,'balance rejection advanced order')
check(not R.tick(r) and #sent==1,'rejection trusted stale READY flag')
recover(s,r);check(R.tick(r) and sent[#sent]=='hfp Fixture','rejected attack did not retry same index after real recovery')
-- Recovery without acknowledgement abandons ONLY the uncertain order, never guesses.
s,r,sent=fresh();proc(s);R.tick(r);recover(s,r)
check(not r.waiting and not s.hunting.flurry,'genuine recovery did not abandon uncertain order')
clock=clock+9;check(R.tick(r) and not r.fault and sent[2]=='combo Fixture spk spp spp','safe normal fallback did not resume')
-- GMCP loss/recovery is also valid, but only actual observed edges.
s,r,sent=fresh();proc(s);R.tick(r)
s.player.balance=false;R.update_balance(r);ack(s,'Hammerfist');s.player.balance=true;R.update_balance(r)
check(not r.waiting,'real GMCP loss/recovery did not release')
-- Lifecycle invalidations: local executor guards plus explicit parent hooks.
for _,change in ipairs({function(x,y)R.stop(y)end,function(x,y)y.mode='FULL_AUTO';R.execute(y,{command=''})end,function(x,y)S.set_target(x,'Other');R.execute(y,{command=''})end,function(x,y)x.room.id=456;R.execute(y,{command=''})end,function(x,y)x.connected=false;R.execute(y,{command=''})end,function(x,y)x.player.dead=true;R.execute(y,{command=''})end})do
 s,r,sent=fresh();proc(s);change(s,r);check(not s.hunting.flurry,'lifecycle left old Flurry')
end
s,r,sent=fresh();proc(s);r.mode='OFF';check(not R.tick(r) and #sent==0,'OFF sent Flurry');K.cancel_flurry(s)
s,r,sent=fresh();proc(s);S.set_target(s,'Second');K.continue_flurry(s)
check(K.flurry_active(s) and K.choose(s).command=='hfp Second','explicit vetted kill-chain carry failed')
s,r,sent=fresh();proc(s);s.mode='FULL_AUTO';r.mode='FULL_AUTO';s.config.pvp_stance=nil
check(K.choose(s).name=='combo' and K.choose(s).command:find('snk left',1,true),'Flurry affected PvP selection')
-- Existing defensive/policy/buff/mount/stance barriers remain authoritative.
for _,block in ipairs({function(x)x.buffs={pending={}}end,function(x)x.walker={pending={}}end,function(x)x.player.prone=true end,function(x)x.player.afflictions.paralysis=true end,function(x)x.player.balance=false end})do
 s,r,sent=fresh();proc(s);block(s);check(not R.tick(r) and #sent==0 and s.hunting.flurry.index==1,'arbitration barrier bypassed')
end
s,r,sent=fresh();proc(s);s.player.hp=1;check(R.tick(r),'health-only BASH hold reintroduced')
s,r,sent=fresh();proc(s);s.player.mounted=true;check(K.choose(s).command=='quickdismount','Flurry bypassed dismount')
s.player.mounted=false;s.player.stance='none';check(K.choose(s).command=='scs','Flurry bypassed observed Scorpion preparation')
R.bind_policy(function()return false,'blocked' end);s,r,sent=fresh();proc(s);check(not R.tick(r) and #sent==0,'Flurry bypassed policy');R.bind_policy(function()return true end)
R.bind_defense(function()return true,'native curing hold' end);s,r,sent=fresh();proc(s);check(not R.tick(r) and #sent==0,'Flurry bypassed defense');R.bind_defense(nil)
-- Normal bookkeeping is based on committed attack headers, not sends/proposals/preparation.
s,r,sent=fresh();r.sender=function()error('normal sender failed')end
check(not R.tick(r) and s.hunting.bash_variant==nil,'failed normal send advanced alternation')
s,r,sent=fresh();s.player.balance=false;check(not R.tick(r) and s.hunting.bash_variant==nil,'blocked normal advanced alternation')
s,r,sent=fresh();s.player.stance='none';check(R.tick(r) and sent[1]=='scs' and s.hunting.bash_variant==nil,'preparation advanced alternation')
s,r,sent=fresh();R.tick(r);E.event(s,'You must regain balance first.');R.update_balance(r)
ack(s,'Spinkick');ack(s,'Spear');ack(s,'Spear');check(s.hunting.bash_variant==nil,'rejected normal advanced alternation')
s,r,sent=fresh();R.tick(r);check(s.hunting.bash_variant==nil,'send without attack acknowledgement advanced normal')
-- The automatic kill chain carries the self buff, but never the old attack's recovery proof.
s,r,sent=fresh();proc(s)
check(R.tick(r),'kill-chain opening failed');ack(s,'Hammerfist');E.event(s,'You have slain Fixture.')
S.set_target(s,'Second');K.continue_flurry(s)
check(not R.tick(r) and #sent==1,'automatic target change erased committed recovery barrier')
clock=clock+.2;recover(s,r);check(R.tick(r) and sent[2]=='spp Second','vetted next target did not continue next token')
ack(s,'Spear','Second');recover(s,r)
check(s.hunting.flurry.index==3 and s.hunting.bash_variant==nil,'kill-chain continuation reset order/normal position')
-- Cancelling intent on manual retarget does not fake readiness or deadlock real recovery.
s,r,sent=fresh();proc(s);R.tick(r);K.cancel_flurry(s);S.set_target(s,'Other')
check(not R.tick(r) and #sent==1,'manual retarget dropped pending physical barrier')
recover(s,r);check(not r.waiting,'cancelled old proc prevented actual recovery')
-- An order-bound action cannot be forged with missing channel requirements.
s,r,sent=fresh();proc(s);local forged=R.propose(r);forged.requires={};s.player.balance=false
check(not R.execute(r,forged) and #sent==0,'forged requirements bypassed actual Flurry balance')
-- Normal cadence stays .3s; only the ordered override removes that extra throttle.
s,r,sent=fresh();R.tick(r);ack(s,'Spinkick');ack(s,'Spear');ack(s,'Spear');recover(s,r)
clock=clock+.2;check(not R.tick(r) and #sent==1,'normal cooldown changed')
clock=clock+.11;check(R.tick(r) and #sent==2,'normal cooldown did not release')
s,r,sent=fresh();proc(s);R.tick(r);E.event(s,'You must regain equilibrium first.');R.update_balance(r)
check(not R.tick(r) and s.hunting.flurry.index==1,'EQ rejection advanced or trusted cached readiness')
E.event(s,'You have recovered equilibrium.');check(R.tick(r) and sent[#sent]=='hfp Fixture','real EQ regain did not permit same ordered retry')
-- First-header execution survives an immediate kill/automatic next target.
s,r,sent=fresh();R.tick(r);ack(s,'Spinkick');E.event(s,'You have slain Fixture.')
S.set_target(s,'Second');K.continue_flurry(s);recover(s,r);clock=clock+.31
check(R.tick(r) and sent[2]=='combo Second sdk ucp ucp','first-hit kill repeated normal variant')
s,r,sent=fresh();R.tick(r);ack(s,'Spinkick');E.event(s,'You miss your strike by mere inches.')
check(s.hunting.bash_variant==2,'first own attack miss did not settle normal intent')
ack(s,'Spear');ack(s,'Spear');check(s.hunting.bash_variant==2,'remaining normal headers advanced twice')
s,r,sent=fresh();r.sender=function()ack(s,'Spinkick');return false end
check(not R.tick(r) and not s.hunting.bash_variant,'synchronous header inside failed normal send advanced')
-- Duplicate captures do not rewind or pause an already validated chain.
s,r,sent=fresh();proc(s);R.tick(r);ack(s,'Hammerfist');local active=s.hunting.flurry
proc(s);check(s.hunting.flurry==active and active.index==2,'duplicate proc rewound active chain')
ack(s,'Hammerfist');check(active.index==2,'old duplicate header consumed next token')
E.event(s,header);check(K.choose(s).command=='spp Fixture','header-only duplicate paused active chain')
clock=clock+100;recover(s,r)
check(R.tick(r) and sent[2]=='spp Fixture','missing duplicate body disabled active chain')
-- Different valid order replaces intent but never the prior physical wait.
s,r,sent=fresh();proc(s);R.tick(r)
proc(s,'spk, jbp, mnk, wwk, sdk, ucp, snk, hkp, spp, hfp')
ack(s,'Hammerfist');check(s.hunting.flurry.index==1 and not R.tick(r),'old commit consumed/released replacement')
recover(s,r);check(R.tick(r) and sent[2]=='spk Fixture','new valid order failed after old recovery')
-- Timeout is only a physical hold while unresolved; a late scoped ACK reconciles.
s,r,sent=fresh();proc(s);R.tick(r);clock=clock+9
check(not R.tick(r) and r.fault and r.waiting,'unresolved physical commit did not hold')
ack(s,'Hammerfist');check(s.hunting.flurry.index==2,'late own ACK was blindly discarded')
recover(s,r);check(not r.fault and not r.waiting and R.tick(r) and sent[2]=='spp Fixture','late ACK/recovery failed reconciliation')
s,r,sent=fresh();proc(s);R.tick(r);clock=clock+9;R.tick(r)
recover(s,r);ack(s,'Hammerfist')
check(not r.fault and not r.waiting and not s.hunting.flurry,'recovered timeout did not abandon uncertain order')
check(R.tick(r) and sent[2]=='combo Fixture spk spp spp','recovered timeout did not resume validated normal')
s,r,sent=fresh();proc(s);R.tick(r);clock=clock+9;R.tick(r)
E.event(s,'You must regain balance first.');R.update_balance(r)
check(not r.fault and not R.tick(r) and s.hunting.flurry.index==1,'late rejection advanced or trusted stale READY')
recover(s,r);check(R.tick(r) and sent[2]=='hfp Fixture','late rejection did not allow genuine recovered retry')
-- A genuine left-arm-only loss/regain needs no imaginary leg/right-arm loss.
for _,acknowledged in ipairs({true,false})do
 s,r,sent=fresh();proc(s);R.tick(r)
 s.player.left_arm_balance=false;R.update_balance(r)
 if acknowledged then ack(s,'Hammerfist')end
 E.event(s,'You have recovered balance on your left arm.');R.update_balance(r)
 check(not r.waiting,'left-arm-only physical recovery deadlocked')
 check(acknowledged and s.hunting.flurry.index==2 or not acknowledged and not s.hunting.flurry,'left-only recovery guessed order')
end
-- Recovery never clears unrelated faults or transport uncertainty.
s,r,sent=fresh();proc(s);R.tick(r);s.player.equilibrium=false;R.update_balance(r)
E.event(s,'You have recovered equilibrium.');R.update_balance(r)
check(r.waiting and s.hunting.flurry.index==1,'independent EQ recovery fabricated physical recovery')
s,r,sent=fresh();proc(s);R.tick(r);r.fault='unrelated failure';clock=clock+9;R.tick(r);recover(s,r)
check(r.fault=='unrelated failure' and not R.tick(r),'fallback cleared unrelated fault')
s,r,sent=fresh();proc(s);r.sender=function()return false end;R.tick(r);recover(s,r)
check(r.waiting and r.fault and not R.tick(r),'recovery erased unknown transport barrier')
-- Invalid capture cannot release a real committed action or bypass arbitration.
s,r,sent=fresh();proc(s);R.tick(r);proc(s,'bad');clock=clock+9
check(r.waiting and not R.tick(r) and #sent==1,'invalid frame released physical commit')
for _,block in ipairs({function(x)x.buffs={pending={}}end,function(x)x.walker={pending={}}end,function(x)x.player.prone=true end,function(x)x.player.afflictions.paralysis=true end,function(x)x.player.balance=false end,function(x)x.player.dead=true end})do
 s,r,sent=fresh();proc(s,'bad');block(s)
 check(not R.tick(r) and #sent==0,'invalid-frame fallback bypassed gate')
end
R.bind_policy(function()return false,'blocked' end);s,r,sent=fresh();proc(s,'bad');check(not R.tick(r) and #sent==0,'fallback bypassed policy');R.bind_policy(function()return true end)
-- Recovery fallback likewise goes through every gate rather than sending directly.
for _,block in ipairs({function(x)x.buffs={pending={}}end,function(x)x.walker={pending={}}end,function(x)x.player.prone=true end,function(x)x.player.afflictions.paralysis=true end,function(x)x.player.balance=false end,function(x)x.player.dead=true end})do
 s,r,sent=fresh();proc(s);R.tick(r);recover(s,r);block(s);clock=clock+.31
 check(not R.tick(r) and #sent==1,'recovered fallback bypassed gate')
end
R.bind_policy(function()return true end);s,r,sent=fresh();proc(s);R.tick(r);recover(s,r);clock=clock+.31
R.bind_policy(function()return false,'blocked' end);check(not R.tick(r) and #sent==1,'recovered fallback bypassed policy');R.bind_policy(function()return true end)
-- Normal transport is just as indivisible as Flurry, even with genuine proof
-- received synchronously before sender returns. Assertions stay outside pcall.
for _,outcome in ipairs({'true','false','throw'})do
 s,r,sent=fresh();local nested_tick,nested_execute,held,commit
 r.sender=function(cmd)
  sent[#sent+1]=cmd
  if #sent>1 then return true end
  commit=r.transport_commit
  ack(s,'Spinkick');recover(s,r);clock=clock+.31
  held=r.waiting and s.hunting.bash_variant==nil
  nested_tick=R.tick(r);nested_execute=R.execute(r,R.propose(r))
  if outcome=='throw' then error('normal synchronous transport failure')end
  return outcome=='true'
 end
 local ok=R.tick(r)
 check(commit and held and not nested_tick and not nested_execute and #sent==1,'normal transport reentry: '..outcome)
 if outcome=='true' then
  check(ok and not r.transport_commit and s.hunting.bash_variant==2,'normal success did not finalize once')
  check(R.tick(r) and #sent==2 and sent[2]=='combo Fixture sdk ucp ucp','normal external recovered tick did not send SDK exactly once')
  check(not R.tick(r) and #sent==2,'cached readiness duplicated next normal')
 else
  check(not ok and r.transport_commit==commit and r.fault and not s.hunting.bash_variant,'failed normal transport finalized/advanced')
  local fault=r.fault
  recover(s,r);E.event(s,'You must regain balance first.');R.update_balance(r)
  check(r.waiting and r.fault==fault and not R.tick(r) and #sent==1,'failed normal transport released on recovery/rejection')
  R.stop(r);r.mode='BASH';s.mode='BASH';recover(s,r)
  check(r.transport_commit==commit and not R.tick(r) and not R.execute(r,R.propose(r)) and #sent==1,'STOP erased failed normal transport review barrier')
 end
end
-- Cached ready flags alone still cannot release a successful normal commit.
s,r,sent=fresh();r.sender=function(cmd)sent[#sent+1]=cmd;ack(s,'Spinkick')end
check(R.tick(r) and not r.transport_commit and s.hunting.bash_variant==2,'header-only normal did not finalize')
clock=clock+.31;check(not R.tick(r) and r.waiting and #sent==1,'transport success fabricated physical readiness')
-- Intent cancellation and mode changes / STOP during transport cannot reopen
-- execute/tick, including when STOP has cleared the ordinary waiting flag.
for _,kind in ipairs({'normal','flurry','preparation'})do
 for _,change in ipairs({'cancel','mode','stop'})do
  for _,outcome in ipairs({'true','false','throw'})do
   s,r,sent=fresh();if kind=='flurry' then proc(s)elseif kind=='preparation' then s.player.stance='none'end
   local nested_tick,nested_execute,commit,retained
   r.sender=function(cmd)
    sent[#sent+1]=cmd;if #sent>1 then return true end
    commit=r.transport_commit
    if kind=='normal' then ack(s,'Spinkick')elseif kind=='flurry' then ack(s,'Hammerfist')end
    if change=='cancel' then K.cancel_flurry(s)
    elseif change=='mode' then r.mode='FULL_AUTO';s.mode='FULL_AUTO'
    else R.stop(r);r.mode='BASH';s.mode='BASH'end
    recover(s,r);clock=clock+.31;retained=r.transport_commit==commit
    nested_tick=R.tick(r);nested_execute=R.execute(r,R.propose(r))
    if outcome=='throw' then error('cancelled synchronous transport failure')end
    return outcome=='true'
   end
   local ok=R.tick(r)
   check(commit and retained and not nested_tick and not nested_execute and #sent==1,'lifecycle bypassed transport: '..kind..'/'..change..'/'..outcome)
   if outcome=='true' then
    check(ok and not r.transport_commit,'successful cancelled transport did not finalize')
   else
    recover(s,r);R.stop(r);r.mode='BASH';s.mode='BASH'
    check(not ok and r.transport_commit==commit and not R.tick(r) and not R.execute(r,R.propose(r)) and #sent==1,'failed cancelled transport lost reviewed barrier')
   end
  end
 end
end
print('PASS '..count..' assertions: ordered Flurry, pure proposals, normal alternation, real recovery, lifecycle and arbitration')
