-- Native, send-free area catalog and selector. No legacy Lua is loaded.
local M={catalog={}}
local function key(v)return tostring(v or ''):lower()end
local function same(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
function M.living(it)
 if type(it)~='table'then return false end
 local a=tostring(it.attrib or '')
 return not a:find('d',1,true)and not a:find('x',1,true)and not a:find('p',1,true)and (a:find('m',1,true)~=nil or it.icon=='monster')
end
function M.complete(payload)
 if type(payload)~='table'or payload.location~='room'or type(payload.items)~='table'then return false end
 local seen,n,max={},0,0
 for i,it in pairs(payload.items)do
  if type(i)~='number'or i<1 or i%1~=0 or type(it)~='table'or not tostring(it.id):match('^%d+$')or type(it.name)~='string'or it.name==''or it.attrib~=nil and type(it.attrib)~='string'or seen[tostring(it.id)]then return false end
  seen[tostring(it.id)]=true;n=n+1;max=math.max(max,i)
 end
 return max==n
end
function M.invalidate(s,keep_encounter)
 s.hunting.area_snapshot=nil;s.hunting.area_dirty=true
 if not keep_encounter then s.hunting.encounter=nil end
end
function M.scope(s)
 local p=s.hunting.preset
 return p and same(p.area,s.room.area)and p or nil
end
-- Explicit private configuration; room sets are mapper IDs supplied by the operator.
-- No graph/room/account data is shipped in this module.
function M.configure(s,id,area,rooms,encounter)
 local row=M.catalog[key(id)]
 if not row then return false,'unknown area preset'end
 if type(area)~='string'or area==''or area~=s.room.area then return false,'explicit current area name required'end
 local w=s.walker or {}
 if w.active or w.offer or w.pending or w.dispatching or w.arrival_hold or w.restock_checkpoint then return false,'stop walking and settle before configuring preset'end
 if row.requires_rooms and type(rooms)~='table'then return false,'preset requires reviewed private room allowlist'end
 local allowed
 if rooms then
  allowed={};local n=0
  for room,yes in pairs(rooms)do if yes~=true or not tostring(room):match('^%d+$')then return false,'invalid room allowlist'end;allowed[tostring(room)]=true;n=n+1 end
  if n==0 then return false,'empty room allowlist'end
 end
 local names={knight="a gargantuan, nightmarish knight"}
 for role,name in pairs(encounter or {})do
  if (role~='shard'and role~='nest'and role~='knight')or type(name)~='string'or name==''then return false,'invalid exact encounter name'end
  names[role]=key(name)
 end
 s.hunting.preset={id=key(id),area=area,rooms=allowed,encounter=names,cutter_limit=4}
 M.invalidate(s);s.hunting.verified_generation=nil
 return true,'Preset configured; stationary, fresh IH and walking YES still required'
end
function M.select(s,id)
 id=key(id);local row=M.catalog[id]
 if not row then return false,'unknown area preset'end
 if not row.areas[key(s.room.area)]then return false,'area name unverified; use explicit private configure with observed area/room scope'end
 return M.configure(s,id,s.room.area)
end
function M.snapshot(s,payload)
 s.hunting.area_snapshot=nil;s.hunting.area_dirty=true
 if not M.complete(payload)then return false end
 s.hunting.area_snapshot={room=s.room.id,area=s.room.area,items=s.room.items,version=s.room.item_version}
 return true
end
function M.fresh(s)
 local q=s.hunting.area_snapshot
 return s.connected and q and same(q.room,s.room.id)and same(q.area,s.room.area)and q.items==s.room.items and q.version==s.room.item_version
end
function M.blocked(s)
 local p=s.hunting.preset
 if p and (not M.scope(s)or p.rooms and not p.rooms[tostring(s.room.id)])then return true,'preset room/area boundary'end
 if p and s.hunting.encounter then return true,'encounter not settled'end
 for _,it in pairs(s.room.items or {})do if M.living(it)then return true,'living room NPC; fresh empty room required'end end
 return false
end
function M.pick(s,items)
 local p=M.scope(s)
 if not p then return nil,'preset area mismatch'end
 if p.rooms and not p.rooms[tostring(s.room.id)]then return nil,'preset room boundary'end
 if not M.fresh(s)or items~=s.room.items then return nil,'awaiting complete fresh room list'end
 local row=M.catalog[p.id];local candidates={};local cutters=0
 local e=s.hunting.encounter
 if e and (not same(e.room,s.room.id)or e.area~=s.room.area)then return nil,"encounter scope unresolved"end
 for id,it in pairs(items)do
  if M.living(it)and not (s.hunting.killed_ids or {})[tostring(id)]then
   local name=key(it.name);local r=row.mobs[name]
   if name=='a crazed nazetu cutter'then cutters=cutters+1 end
   local priority=r and r.priority
   if e then
    local desired=p.encounter[e.role]
    if not desired then return nil,'encounter exact NPC name requires private configuration'end
    priority=name==desired and 300 or nil
   end
   if priority then candidates[#candidates+1]={id=tostring(id),priority=priority}end
  end
 end
 if p.id=='tiyen'and cutters>=(p.cutter_limit or 4)then return nil,'HOLD: cutter pressure limit'end
 table.sort(candidates,function(a,b)
  if a.priority~=b.priority then return a.priority>b.priority end
  local current=tostring(s.target.name)
  if a.id==current or b.id==current then return a.id==current end
  local x,y=tonumber(a.id),tonumber(b.id);if x~=y then return x<y end;return a.id<b.id
 end)
 return candidates[1]and candidates[1].id or nil,'no eligible preset NPC'
end
function M.killed(s)
 local e=s.hunting.encounter;local p=M.scope(s)
 if e and p and (e.role=='nest'or e.role=='knight')and p.encounter[e.role]==key(s.target.display_name)then s.hunting.encounter=nil end
 s.hunting.area_dirty=true
end
local shield='A gargantuan, nightmarish knight lets out a deafening howl, protectivecrimson shards forming upon his armor.'
local broken='A gargantuan, nightmarish knight lets loose a guttural howl as the shards protecting him are destroyed.'
function M.text(s,text)
 local p=M.scope(s)
 if not s.connected or not p or s.mode~='BASH'then return false end
 -- Exact server narrative only; other-player combat lines and substring matches cannot arm.
 if text==shield then s.hunting.encounter={role='shard',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true end
 if text==broken then
  local e=s.hunting.encounter
  if e and e.role=='shard'and same(e.room,s.room.id)and p.encounter.shard and key(s.target.display_name)==p.encounter.shard then
   s.hunting.encounter={role='knight',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true
  end
 elseif type(text)=='string'and text:match('^A slime nest grows in the %a+ section of the cavern!$')then
  s.hunting.encounter={role='nest',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true
 end
 return false
end
-- Catalog rows below are static quotations, not executable reference code.
M.catalog["alaqsii"]={label="Alaqsii Inlet",areas={["alaqsii inlet"]=true},requires_rooms=false,mobs={
 ["an arctic wolf"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Alaqsii Inlet",evidence="--aggro"},
}}
M.catalog["bloodwood"]={label="Bloodwood",areas={["bloodwood"]=true},requires_rooms=false,mobs={
 ["a distressed spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
 ["a lingering spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
 ["a wailing spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
}}
M.catalog["drakuum"]={label="Drakuum",areas={["drakuum"]=true},requires_rooms=false,mobs={
 ["a blackened darkwalker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence="-- some aggro"},
 ["a gnarled spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a hideous lich"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a misty apparition"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a savage shade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence="-- some aggro"},
}}
M.catalog["fengard"]={label="Fengard Keep",areas={["fengard keep"]=true},requires_rooms=true,mobs={
 ["a brawny glaive knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a fiery phenkyre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a horrid basilwyrm"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a massive argobole"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a pious invoker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a pungent lichosphere"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a radiant lumore"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a shrieking grimshrill"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a tall chempala"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a vicious horned garwhol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["an ethereal construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["an ogre berserker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["cosmina, the confessor"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["derban, the ice mage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["derryk, the guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["gladius, the red knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["gloom, the construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["grothgar, the ogre warlord"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["hecuba, the grim witch"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["sylvos, squire of gladius"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tara, the priestess"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["taskmaster grollum"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["the salacious sisters"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tiber, a young telepath"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tiber. a young telepath"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
}}
M.catalog["kalydian"]={label="Kalydian Forest",areas={["kalydian forest"]=true},requires_rooms=false,mobs={
 ["a gaunt elk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
 ["a rabid rabbit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
 ["a ravenous squirrel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
}}
M.catalog["khauskin"]={label="Khauskin Mines",areas={["khauskin mines"]=true},requires_rooms=false,mobs={
 ["a burly dwarven miner"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a dwarven boy"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a dwarven girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a grotesque fangtooth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a powerful dwarven warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a soft-shelled klikkin"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a statuesque dwarven guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a stocky dwarven woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a stout dwarven man"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
}}
M.catalog["lich"]={label="Lich Gardens",areas={["lich gardens"]=true},requires_rooms=false,mobs={
 ["a commanding lich scientist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Lich Gardens",evidence=""},
}}
M.catalog["mamashi"]={label="Mamashi Tunnels",areas={["mamashi tunnels"]=true},requires_rooms=false,mobs={
 ["a githani grappler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a githani inscriber"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a githani master"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a greater nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mature nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk axeman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk bladesman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk illusionist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a young nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["garthun, the maw"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["timol, the head inscriber"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
}}
M.catalog["mor"]={label="Caverns of Mor",areas={["caverns of mor"]=true},requires_rooms=false,mobs={
 ["a ravenous, shadowy ghast"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a robed, skeletal lich"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a skeletal warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a stench-ridden ghoul"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a vampiric warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["aclyr, the vampiric general"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
}}
M.catalog["ollin"]={label="Isle of Ollin",areas={["isle of ollin"]=true},requires_rooms=false,mobs={
 ["a ferocious alpha syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a fiendish, tainted syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a giant, rabid syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a massive, verdant-furred syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a nazetu comfort woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a rotting nazetu ghoul"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a young syll cub"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
}}
M.catalog["salma"]={label="Salma Settlement",areas={["salma settlement"]=true},requires_rooms=false,mobs={
 ["a bemused artist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a busy mage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a common man"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a dark-furred bear"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a dark-haired woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a hooded scholar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a robust blacksmith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a salmati guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a salmati warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a wealthy merchant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a wild-eyed scientist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an energetic child"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an engrossed scholar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an ordinary woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an unclean miner"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["dima, captain of the salmati guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["kyros, the salmati leader"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["linette, the salmati architect"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
}}
M.catalog["ayhesa"]={label="Ayhesa Cliffs",areas={["ayhesa cliffs"]=true},requires_rooms=false,mobs={
 ["a spellshaper adept"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
 ["a spellshaper archon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
 ["a spellshaper master"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
}}
M.catalog["tiyen"]={label="Tiyen Esityi",areas={["tiyen esityi"]=true},requires_rooms=false,mobs={
 ["a ball of chitinous legs"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["a bound shade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a cancerous stallion"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a crazed nazetu cutter"]={priority=200,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi; Fallout / Bashing / Tiyen / Cutter + Cutter here room message",evidence="AC aggro comment; Fallout cutter-only counter <4; native HOLD replaces movement fallback"},
 ["a deformed nazetu priest"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a massive, sacred serpent"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a mutated nazetu intercessor"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["a nazetu captain"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu cook"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu corrupter"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu crossbowman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu halberdier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu necromancer"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro and standard"},
 ["a nazetu provost"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a supply officer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a tangible malevolence"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a victimised intruder"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["commander marakhi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["insubstantial whispers"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["lieutenant chiakhi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["lieutenant gharvoi"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["quartermaster kuius"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["the creature beneath tiyen esityi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["tirahl the necromancer"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
}}
M.catalog["xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},requires_rooms=false,mobs={
 ["a bejeweled xorani harem girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a cautious xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a churning tidal spectre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a firewrought behemoth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a helpless xorani nestling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a merciless xorani warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a stoic bedrock colossus"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a suspicious xorani patrol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a willowy nest guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a wiry xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arcane anomaly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arrogant xorani master at arms"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an electrified sparkwraith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["caelakan, an arrogant prince"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["kithan, a young xorani girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
}}
M.catalog["top-xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},requires_rooms=true,mobs={
 ["a bejeweled xorani harem girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a cautious xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a churning tidal spectre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a firewrought behemoth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a helpless xorani nestling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a merciless xorani warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a stoic bedrock colossus"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a suspicious xorani patrol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a willowy nest guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a wiry xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arcane anomaly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arrogant xorani master at arms"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an electrified sparkwraith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["caelakan, an arrogant prince"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["kithan, a young xorani girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
}}
M.catalog["tcanna"]={label="Tcanna Island",areas={["tcanna island"]=true},requires_rooms=false,mobs={
 ["a bald eagle"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a black and white badger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a black bear"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a blue crab"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a box jellyfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a brown and tan python"]={priority=200,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island; Fallout / Bashing / Tcanna Bashing / Python Target trigger + Python here + guarded animal triggers",evidence=""},
 ["a brown-furred bat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a dark green alligator"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a diseased raccoon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a gray wolf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a great white stag"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a howler monkey"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a large capybara"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a lithe cougar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a long-billed toucan"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a nazetu officer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a ragged coyote"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a scarlet macaw"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a silverback gorilla"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a small ocelot"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a spotted jaguar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a spotted leopard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a striped tiger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a thick boa constrictor"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a troll cook"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a troll guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a venomous bushmaster"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a vicious copperhead snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a water buffalo"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a white goose"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a white-tailed deer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an ebon crow"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an enormous elephant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an oversized tortoise"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
}}
M.catalog["threerock"]={label="Threerock Outpost",areas={["threerock outpost"]=true},requires_rooms=false,mobs={
 ["a beautiful wild horse"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a huge, scarred wildcat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a long-haired buffalo"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a mountain wildcat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a shifty bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a wildcat kitten"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["an enormous troll bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["ennioch, a scruffy bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["the cave bear, white ghost"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["ugtar, a tall troll bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["webb, a shifty bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
}}
M.catalog["ylem"]={label="Ylem Mines",areas={["ylem mines"]=true},requires_rooms=true,mobs={
}}
M.catalog["snakepit"]={label="a snake pit",areas={["a snake pit"]=true},requires_rooms=false,mobs={
 ["a grassel snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a large sertag snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a muselon snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a tiny hatchling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a venenigol snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["an andragil snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["namaqua, queen of serpents"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["nandqua, mate of namaqua"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
}}
M.catalog["spiral"]={label="Spiral of corruption",areas={["spiral of corruption"]=true},requires_rooms=false,mobs={
 ["a five-tentacled octopus of jade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["a miasma-wreathed electric eel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["a rot-infested swordfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence="-- aggro"},
 ["a taint-infested shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["an ethereal, scarred jellyfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence="-- aggro"},
}}
M.catalog["teshen"]={label="Teshen Caldera",areas={["teshen caldera"]=true},requires_rooms=false,mobs={
 ["a gargantuan teshen drone"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen reaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen scout"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen worker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
}}
return M
