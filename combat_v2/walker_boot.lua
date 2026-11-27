-- Opt-in finite area walking adapter. attach() is handler-only and sends nothing.
local M={MAX_ROOMS=3000,MAX_EDGES=36000}
local function sid(v)return v~=nil and tostring(v)or nil end
local function now()return getEpoch and getEpoch()or os.time()end
function M.held(c)local w=c.current.walker or {};return w.pending or w.dispatching or w.physical_dispatch end
function M.offense_held(c)local w=c.current.walker or {};return M.held(c)or w.arrival_hold end
function M.revoke(c,why)
 local w=c.walker.state(c.current);w.intent_epoch=(w.intent_epoch or 0)+1
 if w.restock_checkpoint then w.restock_checkpoint.return_candidate=nil;w.restock_checkpoint.cancelled=why or 'intent revoked';w.restock_checkpoint=nil end
 c.walker.stop(c.current,why);c.current.walker.ask_on_bash=false
 if c.gui.hide_walk_prompt then c.gui.hide_walk_prompt()end
end
local function globe(c)return c.elemental_recovery and c.elemental_recovery.armed end
function M.graph(c)
 for _,k in ipairs({'getRoomArea','getAreaRooms','getRoomExits','roomLocked','getDoors','getRoomWeight'})do if type(_G[k])~='function'then return nil,'mapper API unavailable'end end
 local start=tonumber(c.current.room.id);if not start then return nil,'unknown room'end
 local p=c.current.hunting.preset
 if getRoomArea(start)==338 then
  if p and (not c.areas or not c.areas.scope(c.current)or p.rooms and not p.rooms[tostring(start)])then return nil,'preset room/area boundary'end
  if not c.tour_boot or not c.tour_boot.graph then return nil,'Gloaming terrain adapter unavailable'end
  return c.tour_boot.graph(c,{entry=start,name='Cathedral of Gloaming'})
 end
 if p and p.id=='drakuum' then
  if not c.areas or not c.areas.scope(c.current) or not c.tour_boot or not c.tour_boot.graph then return nil,'Drakuum terrain adapter unavailable' end
  return c.tour_boot.graph(c,{entry=start,name='Drakuum'})
 end
 if p and (not c.areas or not c.areas.scope(c.current)or p.rooms and not p.rooms[tostring(start)])then return nil,'preset room/area boundary'end
 local ok,area=pcall(getRoomArea,start);if not ok or not tonumber(area)or tonumber(area)<0 then return nil,'unmapped start'end
 local good,ids=pcall(getAreaRooms,area);if not good or type(ids)~='table'then return nil,'unknown area rooms'end
 local rooms,n,edges,seen={},0,0,{}
 for _,raw in pairs(ids)do
  local normalized=tonumber(raw)
  if normalized and not seen[normalized]then seen[normalized]=true;n=n+1 end;if n>M.MAX_ROOMS then return nil,'area exceeds bounded room budget'end
  local id=tonumber(raw)
  local preset=c.current.hunting.preset
  if id and (not preset or not preset.rooms or preset.rooms[tostring(id)])then
   local a,actual=pcall(getRoomArea,id);local b,locked=pcall(roomLocked,id);local d,weight=pcall(getRoomWeight,id)
   local e,exits=pcall(getRoomExits,id);local f,doors=pcall(getDoors,id)
   if a and actual==area and b and locked==false and d and tonumber(weight)and tonumber(weight)<=1 and e and type(exits)=='table'and f and type(doors)=='table'then
    for _ in pairs(exits)do edges=edges+1;if edges>M.MAX_EDGES then return nil,'area exceeds bounded edge budget'end end
    local wet=c.special_exits and type(getRoomEnv)=='function' and c.special_exits.water_environment(getRoomEnv(id))or false
    rooms[tostring(id)]={area=area,exits=exits,doors=doors,wet=wet,env=type(getRoomEnv)=='function'and getRoomEnv(id)or nil,weight=weight,locked=locked}
   end
  end
 end
 local special,diagnostics={},{}
 if c.special_exits then special,diagnostics=c.special_exits.descriptors(c,area,rooms)end
 local g,why=c.walker.build(start,area,rooms,{special_edges=special});if g then g.special_diagnostics=diagnostics end;if g then g.mapped_count=n;g.coverage=g.room_count..' reachable safe rooms / '..n..' mapped entries'end
 return g,why
end
function M.offer(c)
 local w=c.walker.state(c.current);w.ask_on_bash=false
 if w.enabled~=true or c.mode~='BASH'or c.current.mode~='BASH'then return false,'walking disabled or BASH not active'end
 if w.offer or w.active then return true end
 if w.restock_checkpoint then M.revoke(c,'fresh consent requested')end
 if M.offense_held(c)then return false,'movement/evidence unresolved'end
 if globe(c)then w.status='Stationary BASH: turn GLOBE OFF before offering walking';return false,w.status end
 local g,why=M.graph(c);if not g then w.status=why;return false,why end
 local token,err=c.walker.offer(c.current,g);if not token then return false,err end
 w.status='Consent requested: '..g.coverage
 if c.gui.show_walk_prompt then c.gui.show_walk_prompt(c.current.room.area,g.coverage,token)end
 return true
end
function M.answer(c,token,yes)
 if c.walker.state(c.current).enabled~=true then return false,'walking disabled'end
 if yes and (globe(c)or M.offense_held(c))then return false,'GLOBE or movement/evidence unresolved'end
 local ok,why=c.walker.accept(c.current,tonumber(token),yes==true)
 if ok then
  if c.gui.hide_walk_prompt then c.gui.hide_walk_prompt()end
  if yes then c.walker.state(c.current).rescan=nil;combat_v2_start_ih('walking consent; fresh room inspection',true,true)end
 end
 return ok,why
