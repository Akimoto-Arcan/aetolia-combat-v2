-- Native tour attachment. All installation/status paths are send-free.
local B={}
-- Explicit native spellings reviewed against the existing static preset labels.
-- No automatic article/substring normalization and no new NPC authority.
B.disabled_presets={khauskin='protected-guard navigation correction not deployed'}
B.reviewed_aliases={
 ['the teshen caldera']='teshen', ['the three rock outpost']='threerock',
 ['the khauskin mines']='khauskin', ['the kalydian forest']='kalydian',
 ['the mamashi tunnels']='mamashi', ['the isle of ollin']='ollin',
 ['the ayhesa cliffs']='ayhesa', ['the fengard keep']='fengard'
}
-- Official aetolia-official.xml SHA256
-- 4717147cc4b0b9ddf01514120551343c0116f5a4c54eeb8269aaf629a444b5df.
-- Each nonidentical mapper label is reviewed at the literal native entrance.
-- This does not move an entrance, approve NPCs, or alias unrelated parent areas.
B.mapper_reviews={
 ['the augerweald']={entry='23791',area=437,name='Augerweald'},
 ["the ia'shal barrow"]={entry='5517',area=266,name="Ia'shal Barrow"},
 ['the sparklight rift']={entry='60845',area=471,name='Sparklight Rift'},
 ['the ruins of salma']={entry='19602',area=67,name='the Salma Settlement'},
 -- Exact literal native entrance and official/native mapper identity; no parent-area alias.
 ['the holy impire of sehal']={entry='24473',area=36,name='the Kingdom of New Sehal'},
 -- Article-only discrepancy, literal entrance and area agree in both snapshots.
 ['the cathedral of gloaming']={entry='22702',area=338,name='Cathedral of Gloaming'},
 -- Batch 2: article-only identity differences, literal native entry/area pinned.
 ['a memory of relovec mansion']={entry='15168',area=668,name='the memory of Relovec Mansion'},
 ['court of the consortium']={entry='27704',area=129,name='the Court of the Consortium'},
 ['the shastaan warrens']={entry='45483',area=255,name='Shastaan Warrens'},
 ['the bakal chasm']={entry='61011',area=477,name='Bakal Chasm'},
 -- Exact native entry; ALL 35 AC2.2 named-area room IDs equal the current
 -- 35-room mapper area 467. Not a parent-area/substring alias.
 ['a bandit encampment in the bonro sands']={entry='60323',area=467,name='bandit encampment in Bonro'}
}
local function sid(v)return v~=nil and tostring(v)or nil end
local function norm(v)return tostring(v or ''):lower()end
function B.area_matches(row,name,graph)
 if norm(name)==norm(row.name)then return true end
 local p=B.mapper_reviews[norm(row.name)]
 return p~=nil and sid(row.entry)==p.entry and graph~=nil and tonumber(graph.area)==p.area and sid(graph.start)==p.entry and norm(name)==norm(p.name)
