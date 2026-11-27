-- Fail-closed BASH permission: server AREAS, current room players, solicited web roster.
local M={}
local Areas
function M.bind_areas(areas)Areas=areas end
local function now()return getEpoch and getEpoch() or os.clock()end
local function norm(v)return tostring(v or ''):lower():match('^%s*(.-)%s*$')end
local function name(v)
 local n=type(v)=='table' and v.name or v
 return type(n)=='string' and n:match("^[%a][%a'%-]*$") and n:lower() or nil
end
-- Exact room identities only: settings keys never accept numbers or coercion.
local function room_key(id)
 if type(id)=='string' and id:match('^[1-9]%d*$') then return id end
 if type(id)=='number' and id>0 and id<=9007199254740991 and id==math.floor(id) then return string.format('%.0f',id) end
end
function M.set_approved_rooms(s,map)
 local p=s.policy;local approved={}
 if type(map)~='table' then p.approved_rooms={};return false end
 for id,yes in pairs(map)do
  if type(id)~='string' or not room_key(id) or yes~=true then p.approved_rooms={};return false end
  approved[id]=true
 end
 p.approved_rooms=approved;return true
end
local function load_approved_rooms(s)
 -- Optional Mudlet facilities only; no global/profile-root fallback, evaluation or writes.
 if type(getMudletHomeDir)~='function' or type(io)~='table' or type(io.open)~='function'
  or type(yajl)~='table' or type(yajl.to_value)~='function' then return end
 s.policy.approved_rooms={}
 local ok,home=pcall(getMudletHomeDir)
 if not ok or type(home)~='string' or home=='' then return end
 local opened,file=pcall(io.open,home..'/combat_v2/bashing-rooms.json','r')
 if not opened or not file then return end
 local read,content=pcall(function()return file:read('*a')end)
 pcall(function()file:close()end)
 if not read or type(content)~='string' then return end
 local decoded,data=pcall(yajl.to_value,content)
 if not decoded or type(data)~='table' then return end
 for key in pairs(data)do if key~='approved_rooms' then return end end
 M.set_approved_rooms(s,data.approved_rooms)
end
function M.init(s,g)
 s.policy=s.policy or {areas={},players={},web={members={}},visit=0,group_web=true}
 local p=s.policy;p.web={members={}};p.players={};p.players_known=false
 M.set_approved_rooms(s,p.approved_rooms or {});load_approved_rooms(s)
 p.self_name=norm(g and g.Char and g.Char.Name and g.Char.Name.name)
 if g and g.Room and g.Room.Info then M.room(s,g.Room.Info) end
 if g and g.Room and type(g.Room.Players)=='table' then M.players(s,g.Room.Players) end
 return p
end
function M.room(s,info)
 local p=s.policy;local changed=s.room.id~=info.num
 local area=norm(info.area)
 if p.area~=area then p.visit=(p.visit or 0)+1;p.consent=nil;p.prompted=nil;p.denied=nil end
 p.area=area;s.room.area=info.area
 if changed then p.players={};p.players_known=false;p.players_room=nil;p.web.at=nil end
 s.room.id=info.num;return changed
end
function M.players(s,list)
 local p=s.policy;if type(list)~='table' then p.players_known=false;return false end
 local players={}
 for _,v in pairs(list)do local n=name(v);if not n then p.players_known=false;return false end;players[n]=true end
 p.players=players;p.native_players=players;p.players_known=true;p.players_room=s.room.id;p.players_version=(p.players_version or 0)+1;return true
end
function M.player_add(s,v)
 local n=name(v);if not n then s.policy.players_known=false;return end
 s.policy.players[n]=true;s.policy.web.at=nil;s.policy.players_version=(s.policy.players_version or 0)+1
end
function M.player_remove(s,v)
 local n=name(v);if not n then s.policy.players_known=false;return end
 s.policy.players[n]=nil;s.policy.players_version=(s.policy.players_version or 0)+1
end
function M.has_others(s)
 for n in pairs(s.policy.players)do if n~=s.policy.self_name then return true end end
 return false
end
function M.area_allowed(s)
 local p=s.policy;local id=room_key(s.room.id)
 if not id then return false,'BASH paused: room identity unknown' end
 if p.approved_rooms and p.approved_rooms[id]==true then return true end
 if p.area=='' or not p.area then return false,'BASH paused: room area unknown' end
 if p.areas_loaded and p.areas[p.area] then return true end
 if p.consent==p.visit then return true end
 return false,'BASH paused: area approval required ('..tostring(s.room.area)..')'
end
function M.allowed(s)
 local p=s.policy;if not p then return false,'BASH safety policy not initialized' end
 if p.denied==p.visit then return false,'BASH paused: explicitly denied area visit'end
 local ok,why=M.area_allowed(s);if not ok then return false,why end
 if not p.players_known or p.players_room~=s.room.id then return false,'BASH paused: waiting for room player list' end
 if M.has_others(s) then
  if not p.group_web then return false,'BASH paused: another player is present (solo mode)' end
  local w=p.web
  if w.pending or not w.at or now()-w.at>=3 then return false,'BASH paused: verifying current web roster' end
  for n in pairs(p.players)do
   if n~=p.self_name and not w.members[n] then return false,'BASH paused: non-web player present ('..n..')' end
  end
 end
 return true