end
-- Navigation authority is deliberately distinct from hunting permission.
-- A current native player list is required even when all those players are webmates.
function M.occupied(c)
 local s=c.current;local w=c.walker.state(s);local p=s.policy or {}
 if not w.active or c.mode~='BASH'or s.mode~='BASH'or not w.graph or not w.graph.nodes[sid(s.room.id)]
  or w.area~=s.room.area or not s.connected or s.player.dead or not p.self_name or p.self_name==''
  or p.players_known~=true or p.players_room~=s.room.id or type(p.players)~='table'or p.players~=p.native_players
  or type(p.players_version)~='number'or p.players_version<1 or p.players_version%1~=0 or p.players_version>=math.huge
  or not c.policy.area_allowed(s)then return false end
 if s.hunting.preset and (not c.areas.scope(s)or s.hunting.preset.rooms and not s.hunting.preset.rooms[sid(s.room.id)])then return false end
 local names={};for name,yes in pairs(p.players)do
  if type(name)~='string'or yes~=true then return false end
  if name~=p.self_name then names[#names+1]=name end
 end
 table.sort(names);if #names==0 then return false end
 return names
end
function M.transit_valid(c)
 local s=c.current;local w=c.walker.state(s);local q=w.transit;local p=s.policy or {}
 local names=M.occupied(c)
 return names and q and q.room_id==sid(s.room.id)and q.area==s.room.area
  and q.items==s.room.items and q.version==s.room.item_version and c.areas.fresh(s)
  and q.sequence==(w.room_sequence or 0)and q.players==p.players and q.player_version==p.players_version
  and q.players_key==table.concat(names,',')and q.self_name==p.self_name
  and q.session==w.movement_session and q.grant==w.offers and q.graph==w.graph and q.epoch==(w.intent_epoch or 0)
end
function M.skip(c)
 local s=c.current;local w=c.walker.state(s);local names=M.occupied(c);local i=w.inspection
 if not names or M.held(c)or not i or i.room~=sid(s.room.id)or i.area~=s.room.area
  or i.items~=s.room.items or i.version~=s.room.item_version or i.sequence~=(w.room_sequence or 0)
  or not c.areas.fresh(s)then w.transit=nil;return false end
 local p=s.policy
 w.transit={room_id=i.room,area=i.area,items=i.items,version=i.version,sequence=i.sequence,
  players=p.players,player_version=p.players_version,players_key=table.concat(names,','),self_name=p.self_name,
  session=w.movement_session,grant=w.offers,graph=w.graph,epoch=w.intent_epoch or 0}
 w.clear=nil;w.arrival_hold=nil;w.reinspect=nil
 if w.cleared then w.cleared[i.room]=nil end
 w.skipped=w.skipped or {};w.skipped[i.room]={reason='occupied player room',players=names,version=i.version,sequence=i.sequence}
 w.visited[i.room]=true -- routing visit only, never clearance
 w.status='SKIPPED occupied player room: '..table.concat(names,', ')
 return true
end
-- A new Room.Info opens one finite GMCP-first window. Cached values and partial
-- updates cannot satisfy it. Only the Core-accepted native FULL callback can.
function M.entry_wait(c,explicit)
 local s=c.current;local e=s.hunting.entry;local w=c.walker.state(s)
 if explicit or not e or e.fallback or e.done or e.room~=sid(s.room.id)or e.area~=s.room.area
  or e.sequence~=(w.room_sequence or 0)or e.session~=w.movement_session then return false end
 if e.scan and e.scan.prompt_ready and not e.scan.invalidated and e.scan.items==s.room.items and e.scan.walker_version==s.room.item_version then return true end
 if now()-(e.full_at or e.at)>=0.75 then
  e.fallback=true
  if e.scan and e.scan==s.hunting.ih then e.scan.active=false;e.scan.pending=false end
  return false
 end
 return true
end
function M.entry_full(c,payload)
 local s=c.current;local e=s.hunting.entry;local w=c.walker.state(s)
 if c.mode~='BASH'or not e or e.done or e.fallback or M.held(c)or e.room~=sid(s.room.id)or e.area~=s.room.area
  or e.sequence~=(w.room_sequence or 0)or e.session~=w.movement_session then return false end
 local info=gmcp and gmcp.Room and gmcp.Room.Info
 if not info or sid(info.num)~=e.room or info.area~=e.area or payload==e.cached
  or not c.areas.complete(payload)or not c.areas.fresh(s)or s.room.item_version<=e.start_version then
  return false
 end
 -- Certify BEFORE the selector consumes pending. This record describes the
 -- actual received FULL, not text IH and not manufactured room emptiness.
 local scan={active=true,pending=true,responded=true,attempts=0,room_id=s.room.id,area=s.room.area,
  start_version=e.start_version,items=s.room.items,walker_items=s.room.items,walker_version=s.room.item_version,
  recovery_prompt=true,prompt_ready=false,entry_full=true,walker_prompt_floor=w.movement_prompt or 0}
 -- One bounded prompt grace from the first accepted FULL. Subsequent FULLs
 -- cannot renew it, and the FULL callback tick cannot preempt its own prompt.
 e.full_at=e.full_at or now()
 e.scan=scan;s.hunting.ih=scan;s.hunting.watch=nil
 return true
end
function M.entry_prompt(c)
 local s=c.current;local e=s.hunting.entry
 if e and e.scan and e.scan==s.hunting.ih and e.scan.items==s.room.items
  and e.scan.walker_version==s.room.item_version and not e.scan.invalidated then
  e.scan.prompt_ready=true;s.hunting.area_recovery=nil
 end
end
function M.items(c,payload)
 local s=c.current;local scan=s.hunting.ih
 M.entry_full(c,payload);scan=s.hunting.ih
 if M.held(c)or type(payload)~='table'or payload.location~='room'or type(payload.items)~='table'or not scan or not scan.active or not scan.pending then return false end
 if scan.invalidated or c.areas and (not c.areas.complete(payload)or not c.areas.fresh(s))then return false end
 for _,it in pairs(payload.items)do if type(it)~='table'or it.id==nil or type(it.name)~='string' then return false end end
 scan.walker_version=s.room.item_version;scan.walker_items=s.room.items;scan.walker_prompt_floor=c.walker.state(s).movement_prompt or 0
 return true
end
function M.inspected(c,scan)
 local s=c.current;local w=c.walker.state(s)
 if M.held(c)or not scan or not scan.responded or scan.source or sid(scan.room_id)~=sid(s.room.id)or not scan.items then return false end
 if scan.area~=nil and scan.area~=s.room.area then return false end
 if scan.invalidated or scan.recovery_prompt and not scan.prompt_ready then return false end
 if s.hunting.preset and (s.hunting.area_recovery or not c.areas or not c.areas.fresh(s)or not c.areas.scope(s))then return false end
 if not scan.walker_version or scan.walker_version~=(s.room.item_version or 0)or scan.walker_version<=(scan.start_version or 0)then return false end
 if scan.walker_items~=s.room.items or scan.items~=s.room.items then return false end
 if not c.policy.allowed(s)and not M.occupied(c)then return false end
 w.arrival_hold=nil;w.reinspect=nil
 w.inspection={room=sid(s.room.id),area=s.room.area,items=s.room.items,version=s.room.item_version,sequence=w.room_sequence or 0,prompt_floor=scan.walker_prompt_floor}
 if s.hunting.entry and (s.hunting.entry.scan==scan or s.hunting.entry.fallback_scan==scan)then s.hunting.entry.done=true end
 return true
end
function M.clear(c,scan)
 local s=c.current;local w=c.walker.state(s)
 if M.occupied(c)then return false end
 -- No unanswered IH, incomplete list, partial update or quiet-watch clearance.
 if not M.inspected(c,scan)or not w.active then return false end
 if c.areas and c.areas.blocked(s)then w.clear=nil;w.status="HOLD: living NPC or preset boundary";return false end
 return c.walker.mark_clear(s,s.room.item_version)
end
local function restock_module(c)return c.restock_module or c.restock_boot end
local function owned_transition(c)
 local m=restock_module(c)
 return m and m.owns_transition and m.owns_transition(c)==true
end
local function borrowed(c)
 local m=restock_module(c)
 return m and m.movement_borrowed and m.movement_borrowed(c)==true
end
local valid_checkpoint
local function return_scope(c,cp)
 local d=c.restock_data;local tr=c.travel_owner;local root=c.runner.root or c.root or {}
 return valid_checkpoint(c,cp,d)and d.active and d.resume_consent and not d.fault and c.user_activity==d and cp.departed and tr and d.route_owner==tr and d.route_serial and tr.serial and tr.serial>=d.route_serial and sid(tr.destination)==cp.room and sid(d.destination)==cp.room and sid(d.route_destination)==cp.room and d.after_route=='return_check' and not (tr.fault or tr.follow_fault or c.transport_unknown or root.transport_unknown or c.runner.transport_unknown)and (d.phase=='route'or d.phase=='return_check'or d.phase=='resume')
end
local function candidate_valid(c,cp)
 local q=cp.return_candidate;local tr=c.travel_owner;local d=c.restock_data
 local p=tr and tr.pending
 return q and return_scope(c,cp)and q.owner==tr and q.serial==tr.serial and q.route_serial==d.route_serial and sid(tr.room)==cp.room and ((not (tr.intent or tr.route or p)and tr.phase=='idle')or (p and p.kind=='go'and p.ack==true and p.serial==q.serial))
end
-- A known server rejection is retained as scoped evidence, never a synthetic
-- arrival or automatic retry. Explicit reviewed recovery remains OFF-only.
function M.rejection(c,text)
 local s=c.current;local w=c.walker.state(s);local p=w.pending
 local typed=p and p.swim_hop
 local own_swim=typed and p.command=='swim '..p.direction and typed.command==p.command
  and w.graph and w.graph.special_edges and w.graph.special_edges[p.from]and w.graph.special_edges[p.from][p.direction]==typed
 if text~="Now now, don't be so hasty!" or not p or not s.connected
  or p.session==nil or p.session~=w.movement_session or p.serial==nil or p.serial~=w.movement_serial
  or p.command~=p.direction and not own_swim or p.from~=sid(s.room.id) or p.area~=s.room.area
  or p.transport_ok==false or (w.fault and w.fault~='movement acknowledgement timed out') then return false end
 p.rejection=p.rejection or {text=text,prompt=w.movement_prompt or 0,sequence=w.room_sequence or 0}
 M.revoke(c,'movement rejected; pending retained for review')
 return true
end
function M.rejection_prompt(c)
 local w=c.walker.state(c.current);w.movement_prompt=(w.movement_prompt or 0)+1
 local p=w.pending;local r=p and p.rejection
 if r and p.transport_ok==true and not w.dispatching and p.session==w.movement_session
  and w.movement_prompt>r.prompt and sid(c.current.room.id)==p.from then r.later_prompt=w.movement_prompt end
end
function M.room(c,info,changed)
 local s=c.current;local w=c.walker.state(s)
 w.room_sequence=(w.room_sequence or 0)+1;w.inspection=nil;w.transit=nil
 -- Room.Info invalidates the entry certificate, including an unsolicited FULL
 -- still awaiting its prompt. It is not an issued IH query: retire only that
 -- exact attempt-zero owner so it cannot strand arrival behind "IH pending".
 local entry=s.hunting.entry;local scan=s.hunting.ih
 if entry and not entry.done and entry.scan==scan and scan and scan.entry_full and scan.attempts==0 then
  scan.active=false;scan.pending=false;scan.invalidated=true
 end
 s.hunting.entry=nil
 -- Retain only the finite fallback budget for this same actual location.
 -- A metadata refresh never renews its FULL certificate or query allowance.
 if entry and not entry.done and not changed and entry.room==sid(s.room.id)and entry.area==s.room.area then
  entry.fallback=true;entry.sequence=w.room_sequence;s.hunting.entry=entry
 end
 if changed and c.mode=='BASH'and not borrowed(c)and info.num~=nil and info.area~=nil then
  s.hunting.entry={room=sid(info.num),area=info.area,sequence=w.room_sequence,session=w.movement_session,
   at=now(),start_version=s.room.item_version or 0,cached=gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items.List}
 end
 local pending=w.pending;local rejection=pending and pending.rejection
 if pending and pending.door_hop and pending.open_response and sid(info.num)==pending.from and info.area==pending.area
  and type(info.exits)=='table'and sid(info.exits[pending.direction])==pending.to
  and w.room_sequence>pending.open_response.sequence then pending.source_readback=w.room_sequence end
 if rejection and pending.transport_ok==true and not w.dispatching and pending.session==w.movement_session
  and w.room_sequence>rejection.sequence and sid(info.num)==pending.from and info.area==pending.area then
  rejection.from_readback=w.room_sequence
 end
 local cp=w.restock_checkpoint
 if cp and not cp.cancelled then
  -- Room.Info also carries unchanged LOOK/partial metadata, not just movement.
  -- Compare explicit locations against the checkpoint's last known location;
  -- upstream `changed` may be true merely because a partial packet omitted num.
  local room=sid(info.num);local area=type(info.area)=='string'and info.area~=''and info.area or nil
  local moved=room and (room~=cp.last_room or area and cp.last_area and area~=cp.last_area)
  if cp.return_candidate and not candidate_valid(c,cp)then cp.return_candidate=nil end
  if M.held(c)or room==cp.room and area and area~=cp.area or not room and area and cp.return_candidate and area~=cp.area or moved and not borrowed(c)then M.revoke(c,'unowned or inconsistent room event during restock')
  elseif moved then
   cp.last_room=room;cp.last_area=area;cp.return_sequence=nil;cp.return_candidate=nil
   if room~=cp.room or area and area~=cp.area then cp.departed=true
   elseif cp.departed and area==cp.area and s.room.area==cp.area and sid(s.room.id)==cp.room then cp.return_sequence=w.room_sequence
   elseif room==cp.room and not area and borrowed(c)and return_scope(c,cp)then
    -- A genuine native GO arrival may lack area. Keep only a scoped candidate,
    -- never permission: later explicit num+area must confirm this exact route.
    local tr=c.travel_owner;local p=tr.pending
    -- Core's checkpoint callback precedes native travel.room: GO is committed
    -- here; its ACK/location must be proven by native travel before confirmation.
    if p and p.kind=='go'and p.serial==tr.serial and tr.intent=='pt'and tr.route then cp.return_candidate={owner=tr,serial=tr.serial,route_serial=c.restock_data.route_serial}end
   end
  elseif room==cp.room and area==cp.area and sid(s.room.id)==cp.room and s.room.area==cp.area and candidate_valid(c,cp)then
   cp.return_sequence=w.room_sequence;cp.return_candidate=nil
  end
 end
 -- Partial room metadata cannot acknowledge an issued hop or retain clearance.
 w.clear=nil;if w.active then w.reinspect=true end
 if info.num==nil then return end
 if changed then
  if w.pending then
   local ok=c.walker.arrive(s,info.num)
   if ok then w.rescan=nil;w.arrival_hold=true;w.arrival_version=s.room.item_version or 0 end
  elseif w.active or w.offer then M.revoke(c,'manual/unexpected room change')end
 end
end
local function resources(c)
 local s=c.current;local r=c.runner;local m=s.mental or {};local b=s.buffs or {};local g=c.elemental_recovery or {};local co=c.containers_data or {}
 local tr=c.travel_owner or {};local ink=c.tattoo_owner or {};local root=r.root or c.root or {}
 -- Distinct shared and runner roots can both retain physical commitments.
 for _,owner in ipairs({c,s,r,r.root or {},c.root or {}})do
  for _,field in ipairs({'transport_unknown','transportUnknown','transport_commit','transportCommit','transport_barrier','transportBarrier','transport_barriers','transportBarriers','dispatching','action_dispatching','actionDispatching'})do
   local v=owner[field]
   if type(v)=='table'and next(v)~=nil or type(v)~='table'and v~=nil and v~=false then return true end
  end
 end
 if c.transport_unknown or root.transport_unknown or root.dispatching or root.action_dispatching or r.transport_unknown or r.waiting or r.fault or r.dispatching or r.transport_commit or r.transport_barrier or m.eq_pending or m.pending or m.fault or m.dispatching or b.pending or b.fault or b.dispatching or g.committed or g.dispatching or co.barrier or co.action_dispatching then return true end
 -- A settled terminal diagnostic is not physical work; all uncertain GLOBE
 -- state (including read-only probes) remains fenced. Missing helper fails closed.
 local tm=c.travel_module
 if (g.pending or g.fault)and not (tm and type(tm.terminal_globe_exhaustion)=='function'and tm.terminal_globe_exhaustion(c)==true)then return true end
 if tr.pending or tr.dispatching or tr.fault or tr.follow_pending or tr.follow_fault or tr.recall_due or tr.intent or tr.route or ink.txn or ink.pending or ink.dispatching or ink.fault then return true end
 if c.convenience and (c.convenience.busy(c)or c.convenience.hold(c))then return true end
 if c.lunch_boot and c.lunch_boot.busy(c)then return true end
end
local function inspected_now(c)
 local s=c.current;local w=c.walker.state(s);local i=w.inspection
 if s.hunting.preset and (s.hunting.area_recovery or not c.areas or not c.areas.fresh(s)or not c.areas.scope(s))then return false end
 return i and i.room==sid(s.room.id)and i.area==s.room.area and i.items==s.room.items and i.version==s.room.item_version and i.sequence==(w.room_sequence or 0)
end
local function no_npcs(c)
 for _,it in pairs(c.current.room.items or {})do
  if not c.areas or type(c.areas.navigation_blocked)~='function'or c.areas.navigation_blocked(c.current,it)then return false end
 end
 return true
end
local function solo(c)
 local s=c.current;local p=s.policy or {}
 if not p.players_known or sid(p.players_room)~=sid(s.room.id)then return false end
 for name in pairs(p.players or {})do if name~=p.self_name then return false end end
 return c.policy.allowed(s)==true
end
function M.restock_ready(c)
 local w=c.walker.state(c.current)
 if not c.current.connected or c.current.player.dead or c.current.training_battle_ended or type(c.current.player.class)~='string'or c.current.player.class==''then return false,'unknown class/session scope'end
 if M.offense_held(c)or w.fault or resources(c)then return false,'action or arrival evidence unresolved'end
 if w.restock_checkpoint then return false,'checkpoint already suspended'end
 if not no_npcs(c)then return false,'living room NPCs'end
 if w.active and (not inspected_now(c)or not solo(c))then return false,'awaiting fresh inspection'end
 return true
end
valid_checkpoint=function(c,cp,lease)
 local s=c.current;local w=c.walker.state(s)
 return type(cp)=='table'and lease==c.restock_data and cp.lease==lease and lease.checkpoint==cp and w.restock_checkpoint==cp and not cp.cancelled and not cp.resumed and cp.epoch==(w.intent_epoch or 0)and cp.generation==w.offers and cp.graph==w.graph and cp.class==s.player.class and s.connected and not s.player.dead and not s.training_battle_ended
end
function M.restock_suspend(c,lease)
 if type(lease)~='table'or lease~=c.restock_data then return nil,'invalid restock lease'end
 local ok,why=M.restock_ready(c);if not ok then return nil,why end
 local s=c.current;local w=c.walker.state(s)
 local cp={lease=lease,was_active=w.active==true,room=sid(s.room.id),area=s.room.area,graph=w.graph,visited=w.visited,steps=w.steps,start=w.start,walk_area=w.area,generation=w.offers,epoch=w.intent_epoch or 0,class=s.player.class,sequence=w.room_sequence or 0,last_room=sid(s.room.id),last_area=s.room.area}
 w.restock_checkpoint=cp;lease.checkpoint=cp;w.active=false;w.clear=nil;w.inspection=nil;w.ask_on_bash=false
 return cp
end
function M.restock_resume(c,cp,lease)
 if not valid_checkpoint(c,cp,lease)then return false,'invalidated restock checkpoint'end
 local s=c.current;local w=c.walker.state(s)
 if M.offense_held(c)or sid(s.room.id)~=cp.room or s.room.area~=cp.area or not cp.return_sequence or cp.return_sequence<=cp.sequence then return false,'awaiting exact return room'end
 if not inspected_now(c)or w.inspection.sequence<cp.return_sequence or not solo(c)or not no_npcs(c)then return false,'awaiting fresh inspection'end
 if c.mode~='BASH'or s.mode~='BASH'or s.player.mounted~=false and s.player.mounted~=0 or resources(c)or not c.runner_module.ready(c.runner)then return false,'awaiting unmounted BASH recovery'end
 w.graph=cp.graph;w.visited=cp.visited;w.steps=cp.steps;w.start=cp.start;w.area=cp.walk_area
 w.active=cp.was_active;w.clear=nil;w.reinspect=cp.was_active;cp.resumed=true;w.restock_checkpoint=nil
 -- The next movement requires a new post-resume IH; no pre-trip clearance survives.
 w.inspection=nil
 return true
end
function M.restock_cancel(c,cp,lease,why)
 if type(cp)~='table'or cp.lease~=lease or lease~=c.restock_data then return false,'invalid restock lease'end
 cp.cancelled=why or 'restock cancelled'
 if c.walker.state(c.current).restock_checkpoint==cp then M.revoke(c,cp.cancelled)end
 return true
end
-- An exact protected-NPC hold may have exhausted its old IH with an unchanged
-- certified item version. Request new evidence once; never mark cached data clear.
local function protected_navigation_hold(c)
 local s=c.current;local w=c.walker.state(s)
 if w.clear or w.status~='HOLD: living NPC or preset boundary'or not c.areas
  or type(c.areas.navigation_exempt)~='function'or c.areas.blocked(s)then return false end
 for _,it in pairs(s.room.items or {})do if c.areas.navigation_exempt(s,it)==true then return true end end
 return false
end
-- A newer duplicate FULL invalidates certified clearance. Re-solicit through
-- the normal bounded three-attempt IH owner, never recertify the cached list.
function M.rescan_safe(c)
 local s=c.current;local scan=s.hunting.ih
 if not c.walker.state(s).active or M.offense_held(c) or resources(c) or c.runner.pending or globe(c) or c.mode~='BASH' or s.mode~='BASH'
  or not s.connected or s.player.dead or s.training_battle_ended or not c.runner_module.ready(c.runner)
  or not solo(c) or not no_npcs(c) or s.hunting.area_recovery or scan and scan.invalidated
  or not c.areas or not c.areas.fresh(s) then return false end
 if c.walker_defense_hold and c.walker_defense_hold(s) then return false end
 local rm=restock_module(c)
 return not (rm and rm.movement_reserved and rm.movement_reserved(c))
end
function M.rescan(c)
 local s=c.current;local w=c.walker.state(s);local i=w.inspection;local scan=s.hunting.ih
 if w.rescan then
  local r=w.rescan;local owned=r.scan
  -- A successful watch target can replace hunting.ih. The bounded rescan is
  -- still this room's owner, not a licence to allocate a new three-check budget.
  -- Never steal a live query or retire an invalid/unknown inspection owner.
  if r.starting or not owned or r.room~=sid(s.room.id)
   or sid(owned.room_id)~=sid(s.room.id)or owned.area~=nil and owned.area~=s.room.area
   or owned.source or owned.invalidated or owned.pending or c.ih_timer
   or not scan or scan.pending or scan.invalidated
   or scan~=owned and (scan.active or sid(scan.room_id)~=sid(s.room.id))then return false end
  local attempts=owned.attempts
  if type(attempts)~='number'or attempts<0 or attempts>3 or attempts%1~=0
   or type(r.attempts)~='number'or r.attempts<0 or r.attempts>3 or r.attempts%1~=0 then return false end
  r.attempts=math.max(r.attempts,attempts)
  if r.attempts>=3 or not M.rescan_safe(c)
   or w.clear and w.clear.version==s.room.item_version
   or not i or i.room~=sid(s.room.id)or i.area~=s.room.area or i.sequence~=(w.room_sequence or 0)
   or type(i.version)~='number'or type(s.room.item_version)~='number'or s.room.item_version<i.version then return false end
  -- Resume the original settled owner with its remaining budget. ih_request
  -- discards old response fields and solicits real new GMCP+IH evidence. No
  -- cached list is certified and a normal active fresh IH is never displaced.
  owned.attempts=r.attempts;owned.active=true;s.hunting.ih=owned;s.hunting.watch=nil
  return combat_v2_request_ih()
 end
 if not M.rescan_safe(c) or w.clear and w.clear.version==s.room.item_version
  or not i or i.room~=sid(s.room.id) or i.area~=s.room.area or i.sequence~=(w.room_sequence or 0)
  or type(i.version)~='number' or type(s.room.item_version)~='number' or s.room.item_version<i.version or s.room.item_version==i.version and not protected_navigation_hold(c)
  or type(s.room.items)~='table'
  or not scan or scan.active or scan.pending or scan.invalidated then return false end
 local record={room=sid(s.room.id),version=s.room.item_version,attempts=0,starting=true}
 w.clear=nil;w.rescan=record -- Reserve before the public API; synchronous FULL may reenter.
 local ok,why=combat_v2_start_ih('WALK stale empty-room inspection; bounded rescan',true,true)
 record.starting=nil;record.scan=s.hunting.ih;record.attempts=record.scan and record.scan.attempts or 0;record.started=ok==true;record.reason=why
 return ok==true
end
-- Missing GMCP exit is permissible only for an exact official hidden edge.
-- Never rewrite canonical Room.Info; explicit disagreement always wins.
function M.live_exit(c,hop,info,emergency)
 if type(getRoomArea)=='function'and getRoomArea(tonumber(hop.from))==338 then
  local policy=c.tour_boot and c.tour_boot.ordinary_environment
  if not policy or not info or not policy(getRoomEnv(tonumber(hop.from)),hop.from,338,info.environment)
   or not policy(getRoomEnv(tonumber(hop.to)),hop.to,getRoomArea(tonumber(hop.to)))then return false end
 end
 if hop.special then return c.special_exits and c.special_exits.native_command(c,hop,info,nil,emergency)~=nil end
 if not info or sid(info.num)~=sid(c.current.room.id)or type(info.exits)~='table'then return false end
 local live=info.exits[hop.direction]
 if live~=nil and sid(live)~=hop.to then return false end
 local w=c.walker.state(c.current)
 local cert=((w.graph.certified_hidden or {})[hop.from]or{})[hop.direction]
 if not cert then return sid(live)==hop.to end
 local ok,g=pcall(M.graph,c)
 if not ok or not g or g.hidden_provenance~=w.graph.hidden_provenance then return false end
 local fresh=g and ((g.certified_hidden or {})[hop.from]or{})[hop.direction]
 return fresh~=nil and fresh.to==cert.to and fresh.source==cert.source and fresh.target==cert.target
end
-- Door responses are inert source-specific patterns, not live observations.
local door_names={n='north',ne='northeast',e='east',se='southeast',s='south',sw='southwest',w='west',nw='northwest',u='up',d='down',['in']='in',out='out'}
local door_closed={['There is a door in the way.']=true,['There is a closed door in the way.']=true}
local door_locked={['The door is locked.']=true,['The door is locked shut.']=true,['This door has been magically locked shut.']=true,['The door has been magically locked shut.']=true,['You are not carrying a key for this door.']=true}
local function door_archive(c,p)
 local w=c.walker.state(c.current)
 w.door_history=w.door_history or {};w.door_history[#w.door_history+1]=p
 w.pending=nil;w.clear=nil;w.transit=nil;w.inspection=nil
 if w.active then w.reinspect=true end
end
function M.door_deadline(c,p)
 local w=c.walker.state(c.current);local r=p.open_response
 if w.pending~=p or not r or not p.transport_ok or w.dispatching or p.look_dispatching
  or p.session~=w.movement_session or p.serial~=w.movement_serial or not c.current.connected
  or sid(c.current.room.id)~=p.from or c.current.room.area~=p.area then return false end
 if now()-r.at<3 or (w.movement_prompt or 0)<=r.prompt then return false end
 -- The own positive OPEN / explicit rejection is known, unlike unknown GO.
 -- Missing source readback denies continuation, not eternal imaginary map updates.
 p.known_refusal='door source readback unavailable after bounded LOOK'
 door_archive(c,p);M.revoke(c,p.known_refusal);w.fault=p.known_refusal
 return true
end
function M.door_response(c,text)
 local s=c.current;local w=c.walker.state(s);local p=w.pending
 if not p or not p.door_hop or p.session~=w.movement_session or p.serial~=w.movement_serial
  or sid(s.room.id)~=p.from or s.room.area~=p.area then return false end
 local kind
 if p.phase=='door-open'and text=='You open the door to the '..tostring(door_names[p.direction])..'.'then kind='open'
 elseif door_locked[text]then kind='locked'
 elseif door_closed[text]or text=='There is a door in the way, to the '..tostring(door_names[p.direction])..'.'then kind='closed'
 end
 -- No supplied source certifies an already-open phrase; never reinterpret it as
 -- own positive ACK. Its bounded timeout remains an explicitly UNKNOWN outcome.
 if not kind then return false end
 if p.phase=='door-open'and kind=='closed'then kind='refused'end
 w.door_open_receipt=nil
 p.open_response=p.open_response or {sequence=w.room_sequence or 0,prompt=w.movement_prompt or 0,at=now(),kind=kind,text=text}
 if type(tempTimer)=='function'and not p.door_deadline_timer then
  p.door_deadline_timer=tempTimer(3.1,function()M.door_deadline(c,p)end)
 end
 return true
end
function M.door_prompt(c)
 local s=c.current;local w=c.walker.state(s);local p=w.pending;local r=p and p.open_response
 if not p or not r or p.transport_ok~=true or w.dispatching or p.look_dispatching
  or p.session~=w.movement_session or p.serial~=w.movement_serial
  or not s.connected or sid(s.room.id)~=p.from or s.room.area~=p.area
  or (w.movement_prompt or 0)<=r.prompt then return false end
 if not p.source_readback or p.source_readback<=r.sequence then
  -- One owned read-only LOOK, reserved before transport. No loop; no native map
  -- write, cached FULL laundering, mode spoofing or post-STOP continuation.
  if not p.look and w.active and c.mode=='BASH'and s.mode=='BASH'and c.runner.mode=='BASH'then
   p.look={sequence=w.room_sequence or 0,prompt=w.movement_prompt or 0,at=now()};p.look_dispatching=true
   local ok,result=pcall(c.walk_sender or send,'look')
   p.look_dispatching=nil;p.look.transport_ok=ok and result~=false
   if not p.look.transport_ok then p.transport_ok=false;w.fault='door LOOK transport unknown';M.revoke(c,w.fault)end
  end
  return false
 end
 if p.look and(p.look.transport_ok~=true or (w.movement_prompt or 0)<=p.look.prompt)then return false end
 if r.kind=='locked'then
  p.known_rejection=true;door_archive(c,p);M.revoke(c,'known locked door; no unlock permission');w.fault='known locked door; no unlock permission';return true
 end
 local ok,state=pcall(c.special_exits.door_readback,p.door_hop)
 if not ok or not state then return false end
 if r.kind=='open'then
  p.open_settled=true
  if w.active then w.door_open_receipt={hop=p.door_hop,session=w.movement_session,epoch=w.intent_epoch or 0,offers=w.offers,graph=w.graph,from=p.from,proof=p}end
  door_archive(c,p);w.status='owned OPEN settled; fresh room inspection required';return true
 end
 p.known_rejection=true;door_archive(c,p)
 local key=tostring(w.offers)..':'..p.from..':'..p.direction
 if r.kind=='closed'and p.phase~='door-open'and not (w.door_attempts or {})[key]and w.active then
  w.door_retry={hop=p.door_hop,epoch=w.intent_epoch or 0,offers=w.offers,proof=p}
  w.status='known closed direction; one owned OPEN retry after fresh inspection';return true
 end
 local why=r.kind=='locked'and 'known locked door; no unlock permission'or 'known door rejection; retry exhausted'
 M.revoke(c,why);w.fault=why;return true
end
function M.surface_ready(c,emergency,hop)
 if emergency~=nil then return emergency==c.bash_emergency and c.walker.emergency_valid(c,emergency,hop)==true end
 local s=c.current;local w=c.walker.state(s);local p=s.player
 if not s.connected or p.dead or p.class=='Shapeshifter'or s.training_battle_ended
  or p.mounted~=false or resources(c)or not c.runner_module.ready(c.runner)
  or c.walker_defense_hold and c.walker_defense_hold(s)then return false end
 local n=c.emergency_numb;if n and(n.pending or n.fault)then return false end
 -- The retained entry guard already fences other survival leases. Calling clear
 -- here would self-block inside that guard's genuine foreign-dispatch scope.
 local scan=s.hunting.ih
 return not(w.pending or w.dispatching or w.arrival_hold or w.fault)and scan and scan.responded==true
  and not scan.invalidated and(not scan.recovery_prompt or scan.prompt_ready==true)
end
local function dispatch_hop(c,hop,emergency)
 local s=c.current;local w=c.walker.state(s)
 if w.kneel_not_before then
  local value=c.walker.movement_clock(s)
  if not value or value<w.kneel_not_before then w.status='awaiting sourced kneel pacing';return false end
 end
 local info=gmcp and gmcp.Room and gmcp.Room.Info
 if not M.live_exit(c,hop,info,emergency)then M.revoke(c,'live exit mismatch');w.fault='live exit mismatch';return false end
 local command=hop.direction
 if hop.special then
  local why;command,why=c.special_exits.native_command(c,hop,info,nil,emergency)
  if not command then M.revoke(c,why);return false end
 end
 -- Reserve the one send attempt atomically; a second clock read cannot bypass it.
 if not c.walker.pace(s,true)then w.status='awaiting minimum movement spacing';return false end
 local opening=hop.kind=='door'and command=='open door '..hop.direction
 if opening then
  w.door_attempts=w.door_attempts or {};local key=tostring(w.offers)..':'..hop.from..':'..hop.direction
  if w.door_attempts[key]then M.revoke(c,'door OPEN attempt exhausted for this grant');return false end
  w.door_attempts[key]=true
 end
 if not c.walker.begin_step(s,hop,emergency)then return false end
 -- dispatching survives synchronous arrival, Stop, nested tick and reconsent.
 local pending=w.pending
 pending.serial=w.movement_serial;pending.command=command;pending.area=s.room.area
 if hop.kind=='kneel'then w.kneel_not_before=w.last_movement_send+3 end -- pacing only, never arrival ACK
 pending.session=w.movement_session
 if hop.kind=='swim'then pending.swim_hop=hop end
 if hop.kind=='door'then pending.door_hop=hop;if not opening then w.door_open_receipt=nil;w.door_retry=nil end end
 if opening then pending.phase='door-open';pending.source_sequence=w.room_sequence or 0 end
 w.dispatching=pending
 local ok,result=pcall(c.walk_sender or send,command)
 w.dispatching=nil;pending.transport_ok=ok and result~=false
 if not ok or result==false then
  w.pending=w.pending or pending;w.fault='movement transport unknown';M.revoke(c,w.fault);return false
 end
 w.sent=(w.sent or 0)+1
 return true
end
function M.new_emergency(c,opt)return c.walker.new_emergency(c,opt)end
function M.emergency_options(c)
 local defense=c.defense;local state=c.current;local numb=c.emergency_numb
 local function barrier(controller,current,owner,lease,preview)
  if controller~=c or current~=state or owner~=defense or c.defense~=defense then return true,'emergency defense identity changed'end
  if c.emergency_numb~=numb then return true,'canonical emergency defense owner changed'end
  if numb and(numb.pending or numb.fault)then return true,'canonical NUMB/SHIFT pending/fault'end
  if defense and defense.numb_hold then
   local ok,held,why=pcall(defense.numb_hold,state)
   if not ok or type(held)~='boolean'or held then return true,why or 'NUMB/SHIFT pending'end
  elseif c.emergency_numb then return true,'NUMB/SHIFT hold API unavailable'end
  local arb=c.survival_arbiter
  if arb and not preview then
   if arb.schema~='survival-v1'or arb.owner~=c or type(arb.clear)~='function'then return true,'shared survival arbiter identity unavailable'end
   local ok,clear=pcall(arb.clear,c,'escape',lease)
   if not ok or clear~=true then return true,'shared survival arbiter held'end
  end
  return false
 end
 return {require_new_grant=true,endpoint_policy='reviewed_ordinary_empty',defense_barrier=barrier}
end
function M.ensure_emergency(c)
 local retired=c.bash_emergency
 if retired and c.walker.emergency_owner and c.walker.emergency_owner(c,retired)then return true end
 if retired then
  local w=c.current.walker or {}
  if c.mode~='OFF'or c.current.mode~='OFF'or not c.runner or c.runner.mode~='OFF'or w.active~=false or w.enabled~=false or M.offense_held(c)or w.fault then return false,'stale emergency owner retained until settled revoked OFF'end
  if c.bash_emergency_retired~=nil and type(c.bash_emergency_retired)~='table'then return false,'emergency archive malformed; old owner preserved'end
 end
 if type(c.walker.new_emergency)~='function'then return false,'native emergency factory unavailable'end
 local owner,why=M.new_emergency(c,M.emergency_options(c))
 if not owner then return false,why end
 if retired then
  c.bash_emergency_retired=c.bash_emergency_retired or {}
  c.bash_emergency_retired[#c.bash_emergency_retired+1]={owner=retired,reason='canonical namespace changed under settled OFF; unsent grant revoked, no automatic resume'}
 end
 c.bash_emergency=owner;return true
end
function M.emergency_service(c)
 if not c.bash_emergency or not c.walker.service_emergency then return false,false end
 return c.walker.service_emergency(c,c.bash_emergency)
end
function M.emergency_status(c)
 local o=c.bash_emergency
 if not o or not c.walker.emergency_owner or not c.walker.emergency_owner(c,o)then return nil end
 local d=o.state or {}
 return 'BASH emergency '..tostring(d.phase)..': '..tostring(d.reason)..'; Shield: '..tostring(d.shield)
end
function M.emergency_step(c,owner,hop)
 if not c.walker.emergency_valid(c,owner,hop)then return false,'private BASH escape grant unavailable'end
 return dispatch_hop(c,hop,owner)
end
function M.step(c)
 local handled,sent=M.emergency_service(c);if handled then return sent end
 local s=c.current;local w=c.walker.state(s)
 c.walker.expire(s)
 local transit=M.transit_valid(c)
 if w.transit and not transit then w.transit=nil end
 if not w.active or w.fault or M.offense_held(c)or not(w.clear or transit)then return false end
 if s.hunting.preset and (not inspected_now(c)or s.hunting.area_recovery)then w.clear=nil;return false end
 if globe(c)then M.revoke(c,'GLOBE requires stationary room');return false end
 if not transit and w.clear.version~=(s.room.item_version or 0)then w.clear=nil;return false end
 if not transit and c.areas and c.areas.blocked(s)then w.clear=nil;return false end
 -- Freshly vetted enemies always interrupt movement.
 if not transit and c.bashing.watch_select(s)then w.clear=nil;s.hunting.verified_generation=s.target_generation;return false end
 local p=s.player
 if not s.connected or p.dead or s.training_battle_ended then M.revoke(c,'session unavailable');return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then M.revoke(c,'disconnected');return false end end
 if not transit and not c.policy.allowed(s)or resources(c)or not c.runner_module.ready(c.runner)then return false end
 if c.walker_defense_hold and c.walker_defense_hold(s)then return false end
 local hp,max=tonumber(p.hp)or 0,tonumber(p.maxhp)or 0
 if max<=0 or hp/max*100<math.max(s.config.health_resume or 60,s.config.defense_health_resume or 65)or p.prone then return false end
 for k,v in pairs(p.afflictions or {})do if v and v~=0 and v~='0'and (k:match('^writhe_')or ({paralysis=true,paresis=true,asleep=true,stun=true,stunned=true,frozen=true,lameness=true,left_leg_crippled=true,right_leg_crippled=true,left_leg_broken=true,right_leg_broken=true})[k])then return false end end
 local rm=restock_module(c)
 if rm and rm.movement_reserved and rm.movement_reserved(c)then return false end
 local hop=c.walker.next(s);if not hop then return false end
 if hop.kind=='kneel'and(not w.inspection or type(w.inspection.prompt_floor)~='number'or(w.movement_prompt or 0)<=w.inspection.prompt_floor)then return false end
 local preset=s.hunting.preset
 if preset and (preset.area~=s.room.area or preset.rooms and not preset.rooms[tostring(hop.to)])then M.revoke(c,'preset destination boundary');return false end
 return dispatch_hop(c,hop)
end
function M.bind_guards(c)
 local cv=c.convenience
 if cv and not cv._walker_policy then
  local old=cv.service_policy;cv.service_policy=function(owner)if M.offense_held(owner)then return 'settle'end;return old(owner)end;cv._walker_policy=true
 end
 local t=c.travel_module
 if t and not t._walker_guard then local old=t.blocked;t.blocked=function(owner,...)if M.offense_held(owner)then return true,'WALK evidence unresolved'end;return old(owner,...)end;t._walker_guard=true end
 local ink=c.tattoo_module
 if ink and ink.safe and not ink._walker_guard then local old=ink.safe;ink.safe=function(owner,...)if M.offense_held(owner)then return false,'WALK evidence unresolved'end;return old(owner,...)end;ink._walker_guard=true end
end
function M.attach(c)
 c.walker_boot=M;c.walker_module=M;c.walker=c.walker or dofile(getMudletHomeDir()..'/combat_v2/walker.lua')
 -- Fence the real graph visitation writer, not only the adapter's clear marker.
 if not c.walker._area_clear_guard then
  local mark_clear=c.walker.mark_clear
  c.walker.mark_clear=function(s,version)
   if s.hunting.preset and (s~=c.current or version~=s.room.item_version or not inspected_now(c)or c.areas.blocked(s))then return false end
   return mark_clear(s,version)
  end
  c.walker._area_clear_guard=true
 end
 -- Preserve the published state, runner, waits, and every previously installed guard.
 if not c.walker.state(c.current).restock_checkpoint then M.revoke(c,'installed; stationary BASH')end
 local w=c.walker.state(c.current);w.movement_session=w.movement_session or {}
 if c.special_exits and c.special_exits.bind_surface_provider then c.special_exits.bind_surface_provider(c)end
 M.ensure_emergency(c) -- Passive: the retained/cancelled graph grants nothing.
 -- Reload replaces only these owned observers; unrelated native hooks survive.
 if w.rejection_trigger and type(killTrigger)=='function' then killTrigger(w.rejection_trigger);w.rejection_trigger=nil end
 if w.rejection_prompt_trigger and type(killTrigger)=='function' then killTrigger(w.rejection_prompt_trigger);w.rejection_prompt_trigger=nil end
 if w.movement_disconnect_handler and type(killAnonymousEventHandler)=='function' then killAnonymousEventHandler(w.movement_disconnect_handler);w.movement_disconnect_handler=nil end
 -- Observers only: no command or automatic retirement on either callback.
 if type(tempRegexTrigger)=='function' then
  w.rejection_trigger=tempRegexTrigger([[^Now now, don't be so hasty!$]],function() M.rejection(c,line) end)
 end
 if w.door_response_trigger and type(killTrigger)=='function'then killTrigger(w.door_response_trigger);w.door_response_trigger=nil end
 if type(tempRegexTrigger)=='function'then w.door_response_trigger=tempRegexTrigger([[^(?:You open the door to the .+\.|There is .*door.*|The door.*|This door.*|You are not carrying a key for this door\.)$]],function() M.door_response(c,line)end)end
 if type(tempPromptTrigger)=='function' then w.rejection_prompt_trigger=tempPromptTrigger(function() M.rejection_prompt(c);M.door_prompt(c) end) end
 if type(registerAnonymousEventHandler)=='function' then
  w.movement_disconnect_handler=registerAnonymousEventHandler('sysDisconnectionEvent',function() w.movement_session={};M.revoke(c,'disconnected') end)
 end
 c.walker_defense_hold=c.walker_defense_hold or c.defense.hold
 local function wrap_service(module,key)
  if not module or module._walker_service then return end
  local original=module.service;if not original then return end
  if key=='buffs'then module.service=function(s,r,sender,hold,policy)return original(s,r,sender,hold,M.offense_held(c)and 'settle'or policy)end
  else module.service=function(owner,sender,policy)return original(owner,sender,M.offense_held(c)and 'settle'or policy)end end
  module._walker_service=true
 end
 wrap_service(c.buffs,'buffs');wrap_service(c.elementals);wrap_service(c.containers)
 M.bind_guards(c)
 local oldglobe=combat_v2_globe
 combat_v2_globe=function(action,...)
  local w=c.current.walker or {}
  action=tostring(action or 'status'):lower()
  if action=='on'and (w.enabled or w.active or w.offer or w.restock_checkpoint or M.offense_held(c))then return false,'Walking and GLOBE are mutually exclusive; walk off first'end
  return oldglobe(action,...)
 end
 local oldrequest=combat_v2_request_ih
 combat_v2_request_ih=function(...)
  local w=c.walker.state(c.current);local r=w.rescan
  if r and (r.starting or r.scan==c.current.hunting.ih) then
   if not M.rescan_safe(c) then r.deferred=true;return false,'WALK rescan waits for safe action settlement' end
   r.deferred=nil
  end
  return oldrequest(...)
 end
 local oldtick=combat_v2_tick
 combat_v2_tick=function(...)
  M.bind_guards(c)
  local s=c.current;local w=c.walker.state(s)
   if w.pending and w.pending.open_response then M.door_deadline(c,w.pending)end
   c.walker.expire(s)
  if not s.connected or s.player.dead or (tonumber(s.player.hp)or 0)<=0 or s.training_battle_ended then M.revoke(c,'session unavailable')end
  -- Emergency movement precedes ordinary entry/clearance/offense; no restart.
  local handled,escaped,escape_reason,reserved=M.emergency_service(c)
  if escaped then return false,'BASH emergency retreat issued' end
  if handled and reserved and not M.offense_held(c) then
   c.defense.service(s,c.defense_sender or send);c.runner_module.update_balance(c.runner)
   c.buffs.service(s,c.runner,c.buff_sender or send,true,'settle');c.mental.tick(s,c.mental_sender or send,true)
   c.runner.status=M.emergency_status(c)or ('BASH emergency: '..tostring(escape_reason));c.gui.refresh(s,c.runner,c.cure)
   return false,c.runner.status
  end
  local e=s.hunting.entry;local scan=s.hunting.ih
  if c.mode=='BASH'and e and not e.done and not e.fallback and not M.held(c)then
   c.defense.service(s,c.defense_sender or send);c.runner_module.update_balance(c.runner)
   c.buffs.service(s,c.runner,c.buff_sender or send,true,'settle');c.mental.tick(s,c.mental_sender or send,true)
   for _,command in ipairs(c.policy.services(s))do if command~='web members'or not M.occupied(c)then send(command)end end
   if scan and scan.entry_full and scan.active and scan.pending and scan.responded and scan.prompt_ready
    and (c.policy.allowed(s)or M.occupied(c))then
    combat_v2_ih_result();return false,'native entry FULL'
   end
   if M.entry_wait(c)then c.runner.status='WALK/BASH: waiting for native entry FULL, players and prompt';return false,c.runner.status end
  end
  if M.offense_held(c)then
   c.defense.service(s,c.defense_sender or send);c.runner_module.update_balance(c.runner)
   c.buffs.service(s,c.runner,c.buff_sender or send,true,'settle')
   c.mental.tick(s,c.mental_sender or send,true)
   -- Arrival is real, but room players AND a fresh solicited IH remain mandatory.
   if w.arrival_hold and not M.held(c)and c.mode=='BASH'and (c.policy.allowed(s)or M.occupied(c))then
    if M.skip(c)then return M.step(c)end
    combat_v2_start_ih('arrival inspection',true,true)
   end
   c.runner.status='WALK: location / fresh room evidence unresolved';c.gui.refresh(s,c.runner,c.cure);return false,c.runner.status
  end
  if w.ask_on_bash then M.offer(c)end
  -- Occupied transit never invokes the hunting selector, including webmates.
  if M.occupied(c)then
   c.defense.service(s,c.defense_sender or send);c.runner_module.update_balance(c.runner)
   c.buffs.service(s,c.runner,c.buff_sender or send,true,'settle');c.mental.tick(s,c.mental_sender or send,true)
   if M.skip(c)then M.step(c)else combat_v2_start_ih('occupied room inspection',true,true)end
   return false,'SKIPPED/inspecting occupied player room'
  end
  if w.active and w.reinspect and c.policy.allowed(s)then
   if not M.entry_wait(c)then w.reinspect=nil end
   combat_v2_start_ih('fresh Room.Info invalidated clearance',true,true)
  end
  if w.active then M.rescan(c) end
  if w.active and w.clear and M.step(c)then return false,'walking'end
  local result,reason=oldtick(...)
  if handled then
   local diagnostic=M.emergency_status(c)
   if diagnostic then c.runner.status=diagnostic;c.gui.refresh(s,c.runner,c.cure) end
  end
  return result,reason
 end
 local oldmode=combat_v2_set_mode
 combat_v2_set_mode=function(mode)
  local wanted=tostring(mode):upper();local own=owned_transition(c)and (wanted=='OFF'or wanted=='BASH')
  local repeated=wanted=='BASH'and c.mode=='BASH'and c.current.mode=='BASH'
  if not own and not repeated then M.revoke(c,'explicit mode selection')end;local bash=wanted=='BASH'
  if tostring(mode):upper()~='OFF'and M.held(c)then return false,'movement unresolved'end
  c.current.walker.ask_on_bash=bash and c.current.walker.enabled==true and not own and not repeated
  return oldmode(mode)
 end
 local oldstop=combat_v2_stop;combat_v2_stop=function(...)if not owned_transition(c)then M.revoke(c,'OFF')end;return oldstop(...)end
 local oldtarget=combat_v2_set_target;combat_v2_set_target=function(...)M.revoke(c,'manual target');if M.offense_held(c)then return false,'movement unresolved'end;return oldtarget(...)end
 local oldreset=combat_v2_reset_wait
 combat_v2_reset_wait=function(...)
  -- Never clear another resource owner's barrier in a movement recovery.
  if M.offense_held(c)then
   if c.current.walker.dispatching or c.current.walker.physical_dispatch then return false,'sender still executing'end
   combat_v2_stop('reviewed movement recovery');local w=c.current.walker;w.pending=nil;w.fault=nil;w.arrival_hold=true
   c.current.room.id=nil;c.current.room.area=nil;c.current.room.items={};c.current.policy.players_known=false;c.current.policy.players_room=nil;c.current.hunting.verified_generation=nil
   return true
  end
  return oldreset(...)
 end
 combat_v2_walk_answer=function(token,yes)return M.answer(c,token,yes)end
 combat_v2_walk=function(cmd)
  cmd=tostring(cmd or 'status'):lower()
  if cmd=='off'then c.walker.state(c.current).enabled=false;M.revoke(c,'stationary BASH');return true end
  if cmd=='on'then
   local w=c.walker.state(c.current)
   if globe(c)or M.offense_held(c)then return false,'GLOBE or movement/evidence unresolved'end
   if w.restock_checkpoint then M.revoke(c,'fresh consent requested')end
   w.enabled=true
   if c.mode~='BASH'or c.current.mode~='BASH'then w.status='WALK enabled; waiting for BASH and fresh YES';return true end
   return M.offer(c)
  end
  if cmd=='yes'or cmd=='no'then local o=c.current.walker.offer;return M.answer(c,o and o.token,cmd=='yes')end
  if cmd==''or cmd=='status'or cmd==nil then local w=c.walker.state(c.current);print('WALK '..(w.enabled and 'ON' or 'OFF')..': '..tostring(w.status));return true end
  return false,'cv2 walk on|off|status|yes|no'
 end

 return true
end
return M
