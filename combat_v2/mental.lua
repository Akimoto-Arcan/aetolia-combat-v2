-- Independent Mind Lock channel; physical waits are never used as channel timers.
local M={}
function M.bind_defense(d) M.defense=d end
local function now()return getEpoch and getEpoch() or os.clock()end
local function norm(v)return tostring(v or ''):lower()end
function M.state(s)
 s.mental=s.mental or {status='idle',retry_at=0,last_blackout=-1000,enabled=true}
 local m=s.mental
 if m.generation~=s.target_generation then
  if m.target or m.lock_target then m.needs_cease=true end
  -- Scope revokes lock permission, never a possibly committed EQ transaction.
  m.status='idle';m.target=nil;m.lock_target=nil;m.generation=s.target_generation;m.retry_at=now()+.3
 end
 return m
end
function M.reset(s)local m=M.state(s);m.eq_pending=nil;m.fault=nil end
function M.text(s,text)
 if type(text)~='string' then return end
 local m=M.state(s)
 -- A named loss revokes this target's lock, not an unresolved cast/transport.
 -- Keep eq_pending/fault and the physical runner's commitment intact.
 local lost=text:match('^Your mind lock with (.+) has been broken%.$')
  or text:match('^(.+) has moved out of range of your telepathy, breaking your mindlock attempt%.$')
  or text:match('^(.+) is out of range of your telepathy, and the mental cords between you snap instantly%.$')
  or text:match('^You dissolve the mindlock, severing all telepathic connections between you and (.+)%.$')
 if lost and norm(lost)==norm(s.target.name) and norm(lost)==norm(m.lock_target or m.target) then
  m.status='idle';m.lock_target=nil;m.target=nil;m.retry_at=now()+3;return
 end
 local who=text:match('^You focus your mind, and begin to concentrate on forming a mind lock with (.+)%.$')
 if who and norm(who)==norm(s.target.name) then m.target=who;m.status='acquiring';m.started=now();m.progress=now();return end
 who=text:match('^You continue to delve deeper and deeper into the mind of (.+)%.$')
 if who and norm(who)==norm(m.target) then m.progress=now();return end
 who=text:match('^Your telepathic efforts are successful, and the mind of (.+) is locked with your own%.$')
 if who and norm(who)==norm(s.target.name) then m.status='locked';m.target=who;m.lock_target=who;m.confirmed=now();return end
 who=text:match('^Your attempts to control the will of (.+) are hopelessly incompetent, and you are forcibly ejected from .+ mind%.$')
 if who and norm(who)==norm(m.target or s.target.name) then m.status='idle';m.lock_target=nil;m.retry_at=now()+3;return end
 if m.eq_pending and (text=='You must regain balance first.' or text=='You must regain equilibrium first.') then m.eq_pending=nil;m.fault=nil;m.last_blackout=m.previous_blackout or -1000;m.blackout_retry=now()+.5;return end
 if text=='You require a mindlock to perform that ability.' then m.status='idle';m.lock_target=nil;m.eq_pending=nil;m.retry_at=now()+3;return end
 if text=='You are already maintaining a mindlock.' then
  if m.status~='locked' then m.status='unknown';m.retry_at=now()+10 end
 end
end
function M.tick(s,sender,paused_health)
 paused_health=paused_health or s.walker and (s.walker.pending or s.walker.dispatching or s.walker.physical_dispatch or s.walker.arrival_hold)
 if s.buffs and s.buffs.pending then return false end
 local m=M.state(s);local p=s.player;local t=now()
 if s.training_battle_ended then return false end
 -- Service an EQ cast even after a mode change; never invent readiness on a timeout.
 if m.eq_pending then
  if not p.equilibrium then m.saw_eq_loss=true end
  if p.equilibrium and (m.saw_eq_loss or (s.recoveries.equilibrium or 0)>(m.eq_snapshot or 0)) then m.eq_pending=nil;m.saw_eq_loss=nil
  elseif t-m.eq_pending>8 then m.fault='Telepathy acknowledgement missing; inspect trace and cv2 reset' end
 end
 if s.mode~='FULL_AUTO' then return m.eq_pending~=nil end
 if p.mounted==true or (tonumber(p.mounted) or 0)>0 or s.dismount_stance then return false end
 if M.defense and M.defense.hold(s) then return false end
 if paused_health or ((tonumber(p.maxhp) or 0)>0 and 100*(tonumber(p.hp) or 0)/p.maxhp<((s.config or {}).health_pause or 30)) then return false end
 if not s.connected or p.dead or (tonumber(p.hp) or 0)<=0 or p.prone or p.afflictions.paralysis or p.afflictions.asleep or p.afflictions.frozen then return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false end end
 local target=s.target.name
 if not target or s.target.dead or not target:match("^[%a][%a'%-]*$") then return false end
 -- Only acquire/use a lock against the explicitly selected player currently here.
 if not s.policy or not s.policy.players_known or not s.policy.players[norm(target)] then return false end
 if m.fault or m.eq_pending then return true end
 if m.needs_cease then m.needs_cease=nil;pcall(sender or send,'mind cease');m.retry_at=t+.5;return false end
 local restore=s.target.restoration
 if m.kaido~=false and p.equilibrium and p.balance and (tonumber(p.kai) or 0)>=40+((s.config or {}).defense_kai_reserve or 20) and p.defences.kai_trance and
    not (p.afflictions.left_arm_crippled and p.afflictions.right_arm_crippled) and
    restore and restore.active and t-restore.started>=.4 and t-restore.started<=1.2 and t-(m.last_kai or -1000)>=8 then
  m.last_kai=t;m.eq_pending=t;m.eq_snapshot=s.recoveries.equilibrium or 0;m.saw_eq_loss=false
  local command='kai cripple '..target;local ok,err=pcall(sender or send,command)
  if not ok then m.fault=tostring(err) end
  s.history[#s.history+1]={time=t,kind='mental_send',target=target,detail=command};while #s.history>100 do table.remove(s.history,1)end
  s.stats.sent=(s.stats.sent or 0)+1;return true
 end
 if m.status=='acquiring'  or m.status=='requested' then
  if t-(m.progress or m.started or t)>120 then m.status='idle';m.retry_at=t+5 end
  return false
 end
 if m.status=='unknown' and t>=m.retry_at then m.status='idle' end
 local command
 if m.enabled and m.status=='locked' and norm(m.lock_target)==norm(target) then
  if p.equilibrium and p.balance and p.left_arm_balance and p.right_arm_balance and t>=(m.blackout_retry or 0) and (tonumber(p.mana) or 0)>=1000 and (not M.defense or M.defense.mana_safe(s,1000)) and t-m.last_blackout>=25 then
   command='mind blackout';m.previous_blackout=m.last_blackout;m.last_blackout=t;m.eq_pending=t;m.eq_snapshot=s.recoveries.equilibrium or 0;m.saw_eq_loss=false
  end
 elseif m.enabled and m.status=='idle' and t>=m.retry_at then
  command='mind lock '..target;m.target=target;m.status='requested';m.started=t;m.progress=t
 end
 if command then
  local ok,err=pcall(sender or send,command)
  if not ok then m.fault='Mind sender error: '..tostring(err);return true end
  s.history[#s.history+1]={time=t,kind='mental_send',target=target,detail=command};while #s.history>100 do table.remove(s.history,1)end
  s.stats.sent=(s.stats.sent or 0)+1
 end
 return m.eq_pending~=nil
end
return M
