local root=getMudletHomeDir().."/combat_v2/"
combat_v2=combat_v2 or {};local c=combat_v2
for _,key in ipairs({"gmcp_handler","text_handler"}) do if c[key] then killAnonymousEventHandler(c[key]);c[key]=nil end end
for _,id in ipairs(c.handlers or {}) do killAnonymousEventHandler(id) end
if c.line_trigger then killTrigger(c.line_trigger) end
if c.alias then killAlias(c.alias) end
if c.target_alias then killAlias(c.target_alias) end
if c.retry_timer then killTimer(c.retry_timer);c.retry_timer=nil end
c.state=dofile(root.."state.lua");c.current=c.current or c.state.new()
c.monk=dofile(root.."monk.lua");c.events=dofile(root.."events.lua")
c.runner_module=dofile(root.."runner.lua");c.curing=dofile(root.."curing.lua");c.gui=dofile(root.."gui.lua")
c.runner=c.runner_module.new(c.current,c.monk);c.cure=(c.cure and c.cure.status) and c.cure or c.curing.new()
c.mode="OFF";c.current.mode="OFF";c.current.stop_reason=nil
local function refresh() c.gui.refresh(c.current,c.runner,c.cure) end
function combat_v2_tick()
 if c.current.stop_reason then combat_v2_stop(c.current.stop_reason);return false end
 local ok,why=c.runner_module.tick(c.runner)
 if why=="cooldown" and not c.retry_timer then c.retry_timer=tempTimer(.35,function() c.retry_timer=nil;combat_v2_tick() end) end
 refresh();return ok,why
end
function combat_v2_stop(reason)
 c.runner_module.stop(c.runner,reason);c.mode="OFF";c.current.stop_reason=nil
 if c.retry_timer then killTimer(c.retry_timer);c.retry_timer=nil end
 refresh();return true
end
function combat_v2_set_mode(mode)
 mode=string.upper(mode or "OFF");if mode=="AUTO" then mode="FULL_AUTO" end
 if not ({OFF=true,SHADOW=true,ASSIST=true,BASH=true,FULL_AUTO=true})[mode] then return false,"invalid mode" end
 if mode=="OFF" then return combat_v2_stop() end
 c.mode=mode;c.runner.mode=mode;c.current.mode=mode;c.runner.pending=nil
 return combat_v2_tick()
end
function combat_v2_set_target(name)
 name=tostring(name or ""):match("^%s*(.-)%s*$")
 if name~="" and (name:find("[\r\n]") or not name:match("^[%w%s'%-]+$")) then return false,"invalid target" end
 if c.current.target.name~=name then c.current.target=c.state.new().target;c.current.target.name=name~="" and name or nil;c.runner.pending=nil end
 c.current.stop_reason=nil;refresh();return true
end
function combat_v2_approve() local ok,why=c.runner_module.approve(c.runner);refresh();return ok,why end
function combat_v2_set_curing(on) local ok,why=c.curing.set(c.cure,c.current,on==true);refresh();return ok,why end
function combat_v2_reset_wait() c.runner.waiting=false;c.runner.pending=nil;c.runner.status="manually reset";refresh() end
function combat_v2_propose() local a=c.runner_module.propose(c.runner);refresh();return a end
function combat_v2_status() print("Combat V2 mode="..c.mode.." target="..tostring(c.current.target.name).." status="..tostring(c.runner.status)) end
c.handlers={}
local function handler(event,fn) c.handlers[#c.handlers+1]=registerAnonymousEventHandler(event,fn) end
handler("gmcp.Char.Vitals",function() c.state.sync_gmcp(c.current,gmcp);combat_v2_tick() end)
handler("sysDisconnectionEvent",function() c.current.connected=false;c.cure.enabled=false;c.cure.status="disconnected";combat_v2_stop("disconnected") end)
handler("gmcp.Char.Afflictions.List",function()
 c.current.player.afflictions={};for _,a in ipairs(gmcp.Char.Afflictions.List or {}) do local n=type(a)=="table" and a.name or a;if n then c.current.player.afflictions[n]=true end end;refresh()
end)
handler("gmcp.Char.Afflictions.Add",function() local a=gmcp.Char.Afflictions.Add;if a and a.name then c.current.player.afflictions[a.name]=true end;refresh() end)
handler("gmcp.Char.Afflictions.Remove",function() local a=gmcp.Char.Afflictions.Remove;for _,n in ipairs(type(a)=="table" and a or {a}) do c.current.player.afflictions[n]=nil end;refresh() end)
c.line_trigger=tempRegexTrigger("^.*$",function() c.events.event(c.current,line or matches[1]);combat_v2_tick() end)
c.alias=tempAlias("^cv2(?:\\s+(.*))?$",function()
 local arg=(matches[2] or ""):match("^%s*(.-)%s*$");local cmd,rest=arg:match("^(%S+)%s*(.*)$");cmd=(cmd or "status"):lower()
 if cmd=="target" then local ok,e=combat_v2_set_target(rest);if not ok then print(e) end
 elseif cmd=="approve" then local ok,e=combat_v2_approve();if not ok then print(e) end
 elseif cmd=="stop" or cmd=="off" then combat_v2_stop()
 elseif cmd=="curing" then if rest=="on" or rest=="off" then local ok,e=combat_v2_set_curing(rest=="on");if not ok then print(e) end else print("cv2 curing on|off") end
 elseif cmd=="reload" then dofile(root.."bootstrap.lua")
 elseif cmd=="reset" then combat_v2_reset_wait()
 elseif cmd=="status" then combat_v2_status()
 else local ok,e=combat_v2_set_mode(cmd);if not ok and e=="invalid mode" then print("cv2 target NAME / bash / auto / assist / approve / off / curing on|off / reload") end end
end)
c.target_alias=tempAlias([[^t(?:\s+(.*))?$]],function()
 local ok,e=combat_v2_set_target(matches[2] or "");if not ok then print(e) end
end)
c.state.sync_gmcp(c.current,gmcp or {})
c.gui.create();refresh()
print("Combat V2 ready: cv2 target NAME, then cv2 bash or cv2 auto; cv2 off stops. FIRSTAID toggle available.")
