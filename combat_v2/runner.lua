local M={}
local function now() return getEpoch and getEpoch() or os.clock() end
local function yes(x) return x==true or tonumber(x)==1 end
local function cfg(r,k,default) return r.state.config and r.state.config[k] or default end
local function connected(s)
 if not s.connected then return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();return tcp==true end
 return true
end
function M.bind_policy(fn) M.policy=fn end
function M.bind_defense(fn) M.defense=fn end
function M.bind_classes(r,router)
 M.class_router=router;r.class_router=router;r.monk=router;router.sync_transport(r.state)
 local c=combat_v2
 local e=router.modules and router.modules.Earthcaller
 if c and c.current==r.state and c.runner_module==M and e and e.bind_runtime then e.bind_runtime(c,M.policy)end
end
function M.new(s,monk) return {state=s,monk=M.class_router or monk,class_router=M.class_router,mode="OFF",waiting=false,enabled=true,last_send=-100,cooldown=.3,status="OFF"} end
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
 local e=r.class_router and r.class_router.modules.Earthcaller
 if e and e.physical_stop then e.physical_stop(r.state) end
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
  if r.mode=="BASH" then r.fault="Attack acknowledgement timed out; cv2 reset after review";r.status=r.fault;return false end
  M.stop(r,"attack acknowledgement timed out; inspect cv2 trace");return true
 end
 return false
