-- Independent Bashing Restock guards. No action or permission at load/bind.
-- Supply trusted core functions in c.restock_api when retiring old lunch guards.
local M={}
function M.busy(c)
 local d=c.restock_data
 -- Only the trusted scoped return dispatcher may pass an upstream convenience
 -- mode/CP-ready guard. Public status still uses restock_module.busy unchanged.
 if d and d.active and d.resume_consent and not d.fault and c.user_activity==d and d.phase=='pausing' and d.capturing_checkpoint and not d.pending and not d.purchase then return false end
 if d and d.phase=='resume' and not d.pending and not d.purchase and c.restock_module and c.restock_module.owns_transition(c) then return false end
 return c.restock_module and c.restock_module.busy(c) or false
end
local function return_recall(c)
 local d=c.restock_data;local tr=c.travel_owner or {};local room=(c.current or {}).room or {}
 return d and d.active and d.resume_consent and not d.fault and not d.purchase and tr.recall_due and not (tr.pending or tr.dispatching or tr.intent or tr.route or tr.fault or tr.follow_pending or tr.follow_fault) and tostring(room.id)==tostring(d.return_room) and tostring(room.area)==tostring(d.return_area) and (d.phase=='return_check' or d.phase=='resume' or (d.phase=='route' and d.after_route=='return_check'))
end
function M.hold(c)
 local d=c.restock_data
 local room=(c.current or {}).room or {}
 if d and d.active and (d.scope_unknown or room.id==nil or room.area==nil) then return true end
 if not d or not M.busy(c) or return_recall(c) then return false end
 -- Owned BASH preparation (dismount, Scorpion, fresh IH) is allowed only after
 -- exact return and transaction settlement. Parent still enforces real readiness.
 return not(d.active and d.resume_consent and not d.fault and not d.purchase and (not d.pending or d.pending.kind=='initial summon') and (d.phase=='resume' or d.phase=='initial_wait'))
end
function M.reserved(c) return c.restock_module and c.restock_module.movement_reserved(c) or false end
local function guard_travel(c)
 local t=c.travel
 if not t or c.restock_guarded_travel==t then return end
 local request=t.request
 if type(request)~='function' then return end
 t.request=function(action,destination,...)
  local d=c.restock_data
  local own=d and c.restock_module.owns_transition(c) and d.phase=='route' and d.pending and d.pending.kind=='route' and action=='pt' and tostring(destination)==tostring(d.destination)
  if c.restock_module.busy(c) and not own then return false,'Restock transaction owns travel; only exact leased PT is permitted' end
  return request(action,destination,...)
 end
 local io=t.io or {}
 local pause=io.pause
 if pause then io.pause=function(...)
  local d=c.restock_data
  local trusted=d and c.restock_module.owns_transition(c)
  if trusted and d.phase=='pausing' then return pause(...) end
  local own=d and (trusted or c.restock_module.movement_borrowed(c)) and d.phase=='route'
  if own then
   d.route_pausing=true
   local ok,result,why=pcall(pause,...)
   d.route_pausing=nil
   if not ok then error(result) end
   return result,why
  end
  if c.restock_module.busy(c) then return false,'Restock owns client' end
  return pause(...)
 end end
 for _,key in ipairs({'recall_ready','send_recall'}) do
  local previous=io[key]
  if previous then io[key]=function(...)
   if io.mount_deferred and io.mount_deferred() then return false,'Mount convenience deferred outside private Haven' end
   if M.hold(c) then return false,'Restock owns client' end
   return previous(...)
  end end
 end
 -- Balance-free FOLLOW and native curing remain independent.
 c.restock_guarded_travel=t
end
function M.bind(c,api)
 api=api or c.restock_api or _G
 local mod=c.restock_module
 if not mod or type(mod.user_stop)~='function' or type(api.combat_v2_set_mode)~='function' then return false,'Restock/mode API unavailable' end
 c.restock_api=api;c.restock_boot=M
 if not c.restock_controller then local t,why=mod.attach(c);if not t then return false,why end end
 if api.combat_v2_set_mode~=c.restock_mode_guard then
  local previous=api.combat_v2_set_mode
  local wrapped=function(mode,...)
   local selected=tostring(mode or 'OFF'):upper();local d=c.restock_data
   local owned=mod.owns_transition(c)
   local route_pause=d and d.route_pausing and mod.movement_borrowed(c)
   local own=owned and ((selected=='OFF' and (d.phase=='pausing' or d.phase=='route')) or (selected=='BASH' and d.phase=='resume')) or (selected=='OFF' and route_pause)
   if not own then
    -- Explicit OFF revokes even if already OFF; any other external mode
    -- selection revokes resume too, but may not bypass a retained transaction.
    if selected=='OFF' or (d and (d.reserved or M.busy(c))) then mod.user_stop(c,'explicit operator mode '..selected) end
    if selected~='OFF' and mod.busy(c) then return false,'Restock transaction unresolved; cannot restart independently' end
   end
   return previous(mode,...)
  end
  api.combat_v2_set_mode=wrapped;c.restock_mode_guard=wrapped
 end
 if type(api.combat_v2_globe)=='function' and api.combat_v2_globe~=c.restock_globe_guard then
  local previous=api.combat_v2_globe
  local wrapped=function(action,...)
   local value=tostring(action or 'status'):lower()
   if value=='off' then mod.globe_off(c) end -- never cancels restocking
   local own=mod.owns_transition(c) and c.restock_data.phase=='resume' and c.restock_data.resume_globe
   if value=='on' and M.reserved(c) and not own then return false,'Restock reserved; cannot independently arm GLOBE' end
   return previous(action,...)
  end
  api.combat_v2_globe=wrapped;c.restock_globe_guard=wrapped
 end
 api.combat_v2_restock=function(action) return mod.command(c,action) end
 local con=c.convenience
 if con and type(con.hold)=='function' and c.restock_guarded_convenience~=con then
  local previous=con.hold
  con.hold=function(root) return M.hold(root) or previous(root) end
  c.restock_guarded_convenience=con
 end
 guard_travel(c)
 -- Walker already centralizes real STOP/retarget/queue/session revocations.
 -- Observe that entry point, rather than duplicating aliases or waiting until
 -- a cancelled checkpoint is eventually encountered after shopping.
 local walker=c.walker_boot
 if walker and type(walker.revoke)=='function' and c.restock_guarded_walker~=walker then
  local previous=walker.revoke
  walker.revoke=function(root,why,...)
   local d=root.restock_data
   if d and d.active and (d.reserved or mod.busy(root)) then mod.user_stop(root) end
   return previous(root,why,...)
  end
  c.restock_guarded_walker=walker
 end
 -- Native prompt/timer callbacks call the module dynamically. Fence that real
 -- entry point as well as the FSM tick, so an ACKed read-only probe cannot
 -- promote itself to DRAIN between restock ticks. Committed continuations and
 -- bookkeeping retain the native owner's authority.
 local e=c.elementals
 if e and type(e.service)=='function' and c.restock_guarded_elementals~=e then
  local previous=e.service
  e.service=function(root,sender,policy)
   local d=root.restock_data
   if d and d.active and d.reserved and d.phase=='drain' and root.restock_controller then
    root.restock_controller.io.disarm_spawn(d)
    local g=root.elemental_recovery or {}
    if not g.committed then policy='settle' end
   end
   return previous(root,sender,policy)
  end
  c.restock_guarded_elementals=e
 end
 return true
end
M.attach=M.bind -- Bootstrap entry point; attachment alone never enables permission.
return M
