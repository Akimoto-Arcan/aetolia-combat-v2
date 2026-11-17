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
 for _,item in ipairs(payload.items or {}) do if item.id then s.room.items[tostring(item.id)]={name=tostring(item.name or item.id),attrib=tostring(item.attrib or ""),icon=item.icon} end end
 s.room.item_version=(s.room.item_version or 0)+1
 local scan=s.hunting.ih
 if scan and scan.active and scan.pending and (scan.room_id==nil or scan.room_id==s.room.id) then scan.responded=true;scan.items=s.room.items end
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
function M.ih_begin(s)
 s.hunting.active=true;s.stop_reason=nil
 s.hunting.ih={active=true,attempts=0,pending=false,room_id=s.room.id}
 return s.hunting.ih
end
function M.ih_request(s)
 local scan=s.hunting.ih
 if not scan or not scan.active or scan.pending then return false end
 scan.attempts=scan.attempts+1;scan.pending=true;scan.responded=false;scan.items=nil;scan.header=nil
 return true
end
function M.ih_text(s,text)
 if type(text)~="string" then return false end
 local scan=s.hunting.ih;if not scan or not scan.active or not scan.pending then return false end
 if text=="There is nothing here." then scan.responded=true;scan.items={};scan.header=0;return true end
 local n=text:match("^You can see the following (%d+) objects:$")
 if n then scan.header=tonumber(n);if scan.header==0 then scan.responded=true;scan.items={} end;return true end
 return false
end
function M.ih_select(s)
 local scan=s.hunting.ih
 if not scan or not scan.active or not scan.pending or not scan.responded then return false,"awaiting fresh IH room list" end
 if scan.room_id~=nil and scan.room_id~=s.room.id then return false,"IH room changed" end
 scan.pending=false
 local ids={};for id,item in pairs(scan.items or {}) do
  if tostring(id):match("^%d+$") and ((item.attrib or ""):find("m",1,true) or item.icon=="monster") then ids[#ids+1]=tostring(id) end
 end
 table.sort(ids,function(a,b)return (tonumber(a) or 0)<(tonumber(b) or 0) end)
 local wanted={}
 if s.target.name and not s.target.dead then wanted[#wanted+1]={token=tostring(s.target.name),display=s.target.display_name} end
 for i,name in ipairs(s.hunting.queue) do wanted[#wanted+1]={token=name,queue=i} end
 for _,candidate in ipairs(wanted) do
  for _,id in ipairs(ids) do
   local item=scan.items[id];local name=item.name:lower();local token=candidate.token:lower()
   local a,z=name:find(token,1,true)
   local word_match=a and (a==1 or not name:sub(a-1,a-1):match("%w")) and (z==#name or not name:sub(z+1,z+1):match("%w"))
   local match=id==token or name==token or (not token:match("^%d+$") and word_match) or (candidate.display and name==candidate.display:lower())
   if match then
    if candidate.queue then table.remove(s.hunting.queue,candidate.queue) end
    State.set_target(s,id);s.target.display_name=item.name;scan.active=false;scan.found=id;s.stop_reason=nil
    return true,id
   end
  end
 end
 return false,"no selected or queued monster in IH"
end
return M
