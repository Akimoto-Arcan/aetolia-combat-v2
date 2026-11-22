local M={}
local function now() return getEpoch and getEpoch() or os.clock() end
local function yes(x) return x==true or tonumber(x)==1 end
local function cfg(r,k,default) return r.state.config and r.state.config[k] or default end
local function connected(s)
 if not s.connected then return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();return tcp==true end
 return true
end
local function sync_flurry_scope(r)
 local s,p=r.state,r.state.player;local f=s.hunting and s.hunting.flurry
 local frame=s.hunting and s.hunting.flurry_frame
 if frame and (now()-frame.created>2 or frame.lines>8 or frame.generation~=s.target_generation or frame.room~=(s.room and s.room.id) or r.mode~="BASH" or not connected(s) or p.dead) then s.hunting.flurry_frame=nil end
 if f and (r.mode~="BASH" or not connected(s) or p.dead or (tonumber(p.hp) or 0)<=0 or f.room~=(s.room and s.room.id) or f.generation~=s.target_generation) and r.monk.cancel_flurry then r.monk.cancel_flurry(s) end
end
function M.bind_policy(fn) M.policy=fn end
function M.bind_defense(fn) M.defense=fn end
function M.new(s,monk) return {state=s,monk=monk,mode="OFF",waiting=false,enabled=true,last_send=-100,cooldown=.3,status="OFF"} end
function M.ready(r,requirements)
 local p=r.state.player
 requirements=requirements or {balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true}
 for key,required in pairs(requirements) do if required and not yes(p[key]) then return false end end
 return true
end
function M.propose(r)
 r.state.mode=r.mode;local a=r.monk.choose(r.state);a.generation=r.state.target_generation;r.state.last_action=a;return a
end
function M.stop(r,reason)
 if r.monk.cancel_flurry then r.monk.cancel_flurry(r.state) end
 r.mode="OFF";r.state.mode="OFF";r.pending=nil;r.waiting=false;r.status=reason or "OFF";r.paused_health=false;r.fault=nil;r.state.dismount_stance=nil;r.waiting_dismount=nil
 if r.state.hunting then r.state.hunting.active=false end
end
function M.watchdog(r)
 if r.mode=="OFF" or r.mode=="SHADOW" then return false end
 -- Char.Vitals is event-driven, not a heartbeat; an idle timestamp is diagnostic only.
 if not connected(r.state) then
  if r.mode=="BASH" then r.status="BASH paused: disconnected";return false end
  M.stop(r,"not logged in / disconnected");return true
 end
 if r.waiting and now()-r.last_send>cfg(r,"ack_timeout",8) then
  if r.mode=="BASH" then
   if not r.fault then r.fault="Attack acknowledgement timed out; cv2 reset after review";r.flurry_timeout=r.waiting_flurry and r.fault or nil end
   r.status=r.fault;return false
  end
  M.stop(r,"attack acknowledgement timed out; inspect cv2 trace");return true
 end
 return false
