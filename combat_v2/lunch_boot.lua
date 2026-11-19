-- Lunch authorization guards only. Loading/installing never starts duty or moves.
local M={}
function M.busy(c)
 local d=c.lunch_duty
 return not not(d and not(d.dispatching and d.phase=='resume' and not d.purchase and not d.pending) and (d.busy or d.pending or d.purchase))
end
function M.hold(c)
 local d=c.lunch_duty
 if not d or not(d.busy or d.pending or d.purchase)then return false end
 -- Real dismount, recovery and normal native summoning must work during return.
 return not(d.active and not d.fault and not d.purchase and (not d.pending or d.pending.kind=='initial summon') and (d.phase=='resume' or d.phase=='initial_wait'))
end
local function guard_travel(c)
 local t=c.travel
 if not t or c.lunch_guarded_travel==t then return end
 local request=t.request
 t.request=function(action,destination,...)
  local d=c.lunch_duty;local leased=d and(d.busy or d.pending or d.purchase)
  local own=d and d.dispatching and d.phase=='route'and d.pending and d.pending.kind=='route'and action=='pt'and tostring(destination)==tostring(d.destination)
  if leased and not own then return false,'Lunch transaction unresolved; stop and review before another convenience action' end
  return request(action,destination,...)
 end
 local io=t.io or {}
 for _,key in ipairs({'recall_ready','send_recall'})do
  local original=io[key]
  if original then io[key]=function(...)
   if M.hold(c)then return false,'Lunch activity owns the client' end
   return original(...)
  end end
 end
 -- FOLLOW stays in its existing balance-free lane, including during PT.
 c.lunch_guarded_travel=t
end
function M.bind(c)
 local api=c.lunch_api or _G
 if not c.lunch_module or type(c.lunch_module.user_stop)~='function' or type(api.combat_v2_set_mode)~='function'then return false,'Lunch/mode API unavailable' end
 c.lunch_boot=M
 if not c.lunch_mode_guard_installed then
  local previous=api.combat_v2_set_mode
  api.combat_v2_set_mode=function(mode,...)
   local d=c.lunch_duty;local selected=tostring(mode or'OFF'):upper();local off=selected=='OFF'
   local own=d and d.dispatching and(off and(d.phase=='pausing'or d.phase=='drain'or d.phase=='route'and d.pending and d.pending.kind=='route')or selected=='BASH'and d.phase=='resume'and not d.pending and not d.purchase)
   if off and not own then c.lunch_module.user_stop(c) end
   if not off and d and(d.busy or d.pending or d.purchase)and not own then return false,'Lunch transaction unresolved; cannot restart independently' end
   return previous(mode,...)
  end
  c.lunch_mode_guard_installed=true
 end
 if type(api.combat_v2_globe)=='function'and api.combat_v2_globe~=c.lunch_globe_guard then
  local previous=api.combat_v2_globe
  local wrapped=function(action,...)
   local value=tostring(action or 'status'):lower()
   -- Only explicit public OFF revokes permission. The owned shopping trip
   -- disarms spawns internally and must not revoke its own return grant.
   if value=='off'then c.lunch_module.user_stop(c)end
   if value=='on'and M.busy(c)then return false,'Restock transaction unresolved; cannot independently rearm GLOBE'end
   return previous(action,...)
  end
  c.lunch_globe_guard=wrapped;api.combat_v2_globe=wrapped
 end
 local con=c.convenience
 if con and type(con.hold)=='function'and c.lunch_guarded_convenience~=con then
  local previous=con.hold
  con.hold=function(root)return M.hold(root)or previous(root)end
  c.lunch_guarded_convenience=con
 end
 guard_travel(c)
 return true
end
return M
