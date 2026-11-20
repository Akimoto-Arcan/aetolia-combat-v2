-- Explicit hunting queue. Never auto-select players, neutrals, or unknown room objects.
local M={};local State;local Mobs={}
function M.bind_mobs(list) Mobs=list or {} end
function M.bind(state) State=state end
function M.bind_areas(areas) M.areas=areas end
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
 s.hunting.active=true;s.hunting.killed_ids={}
 if not s.target.name or s.target.dead then return M.next(s) end
 local item=s.room.items[tostring(s.target.name)];if item then s.target.display_name=item.name end
 return true
end
function M.killed(s)
 if not s.hunting.active or s.mode~="BASH" then return false end
 s.hunting.kills=s.hunting.kills+1
 s.hunting.target_name=s.target.display_name or s.hunting.target_name
 s.hunting.killed_ids=s.hunting.killed_ids or {}
 if s.target.name then s.hunting.killed_ids[tostring(s.target.name)]=true end
 return M.next(s)
end
function M.items(s,payload)
 if type(payload)~="table" or payload.location~="room" then return false end
 if M.areas and not M.areas.complete(payload)then
  -- A rejected FULL list is newer evidence, not permission to retain an old IH.
  s.room.item_version=(s.room.item_version or 0)+1
  s.hunting.area_snapshot=nil;s.hunting.area_dirty=true;s.hunting.verified_generation=nil;s.hunting.area_recovery=true
  local scan=s.hunting.ih
  if scan then scan.responded=false;scan.items=nil;scan.header=nil;scan.walker_version=nil;scan.walker_items=nil;scan.invalidated=true;scan.recovery_prompt=true end
  local w=s.walker;if w then w.clear=nil;w.inspection=nil end
  return false
 end
 s.room.items={}
 for _,item in ipairs(payload.items or {}) do if item.id then s.room.items[tostring(item.id)]={name=tostring(item.name or item.id),attrib=tostring(item.attrib or ""),icon=item.icon} end end
 s.room.item_version=(s.room.item_version or 0)+1
 if M.areas then M.areas.snapshot(s,payload)end
 local scan=s.hunting.ih
 if scan and scan.active and scan.pending and not scan.invalidated and (scan.room_id==nil or scan.room_id==s.room.id) then scan.responded=true;scan.items=s.room.items;scan.prompt_ready=nil end
 local item=s.room.items[tostring(s.target.name)];if item then s.target.display_name=item.name end
 return true
end
function M.item_removed(s,payload)
 if type(payload)~="table" or payload.location~="room" then return end
 local raw=payload.item or payload.id;local id=type(raw)=="table" and raw.id or raw
 if not id then return end
 s.room.items[tostring(id)]=nil;s.room.item_version=(s.room.item_version or 0)+1
 if M.areas then s.hunting.area_snapshot=nil;s.hunting.area_dirty=true end
 if s.mode=="BASH" and tostring(s.target.name)==tostring(id) and not s.target.dead then s.stop_reason="target left room; confirmation required" end
end
function M.item_changed(s,payload,added)
 if type(payload)~="table" or payload.location~="room" then return false end
 local item=type(payload.item)=="table" and payload.item or payload
 if not item.id then return false end
 local id=tostring(item.id);local old=s.room.items[id] or {}
 local nextitem={name=tostring(item.name or old.name or id),attrib=tostring(item.attrib or old.attrib or ""),icon=item.icon or old.icon}
 s.room.items[id]=nextitem;s.room.item_version=(s.room.item_version or 0)+1
 if M.areas then s.hunting.area_snapshot=nil;s.hunting.area_dirty=true end
 local flags=nextitem.attrib;local living=(flags:find("m",1,true) or nextitem.icon=="monster") and not flags:find("d",1,true) and not flags:find("x",1,true)
 if living and (added or tostring(old.attrib or ""):find("d",1,true)) and s.hunting.killed_ids then s.hunting.killed_ids[id]=nil end
 return true
end
-- Fresh GMCP updates reuse the same guarded NPC selector without sending IH.
function M.watch_select(s)
 local watch=s.hunting.watch
 if not watch or watch.room_id~=s.room.id then return false end
 local old=s.hunting.ih
 s.hunting.ih={active=true,pending=true,responded=true,room_id=s.room.id,items=s.room.items,attempts=0,source="GMCP watch"}
 local ok,why=M.ih_select(s)
 if ok then s.hunting.watch=nil else s.hunting.ih=old end
 return ok,why