end
-- Path is the mapper's semantic ordinary-foot terrain, never a numeric ID.
local dry={path=true,crater=true,['natural underground']=true,['constructed underground']=true,grasslands=true,graveyard=true,road=true,roads=true,forest=true,grassland=true,hills=true,mountains=true,mountain=true,urban=true,indoors=true,inside=true,cave=true,cavern=true,desert=true,tundra=true,swamp=true,jungle=true,beach=true,garden=true,plain=true,plains=true,field=true,fields=true,city=true,village=true,building=true,ruins=true,underground=true,valley=true,scrubland=true}
-- Missing native semantic labels, sourced from the pinned official XML above.
-- These are NAME receipts, not numeric movement permissions. Native labels win.
-- In particular lava/ice/water and unknown names remain rejected below.
B.official_environment_names={
 [1]="Chaos",
 [2]="Constructed underground",
 [3]="Natural underground",
 [4]="Forest",
 [5]="Beach",
 [6]="Desert",
 [7]="Grasslands",
 [8]="Urban",
 [9]="Hills",
 [10]="River",
 [11]="Path",
 [12]="Road",
 [13]="Valley",
 [14]="Mountains",
 [15]="Swamp",
 [16]="Tundra",
 [17]="Jungle",
 [18]="Field",
 [19]="Tsol'aa city",
 [20]="Ocean",
 [21]="Garden",
 [22]="Freshwater",
 [23]="Sewer",
 [24]="Deep ocean",
 [25]="Reef",
 [26]="Ruins",
 [27]="Village",
 [28]="Underwater city",
 [29]="Temple",
 [30]="Ice",
 [31]="Graveyard",
 [32]="Mines",
 [33]="Onboard",
 [34]="Canyon",
 [35]="Coniferous Forest",
 [36]="Within a tree",
 [37]="Crater",
 [38]="Haven",
 [39]="Lava",
 [40]="Subterranean lake",
 [41]="Sunken ship",
 [42]="Reef island",
 [43]="Lagoon",
 [44]="Stagnant water",
 [45]="Loose terrain",
 [46]="Mud flat",
 [47]="Ocean floor",
 [48]="Stream",
 [49]="Pond",
 [50]="Lake",
 [52]="A monstrous body",
 [53]="Oasis",
 [54]="Lifeless sands",
 [55]="Settlement",
 [56]="Logged forest",
 [57]="Camp site",
 [58]="Shadows",
 [59]="Cliffs",
 [60]="Light",
 [61]="Castle",
 [62]="Airship wreckage",
 [63]="Farm",
 [64]="Labyrinth",
 [65]="Airship",
 [66]="Divine",
 [67]="Ethereal",
 [68]="Abyss",
 [69]="Cavern",
 [70]="Grotto",
 [71]="Wetland",
 [72]="Marsh",
 [73]="Constructible",
 [75]="Petrified Forest",
 [76]="Quarry",
 [77]="Unstable",
 [78]="Ancient forest",
 [79]="Tent",
 [80]="Keep",
 [81]="Putrid water",
 [82]="Primordial earth",
 [83]="Ruined forest",
 [84]="Tidal pool",
 [85]="Rocky outcropping",
 [86]="Blighted forest",
 [87]="Deep subterrane",
 [88]="Open air",
 [89]="Blighted woodland",
 [90]="Lodge",
 [91]="Estate",
 [92]="Fen",
 [93]="Quicksilver sea",
 [94]="Desert village",
 [96]="Lava pit",
 [98]="Military outpost",
 [99]="Underground stronghold",
 [100]="Stronghold",
 [101]="Snow",
 [102]="Scree",
 [103]="Alpine",
 [104]="Wasteland",
 [105]="Catacombs",
 [106]="Cabin",
 [107]="Sanctum",
 [108]="Library",
 [109]="Shipyards",
 [110]="Bridge",
 [113]="Tavern",
 [114]="Alien structure",
 [116]="A construct of corpses",
 [117]="Frozen forest",
 [118]="Ship",
 [120]="A spice field",
 [121]="Pasture",
 [122]="A grain field",
 [123]="A vegetable field",
 [124]="A tuber field",
 [125]="A fruit field",
 [126]="A cotton field",
 [127]="Ship wreckage",
 [128]="Ethereal forest",
 [129]="Mirror",
 [130]="Nest",
 [131]="Great Rock",
 [132]="Docks",
 [133]="A rice field",
 [134]="Forestal campsite",
 [136]="Elemental Vortex",
 [137]="Burrow",
 [138]="Woodland",
 [140]="Yard",
 [142]="Eldritch verdancy",
 [143]="Chaotic machinery",
 [144]="Golden effulgence",
 [145]="Poppy fields",
 [146]="Crystalline catacombs",
 [147]="Oceanic palace",
 [148]="Blue basilica",
 [149]="Iridescent tallgrass",
 [150]="Absinthian corridors",
 [151]="Chaos-torn jungle",
 [152]="Metallic wilds",
 [153]="Cinnabar passages",
 [154]="Purple dunes",
 [155]="Verdant growth",
 [156]="Shadowed labyrinth",
 [157]="Rosy labyrinth",
 [158]="Limestone caverns",
 [159]="Cyanic cenote",
 [160]="Encampment",
 [161]="Walls",
 [162]="Within a prison cell",
 [163]="Bathhouse",
 [164]="Ancestral crypt",
 [165]="Quicksilver landscape",
 [166]="Deep beneath the earth",
 [167]="Saffron fields",
 [168]="Indigotic inflorescence",
 [169]="Violaceous vaults",
 [170]="Celestial brilliance",
 [171]="Garnet-hued halls",
 [172]="Azurine alcove",
 [173]="Underground forest",
 [174]="Hotspring",
 [175]="Lavender fields",
 [176]="Iris fields",
 [177]="Periwinkle fields",
 [178]="Chaotic carnations",
 [179]="Elemental chaos",
 [184]="Polluted lake",
 [185]="Death-infused ruins",
 [187]="Royal vaults",
 [188]="Belfry",
 [190]="Vacuum",
 [191]="Creation",
 [192]="Infernal",
 [193]="Cataclysm",
 [194]="Scoured",
 [195]="Ylem rapids",
 [197]="Dilapidated garden",
 [198]="Orchard",
 [199]="Endless Battlefield",
 [200]="Tar pit",
 [201]="Bone",
 [202]="Volcanic",
 [203]="Land bridge",
 [204]="Foothills",
 [205]="Canal",
 [206]="Aechrian Thinking Engine",
 [208]="Hlugnic city",
 [209]="Mushroom garden",
 [210]="Hatchery",
 [211]="Aboard a ship",
 [212]="Hellfire",
 [213]="Sauna",
 [215]="Harbor",
 [216]="Crystal",
 [219]="Arcane Sanctum",
 [222]="Turbulent ocean",
 [223]="Frozen beach",
 [224]="Salt plains",
 [225]="Lair",
 [226]="Blightfield",
 [227]="Dirt",
 [228]="Structure",
 [229]="Igneous Flats"
}
-- Ordinary land/building semantics reviewed independently of their IDs. Frozen
-- forest is not Ice; Scoured is not Vacuum or Chaos. No water/lava travel grant.
for _,name in ipairs({'field','coniferous forest','lifeless sands','canyon','cliffs',
 'farm','petrified forest','ancient forest','tent','keep',
 'rocky outcropping','lodge','estate',
 'desert village','military outpost','underground stronghold','stronghold',
 'snow','alpine','wasteland','catacombs','cabin','library','bridge','a bridge',
 'tavern','frozen forest','burrow','woodland','encampment','scoured','orchard',
 'land bridge','foothills','temple','mines','castle','logged forest','camp site'})do dry[name]=true end
