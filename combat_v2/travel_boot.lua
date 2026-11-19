-- Persistent convenience attachment; no gameplay on installation/startup.
local M={}
function M.busy(c)
 local s=c and c.travel_owner
 return c and c.lunch_boot and c.lunch_boot.busy(c) or s and (s.pending or s.dispatching or s.fault or s.intent or s.route or s.follow_pending or s.follow_fault or s.recall_due) or c and c.tattoo_owner and c.tattoo_owner.txn
end
function M.hold(c)
 local s=c.travel_owner or {};local p=s.pending
 return c.lunch_boot and c.lunch_boot.hold(c) or s.dispatching or s.fault or s.follow_fault or s.recall_due or (p and p.kind=='recall') or c.tattoo_owner and c.tattoo_owner.txn
end
-- Only a recall reservation may finish an already committed physical action.
-- Other holds still allow evidence settlement, never another physical send.
function M.service_policy(c)
 if not M.hold(c) then return nil end
 if c.lunch_boot and c.lunch_boot.hold(c)then return 'settle' end
 local s=c.travel_owner or {}
 if s.recall_due and not (s.pending or s.dispatching or s.fault or s.follow_fault or s.intent or s.route or s.follow_pending or c.tattoo_owner and c.tattoo_owner.txn) then return 'continue' end
 return 'settle'
end
function M.attach(c,prime)
 local root=getMudletHomeDir()..'/combat_v2/'
 local settings={};local f=io.open(root..'convenience-settings.json','r')
 if f then local raw=f:read('*a');f:close();local ok,v=pcall(yajl.to_value,raw);if ok and type(v)=='table'then settings=v end end
 -- Resolve the fresh native PATH FIND title only when unique in the real mapper.
 settings.resolve_target_room=function(title)
  if not getRooms then return end;local found
  for id,name in pairs(getRooms())do if name==title then if found then return end;found=id end end
  return found
 end
 -- The pre-existing core owns the current-room GMCP view. Only consume events
 -- after that owner has accepted a new version; no cached absence on attachment.
 local seen=c.current.room.item_version or 0
 settings.room_for_items=function(payload)
  local r=c.current.room
  if payload.location~='room' or not r.id or (r.item_version or 0)<=seen then return end
  seen=r.item_version;return r.id
 end
 c.travel_module=c.travel_module or dofile(root..'travel.lua')
 local t,why=c.travel_module.attach(c,settings);if not t then return false,why end
 if prime then
  -- Hot-install baseline from the continuously owned live world view. First 0
  -- is not dismount, and initial presence never dispatches a command.
  t.vitals(gmcp.Char.Vitals.mounted)
  local items={};for id,it in pairs(c.current.room.items or{})do items[#items+1]={id=id,name=it.name,attrib=it.attrib}end
  t.items(c.current.room.id,items,true,0)
 end
 local original_mode=combat_v2_set_mode
 if c.convenience_mode_original~=original_mode then
  local wrapped=function(mode)
   if tostring(mode or'OFF'):upper()~='OFF' and M.busy(c)then return false,'Travel/inking unfinished; resolve before restarting combat' end
   return original_mode(mode)
  end
  c.convenience_mode_original=wrapped;combat_v2_set_mode=wrapped
 end
 if c.convenience_runner~=c.runner_module then
  local guard=setmetatable({hold=function(s)
   if M.hold(c)then return true,'convenience action unresolved' end
   return c.defense.hold(s)
  end},{__index=c.defense})
  c.runner_module.bind_defense(guard.hold);c.mental.bind_defense(guard)
  c.convenience_runner=c.runner_module
 end
 if c.convenience_buffs~=c.buffs then
  local service=c.buffs.service;c.buffs.service=function(s,runner,sender,hold,policy)
   return service(s,runner,sender,hold,M.service_policy(c) or policy)
  end;c.convenience_buffs=c.buffs
 end
 if c.convenience_elementals~=c.elementals then
  local service=c.elementals.service;c.elementals.service=function(owner,sender,policy)
   return service(owner,sender,M.service_policy(c) or policy)
  end;c.convenience_elementals=c.elementals
 end
 if c.convenience_containers~=c.containers then
  local service=c.containers.service;c.containers.service=function(owner,sender,policy)
   return service(owner,sender,M.service_policy(c) or policy)
  end;c.convenience_containers=c.containers
 end
 c.tattoo_module=c.tattoo_module or dofile(root..'tattoo.lua');local inkok,inkwhy=c.tattoo_module.attach(c);if not inkok then return false,inkwhy end
 c.convenience=M;return true
end
return M
