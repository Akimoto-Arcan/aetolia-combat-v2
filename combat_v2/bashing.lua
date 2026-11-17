-- Explicit hunting queue. Never auto-select players, neutrals, or unknown room objects.
local M={};local State
function M.bind(state) State=state end
function M.add(s,name)
 name=tostring(name or ""):match("^%s*(.-)%s*$")
 if not State.valid_target(name) then return false,"invalid queue target" end
 for _,v in ipairs(s.hunting.queue) do if v:lower()==name:lower() then return false,"already queued" end end
 s.hunting.queue[#s.hunting.queue+1]=name;return true
end
function M.next(s,skipped)
 if skipped then s.hunting.skipped=s.hunting.skipped+1 end
 local name=table.remove(s.hunting.queue,1)
 State.set_target(s,name or "")
 if name then
  local item=s.room.items[tostring(name)];if item then s.target.display_name=item.name end
  return true,name
 end
 s.hunting.active=false;s.stop_reason="hunting queue complete";return false,s.stop_reason
end
function M.start(s)
 s.hunting.active=true
 if not s.target.name or s.target.dead then return M.next(s) end
 local item=s.room.items[tostring(s.target.name)];if item then s.target.display_name=item.name end
 return true
end
function M.killed(s)
 if not s.hunting.active or s.mode~="BASH" then return false end
 s.hunting.kills=s.hunting.kills+1
 return M.next(s)
end
function M.items(s,payload)
 if type(payload)~="table" or payload.location~="room" then return false end
 s.room.items={}
 for _,item in ipairs(payload.items or {}) do if item.id then s.room.items[tostring(item.id)]={name=tostring(item.name or item.id),attrib=tostring(item.attrib or "")} end end
 local item=s.room.items[tostring(s.target.name)];if item then s.target.display_name=item.name end
 return true
end
function M.item_removed(s,payload)
 if type(payload)~="table" or payload.location~="room" then return end
 local raw=payload.item or payload.id;local id=type(raw)=="table" and raw.id or raw
 if not id then return end
 s.room.items[tostring(id)]=nil
 if s.mode=="BASH" and tostring(s.target.name)==tostring(id) and not s.target.dead then s.stop_reason="target left room; confirmation required" end
end
return M