function B.environment_name(id)
 local m=mmp or {};local name=(m.envidsr or {})[id]or(m.envidsr or {})[tostring(id)]
 if not name then for k,v in pairs(m.envids or {})do if tostring(v)==tostring(id)then name=k;break end end end
 return name or B.official_environment_names[tonumber(id)]
end
function B.dry_environment(id)
 local m=mmp or {};local name=B.environment_name(id)
 if type(name)~='string'then return false end
 local water=m.waterenvs or {}
 if water[id]or water[tostring(id)]or water[name]then return false end
 for _,v in pairs(water)do if v==id or v==name then return false end end
 return dry[norm(name)]==true
end
-- Scoped ordinary Igneous review: pinned native DTO + AC/Darkside/Sunder
-- ordinary volcanic route targets. NOT a global terrain or numeric-ID grant.
local gloaming_igneous={}
for _,id in ipairs({24722,24723,24783,22796,22797,22798,22799,22800,22801,22802,22803,22804,22805,22806,22807,22808,22809,22810,22811,22812,22813,22814,22815,22816,22817,22820,22821,22822,22823,22853})do gloaming_igneous[id]=true end
function B.ordinary_environment(env,room,area,label)
 if label~=nil and type(label)~='string'then return false end
 local name=B.environment_name(env)
 if B.dry_environment(env)then return label==nil or dry[norm(label)]==true end
 if tonumber(area)~=338 or not gloaming_igneous[tonumber(room)]or norm(name)~='igneous flats'
  or label~=nil and norm(label)~='igneous flats' then return false end
 if type(getRoomName)~='function'or getRoomName(tonumber(room))~='Upon a vast volcanic stretch'then return false end
 local m=mmp or {};local water=m.waterenvs or {}
 if water[env]or water[tostring(env)]or water[name]then return false end
 for _,v in pairs(water)do if v==env or v==name then return false end end
 return true
end
function B.graph(c,row)
 for _,key in ipairs({'getRoomArea','getAreaRooms','getAreaTable','getRoomExits','getRoomEnv','roomLocked','getDoors','getRoomWeight'})do if type(_G[key])~='function'then return nil,'mapper/terrain API unavailable: '..key end end
 local entry=tonumber(row.entry);if not entry or entry<=0 then return nil,'no positive entry VNum'end
 local area=getRoomArea(entry)
 if not area or tonumber(area)==-1 or tonumber(area)==0 then return nil,'unmapped entrance VNum '..tostring(entry)end
 if roomLocked(entry)~=false then return nil,'mapped entrance locked or lock state unknown'end
 if not tonumber(getRoomWeight(entry))or tonumber(getRoomWeight(entry))>1 then return nil,'mapped entrance weight unsupported'end
 if not B.ordinary_environment(getRoomEnv(entry),entry,area)and not(c.special_exits and c.special_exits.water_environment(getRoomEnv(entry)))then
  return nil,'terrain unsupported at mapped entrance: '..tostring(B.environment_name(getRoomEnv(entry))or ('unknown environment '..tostring(getRoomEnv(entry))))
 end
 local names=getAreaTable();local area_name
 if type(names)=='table'then
  if type(names[area])=='string'then area_name=names[area]
  else for name,id in pairs(names)do
   if type(name)=='string'and tonumber(id)==tonumber(area)then if area_name then return nil,'ambiguous mapper area name'end;area_name=name end
  end end
 end
 if not B.area_matches(row,area_name,{area=area,start=sid(entry)})then return nil,'entry mapper area name not verified: '..tostring(area_name)..' (area '..tostring(area)..', entrance '..tostring(entry)..')'end
 local ids=getAreaRooms(area);if type(ids)~='table'then return nil,'unmapped area'end
 local rooms,total,excluded,seen={},0,0,{}
 local active=c.current and c.current.hunting and c.current.hunting.preset
 -- Planning a later row must not inherit the currently selected area's scope.
 local preset=active and B.area_matches(row,active.area,{area=area,start=sid(entry)}) and active or nil
 local scoped=c.walker.hidden_scope and c.walker.hidden_scope('drakuum',area,area_name,getRoomArea(19854)) and norm(row.name)=='drakuum'
 for _,id in pairs(ids)do
  id=tonumber(id)
  if id and not seen[id]then
  seen[id]=true;total=total+1;if total>3000 then return nil,'map room budget exceeded'end
  if id and (not preset or not preset.rooms or preset.rooms[tostring(id)]) and getRoomArea(id)==area and roomLocked(id)==false and tonumber(getRoomWeight(id))and tonumber(getRoomWeight(id))<=1 and (B.ordinary_environment(getRoomEnv(id),id,area) or c.special_exits and c.special_exits.water_environment(getRoomEnv(id)))then
   local exits,doors=getRoomExits(id),getDoors(id)
   if type(exits)~='table'or type(doors)~='table'then return nil,'malformed mapper exits/doors'end
   rooms[tostring(id)]={area=area,exits=exits,doors=doors,hidden_scope=scoped,env=getRoomEnv(id),weight=getRoomWeight(id),locked=roomLocked(id),wet=not B.ordinary_environment(getRoomEnv(id),id,area)}
  else excluded=excluded+1 end
  end
 end
 local special,diagnostics={},{}
 if c.special_exits then special,diagnostics=c.special_exits.descriptors(c,area,rooms)end
 local incoming,outgoing={},{}
 for _,e in ipairs(special)do if e.kind=='swim'then incoming[e.to]=true;outgoing[e.from]=true end end
 for id,room in pairs(rooms)do if room.wet and not(incoming[id]and outgoing[id])then rooms[id]=nil;excluded=excluded+1 end end
 local g,why=c.walker.build(entry,area,rooms,{special_edges=special})
 if not g and not rooms[sid(entry)]and c.special_exits and c.special_exits.water_environment(getRoomEnv(entry))then
  return nil,'terrain unsupported at mapped entrance: '..tostring(B.environment_name(getRoomEnv(entry)))..' (no vetted water capability)'
 end
 if g then g.special_diagnostics=diagnostics end
 if g then
  g.mapped_count=total;g.terrain_excluded=excluded
  g.disconnected_count=math.max(0,total-excluded-g.room_count)
  g.partial_coverage=g.room_count<total
  g.coverage=g.room_count..' reachable safe foot rooms / '..total..' mapped entries'
   ..(g.partial_coverage and ' (partial; excluded terrain/locks/doors or disconnected components remain)'or '')
 end
 return g,why
