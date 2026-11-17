local root=getMudletHomeDir().."/combat_v2/"
combat_v2=combat_v2 or {};local c=combat_v2
for _,key in ipairs({"gmcp_handler","text_handler"}) do if c[key] then killAnonymousEventHandler(c[key]);c[key]=nil end end
for _,id in ipairs(c.handlers or {}) do killAnonymousEventHandler(id) end
for _,key in ipairs({"line_trigger"}) do if c[key] then killTrigger(c[key]) end end
for _,key in ipairs({"alias","target_alias"}) do if c[key] then killAlias(c[key]) end end
for _,key in ipairs({"retry_timer","watch_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
c.state=dofile(root.."state.lua");c.current=c.state.upgrade(c.current)
c.tracker=dofile(root.."tracker.lua");c.bashing=dofile(root.."bashing.lua");c.bashing.bind(c.state)
c.monk=dofile(root.."monk.lua");c.monk.bind(c.tracker)
c.events=dofile(root.."events.lua");c.events.bind(c.tracker)
c.runner_module=dofile(root.."runner.lua");c.curing=dofile(root.."curing.lua");c.gui=dofile(root.."gui.lua")
c.runner=c.runner_module.new(c.current,c.monk);c.cure=(c.cure and c.cure.status) and c.cure or c.curing.new()
c.mode="OFF";c.current.mode="OFF";c.current.hunting.active=false;c.current.stop_reason=nil
local function refresh() c.gui.refresh(c.current,c.runner,c.cure) end
function combat_v2_stop(reason)
 c.runner_module.stop(c.runner,reason);c.mode="OFF";c.current.stop_reason=nil
 c.current.stats.stops=c.current.stats.stops+1;c.state.record(c.current,"stop",reason or "OFF")
 for _,key in ipairs({"retry_timer","watch_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
 refresh();return true
end
local function watchdog()
 c.watch_timer=nil
 if c.runner_module.watchdog(c.runner) then combat_v2_stop(c.runner.status);return end
 if c.mode~="OFF" and c.mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
end
function combat_v2_tick()
 local s=c.current
 if s.stop_reason then
  if s.stop_reason=="target slain" and c.mode=="BASH" and s.hunting.active then
   s.stop_reason=nil;local ok,why=c.bashing.killed(s);if not ok then combat_v2_stop(why);return false,why end
  else local why=s.stop_reason;combat_v2_stop(why);return false,why end
 end
 local ok,why=c.runner_module.tick(c.runner);c.mode=c.runner.mode;s.mode=c.mode
 if why=="cooldown" and not c.retry_timer then c.retry_timer=tempTimer(.35,function() c.retry_timer=nil;combat_v2_tick() end) end
 refresh();return ok,why
end
function combat_v2_set_mode(mode)
 mode=string.upper(mode or "OFF");if mode=="AUTO" or mode=="PVP" then mode="FULL_AUTO" end
 if not ({OFF=true,SHADOW=true,ASSIST=true,BASH=true,FULL_AUTO=true})[mode] then return false,"invalid mode" end
 if mode=="OFF" then return combat_v2_stop() end
 c.mode=mode;c.runner.mode=mode;c.current.mode=mode;c.runner.pending=nil;c.current.hunting.active=false
 if mode=="BASH" then local ok,why=c.bashing.start(c.current);if not ok then combat_v2_stop(why);return false,why end end
 if not c.watch_timer and mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
 return combat_v2_tick()
end
function combat_v2_set_target(name)
 local ok,why=c.state.set_target(c.current,name)
 if ok then c.runner.pending=nil end
 refresh();return ok,why
end
function combat_v2_approve() local ok,why=c.runner_module.approve(c.runner);refresh();return ok,why end
function combat_v2_set_curing(on) local ok,why=c.curing.set(c.cure,c.current,on==true);refresh();return ok,why end
function combat_v2_reset_wait()
 -- Deliberate manual recovery; never release wait from a timer alone.
 c.runner.waiting=false;c.runner.pending=nil;c.runner.last_send=-100;c.runner.status="manually reset";c.state.record(c.current,"reset","manual waiting reset");refresh()
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
 if key=="estimate_trauma" then
  if value~="on" and value~="off" then return false,"estimate_trauma on|off" end
  c.current.config.estimate_trauma=value=="on";return true
 end
 local bounds={health_pause={1,95},health_resume={2,100},ack_timeout={2,60},stale_vitals={5,120},parry_ttl={1,60},parry_min_confidence={0,1},kick_trauma={0,100},punch_trauma={0,100},boost_kick_trauma={0,100},boost_punch_trauma={0,100}}
 local b=bounds[key];local n=tonumber(value)
 if not b or not n or n~=n or n<b[1] or n>b[2] then return false,"invalid config value/key" end
 local cfg=c.current.config
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
handler("sysDisconnectionEvent",function() c.current.connected=false;c.cure.enabled=false;c.cure.status="disconnected";combat_v2_stop("disconnected") end)
local function collection(kind)
 handler("gmcp.Char."..kind..".List",function()
  local dest=kind=="Afflictions" and "afflictions" or "defences";local t={}
  for _,a in ipairs(gmcp.Char[kind].List or {}) do local n=type(a)=="table" and a.name or a;if n then t[n]=true end end
  c.current.player[dest]=t
  if kind=="Afflictions" then c.current.player.prone=(t.prone or t.fallen) and true or false end
  refresh()
 end)
 handler("gmcp.Char."..kind..".Add",function()
  local a=gmcp.Char[kind].Add;local n=type(a)=="table" and a.name or a
  if n then c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=true end
  if kind=="Afflictions" and (n=="prone" or n=="fallen") then c.current.player.prone=true end
  refresh()
 end)
 handler("gmcp.Char."..kind..".Remove",function()
  local a=gmcp.Char[kind].Remove;local values=type(a)=="table" and (a.name and {a.name} or a) or {a}
  for _,n in ipairs(values) do
   c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=nil
   if kind=="Afflictions" and (n=="prone" or n=="fallen") then local aff=c.current.player.afflictions;c.current.player.prone=(aff.prone or aff.fallen) and true or false end
  end
  refresh()
 end)
end
collection("Afflictions");collection("Defences")
handler("gmcp.Char.Items.List",function() c.bashing.items(c.current,gmcp.Char.Items.List);refresh() end)
handler("gmcp.Char.Items.Remove",function() c.bashing.item_removed(c.current,gmcp.Char.Items.Remove);combat_v2_tick() end)
handler("gmcp.Room.Info",function()
 local info=gmcp.Room.Info or {};local previous=c.current.room.id;c.current.room.id=info.num
 if previous and info.num~=previous then c.current.room.items={};if c.mode=="BASH" then combat_v2_stop("room changed; retarget before restarting") end end
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
 c.events.event(c.current,line or matches[1]);combat_v2_tick()
end)
c.alias=tempAlias([[^cv2(?:\s+(.*))?$]],function()
 local arg=(matches[2] or ""):match("^%s*(.-)%s*$");local cmd,rest=arg:match("^(%S+)%s*(.*)$");cmd=(cmd or "status"):lower();rest=rest or ""
 local ok,why=true,nil
 if cmd=="target" then ok,why=combat_v2_set_target(rest)
 elseif cmd=="approve" then ok,why=combat_v2_approve()
 elseif cmd=="stop" or cmd=="off" then combat_v2_stop()
 elseif cmd=="curing" then if rest=="on" or rest=="off" then ok,why=combat_v2_set_curing(rest=="on") else ok,why=false,"cv2 curing on|off" end
 elseif cmd=="reload" then dofile(root.."bootstrap.lua")
 elseif cmd=="reset" then combat_v2_reset_wait()
 elseif cmd=="status" then combat_v2_status()
 elseif cmd=="trace" then combat_v2_trace(rest)
 elseif cmd=="route" then ok,why=combat_v2_set_route(rest)
 elseif cmd=="config" then local k,v=rest:match("^(%S+)%s+(%S+)$");ok,why=combat_v2_config(k,v)
 elseif cmd=="track" then local k,a,b=rest:match("^(%S+)%s*(%S*)%s*(%S*)$");ok,why=combat_v2_track(k,a,b)
 elseif cmd=="queue" then
  local sub,name=rest:match("^(%S+)%s*(.*)$");sub=sub or "list"
  if sub=="add" then ok,why=c.bashing.add(c.current,name)
  elseif sub=="clear" then c.current.hunting.queue={};print("Queue cleared")
  elseif sub=="next" then ok,why=c.bashing.next(c.current,true);if ok then combat_v2_tick() else combat_v2_stop(why) end
  elseif sub=="list" then print("Queued: "..table.concat(c.current.hunting.queue,", "))
  else ok,why=false,"cv2 queue add NAME | list | next | clear" end
 elseif cmd=="help" then print("t NAME; cv2 bash/pvp/assist/approve/off; route legs/arms/head/torso/balanced; queue add NAME/list/next/clear; track; config; trace; curing on/off; reload")
 else ok,why=combat_v2_set_mode(cmd) end
 if not ok and why then print(why) end
end)
c.target_alias=tempAlias([[^t(?:\s+(.*))?$]],function() local ok,why=combat_v2_set_target(matches[2] or "");if not ok then print(why) end end)
 local cached_connected,cached_vitals=c.current.connected,c.current.vitals_at
c.state.sync_gmcp(c.current,gmcp or {})
c.current.connected=cached_connected;c.current.vitals_at=cached_vitals
if getConnectionInfo then local _,_,connected=getConnectionInfo();if not connected then c.current.connected=false end end
c.gui.create();refresh()
print("Combat V2 backend ready (OFF). t NAME; cv2 bash / pvp / assist; cv2 help; cv2 trace.")