end
function M.attack_allowed(s)
 if s.walker and s.walker.active and s.policy.players_known and s.policy.players_room==s.room.id and M.has_others(s)then return false,'BASH paused: WALK skips occupied player rooms'end
 local ok,why=M.allowed(s);if not ok then return false,why end
 if s.hunting.area_auto then
  if not Areas or s.hunting.area_auto_hold and not Areas.manual_permitted(s)or not Areas.auto_certified(s)then return false,'BASH paused: current area target proof required'end
  local id=Areas.pick(s,s.room.items)
  if id~=tostring(s.target.name)then return false,'BASH paused: selector no longer approves target'end
 end
 if s.hunting.manual_target then
  local id,why=Areas and Areas.manual_pick(s,s.room.items)
  if not id or id~=tostring(s.target.name)then return false,why or 'manual target not certified'end
 end
 local item=s.room.items[tostring(s.target.name)]
 if s.hunting.verified_generation~=s.target_generation or not item then return false,'BASH paused: target not confirmed in current room' end
 if s.hunting.defensive_selected==tostring(s.target.name)and(not Areas or not Areas.defensive_eligible(s,s.target.name))then return false,'BASH paused: defensive attack evidence expired or invalid'end
 local f=item.attrib or '';local n=tostring(item.name or ''):lower()
 if not (f:find('m',1,true) or item.icon=='monster') or f:find('d',1,true) or f:find('x',1,true) or n:find('guard',1,true) then return false,'BASH paused: protected, dead, guard or non-monster target' end
 return true
end
function M.approve(s,visit,yes)
 local p=s.policy
 if s.mode~='BASH' or tonumber(visit)~=p.visit or p.area=='' then return false,'area prompt expired / BASH not selected' end
 p.prompted=p.visit
 if yes then p.consent=p.visit;p.denied=nil else p.consent=nil;p.denied=p.visit end
 return true
end
function M.request_areas(s)
 local p=s.policy;p.areas_requested=now();p.areas_collect=nil;p.areas_buffer={}
end
function M.request_web(s)
 local w=s.policy.web;w.pending=true;w.requested=now();w.at=nil;w.members={};w.collect=nil;w.buffer={};w.rows=0
end
function M.services(s)
 local out={};local p=s.policy;local t=now()
 if s.mode~='BASH' or not s.connected or s.player.dead or (tonumber(s.player.hp) or 0)<=0 then return out end
 if not p.areas_loaded and (not p.areas_requested or t-p.areas_requested>=10) then M.request_areas(s);out[#out+1]='areas' end
 if (not p.players_known or p.players_room~=s.room.id) and (not p.look_at or t-p.look_at>=2) then p.look_at=t;out[#out+1]='look' end
 if p.players_known and M.has_others(s) and p.group_web then
  local w=p.web
  if (not w.requested or t-w.requested>=2) and (not w.at or t-w.at>=2) then M.request_web(s);out[#out+1]='web members' end
 end
 return out
end
function M.text(s,text)
 if type(text)~='string' then return false end
 local p=s.policy;if not p then return false end
 -- Neither quoted chat nor channel talk grants permission. Parse solicited server blocks only.
 if p.areas_requested and text:match('^%*+') and text:find('[ Areas by level ]',1,true) then p.areas_collect=true;p.areas_buffer={};return true end
 if p.areas_collect then
  local level,threat,area,id=text:match('^%s*(%d+)%+?%s+(%a+)%s+(.-)%s+(%d+)%s*$')
  if level and ({Safe=true,Moderate=true,Challenging=true,Dangerous=true,Lethal=true})[threat] then p.areas_buffer[norm(area)]=true;return true end
  if text:match('^%*%*%*%*%*+$') then
   if next(p.areas_buffer) then p.areas=p.areas_buffer;p.areas_loaded=true end
   p.areas_collect=nil;p.areas_requested=nil;return true
  end
 end
 local w=p.web
 if text=='You are not the member of any web.' then w.members={};w.at=now();w.pending=false;w.collect=nil;return true end
 if w.pending and now()-(w.requested or 0)<2 then
  if text=='Your web has the following members:' then w.collect='before';w.buffer={};w.rows=0;return true end
  if w.collect and text:match('^%-%-%-%-%-+$') then
   if w.collect=='before' then w.collect='rows'
   else
    if w.rows>0 then w.members=w.buffer;w.at=now() end
    w.pending=false;w.collect=nil
   end
   return true
  end
  if w.collect=='rows' then
   local row=text:gsub('%.$','');local valid=true;local count=0
   for token in (row..','):gmatch('(.-),')do
    local n=name(token:match('^%s*(.-)%s*$'));if not n then valid=false;break end
    w.buffer[n]=true;count=count+1
   end
   if not valid or count==0 then w.pending=false;w.collect=nil;w.at=nil;w.members={} else w.rows=w.rows+count end
   return true
  end
 end
 -- Unclassified web notices revoke cached permission; never infer members from speech.
 if text:lower():find('web',1,true) and not text:match('^H:') then w.at=nil end
 return false
end
return M