end
-- Read-only approach planning. This is NOT an executor, consent, special edge,
-- hunting scope or permission to replace the literal server entrance.
-- Only the recorded one-hop Centipede boundary is reviewed; no graph search.
function B.approach(c,row)
 if norm(row.name)~='the centipede cave'or sid(row.entry)~='22824'then return nil,'no reviewed direct ordinary approach descriptor'end
 for _,key in ipairs({'getRoomArea','getAreaTable','getRoomExits','getDoors','roomLocked','getRoomWeight','getRoomEnv'})do
  if type(_G[key])~='function'then return nil,'approach mapper API unavailable: '..key end
 end
 local names=getAreaTable()
 local function label(area)
  if type(names[area])=='string'then return names[area]end
  for name,id in pairs(names)do if tonumber(id)==area then return name end end
 end
 local from,to=22824,22825
 if getRoomArea(from)~=441 or getRoomArea(to)~=462 or label(441)~='Mount Heylai'or label(462)~='the Centipede Caves'then return nil,'approach exact mapper identity changed'end
 local forward,back=getRoomExits(from),getRoomExits(to)
 local function points(exits,long,short,destination)
  return type(exits)=='table'and(exits[long]~=nil or exits[short]~=nil)
   and(exits[long]==nil or tonumber(exits[long])==destination)
   and(exits[short]==nil or tonumber(exits[short])==destination)
 end
 if not points(forward,'down','d',to)or not points(back,'up','u',from)then return nil,'approach ordinary forward/reverse topology changed'end
 for _,x in ipairs({{from,'down','d'},{to,'up','u'}})do
  local doors=getDoors(x[1]);if type(doors)~='table'then return nil,'approach doors unknown'end
  for _,key in ipairs({x[2],x[3]})do if doors[key]~=nil and tonumber(doors[key])~=0 then return nil,'approach door handling required'end end
  local weight=tonumber(getRoomWeight(x[1]))
  if roomLocked(x[1])~=false or not weight or weight>1 or not B.dry_environment(getRoomEnv(x[1]))then return nil,'approach endpoint lock/weight/terrain unsupported'end
 end
 -- Build the target area independently. The outside entrance never becomes a
 -- hunting node and no identity alias equates Mount Heylai with the cave.
 local graph,why=B.graph(c,{name='the Centipede Caves',entry='22825'})
 if not graph then return nil,why end
 return {native_name=row.name,native_entry=sid(row.entry),from='22824',to='22825',
  direction='d',command='d',reverse='u',from_area=441,target_area=462,
  target_mapper_name='the Centipede Caves',graph=graph,executable=false,
  provenance='native-map 2026-11-25_07-42-47 + pinned official XML; exact ordinary down/up pair',
  requires='parent-owned approach dispatch/arrival integration and fresh native source readiness; no automatic execution'}
end
local function hidden_equal(a,b)
 for k,exits in pairs(a.certified_hidden or {})do for d,v in pairs(exits)do
  local w=((b.certified_hidden or {})[k]or{})[d]
  if not w or v.to~=w.to or v.source~=w.source or v.target~=w.target then return false end
 end end
 return true
end
local function samegraph(a,b)
 if not a or not b or a.start~=b.start or a.area~=b.area or a.hidden_provenance~=b.hidden_provenance or not hidden_equal(a,b)or not hidden_equal(b,a)then return false end
 for id,exits in pairs(a.nodes)do if not b.nodes[id]then return false end;for d,to in pairs(exits)do if b.nodes[id][d]~=to then return false end end end
 for id,exits in pairs(b.nodes)do if not a.nodes[id]then return false end;for d,to in pairs(exits)do if a.nodes[id][d]~=to then return false end end end
 return true
