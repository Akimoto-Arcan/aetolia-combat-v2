local root=getMudletHomeDir().."/combat_v2/"
combat_v2=combat_v2 or {};local c=combat_v2
for _,key in ipairs({"gmcp_handler","text_handler"}) do if c[key] then killAnonymousEventHandler(c[key]);c[key]=nil end end
for _,id in ipairs(c.handlers or {}) do killAnonymousEventHandler(id) end
for _,key in ipairs({"line_trigger","prompt_trigger","buff_prompt_trigger"}) do if c[key] then killTrigger(c[key]) end end
for _,key in ipairs({"alias","target_alias"}) do if c[key] then killAlias(c[key]) end end
for _,key in ipairs({"retry_timer","watch_timer","ih_timer","buff_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
c.state=dofile(root.."state.lua");c.current=c.state.upgrade(c.current)
c.tracker=dofile(root.."tracker.lua");c.bashing=dofile(root.."bashing.lua");c.bashing.bind(c.state);c.mobs=dofile(root.."mobs.lua");c.bashing.bind_mobs(c.mobs)
c.monk=dofile(root.."monk.lua");c.monk.bind(c.tracker)
c.events=dofile(root.."events.lua");c.events.bind(c.tracker)
c.runner_module=dofile(root.."runner.lua");c.curing=dofile(root.."curing.lua");c.gui=dofile(root.."gui.lua")
c.policy=dofile(root.."policy.lua");c.policy.init(c.current,gmcp or {});c.runner_module.bind_policy(c.policy.attack_allowed)
c.runner=c.runner_module.new(c.current,c.monk);c.cure=(c.cure and c.cure.status) and c.cure or c.curing.new()
c.defense=dofile(root.."defense.lua");c.runner_module.bind_defense(c.defense.hold)
c.mental=dofile(root.."mental.lua");c.mental.bind_defense(c.defense);c.current.mental=nil;c.current.config.pvp_stance=c.current.config.pvp_stance or "eagle";c.current.config.finish_stance=c.current.config.finish_stance or "cobra"
c.mode="OFF";c.current.mode="OFF";c.current.hunting.active=false;c.current.stop_reason=nil
local function refresh() c.gui.refresh(c.current,c.runner,c.cure) end
-- Buff preparation/upkeep is separate from FIRSTAID's survival governor.
c.buffs=dofile(root.."buffs.lua");c.buffs.stop(c.current,"reload; upkeep disarmed");c.buff_class_seen=nil;c.buff_skill_seen=nil
local function buff_invalidate()
  local b=c.buffs.state(c.current);b.known={};b.known_ready=false;c.buff_skill_seen=nil
  b.native_priorities={};b.native_pending={};b.native_version=(b.native_version or 0)+1;b.native_listing=nil;b.native_status=nil;b.native_defences=nil
 if b.query and b.query.kind=="skills"then b.query=nil end
 if b.pending then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false end
 -- Fence cached payloads across class/session boundaries, including in-place GMCP tables.
 local skills=gmcp and gmcp.Char and gmcp.Char.Skills or {}
 c.buff_groups_seen=skills.Groups;c.buff_list_seen=skills.List
end
buff_invalidate();c.buff_groups_seen=nil;c.buff_list_seen=nil
local function buff_snapshot(source)
 local g=gmcp or {};local v=g.Char and g.Char.Vitals or {};local status=g.Char and g.Char.Status or {}
 local name=status.class
 if name and name~=c.buff_class_seen then
  if c.buff_class_seen~=nil then buff_invalidate()end
  c.buff_class_seen=name;c.buffs.set_class(c.current,name);c.current.player.class=name
 end
 for key,field in pairs({wp="willpower",maxwp="maxwillpower"})do if tonumber(v[key])then c.current.player[field]=tonumber(v[key])end end
 local skills=g.Char and g.Char.Skills or {}
 local groups,list=skills.Groups,skills.List
 -- Events also recognize payloads updated in place. Polling consumes new identities
 -- once only; a cached group cannot re-infer all after a restrictive List.
 local fresh_groups=source=="gmcp.Char.Skills.Groups" or groups~=c.buff_groups_seen
 local fresh_list=source=="gmcp.Char.Skills.List" or list~=c.buff_list_seen
 c.buff_groups_seen=groups;c.buff_list_seen=list
 if c.buffs.state(c.current).class~="monk"then return end
 if fresh_groups then
  local all=false
  for _,group in pairs(type(groups)=="table"and groups or {})do
   if type(group)=="table"and tostring(group.name):lower()=="kaido"then all=tostring(group.rank):lower():match("^transcendent")~=nil;break end
  end
  if all and c.buff_skill_seen~="kaido-list"then
   local names={};for _,entry in ipairs(c.buffs.catalog)do names[#names+1]=entry.key end
   c.buffs.set_known(c.current,names);c.buff_skill_seen="all-kaido"
  elseif not all and c.buff_skill_seen=="all-kaido"then
   local b=c.buffs.state(c.current);b.known={};b.known_ready=false;c.buff_skill_seen=nil
  end
 end
 if fresh_list and type(list)=="table"and tostring(list.group):lower()=="kaido"and type(list.list)=="table"then
  c.buffs.set_known(c.current,list.list);c.buff_skill_seen="kaido-list"
 end
end
-- Explicit event source is also the narrow hook for a handler-only loader.
c.buff_snapshot=buff_snapshot
local function buff_preferences(save)
 local path=root.."defup-settings.json";local d=c.buffs.state(c.current)
 if not yajl or not yajl.to_value or not yajl.to_string then return false,"JSON support unavailable; preferences not saved" end
 if not save then
  local file=io.open(path,"r");if not file then return true end
  local content=file:read("*a");file:close();local ok,data=pcall(yajl.to_value,content)
  if not ok or type(data)~="table"or data.version~=1 or type(data.wanted)~="table"then return false,"Invalid defense settings; safe defaults used" end
  for _,entry in ipairs(c.buffs.catalog)do if type(data.wanted[entry.key])=="boolean"then d.wanted[entry.key]=data.wanted[entry.key]end end
  return true
 end
 local wanted={};for _,entry in ipairs(c.buffs.catalog)do wanted[entry.key]=d.wanted[entry.key]==true end
 local encoded=yajl.to_string({version=1,wanted=wanted});local file,err=io.open(path..".new","w");if not file then return false,err end
 local wrote,why=file:write(encoded);file:close();if not wrote then return false,why end
 local ok,reason=os.rename(path..".new",path);if not ok then return false,reason end
 local check=io.open(path,"r");if not check then return false,"settings readback failed"end;local actual=check:read("*a");check:close()
 if actual~=encoded then return false,"settings readback mismatch"end
 return true
end
buff_snapshot();local prefs_ok,prefs_error=buff_preferences(false);if not prefs_ok then print(prefs_error)end
local function buff_timer()
 c.buff_timer=nil
 if c.buffs.has_work(c.current)then
  if not c.watch_timer then combat_v2_tick()end
  c.buff_timer=tempTimer(1,buff_timer)
 end
end
local function buff_dispatch(command)
 c.state.record(c.current,(command=="defences"or command=="ab kaido")and"buff_audit"or"buff_send",command)
 return (c.buff_sender or send)(command)
end
local function buff_wake()
 if c.buffs.has_work(c.current) and not c.buff_timer then c.buff_timer=tempTimer(1,buff_timer)end
end
function combat_v2_globe(action)
 action=tostring(action or"status"):lower()
 if not c.elementals then return false,"Globe recovery module unavailable"end
 local b=c.elementals.state(c)
 if action=="on"or action=="off"then
  if action=="on"and not b.attached then c.elementals.attach(c)end
  local ok=c.elementals.arm(c,action=="on");refresh();return ok,b.status
 elseif action~="status"then return false,"cv2 globe on|off|status"end
 print("GLOBE: "..(c.mode=="BASH"and b.armed and"ON"or"OFF").." - "..tostring(b.status));return true,b.status
end
function combat_v2_buffs(action,rest)
 action=(action or "status"):lower();rest=(rest or ""):lower():match("^%s*(.-)%s*$")
 if action=="defup"then action=rest~="" and rest or "start";rest=""end
 local ok,why=true,nil
 buff_snapshot()
 if action=="show"then return c.gui.show_defenses()end
 if action=="save"then local ok,why=buff_preferences(true);if ok then print("Defense choices saved; upkeep arm state is never saved")end;return ok,why end
 if action=="audit"then
  if not c.current.connected or c.current.player.dead then return false,"Disconnected: defense audit unavailable"end
  if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false,"Disconnected"end end
  send("ab kaido");send("defences");send("firstaid");send("firstaid priority defence list");return true,"Read-only defense/ability/native FIRSTAID audit requested"
 elseif action=="native"then
   local key,value=rest:match("^([%a_]+)%s+(%a+)$")
   if not key or not c.buffs.native_catalog or not c.buffs.native_catalog[key] or (value~="on"and value~="off")then return false,"Native defense requires a supported name and on|off"end
   if c.mode=="SHADOW"then return false,"SHADOW is read-only"end
   if not c.current.connected or c.current.player.dead or (tonumber(c.current.player.hp)or 0)<=0 then return false,"Disconnected/dead: native defense configuration unavailable"end
   if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false,"Disconnected"end end
   if c.buffs.native_priority(c.current,key)==nil then return false,"Native priorities unknown; use defup audit first"end
   local priority=value=="off"and 26 or c.buffs.native_enable_priority(c.current,key)
   if type(priority)~="number"or priority%1~=0 or priority<1 or priority>26 or (value=="on"and priority==26)then return false,"Invalid native priority"end
   local command="firstaid priority defence "..key.." "..priority
   if not c.buffs.native_request(c.current,key,priority)then return false,"Native priorities unknown; use defup audit first"end
   local sent,result=pcall(c.buff_sender or send,command)
   if not sent or result==false then return false,"Native defense setting failed; readback required"end
   c.state.record(c.current,"buff_native",command)
   local queried,qresult=pcall(c.buff_sender or send,"firstaid priority defence list")
   if not queried or qresult==false then return false,"Setting requested but readback failed; use defup audit"end
   return true,"Native priority requested; server readback required. Global FIRSTAID switches unchanged."
 elseif action=="status"then
  local d=c.buffs.state(c.current);print("DEFUP: "..tostring(c.buff_status or d.status or "idle").."; upkeep="..tostring(d.master))
  for _,entry in ipairs(c.buffs.catalog)do print(entry.key.." wanted="..tostring(d.wanted[entry.key]).." active="..tostring(d.have and d.have[entry.key]or false)..(entry.drain and " [DRAIN / OPT-IN]"or""))end;return true
 elseif action=="stop"then c.buffs.stop(c.current,"defup/upkeep stopped; committed action still acknowledged")
 elseif action=="reset"then combat_v2_stop("reviewed defup reset");c.buffs.reset(c.current);c.buff_status="Reviewed reset; combat/upkeep OFF"
 elseif action=="start"then
  if c.mode=="SHADOW"then return false,"SHADOW is read-only; use cv2 off before defup"end
  ok,why=c.buffs.start(c.current)
 elseif action=="keep"then
  if rest=="on"or rest=="off"then
   if rest=="on"and c.mode=="SHADOW"then return false,"SHADOW is read-only; use cv2 off first"end
   ok,why=c.buffs.master(c.current,rest=="on")
   if rest=="off"then print("Upkeep paused; active drains remain. Use defkeep NAME off to cancel a specific supported defense.")end
  else
   local key,value=rest:match("^([%a_]+)%s+(%a+)$")
   if not key or (value~="on"and value~="off")then return false,"defkeep on|off|NAME on|off"end
   if c.mode=="SHADOW"then return false,"SHADOW is read-only; use cv2 off first"end
   if c.buffs.native_catalog and c.buffs.native_catalog[key]then return combat_v2_buffs("native",rest)end
   ok,why=c.buffs.toggle(c.current,key,value=="on")
   if ok then local saved,err=buff_preferences(true);if not saved then print("Defense choice applied but NOT saved: "..tostring(err))end end
  end
 else return false,"defup [status|stop|audit|reset]; defkeep on|off|NAME on|off; cv2 defs"end
 if not ok then return false,why end
 buff_wake();combat_v2_tick();if why then print(why)end;return true,why
end

local function cancel_ih()
 if c.ih_timer then killTimer(c.ih_timer);c.ih_timer=nil end
 local scan=c.current.hunting.ih;if scan then scan.active=false;scan.pending=false end
end
local function enter_room_watch()
 local s=c.current;local scan=s.hunting.ih;cancel_ih()
 s.hunting.watch={room_id=s.room.id,checked_version=scan and scan.start_version or (s.room.item_version or 0)};s.hunting.verified_generation=nil
 c.runner.status="BASH armed: 3 IH checks exhausted; watching GMCP room updates"
 c.state.record(s,"ih_watch","3 checks exhausted; quiet GMCP watch");refresh();return false,c.runner.status
end
-- Failed IH checks retry at most three times, then wait for real room updates.
function combat_v2_ih_result()
 local s=c.current;local scan=s.hunting.ih
 if c.mode~="BASH" or not scan or not scan.active or not scan.pending or not scan.responded then return false end
 local ok,why=c.bashing.ih_select(s)
 if ok then
  cancel_ih();s.hunting.verified_generation=s.target_generation
  c.runner.status="IH confirmed target "..tostring(s.target.name);c.state.record(s,"ih_found",s.target.name)
  return combat_v2_tick()
 end
 if scan.attempts>=3 then scan.last_failure=why;return enter_room_watch() end
 scan.last_failure=why;c.state.record(s,"ih_miss",scan.attempts.."/3: "..why)
 c.runner.status="BASH armed: no matching target; IH check "..scan.attempts..", retry in 2s";refresh();return false
end
function combat_v2_request_ih()
 local s=c.current;local scan=s.hunting.ih
 if c.mode~="BASH" or not scan or not scan.active then return false end
 if not s.connected or (tonumber(s.player.hp) or 0)<=0 or s.player.dead then cancel_ih();c.runner.status="BASH paused: disconnected / dead";refresh();return false end
 local safe,reason=c.policy.allowed(s);if not safe then cancel_ih();c.runner.status=reason;refresh();return false end
 if scan.attempts>=3 then return enter_room_watch() end
 if not c.bashing.ih_request(s) then return false end
 c.runner.status="Checking IH "..scan.attempts;c.state.record(s,"ih_request",scan.attempts.."/3")
 c.ih_timer=tempTimer(2,function()
  if c.mode~="BASH" or c.current.hunting.ih~=scan or not scan.active then return end
  c.ih_timer=nil
  if scan.pending then scan.pending=false;scan.last_failure="IH response unavailable";c.state.record(s,"ih_timeout",scan.attempts.."/3") end
  combat_v2_request_ih()
 end)
 local ok,why=pcall(function()
  -- IH does not refresh an unchanged item list by itself. Aetolia flushes
  -- this explicit GMCP request when the following IH produces its prompt.
  sendGMCP([[Char.Items.Room ""]])
  local sender=c.ih_sender or send;sender("ih")
 end)
 if not ok then cancel_ih();c.runner.fault="IH send failed: "..tostring(why);c.runner.status=c.runner.fault;refresh();return false end
 refresh();return true
end
function combat_v2_start_ih(reason,force)
 if c.mode~="BASH" then return false end
 if force then c.current.hunting.watch=nil end
 if c.current.hunting.watch then return false,"watching GMCP room updates" end
 local scan=c.current.hunting.ih
 if scan and scan.active then return false,"IH already pending" end
 cancel_ih();c.bashing.ih_begin(c.current);c.runner.pending=nil
 if c.retry_timer then killTimer(c.retry_timer);c.retry_timer=nil end
 c.state.record(c.current,"ih_begin",reason or "target verification")
 return combat_v2_request_ih()
end
function combat_v2_stop(reason)
 if c.elementals then c.elementals.arm(c,false)end
 c.buffs.stop(c.current,reason or "OFF; upkeep disarmed")
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"OFF")end
 cancel_ih();c.current.hunting.watch=nil
 if c.current.training_battle_ended then
  local m=c.current.mental
  if m then if m.target then pcall(send,"mind cease") end;m.status="stopped";m.target=nil;m.lock_target=nil;m.eq_pending=nil end
 end
 c.runner_module.stop(c.runner,reason);c.mode="OFF";c.current.stop_reason=nil
 c.current.stats.stops=c.current.stats.stops+1;c.state.record(c.current,"stop",reason or "OFF")
 for _,key in ipairs({"retry_timer","watch_timer","ih_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
 refresh();return true
end
local function watchdog()
 c.watch_timer=nil
 if c.mode=="BASH" or c.mode=="FULL_AUTO" then combat_v2_tick()
 elseif c.runner_module.watchdog(c.runner) then combat_v2_stop(c.runner.status);return end
 if c.mode~="OFF" and c.mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
end
function combat_v2_area_approve(visit,yes)
 local ok,why=c.policy.approve(c.current,visit,yes~=false)
 if ok then combat_v2_tick() end
 return ok,why
end
local function area_prompt()
 local p=c.current.policy
 if p.areas_loaded and not c.policy.area_allowed(c.current) and p.prompted~=p.visit then
  p.prompted=p.visit
  print("BASH PAUSED: "..tostring(c.current.room.area).." is not in AREAS. Enable bashing for this area visit?")
  if echoLink then
   echoLink("[Enable here] ","combat_v2_area_approve("..p.visit..",true)","Approve only this area visit",true)
   echoLink("[Keep paused]\n","combat_v2_area_approve("..p.visit..",false)","Do not attack here",true)
  else print("cv2 area yes / cv2 area no") end
 end
end
function combat_v2_tick()
 local s=c.current;buff_snapshot()
 if s.stop_reason then
  if s.stop_reason=="training battle ended" then combat_v2_stop(s.stop_reason);return false,"training battle ended" end
  if s.stop_reason=="target slain" and c.mode=="BASH" and s.hunting.active then
   s.stop_reason=nil;local ok=c.bashing.killed(s)
   if not ok then s.hunting.active=true;s.stop_reason=nil end
   combat_v2_start_ih("target slain; refresh room");return false,"checking IH"
  elseif c.mode=="BASH" and (s.stop_reason=="target unavailable" or s.stop_reason=="target left room; confirmation required") then
   local why=s.stop_reason;s.stop_reason=nil
   if why=="target unavailable" then c.runner.waiting=false end
   combat_v2_start_ih(why);return false,"checking IH"
  elseif c.mode=="BASH" then local why=s.stop_reason;s.stop_reason=nil;cancel_ih();c.runner.status="BASH paused: "..why;refresh();return false,why
  else local why=s.stop_reason;combat_v2_stop(why);return false,why end
 end
 local defense=c.defense.service(s,c.defense_sender or send)
 c.runner_module.update_balance(c.runner)
 local flurry_hold=c.mode=="BASH"and c.monk.flurry_active and c.monk.flurry_active(s)
 local buffs=c.buffs.service(s,c.runner,buff_dispatch,defense.hold or flurry_hold);c.buff_status=buffs.status
 if buffs.busy then c.runner.status="DEFUP: "..tostring(buffs.status);refresh();return false,c.runner.status end
 if defense.hold and (c.mode=="FULL_AUTO" or c.mode=="BASH") then c.runner_module.update_balance(c.runner);c.runner.pending=nil;c.runner.status="DEFENSE: "..defense.phase;refresh();return false,c.runner.status end
 if c.mode=="BASH" then
  c.runner_module.update_balance(c.runner);c.runner_module.watchdog(c.runner)
  if c.runner.fault then cancel_ih();c.runner.status=c.runner.fault;refresh();return false,c.runner.fault end
  for _,command in ipairs(c.policy.services(s)) do send(command) end
  local safe,why=c.policy.allowed(s)
  if not safe or not s.connected or s.player.dead or (tonumber(s.player.hp) or 0)<=0 then
   cancel_ih();s.hunting.verified_generation=nil;c.runner.pending=nil
   c.runner.status=not s.connected and "BASH paused: disconnected" or s.player.dead and "BASH paused: dead" or why
   area_prompt();refresh();return false,c.runner.status
  end
  if s.hunting.ih and s.hunting.ih.active then refresh();return false,"checking IH" end
  local watch=s.hunting.watch
  if watch then
   if watch.room_id~=s.room.id then s.hunting.watch=nil
   else
    local version=s.room.item_version or 0
    if version>(watch.checked_version or 0) then
     watch.checked_version=version
     if c.bashing.watch_select(s) then s.hunting.verified_generation=s.target_generation;c.state.record(s,"gmcp_found",s.target.name) end
    end
    if s.hunting.watch then c.runner.status="BASH armed: watching GMCP room updates (IH 3/3)";refresh();return false,c.runner.status end
   end
  end
  if not s.target.name or s.target.dead or s.hunting.verified_generation~=s.target_generation then combat_v2_start_ih("verify bashing target");return false,"checking IH" end
 end
 if c.mental.tick(s,c.mental_sender or c.runner.sender or send,c.runner.paused_health) then c.runner_module.update_balance(c.runner);refresh();return false,"Telepathy equilibrium pending" end
 local ok,why=c.runner_module.tick(c.runner);c.mode=c.runner.mode;s.mode=c.mode
 if why=="cooldown" and not c.retry_timer then c.retry_timer=tempTimer(.35,function() c.retry_timer=nil;combat_v2_tick() end) end
 refresh();return ok,why
end
function combat_v2_set_mode(mode)
 mode=string.upper(mode or "OFF");if mode=="AUTO" or mode=="PVP" then mode="FULL_AUTO" end
 if not ({OFF=true,SHADOW=true,ASSIST=true,BASH=true,FULL_AUTO=true})[mode] then return false,"invalid mode" end
 if c.monk.cancel_flurry and mode~=c.mode then c.monk.cancel_flurry(c.current,"mode changed")end
 if mode~="BASH"and c.elementals then c.elementals.arm(c,false)end
 if mode=="OFF" then return combat_v2_stop() end
 cancel_ih();c.current.hunting.watch=nil
 if c.current.training_battle_ended then c.current.training_battle_ended=nil;c.current.mental=nil end
 c.current.dismount_stance=nil
 if mode=="SHADOW"then c.buffs.stop(c.current,"SHADOW; upkeep disarmed")end
 c.mode=mode;c.runner.mode=mode;c.current.mode=mode;c.runner.pending=nil;c.current.hunting.active=false
 if mode=="BASH" then
  local ok=c.bashing.start(c.current);if not ok then c.current.hunting.active=true;c.current.stop_reason=nil end
  c.current.hunting.verified_generation=nil
 end
 if not c.watch_timer and mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
 return combat_v2_tick()
end
function combat_v2_reset_enemy_afflictions()
 local ok,why=c.tracker.clear_afflictions(c.current)
 if not ok then return false,why end
 c.runner.pending=nil
 if combat_v2_ui and combat_v2_ui.pages then combat_v2_ui.pages.enemy_afflictions=1 end
 c.state.record(c.current,"enemy_reset","cleared enemy afflictions/injury flags; preserved trauma and target")
 refresh();return true
end
function combat_v2_set_target(name)
 local previous=c.current.target_generation
 local ok,why=c.state.set_target(c.current,name)
 if ok then
  c.runner.pending=nil
  if c.current.target_generation~=previous and c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"manual target changed")end
  if c.current.target_generation~=previous then c.current.hunting.watch=nil;c.current.hunting.target_name=nil;c.current.hunting.killed_ids={};c.current.hunting.query=c.current.target.name end
 end
 refresh();return ok,why
end
function combat_v2_approve() local ok,why=c.runner_module.approve(c.runner);refresh();return ok,why end
function combat_v2_defense(cmd)
 local s=c.current;cmd=cmd~="" and cmd or "status"
 if cmd=="audit" then return c.defense.audit(s,c.defense_sender or send)
 elseif cmd=="setup" then combat_v2_stop("Explicit defensive FIRSTAID setup");return c.defense.setup(s,c.defense_sender or send)
 elseif cmd=="on" or cmd=="off" then s.config.defense_enabled=cmd=="on";refresh();return true
 elseif cmd~="status" then return false,"cv2 defense status|audit|setup|on|off" end
 local d=c.defense.plan(s);print("DEFENSE: "..d.phase.." (hold="..tostring(d.hold)..")")
 for channel,b in pairs(d.blocked)do print("FIRSTAID blocked "..channel.." curing "..b.aff.." at "..b.time)end
 for _,a in ipairs(d.proposals)do print("Proposed: "..a.command)end
 print("Class emergency skills require live AB verification; none auto-enabled")
 return true
end
function combat_v2_set_curing(on) local ok,why=c.curing.set(c.cure,c.current,on==true);refresh();return ok,why end
function combat_v2_reset_wait()
 -- Deliberate manual recovery; never release wait from a timer alone.
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"reviewed reset")end
 c.defense.reset(c.current);c.mental.reset(c.current);c.runner.fault=nil;c.runner.waiting=false;c.runner.pending=nil;c.runner.last_send=-100;c.runner.status="manually reset";c.state.record(c.current,"reset","manual waiting reset");refresh()
end
function combat_v2_propose() local a=c.runner_module.propose(c.runner);refresh();return a end
function combat_v2_observe(e)
 local ok,why=c.tracker.apply(c.current,e)
 if ok then c.state.record(c.current,"observation",e.kind);combat_v2_tick() else refresh() end
 return ok,why
end
function combat_v2_track(kind,key,value)
 local e={kind=kind,target=c.current.target.name,source="manual",confidence=1,generation=c.current.target_generation}
 if kind=="limb" or kind=="damage" then e.limb=key;e.amount=tonumber(value)
 elseif kind=="parry" then e.limb=key
 elseif kind=="aff" then e.kind="affliction";e.name=key;if value~="on" and value~="off" then return false,"use aff NAME on|off" end;e.value=value=="on"
 elseif kind=="broken" or kind=="mangled" or kind=="crippled" then e.limb=key;if value~="on" and value~="off" then return false,"use MARKER LIMB on|off" end;e.value=value=="on"
 elseif kind=="prone" or kind=="shield" or kind=="rebounding" then if key~="on" and key~="off" then return false,"use "..kind.." on|off" end;e.value=key=="on"
 else return false,"track limb/damage LIMB NUMBER; aff NAME on|off; parry LIMB|none; prone/shield/rebounding on|off; broken/crippled/mangled LIMB on|off" end
 return combat_v2_observe(e)
end
function combat_v2_set_route(route)
 if not ({legs=true,arms=true,head=true,torso=true,balanced=true})[route] then return false,"route legs|arms|head|torso|balanced" end
 c.current.config.route=route;c.runner.pending=nil;c.state.record(c.current,"route",route);refresh();return true
end
function combat_v2_config(key,value)
 if key=="pvp_stance" or key=="finish_stance" then if not ({eagle=true,cobra=true,dragon=true,tiger=true,wolf=true,scorpion=true,manual=true})[value] then return false,"stance eagle|cobra|dragon|tiger|wolf|scorpion|manual" end;c.current.config[key]=value;c.runner.pending=nil;refresh();return true end
 if key=="kaido" then if value~="on" and value~="off" then return false,"kaido on|off" end;c.mental.state(c.current).kaido=value=="on";return true end
 if key=="mindlock" then if value~="on" and value~="off" then return false,"mindlock on|off" end;c.mental.state(c.current).enabled=value=="on";return true end
 if key=="training_reports" then
  if value=="off" then c.current.training=nil;return true end
  if value~="on" or not c.current.target.name then return false,"select a target; training_reports on|off" end
  local present=false;for _,item in pairs(c.current.room.items)do if tostring(item.name):lower()=="a runed target dummy" then present=true end end
  if not present then return false,"No reporting runed target dummy in this room" end
  c.current.training={enabled=true,target=c.current.target.name,generation=c.current.target_generation,room=c.current.room.id};return true
 end
 if key=="group_web" then if value~="on" and value~="off" then return false,"group_web on|off" end;c.current.policy.group_web=value=="on";c.current.policy.web.at=nil;combat_v2_tick();return true end
 if key=="estimate_trauma" then
  if value~="on" and value~="off" then return false,"estimate_trauma on|off" end
  c.current.config.estimate_trauma=value=="on";return true
 end
 local bounds={defense_health_pause={1,94},defense_health_resume={2,100},defense_mana_reserve={0,90},defense_kai_reserve={0,80},health_pause={1,95},health_resume={2,100},ack_timeout={2,60},parry_ttl={1,60},parry_min_confidence={0,1},kick_trauma={0,100},punch_trauma={0,100},boost_kick_trauma={0,100},boost_punch_trauma={0,100}}
 local b=bounds[key];local n=tonumber(value)
 if not b or not n or n~=n or n<b[1] or n>b[2] then return false,"invalid config value/key" end
 local cfg=c.current.config
 if key=="defense_health_pause" and n>=(cfg.defense_health_resume or 65) or key=="defense_health_resume" and n<=(cfg.defense_health_pause or 45) then return false,"defense resume must exceed pause" end
 if key=="health_pause" and n>=cfg.health_resume or key=="health_resume" and n<=cfg.health_pause then return false,"resume must exceed pause" end
 cfg[key]=n;c.state.record(c.current,"config",key.."="..n);return true
end
function combat_v2_status()
 local s=c.current;print("Combat V2 "..c.mode.." route="..s.config.route.." target="..tostring(s.target.name).." status="..tostring(c.runner.status))
 print("sent="..s.stats.sent.." observations="..s.stats.observed.." kills="..s.hunting.kills.." queued="..#s.hunting.queue.." last vitals="..tostring(s.vitals_at))
end
function combat_v2_trace(n)
 local h=c.current.history;n=math.min(100,math.max(1,tonumber(n) or 12))
 for i=math.max(1,#h-n+1),#h do local e=h[i];print(tostring(e.time).." "..e.kind.." ["..tostring(e.target).."] "..tostring(e.detail)) end
end
c.handlers={}
local function handler(event,fn) c.handlers[#c.handlers+1]=registerAnonymousEventHandler(event,fn) end
handler("gmcp.Char.Vitals",function() c.state.sync_gmcp(c.current,gmcp);combat_v2_tick() end)
for _,kind in ipairs({"Groups","List"})do
 local event="gmcp.Char.Skills."..kind
 handler(event,function()buff_snapshot(event);combat_v2_tick()end)
end
handler("sysDisconnectionEvent",function()
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"disconnect")end
 c.buffs.stop(c.current,"disconnect; upkeep disarmed");buff_invalidate();local b=c.buffs.state(c.current);b.defs_known=false;b.defs_at=nil
 c.current.defense=nil;c.current.mental=nil;c.current.training=nil;c.current.connected=false;c.cure.enabled=false;c.cure.status="disconnected"
 c.current.policy.players_known=false;c.current.policy.web.at=nil;cancel_ih()
 if c.mode=="BASH" then if c.runner.waiting then c.runner.fault="Disconnected during attack; cv2 reset after review" end;c.runner.status="BASH paused: disconnected";refresh()
 else combat_v2_stop("disconnected") end
end)
handler("gmcp.Char.Name",function() c.current.policy.self_name=tostring((gmcp.Char.Name or {}).name or ""):lower() end)
handler("gmcp.Room.Players",function() c.policy.players(c.current,gmcp.Room.Players);combat_v2_tick() end)
handler("gmcp.Room.AddPlayer",function() c.policy.player_add(c.current,gmcp.Room.AddPlayer);combat_v2_tick() end)
handler("gmcp.Room.RemovePlayer",function() c.policy.player_remove(c.current,gmcp.Room.RemovePlayer);combat_v2_tick() end)
local function collection(kind)
 handler("gmcp.Char."..kind..".List",function()
  if kind=="Defences"then c.buffs.sync(c.current,"List",gmcp.Char[kind].List)end
  local dest=kind=="Afflictions" and "afflictions" or "defences";local t={}
  for _,a in ipairs(gmcp.Char[kind].List or {}) do local n=type(a)=="table" and a.name or a;if n then t[c.defense.key(n)]=true end end
  c.current.player[dest]=t
  if kind=="Afflictions" then c.current.player.prone=(t.prone or t.fallen) and true or false end
  combat_v2_tick()
 end)
 handler("gmcp.Char."..kind..".Add",function()
  if kind=="Defences"then c.buffs.sync(c.current,"Add",gmcp.Char[kind].Add)end
  local a=gmcp.Char[kind].Add;local n=type(a)=="table" and a.name or a
  if n then n=c.defense.key(n);c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=true end
  if kind=="Afflictions" and (n=="prone" or n=="fallen") then c.current.player.prone=true end
  combat_v2_tick()
 end)
 handler("gmcp.Char."..kind..".Remove",function()
  if kind=="Defences"then c.buffs.sync(c.current,"Remove",gmcp.Char[kind].Remove)end
  local a=gmcp.Char[kind].Remove;local values=type(a)=="table" and (a.name and {a.name} or a) or {a}
  for _,n in ipairs(values) do
   n=c.defense.key(n);c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=nil
   if kind=="Afflictions" and (n=="prone" or n=="fallen") then local aff=c.current.player.afflictions;c.current.player.prone=(aff.prone or aff.fallen) and true or false end
  end
  combat_v2_tick()
 end)
end
collection("Afflictions");collection("Defences")
handler("gmcp.Char.Items.List",function()
 local changed=c.bashing.items(c.current,gmcp.Char.Items.List);combat_v2_ih_result()
 local s=c.current;local scan=s.hunting.ih
 if changed and c.mode=="BASH" and not (scan and scan.active) and s.hunting.verified_generation==s.target_generation and s.target.name and not s.room.items[tostring(s.target.name)] then
  s.stop_reason="target left room; confirmation required";combat_v2_tick()
 end
 if changed then combat_v2_tick() else refresh() end
end)
for _,kind in ipairs({"Add","Update"})do
 local item_kind=kind
 handler("gmcp.Char.Items."..item_kind,function()if c.bashing.item_changed(c.current,gmcp.Char.Items[item_kind],item_kind=="Add")then combat_v2_tick()end end)
end
handler("gmcp.Char.Items.Remove",function() c.bashing.item_removed(c.current,gmcp.Char.Items.Remove);combat_v2_tick() end)
handler("gmcp.Room.Info",function()
 local s=c.current;local info=gmcp.Room.Info or {};local changed=c.policy.room(s,info)
 if changed and c.monk.cancel_flurry then c.monk.cancel_flurry(s,"room changed")end
 if changed then
  s.hunting.watch=nil;s.training=nil;s.room.items={};s.hunting.killed_ids={};s.hunting.verified_generation=nil;cancel_ih()
  if c.mode=="BASH" then c.state.set_target(s,"");c.runner.pending=nil end
 end
 combat_v2_tick()
end)
handler("combat_v2.observation",function(_,kind,target,key,value,confidence)
 local e={kind=kind,target=target,source="integration",confidence=tonumber(confidence) or 1}
 if kind=="limb" or kind=="damage" then e.limb=key;e.amount=tonumber(value)
 elseif kind=="affliction" then e.name=key;e.value=value
 elseif kind=="parry" then e.limb=key
 elseif kind=="broken" or kind=="mangled" or kind=="crippled" then e.limb=key;e.value=value
 else e.value=value end
 combat_v2_observe(e)
end)
c.line_trigger=tempRegexTrigger("^.*$",function()
 local text=line or matches[1]
 c.buffs.text(c.current,text)
 c.defense.text(c.current,text)
 c.mental.text(c.current,text)
 if c.policy.text(c.current,text) then combat_v2_tick();refresh();return end
 if c.bashing.ih_text(c.current,text) then combat_v2_ih_result();refresh();return end
 c.events.event(c.current,text);combat_v2_tick()
end)
if type(tempPromptTrigger)=="function" then
 c.prompt_trigger=tempPromptTrigger(function()
  c.buffs.on_prompt(c.current);if c.buffs.has_work(c.current)then combat_v2_tick()end
  if c.gui.render_prompt then c.gui.render_prompt(c.current,c.runner) end
 end)
end
for _,id in ipairs(c.buff_aliases or {})do killAlias(id)end
c.buff_aliases={
 tempAlias([[^defup(?:\s+(.*))?$]],function()local ok,why=combat_v2_buffs("defup",matches[2] or "");if not ok then print(why)end end),
 tempAlias([[^defkeep(?:\s+(.*))?$]],function()local arg=matches[2]or"status";local ok,why=combat_v2_buffs(arg=="status"and"status"or"keep",arg);if not ok then print(why)end end)
}

c.alias=tempAlias([[^cv2(?:\s+(.*))?$]],function()
 local arg=(matches[2] or ""):match("^%s*(.-)%s*$");local cmd,rest=arg:match("^(%S+)%s*(.*)$");cmd=(cmd or "status"):lower();rest=rest or ""
 local ok,why=true,nil
 if cmd=="target" then ok,why=combat_v2_set_target(rest)
 elseif cmd=="approve" then ok,why=combat_v2_approve()
 elseif cmd=="stop" or cmd=="off" then combat_v2_stop()
 elseif cmd=="enemy" then if rest=="reset" then ok,why=combat_v2_reset_enemy_afflictions() else ok,why=false,"cv2 enemy reset" end
 elseif cmd=="globe"then ok,why=combat_v2_globe(rest~=""and rest or"status")
 elseif cmd=="defup"then ok,why=combat_v2_buffs("defup",rest)
 elseif cmd=="defkeep"then ok,why=combat_v2_buffs("keep",rest)
 elseif cmd=="defs"or cmd=="defences"then ok,why=combat_v2_buffs("show",rest)
 elseif cmd=="defense" then ok,why=combat_v2_defense(rest)
 elseif cmd=="curing" then if rest=="on" or rest=="off" then ok,why=combat_v2_set_curing(rest=="on") else ok,why=false,"cv2 curing on|off" end
 elseif cmd=="reload" then dofile(root.."bootstrap.lua")
 elseif cmd=="reset" then combat_v2_reset_wait()
 elseif cmd=="status" then combat_v2_status()
 elseif cmd=="trace" then combat_v2_trace(rest)
 elseif cmd=="ih" then ok,why=combat_v2_start_ih("manual IH verification",true)
 elseif cmd=="area" then if rest=="yes" or rest=="no" then ok,why=combat_v2_area_approve(c.current.policy.visit,rest=="yes") else ok,why=false,"cv2 area yes|no" end
 elseif cmd=="areas" then c.policy.request_areas(c.current);send("areas")
 elseif cmd=="web" then c.policy.request_web(c.current);send("web members")
 elseif cmd=="route" then ok,why=combat_v2_set_route(rest)
 elseif cmd=="config" then local k,v=rest:match("^(%S+)%s+(%S+)$");ok,why=combat_v2_config(k,v)
 elseif cmd=="track" then local k,a,b=rest:match("^(%S+)%s*(%S*)%s*(%S*)$");ok,why=combat_v2_track(k,a,b)
 elseif cmd=="queue" then
  local sub,name=rest:match("^(%S+)%s*(.*)$");sub=sub or "list"
  if sub=="add" then ok,why=c.bashing.add(c.current,name)
  elseif sub=="clear" then c.current.hunting.queue={};print("Queue cleared")
  elseif sub=="next" then if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"manual queue next")end; ok,why=c.bashing.next(c.current,true);if ok then combat_v2_tick() elseif c.mode=="BASH" then c.current.hunting.active=true;c.current.stop_reason=nil;combat_v2_start_ih("queue empty") else combat_v2_stop(why) end
  elseif sub=="list" then print("Queued: "..table.concat(c.current.hunting.queue,", "))
  else ok,why=false,"cv2 queue add NAME | list | next | clear" end
 elseif cmd=="help" then if c.gui.show_help then c.gui.show_help() else print("Help GUI unavailable; see docs/backend.md") end
 else ok,why=combat_v2_set_mode(cmd) end
 if not ok and why then print(why) end
end)
c.target_alias=tempAlias([[^t(?:\s+(.*))?$]],function() local ok,why=combat_v2_set_target(matches[2] or "");if not ok then print(why) end end)
cancel_ih()
local cached_connected,cached_vitals=c.current.connected,c.current.vitals_at
c.state.sync_gmcp(c.current,gmcp or {})
c.current.connected=cached_connected;c.current.vitals_at=cached_vitals
if getConnectionInfo then local _,_,connected=getConnectionInfo();if not connected then c.current.connected=false end end
if c.elementals then c.elementals.detach(c)end
c.elementals=dofile(root.."elementals.lua");c.elementals.arm(c,false)
c.gui.create();refresh()
print("Combat V2 backend ready (OFF). t NAME; cv2 bash / pvp / assist; cv2 help; cv2 trace.")