end
function M.ih_begin(s)
 s.hunting.watch=nil
 s.hunting.active=true;s.stop_reason=nil
 s.hunting.ih={active=true,attempts=0,pending=false,room_id=s.room.id,start_version=s.room.item_version or 0,recovery_prompt=s.hunting.area_recovery}
 return s.hunting.ih
end
function M.ih_request(s)
 local scan=s.hunting.ih
 if not scan or not scan.active or scan.pending or scan.attempts>=3 then return false end
 scan.attempts=scan.attempts+1;scan.pending=true;scan.responded=false;scan.items=nil;scan.header=nil
 scan.invalidated=nil;scan.prompt_ready=nil;scan.walker_version=nil;scan.walker_items=nil
 scan.area=s.room.area
 return true
end
function M.ih_text(s,text)
 if type(text)~="string" then return false end
 local scan=s.hunting.ih;if not scan or not scan.active or not scan.pending then return false end
 if scan.invalidated or scan.recovery_prompt then return false end
 if text=="There is nothing here." then scan.responded=true;scan.items={};scan.header=0;return true end
 local n=text:match("^You can see the following (%d+) objects:$")
 if n then scan.header=tonumber(n);if scan.header==0 then scan.responded=true;scan.items={} end;return true end
 return false
end
function M.ih_select(s)
 local scan=s.hunting.ih
 if not scan or not scan.active or not scan.pending or not scan.responded then return false,"awaiting fresh IH room list" end
 if scan.room_id~=nil and scan.room_id~=s.room.id then return false,"IH room changed" end
 if scan.area~=nil and scan.area~=s.room.area then return false,"IH area changed"end
 if M.areas and s.hunting.preset and s.hunting.area_recovery then return false,"awaiting solicited recovery list and later prompt"end
 if scan.invalidated or scan.recovery_prompt and not scan.prompt_ready then return false,"awaiting solicited complete list and later prompt" end
 if M.areas and s.hunting.preset and (not M.areas.fresh(s)or scan.items~=s.room.items)then return false,"awaiting complete fresh room list" end
 scan.pending=false
 if M.areas and s.hunting.preset then
  local id,why=M.areas.pick(s,scan.items)
  if not id then s.hunting.verified_generation=nil;return false,why end
  local item=scan.items[id]
  if tostring(s.target.name)~=id or s.target.dead then State.set_target(s,id)end
  s.target.display_name=item.name;s.hunting.target_name=item.name
  scan.active=false;scan.found=id;s.stop_reason=nil;s.hunting.area_dirty=false
  return true,id
 end
 local ids={};for id,item in pairs(scan.items or {}) do
  local flags=item.attrib or ""
  if tostring(id):match("^%d+$") and (flags:find("m",1,true) or item.icon=="monster") and not flags:find("d",1,true) and not flags:find("x",1,true) and not item.name:lower():find("guard",1,true) and not (s.hunting.killed_ids or {})[tostring(id)] then ids[#ids+1]=tostring(id) end
 end
 table.sort(ids,function(a,b)return (tonumber(a) or 0)<(tonumber(b) or 0) end)
 local wanted={}
 if s.target.name and not s.target.dead then wanted[#wanted+1]={token=tostring(s.target.name),display=s.target.display_name} end
 for i,name in ipairs(s.hunting.queue) do wanted[#wanted+1]={token=name,queue=i} end
 if s.hunting.query and not s.hunting.query:match("^%d+$") then wanted[#wanted+1]={token=s.hunting.query} end
 if s.hunting.target_name then wanted[#wanted+1]={token=s.hunting.target_name,exact=true} end
 for _,id in ipairs(ids)do local n=scan.items[id].name:lower();if Mobs[n] then wanted[#wanted+1]={token=n,exact=true} end end
 for _,candidate in ipairs(wanted) do
  for _,id in ipairs(ids) do
   local item=scan.items[id];local name=item.name:lower();local token=candidate.token:lower()
   local a,z=name:find(token,1,true)
   local word_match=a and (a==1 or not name:sub(a-1,a-1):match("%w")) and (z==#name or not name:sub(z+1,z+1):match("%w"))
   local match=id==token or name==token or (not candidate.exact and not token:match("^%d+$") and word_match) or (candidate.display and name==candidate.display:lower())
   if match then
    if candidate.queue then table.remove(s.hunting.queue,candidate.queue) end
    State.set_target(s,id);s.target.display_name=item.name;s.hunting.target_name=item.name;scan.active=false;scan.found=id;s.stop_reason=nil
    return true,id
   end
  end
 end
 return false,"no selected or queued monster in IH"
end
return M