end
function B.attach(c)
 if c.tour_attachment then B.detach(c)end
 local M=dofile(getMudletHomeDir()..'/combat_v2/tour.lua')
 local a={attached=true,session={},room_sequence=0,aliases={},handlers={}};c.tour_attachment=a;c.tour_module=M;c.tour_boot=B
 local function owned(fn,...)
  local args={...};local before,mode_budget,revoke_budget=a.owned,a.mode_budget,a.revoke_budget;a.owned=true
  if fn==combat_v2_set_mode then a.mode_budget={wanted=tostring(args[1]):upper()}
  elseif fn==(c.travel_module and c.travel_module.pt)or fn==(c.travel and c.travel.request)then a.mode_budget={wanted='OFF'}end
  if fn==c.walker_boot.revoke then a.revoke_budget={reason=args[2]}end
  local ok,x,y=pcall(fn,...);a.owned=before;a.mode_budget=mode_budget;a.revoke_budget=revoke_budget
  if not ok then error(x)end;return x,y
 end
 local function restock_owned()
  return c.restock_module and c.restock_module.owns_transition and c.restock_module.owns_transition(c)==true
 end
 local function scoped(grant)
  return a.attached and c.tour_attachment==a and grant.session==a.session and c.current.connected and not c.current.player.dead and c.current.player.class==grant.class and grant.generation==c.tour.state.generation
 end
 local function trbusy()
  local s=c.travel_owner or {}
  return s.pending or s.intent or s.route or s.dispatching or s.fault or s.follow_pending or s.follow_fault or s.follow_due or s.recall_due or s.stopping or s.refresh_due
 end
 local catalog={}
 for id,row in pairs(c.areas.catalog)do
  local areas={};for name,yes in pairs(row.areas)do areas[name]=yes end
  for name,preset in pairs(B.reviewed_aliases)do if preset==id then areas[name]=true end end
  catalog[id]={areas=areas,requires_rooms=row.requires_rooms,disabled_reason=B.disabled_presets[id]}
 end
 local io={catalog=catalog,now=function()return getEpoch and getEpoch()or os.clock()end,scope=scoped}
 io.stream_session=function()return a.session end
 io.grant=function(g,lo,hi)return {session=a.session,class=c.current.player.class,generation=g,lo=lo,hi=hi}end
 io.start_ready=function()
  if not c.travel or not c.travel.attached then return false,'native PT convenience not attached/configured'end
  if not c.current.connected or type(c.current.player.class)~='string'or c.current.player.class==''then return false,'session/class unavailable'end
  if not combat_v2_area_settled()then return false,'requires OFF and every real action/travel/restock owner settled'end
  local g=c.elemental_recovery or {};if g.armed then return false,'GLOBE must be OFF'end
  return true
 end
 io.arm_controls=function()
  local ok,why=combat_v2_restock('on');if not ok then return false,why end
  local w=c.walker.state(c.current);w.enabled=true;w.ask_on_bash=false
  return true
 end
 io.ratings=function()
  if c.tour.state.phase=='ratings'then c.policy.request_areas(c.current)end
  return send('areas')~=false
 end
 io.graph=function(row)return B.graph(c,row)end
 io.transfer_stamp=function()return {sequence=a.room_sequence}end
 io.transfer=function(slot,grant)
  if not scoped(grant)or not io.start_ready()then return false,'transfer grant/readiness expired'end
  slot.transfer_owner=c.travel_owner
  if sid(c.current.room.id)==slot.row.entry then slot.local_entry=true;return send('look')~=false end
  local ok,why=owned(c.travel_module.pt,c,slot.row.entry)
  slot.transfer_serial=(c.travel_owner or {}).serial
  return ok,why
 end
 io.arrived=function(slot,stamp)
  local tr=c.travel_owner or {}
  if tr~=slot.transfer_owner then return nil,'PT owner identity changed'end
  if tr.fault or tr.follow_fault then return nil,tr.fault or tr.follow_fault end
  if not slot.local_entry and (tr.destination~=slot.row.entry or tr.serial<(slot.transfer_serial or 0))then return nil,'transfer destination/serial changed'end
  if trbusy()then return false end
  local refusal=tr.refusal;local rejected=tr.last_find_rejection
  if refusal and refusal.recoverable==true and refusal.kind=='find_cooldown'and rejected
   and refusal.serial==rejected.serial and rejected.transport_ok==true then
   slot.retry_count=tr.find_attempts
   if not slot.refusal_check then
    -- Native PT already bounded its exact known rejection to three attempts.
    -- Local status first, then one solicited read-only source-room check.
    slot.check=io.status();slot.refusal_check={room=sid(c.current.room.id),area=c.current.room.area,version=c.current.room.item_version,sequence=a.room_sequence,at=io.now()}
    local ok,x=pcall(function()if send('look')==false then return false end;return c.travel.io.refresh_items()end)
    if not ok or x==false then return nil,'known refusal status transport unknown'end
    return false
   end
   local proof=slot.refusal_check;local s=c.current
   if sid(s.room.id)~=proof.room or s.room.area~=proof.area then return nil,'source room changed during refusal status check'end
   if a.room_sequence>proof.sequence and s.room.item_version>proof.version and c.areas.fresh(s)then
    slot.refusal_proven=true;return nil,refusal.reason
   end
   if io.now()-proof.at>15 then return nil,'known refusal status response incomplete'end
   return false
  end
  if a.room_sequence<=stamp.sequence then return false end
  local r=a.room_info
  if not r or sid(r.num)~=slot.row.entry or not B.area_matches(slot.row,r.area,slot.graph)then return nil,'actual entrance Room.Info does not match granted area'end
  if sid(c.current.room.id)~=slot.row.entry or c.current.room.area~=r.area then return nil,'canonical entrance mismatch'end
  return true
 end
 io.prepare=function(slot,grant)
  if not scoped(grant)or not io.start_ready()then return false,'preparation not settled OFF'end
  local ok,why=owned(combat_v2_area_configure,slot.preset,c.current.room.area);if not ok then return false,why end
  slot.prepare_sequence=a.room_sequence
  if c.current.player.mounted~=false then
   slot.dismount_owner=c.travel_owner
   return owned(c.travel.request,'qd')
  end
  return true
 end
 io.prepared=function(slot,grant)
  if not scoped(grant)then return nil,'preparation consent expired'end
  if trbusy()then slot.ready_since=nil;local tr=c.travel_owner;if tr.fault or tr.follow_fault then return nil,tr.fault or tr.follow_fault end;return false end
  local s=c.current
  if sid(s.room.id)~=slot.row.entry or not B.area_matches(slot.row,s.room.area,slot.graph)then return nil,'entrance changed during preparation'end
  if s.player.mounted~=false then slot.ready_since=nil;return false end
  if not io.start_ready()then slot.ready_since=nil;return false end
  local ready,why=c.travel.io.ready();if not ready then slot.ready_since=nil;return false,why end
  if not c.policy.allowed(s)then slot.ready_since=nil;return false,'fresh area/player policy required'end
  local g,err=B.graph(c,slot.row)
  if not g then return nil,err end
  if not samegraph(g,slot.graph)then return nil,'validated safe foot graph changed since plan'end
  if not slot.ready_since then slot.ready_since=io.now();return false,'settled entry pacing gap'end
  if io.now()-slot.ready_since<2 then return false,'settled entry pacing gap'end
  slot.active_graph=g;return true
 end
 io.begin=function(slot,grant)
  if not scoped(grant)or not io.prepared(slot,grant)then return false,'fresh arrival/preparation proof required'end
  local s=c.current;local w=c.walker.state(s)
  -- Do not arm WALK until BASH preparation has settled. No popup/automatic offer.
  w.enabled=false
  local ok,why=owned(combat_v2_set_mode,'BASH')
  -- Public mode returns the first tick's result, not transition success; an
  -- empty reviewed entrance legitimately returns false/no eligible preset NPC.
  if c.mode~='BASH'or s.mode~='BASH'or c.runner.mode~='BASH'then return false,why or 'BASH transition refused'end
  if not scoped(grant)or not B.area_matches(slot.row,s.room.area,slot.graph)or sid(s.room.id)~=slot.row.entry then return false,'grant changed during BASH preparation'end
  local d=c.restock_data
  if d and d.enabled and not d.active and not d.fault and not d.busy and not d.pending and not d.purchase then
   local armed,err=combat_v2_restock('on');if not armed then return false,err or 'restock monitor rearm refused'end
  end
  w.enabled=true;w.ask_on_bash=false
  local token,err=c.walker.offer(s,slot.active_graph);if not token then return false,err end
  slot.token=token;slot.epoch=w.intent_epoch;slot.grant=grant
  -- Only this fresh range grant and exact area graph may answer this one offer.
  return owned(c.walker_boot.answer,c,token,true)
 end
 io.walker=function()return c.walker.state(c.current)end
 io.borrowed=function(slot)
  local d=c.restock_data or {};local w=io.walker();local cp=w.restock_checkpoint
  if cp then
   if cp.lease~=d or cp.graph~=slot.active_graph or cp.visited~=w.visited or cp.cancelled or cp.generation~=slot.token then return nil,'restock checkpoint identity invalid'end
   if d.fault then return nil,'restock fault: '..tostring(d.fault)end
   slot.checkpoint=cp;return true
  end
  if slot.checkpoint then
   if not slot.checkpoint.resumed then return nil,'restock checkpoint removed without exact-room restoration'end
   if w.graph~=slot.checkpoint.graph or w.visited~=slot.checkpoint.visited then return nil,'restock route identity changed'end
   slot.checkpoint=nil
  end
  local rm=c.restock_module
  if rm and ((rm.busy and rm.busy(c))or(rm.movement_reserved and rm.movement_reserved(c)))then return true end
  return false
 end
 io.hunt_fault=function(slot)
  local s=c.current;local w=io.walker()
  if not B.area_matches(slot.row,s.room.area,slot.active_graph)or not slot.active_graph.nodes[sid(s.room.id)]then return 'live area/graph mismatch'end
  if w.offers~=slot.token or w.intent_epoch~=slot.epoch then return 'walker generation/intent changed'end
  -- A vetted surface node is NOT ordinary foot: retain the canonical SWIM
  -- descriptors and revalidate future topology/learning separately from dispatch.
  local surface=false;local sx=c.special_exits;local id=sid(s.room.id)
  if sx and sx.surface_endpoint and type(c.special_exit_capability)=='function'then
   local endpoint=sx.surface_endpoint(c,tonumber(id))
   if endpoint and endpoint.water==true then
    for direction,hop in pairs((slot.active_graph.special_edges or {})[id]or {})do
     if hop.kind=='swim'and slot.active_graph.nodes[id][direction]==hop.to then
      local ok,cap=pcall(c.special_exit_capability,c,hop.metadata,'plan')
      local pinned=hop.capability
      if ok and cap and pinned and cap.session==pinned.session and cap.epoch==pinned.epoch and cap.graph==pinned.graph then surface=true;break end
     end
    end
   end
  end
  -- Core handles Room.Info before the coordinator's later multicast observer.
  -- Never apply that observer's previous wet-room label to the new dry shore.
  local native=gmcp and gmcp.Room and gmcp.Room.Info
  local current_info=native and sid(native.num)==id and native.area==s.room.area and native or a.room_info
  local env=current_info and sid(current_info.num)==id and current_info.area==s.room.area and current_info.environment or nil
  if not surface and not B.ordinary_environment(getRoomEnv(tonumber(s.room.id)),s.room.id,getRoomArea(tonumber(s.room.id)),env)then return 'live/mapper terrain not reviewed for ordinary foot travel'end
  if surface and type(env)=='string'and norm(env)~='river'and norm(env)~='freshwater'then return 'live surface terrain changed'end
  if s.hunting.area_recovery then return 'room parser recovery required'end
  if c.areas.fresh(s)then
   local row=c.areas.catalog[slot.preset]
   for id,it in pairs(s.room.items or {})do
    if c.areas.navigation_blocked(s,it)and not row.mobs[norm(it.name)]and not c.areas.defensive_eligible(s,id)then return 'unsupported living NPC: '..tostring(it.name)end
   end
  end
 end
 io.finish_ready=function(slot)
  local s=c.current;local w=io.walker();local i=w.inspection
  if io.borrowed(slot)then return false,'restock owns completion'end
  if trbusy()or c.runner.waiting or c.runner.pending or c.runner.fault or not c.runner_module.ready(c.runner)then return false,'real action recovery unfinished'end
  if not i or i.room~=sid(s.room.id)or i.items~=s.room.items or i.version~=s.room.item_version or i.sequence~=w.room_sequence or not c.areas.fresh(s)or c.areas.blocked(s)or not c.policy.allowed(s)then return false,'fresh safe completion inspection required'end
  if c.travel_module.blocked(c)then return false,'shared owner blocks finish'end
  return true
 end
 io.finish=function()return owned(combat_v2_set_mode,'OFF')end
 io.status=function()
  local s=c.current;local w=io.walker();local p=s.player or {};local tr=c.travel_owner or {};local d=c.restock_data or {}
  return {room=s.room.id,area=s.room.area,hp=p.hp,maxhp=p.maxhp,connected=s.connected,dead=p.dead,
   walker_pending=w.pending,arrival_hold=w.arrival_hold,travel_pending=tr.pending,travel_fault=tr.fault,
   restock_pending=d.pending,restock_fault=d.fault,runner_waiting=c.runner.waiting,runner_fault=c.runner.fault}
 end
 io.can_retire=function(slot,reason,check)
  local s=c.current;local p=s.player;local w=io.walker();local tr=c.travel_owner or {}
  local hp,max=tonumber(p.hp)or 0,tonumber(p.maxhp)or 0
  if not s.connected or p.dead or max<=0 or hp/max*100<math.max(s.config.health_resume or 60,s.config.defense_health_resume or 65)then return false end
  if trbusy()or w.pending or w.dispatching or w.physical_dispatch or w.arrival_hold or w.restock_checkpoint or w.fault then return false end
  local rm=c.restock_module
  if rm and ((rm.busy and rm.busy(c))or(rm.movement_reserved and rm.movement_reserved(c)))then return false end
  if c.travel_module.blocked(c)or not c.runner_module.ready(c.runner)then return false end
  local refusal=slot.refusal_proven and c.mode=='OFF'and slot.refusal_check
   and slot.refusal_check.room==sid(s.room.id)and slot.refusal_check.area==s.room.area
  if refusal then
   local policy=s.policy
   if not policy.players_known or policy.players_room~=s.room.id or c.policy.has_others(s)then return false end
  elseif not c.policy.allowed(s)then return false end
  -- No status check manufactures fresh occupancy or permits abandoning a threat.
  if not c.areas.fresh(s)then return false end
  for _,it in pairs(s.room.items or {})do if c.areas.navigation_blocked(s,it)then return false end end
  if refusal then return true end
  local i=w.inspection
  return i and i.room==sid(s.room.id)and i.items==s.room.items and i.version==s.room.item_version and i.sequence==w.room_sequence or false
 end
 io.retire=function(slot)
  slot.check=io.status();slot.reason=c.tour.state.reason
  owned(c.walker_boot.revoke,c,'tour skipping settled safe area: '..tostring(slot.reason))
  return owned(combat_v2_set_mode,'OFF')
 end
 io.hold=function()
  -- Revoke only unsent walking. Never generic BASH OFF or clear a real owner.
  if not(c.restock_data and c.restock_module and c.restock_module.busy(c))then owned(c.walker_boot.revoke,c,'tour held; unsent walking revoked')end
 end
 io.cancel=function(why)return owned(c.walker_boot.revoke,c,why)end
 local t=M.new(io);c.tour=t
 local revoke=c.walker_boot.revoke
 c.walker_boot.revoke=function(owner,why,...)
  local direct=a.revoke_budget and not a.revoke_budget.used and a.revoke_budget.reason==why
  if direct then a.revoke_budget.used=true end
  local internal=direct or a.owned and (why=='private preset configured; fresh consent required'or (a.mode_depth or 0)>0 and (why=='OFF'or why=='explicit mode selection'))
  -- Broad sender/reentrant scope is NOT an operator-intent exemption.
  if owner==c and not internal and not restock_owned()then t.cancel(why,true)end
  return revoke(owner,why,...)
 end
 local mode=combat_v2_set_mode
 combat_v2_set_mode=function(value,...)
  local budget=a.mode_budget
  local internal=budget and not budget.used and budget.wanted==tostring(value):upper()
  if internal then budget.used=true end
  if not internal and not restock_owned()then t.cancel('explicit operator mode '..tostring(value))end
  a.mode_depth=(a.mode_depth or 0)+1
  local ok,x,y=pcall(mode,value,...);a.mode_depth=a.mode_depth-1
  if not ok then error(x)end;return x,y
 end
 local tick=combat_v2_tick
 combat_v2_tick=function(...)
  if a.attached then t.tick()end
  return tick(...)
 end
 -- Own only named handles. Old callbacks become inert on reload/detach.
 local function event(name,fn)a.handlers[#a.handlers+1]=registerAnonymousEventHandler(name,fn)end
 event('gmcp.Room.Info',function()
  if not a.attached then return end
  local r=gmcp and gmcp.Room and gmcp.Room.Info
  if r and r.num~=nil and type(r.area)=='string'then a.room_sequence=a.room_sequence+1;a.room_info={num=r.num,area=r.area,environment=r.environment}end
 end)
 event('sysDisconnectionEvent',function()a.session={};t.cancel('disconnected')end)
 a.trigger=tempRegexTrigger('^.*$',function()if a.attached then t.line(line or '')end end)
 local function timer()
  if not a.attached then return end;t.tick();a.timer=tempTimer(0.5,timer)
 end
 a.timer=tempTimer(0.5,timer)
 combat_v2_tour=function(command)
  command=tostring(command):gsub('^bash +','bash')
  if command=='bashstatus'then return B.status(c)
  elseif command=='bashstop'then t.cancel('explicit bashstop');return owned(combat_v2_walk,'off')
  elseif command=='bashplan'then return B.status(c)end
  return t.start(command)
 end
 -- Never remove or overwrite legacy aliases. Refuse installation on named
 -- collisions; arbitrary unnamed third-party regexes require operator audit.
 local collision=false
 if type(exists)=='function'then
  for _,name in ipairs({'bash','bash75','bash100','bashstatus','bashstop','bashplan'})do if exists(name,'alias')>0 then collision=true end end
 end
 if c.tour_alias_collision==true then collision=true end
 if not collision then
  for _,pattern in ipairs({'^bash[ ]*[0-9]+(?:[ ]+[0-9]+)?$','^bash[ ]*status$','^bash[ ]*stop$','^bash[ ]*plan$'})do
   a.aliases[#a.aliases+1]=tempAlias(pattern,function()local ok,why=combat_v2_tour(matches and matches[1]or '');if not ok and why then print('TOUR: '..tostring(why))end end)
  end
 else a.alias_error='legacy alias collision: no range aliases installed'end
 return true
end
function B.status(c)
 local s=c.tour.state;local out={phase=s.phase,reason=s.reason,lo=s.lo,hi=s.hi,ready={},completed={},partial={},skipped={},unsupported={},unmapped={},terrainexcluded={},held={}}
 for k,v in pairs(s.plan or {})do
  if k~='ready'and k~='completed'and k~='partial'then for _,slot in ipairs(v)do out[k][#out[k]+1]=slot end end
 end
 for _,slot in ipairs(s.plan and s.plan.ready or {})do
  local bucket=slot.status=='partial'and 'partial'or slot.status=='completed'and 'completed'or slot.status=='held'and 'held'or slot.status=='skipped'and 'skipped'or 'ready'
  out[bucket][#out[bucket]+1]=slot
 end
 print('TOUR '..s.phase..' '..tostring(s.lo or '')..'..'..tostring(s.hi or '')..': '..tostring(s.reason or ''))
 for _,key in ipairs({'ready','completed','partial','skipped','unsupported','unmapped','terrainexcluded','held'})do
  print(key..': '..#out[key]);for _,slot in ipairs(out[key])do print('  '..slot.row.rating..' '..slot.row.name..' ['..tostring(slot.status or slot.reason)..'] '..tostring(slot.reason or ''))end
 end
 if c.tour_attachment.alias_error then print(c.tour_attachment.alias_error)end
 return true,out
end
function B.detach(c)
 local a=c.tour_attachment;if not a then return true end
 a.attached=false;if c.tour then c.tour.cancel('reload/detach')end
 for _,id in ipairs(a.aliases)do killAlias(id)end
 for _,id in ipairs(a.handlers)do killAnonymousEventHandler(id)end
 if a.trigger then killTrigger(a.trigger)end;if a.timer then killTimer(a.timer)end
 return true
end
return B