end
function M.execute(r,a,approved)
 local s,p=r.state,r.state.player
 local function deny(msg) r.status=msg;return false,msg end
 if r.class_router then
  s.mode=r.mode;s.clock=now();if s.shapeshifter then s.shapeshifter.now=s.clock end
  local ok,canonical=r.class_router.validate(s,a);if not ok then return deny(canonical)end;a=canonical
 end
 if s.walker and (s.walker.pending or s.walker.dispatching or s.walker.physical_dispatch or s.walker.arrival_hold) then return deny("WALK location/evidence unresolved") end
 if r.mode=="OFF" or r.mode=="SHADOW" then return deny(r.mode) end
 if s.buffs and s.buffs.pending then return deny("BUFF action unresolved; await confirmation/recovery or reviewed reset") end
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
 if now()-r.last_send<r.cooldown then return deny("cooldown") end
 if r.mode=="ASSIST" and not approved then r.pending=a;return deny("approval required") end
 local sender=r.sender or send
 r.waiting=true;r.saw_unready=false;r.waiting_requires=a.requires;r.last_send=now();r.pending=nil;r.state.last_action=a;r.status="sent: "..a.command
 r.waiting_dismount=a.name=="dismount" or nil
 if r.waiting_dismount then s.dismount_stance=a.after_stance elseif s.dismount_stance==tostring(p.stance or ""):lower() then s.dismount_stance=nil end
 r.waiting_stance=a.stance;r.stance_free_snapshot=s.stance_free_sequence or 0
 r.recovery_snapshot={equilibrium=(s.recoveries or {}).equilibrium or 0};for key,n in pairs(s.recoveries or {}) do r.recovery_snapshot[key]=n end
 r.reject_snapshot=s.reject_sequence or 0;if a.name~="dismount" then s.target.attacked_generation=s.target_generation;s.target.last_attack_at=now() end
 -- A synchronous combat sender may deliver recovery before it returns.
 -- That is not permission for a nested walker hop or another attack.
 local physical=s.walker and {};if physical then s.walker.physical_dispatch=physical end
 if r.class_router then
  local valid,canonical=r.class_router.commit(s,a)
  if not valid then if physical and s.walker.physical_dispatch==physical then s.walker.physical_dispatch=nil end;r.waiting=false;return deny(canonical)end
  a=canonical
 end
 local earth_owner=r.class_router and r.class_router.modules.Earthcaller
 if (a.name=='earth_quash' or a.name=='earth_rewield' or a.name=='earth_graft') and earth_owner and not earth_owner.transport_begin(s) then
  return deny('Earthcaller issued identity missing; retained unknown')
 end
 local earth=r.class_router and r.class_router.modules.Earthcaller
 local transaction=earth and s.earthcaller and s.earthcaller.physical
 local command=a.command;local batch=false
 if a.name=='earth_quash' and transaction then
  -- Commit both legs BEFORE a single native Mudlet separator-expanded send.
  -- Server prompts remain server output, never an admission wait for Splinter.
  local hold=M.defense and M.defense(s)
  local safe=M.policy and M.policy(s)
  local separator=type(getCommandSeparator)=='function' and getCommandSeparator()
  if type(separator)=='string' and #separator>0 and not separator:find('[%w%s]')
   and not hold and safe and r.mode=='BASH' and s.mode=='BASH'
   and connected(s) and not r.fault and not(s.buffs and s.buffs.pending)
   and not(s.walker and(s.walker.pending or s.walker.dispatching or s.walker.arrival_hold))
   and earth.pair_commit(s) then
   command=command..separator..'OSSO SPLINTER';batch=true
  end
 end
 local ok,err=pcall(sender,command)
 if (a.name=='earth_quash' or a.name=='earth_rewield' or a.name=='earth_graft') and transaction then
  earth.transport_result(s,a.name=='earth_graft' and 'graft' or a.name=='earth_rewield' and 'rewield' or 'quash',ok,err)
  if batch then
   earth.transport_result(s,'splinter',ok,err)
   if ok and err==true then
    if s.stats then s.stats.sent=s.stats.sent+1 end
    if s.history then s.history[#s.history+1]={time=now(),kind='send',target=s.target.name,detail='OSSO SPLINTER',reason='owned separator-batched Quash pair',generation=s.target_generation}end
   end
  end
  if a.name=='earth_graft' and ok and err==true and r.mode=='BASH' and s.mode=='BASH' then
   -- One activation readback, not per-swing polling. The same Runner owns IO.
   local counted,result=pcall(sender,'OSSO COUNT')
   transaction.graft.count_transport=counted and result==true
   if not transaction.graft.count_transport then transaction.unknown='Graft COUNT transport unresolved' end
  end
  transaction.dispatching=false
  if transaction.unknown then
   r.waiting=true;r.fault='Earthcaller transport unresolved: '..transaction.unknown;r.status=r.fault
   if physical and s.walker.physical_dispatch==physical then s.walker.physical_dispatch=nil end
   return false,r.status
  end
 end
 if physical and s.walker.physical_dispatch==physical then s.walker.physical_dispatch=nil end
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
 if r.state.earthcaller and r.state.earthcaller.physical then return end
 if r.waiting then
  if r.waiting_dismount then if r.state.player.mounted==false and M.ready(r,r.waiting_requires) then r.waiting=false;r.waiting_dismount=nil end;return end
  if r.waiting_stance and tostring(r.state.player.stance or ""):lower()==r.waiting_stance and (r.waiting_stance=="eagle" or (r.state.stance_free_sequence or 0)>(r.stance_free_snapshot or 0)) and M.ready(r,r.waiting_requires) then r.waiting=false;r.waiting_stance=nil;return end
  if (r.state.reject_sequence or 0)>(r.reject_snapshot or 0) then r.waiting=false;r.saw_unready=false;return end
  local requirements=r.waiting_requires or {balance=true,left_arm_balance=true,right_arm_balance=true}
  local physical=false
  for key,needed in pairs(requirements) do if needed and key~="equilibrium" then physical=true end end
  -- Physical recipes commonly REQUIRE EQ without consuming it. Preserve their
  -- arm/kick contract; an EQ-only recipe must instead witness EQ recovery.
  -- A retained transaction without a transport snapshot is unknown, not ready.
  if not physical and requirements.equilibrium and type((r.recovery_snapshot or {}).equilibrium)~="number" then return end
  local recovered=true
  for key,needed in pairs(requirements) do
   if needed and (key~="equilibrium" or not physical) and ((r.state.recoveries or {})[key] or 0)<=((r.recovery_snapshot or {})[key] or 0) then recovered=false end
  end
  if recovered and M.ready(r,r.waiting_requires) then r.waiting=false;r.saw_unready=false;return end
  if not M.ready(r,r.waiting_requires) then r.saw_unready=true
  elseif r.saw_unready then r.waiting=false;r.saw_unready=false end
 end
end
function M.tick(r)
 M.update_balance(r)
 if M.watchdog(r) then return false,r.status end
 if r.mode=="OFF" then return false,r.status end
 return M.execute(r,M.propose(r))
end
return M