end
function M.execute(r,a,approved)
 local s,p=r.state,r.state.player
 sync_flurry_scope(r)
 local function deny(msg) r.status=msg;return false,msg end
 if r.transport_commit then return deny("Transport commit unresolved; await sender completion or cv2 reset after review") end
 if r.mode=="OFF" or r.mode=="SHADOW" then return deny(r.mode) end
 if s.buffs and s.buffs.pending then return deny("BUFF action unresolved; await confirmation/recovery or reviewed reset") end
 if s.walker and s.walker.pending then return deny("WALK location unresolved; await arrival or cv2 reset after review") end
 if s.training_battle_ended then return deny("training battle ended; explicit mode re-arm required") end
 if r.fault then return deny(r.fault) end
 if r.mode=="BASH" then
  if not M.policy then return deny("BASH safety policy not initialized") end
  local ok,why=M.policy(s);if not ok then return deny(why) end
 end
 if r.mode=="BASH" and s.hunting and s.hunting.ih and s.hunting.ih.active then return deny("waiting for IH target confirmation") end
 if not connected(s) then return deny("not logged in / disconnected") end
 if (tonumber(p.hp) or 0)<=0 or p.dead then return deny("dead / no vitals") end
 if M.defense then local hold,why=M.defense(s);if hold then return deny("DEFENSE: "..why) end end
 if not s.target.name or s.target.dead or not tostring(s.target.name):match("^[%w%s'%-]+$") or tostring(s.target.name):find("[\r\n]") then return deny("no valid living target") end
 local pct=(tonumber(p.maxhp) or 0)>0 and 100*p.hp/p.maxhp or 100
 if r.mode=="BASH" then r.paused_health=false -- user policy: FIRSTAID heals while BASH keeps pressure
 else
  if pct<cfg(r,"health_pause",30) then r.paused_health=true end
  if r.paused_health then if pct<cfg(r,"health_resume",60) then return deny("low health pause (resume at "..cfg(r,"health_resume",60).."%)") end;r.paused_health=false end
 end
 if p.prone or p.afflictions.paralysis or p.afflictions.asleep then return deny("player hindered/prone; recover first") end
 if r.waiting then return deny("waiting for balance recovery") end
 if (p.mounted==true or (tonumber(p.mounted) or 0)>0) and not (a and a.name=="dismount" and a.command=="quickdismount") then return deny("mounted; confirm dismount before stance/attack") end
 if not a or type(a.command)~="string" or a.command=="" or a.command:find("[;\r\n]") then return deny(a and a.reason or "no valid action") end
 if a.generation and a.generation~=s.target_generation then return deny("stale action target") end
 if not M.ready(r,a.requires) then return deny("waiting for required balances") end
 if r.mode=="BASH" and (a.name=="flurry_strike" or a.name=="bash_strike" or (s.hunting and s.hunting.flurry)) then
  local current=r.monk.choose(s)
  if a.command~=current.command or a.name~=current.name or a.flurry~=current.flurry or a.flurry_index~=current.flurry_index or a.bash_variant~=current.bash_variant then return deny("stale BASH order; request fresh proposal") end
  a=current;a.generation=s.target_generation
  if not M.ready(r,a.requires) then return deny("waiting for required balances") end
 end
 if now()-r.last_send<(a.name=="flurry_strike" and 0 or r.cooldown) then return deny("cooldown") end
 if r.mode=="ASSIST" and not approved then r.pending=a;return deny("approval required") end
 local sender=r.sender or send
 r.waiting=true;r.saw_unready=false;r.waiting_requires=a.requires;r.last_send=now();r.pending=nil;r.state.last_action=a;r.status="sent: "..a.command
 r.loss_channels={};r.flurry_timeout=nil
 r.waiting_dismount=a.name=="dismount" or nil
 if r.waiting_dismount then s.dismount_stance=a.after_stance elseif s.dismount_stance==tostring(p.stance or ""):lower() then s.dismount_stance=nil end
 r.waiting_stance=a.stance;r.stance_free_snapshot=s.stance_free_sequence or 0
 r.recovery_snapshot={};for key,n in pairs(s.recoveries or {}) do r.recovery_snapshot[key]=n end
 r.reject_snapshot=s.reject_sequence or 0;if a.name~="dismount" then s.target.attacked_generation=s.target_generation;s.target.last_attack_at=now() end
 local committed=r.monk.begin_commit and r.monk.begin_commit(s,a)
 r.waiting_flurry=committed and committed.flurry and committed or nil
 -- Independent of physical waiting / cancellable attack intent: STOP cannot
 -- unsend an in-progress transport, and recovery cannot prove its outcome.
 r.transport_commit=committed or {}
 local ok,err=pcall(sender,a.command)
 if ok and err==false then ok=false;err="sender returned false (commit unknown)" end
 if r.monk.finish_commit then r.monk.finish_commit(s,committed,ok) end
 -- Retain unknown failed transports until explicit reviewed reset, even if
 -- a synchronous callback stopped the runner or cancelled the attack intent.
 if ok then r.transport_commit=nil end
 if not ok then if r.mode=="BASH" then r.fault="sender error: "..tostring(err);r.status=r.fault else M.stop(r,"sender error: "..tostring(err)) end;return false,r.status end
 if a.name=="sweep" then s.target.sweep_attempted=true end
 if s.stats then s.stats.sent=s.stats.sent+1 end
 if s.history then s.history[#s.history+1]={time=now(),kind="send",target=s.target.name,detail=a.command,reason=a.reason,generation=s.target_generation};while #s.history>100 do table.remove(s.history,1) end end
 return true,a.command
end
function M.approve(r)
 if r.mode~="ASSIST" or not r.pending then return false,"no pending action" end
 local pending=r.pending;local current=r.monk.choose(r.state)
 if pending.generation~=r.state.target_generation or pending.command~=current.command then r.pending=nil;return false,"proposal stale; request a fresh proposal" end
 return M.execute(r,pending,true)
end
function M.update_balance(r)
 if r.transport_commit then return end
 if r.waiting then
  if r.waiting_dismount then if r.state.player.mounted==false and M.ready(r,r.waiting_requires) then r.waiting=false;r.waiting_dismount=nil end;return end
  if r.waiting_stance and tostring(r.state.player.stance or ""):lower()==r.waiting_stance and (r.waiting_stance=="eagle" or (r.state.stance_free_sequence or 0)>(r.stance_free_snapshot or 0)) and M.ready(r,r.waiting_requires) then r.waiting=false;r.waiting_stance=nil;return end
  local c=r.waiting_flurry
  -- A failed/unfinished transport cannot be resolved by a coincident refusal.
  if c and (c.failed or not c.sent) then return end
  if (r.state.reject_sequence or 0)>(r.reject_snapshot or 0) then
   if r.state.tekura_inflight then r.state.tekura_inflight.rejected=true end
   if r.flurry_timeout and r.fault==r.flurry_timeout then r.fault=nil end
   r.flurry_timeout=nil
   r.waiting=false;r.saw_unready=false;r.waiting_flurry=nil;return
  end
  local observed_loss=false
  r.loss_channels=r.loss_channels or {}
  for key,needed in pairs(r.waiting_requires or {}) do
   if needed and not yes(r.state.player[key]) then r.loss_channels[key]=true end
   if key~="equilibrium" and r.loss_channels[key] then observed_loss=true end
  end
  local recovered=true
  for key,needed in pairs(r.waiting_requires or {balance=true,left_arm_balance=true,right_arm_balance=true}) do
   if needed and key~="equilibrium" and ((r.state.recoveries or {})[key] or 0)<=((r.recovery_snapshot or {})[key] or 0) then recovered=false end
  end
  if c then
   if M.ready(r,r.waiting_requires) and (recovered or observed_loss) then
    -- Recovery proves physical safety, NOT which ordered token executed.
    -- Abandon uncertain order instead of guessing or permanently stopping BASH.
    if not c.acknowledged and not c.cancelled then
     c.cancelled=true
     if r.state.hunting.flurry==c.flurry then r.state.hunting.flurry=nil end
    end
    r.waiting=false;r.saw_unready=false;r.waiting_flurry=nil
    if r.flurry_timeout and r.fault==r.flurry_timeout then r.fault=nil end
    r.flurry_timeout=nil;return
   end
   return
  end
  if recovered and M.ready(r,r.waiting_requires) then r.waiting=false;r.saw_unready=false;return end
  if not M.ready(r,r.waiting_requires) then r.saw_unready=true
  elseif r.saw_unready then r.waiting=false;r.saw_unready=false end
 end
end
function M.tick(r)
 sync_flurry_scope(r)
 if r.transport_commit then r.status="Transport commit unresolved; await sender completion or cv2 reset after review";return false,r.status end
 M.update_balance(r)
 if M.watchdog(r) then return false,r.status end
 if r.mode=="OFF" then return false,r.status end
 return M.execute(r,M.propose(r))
end
return M
