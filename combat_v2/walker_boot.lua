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
 local ok,area=pcall(getRoomArea,start);if not ok or not tonumber(area)or tonumber(area)<0 then return nil,'unmapped start'end
 local good,ids=pcall(getAreaRooms,area);if not good or type(ids)~='table'then return nil,'unknown area rooms'end
 local rooms,n,edges={},0,0
 for _,raw in pairs(ids)do
  n=n+1;if n>M.MAX_ROOMS then return nil,'area exceeds bounded room budget'end
  local id=tonumber(raw)
  if id then
   local a,actual=pcall(getRoomArea,id);local b,locked=pcall(roomLocked,id);local d,weight=pcall(getRoomWeight,id)
   local e,exits=pcall(getRoomExits,id);local f,doors=pcall(getDoors,id)
   if a and actual==area and b and locked==false and d and tonumber(weight)and tonumber(weight)<=1 and e and type(exits)=='table'and f and type(doors)=='table'then
    for _ in pairs(exits)do edges=edges+1;if edges>M.MAX_EDGES then return nil,'area exceeds bounded edge budget'end end
    rooms[tostring(id)]={area=area,exits=exits,doors=doors}
   end
  end
 end
 local g,why=c.walker.build(start,area,rooms);if g then g.mapped_count=n;g.coverage=g.room_count..' reachable safe rooms / '..n..' mapped entries'end
 return g,why
end
function M.offer(c)
 local w=c.walker.state(c.current);w.ask_on_bash=false
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
 if yes and (globe(c)or M.offense_held(c))then return false,'GLOBE or movement/evidence unresolved'end
 local ok,why=c.walker.accept(c.current,tonumber(token),yes==true)
 if ok then
  if c.gui.hide_walk_prompt then c.gui.hide_walk_prompt()end
  if yes then combat_v2_start_ih('walking consent; fresh room inspection',true)end
 end
 return ok,why
end
function M.items(c,payload)
 local s=c.current;local scan=s.hunting.ih
 if M.held(c)or type(payload)~='table'or payload.location~='room'or type(payload.items)~='table'or not scan or not scan.active or not scan.pending then return false end
 for _,it in pairs(payload.items)do if type(it)~='table'or it.id==nil or type(it.name)~='string' then return false end end
 scan.walker_version=s.room.item_version;scan.walker_items=s.room.items
 return true
end
function M.inspected(c,scan)
 local s=c.current;local w=c.walker.state(s)
 if M.held(c)or not scan or not scan.responded or scan.source or sid(scan.room_id)~=sid(s.room.id)or not scan.items then return false end
 if not scan.walker_version or scan.walker_version~=(s.room.item_version or 0)or scan.walker_version<=(scan.start_version or 0)then return false end
 if scan.walker_items~=s.room.items or scan.items~=s.room.items then return false end
 if not c.policy.allowed(s)then return false end
 w.arrival_hold=nil;w.reinspect=nil
 w.inspection={room=sid(s.room.id),area=s.room.area,items=s.room.items,version=s.room.item_version,sequence=w.room_sequence or 0}
 return true
end
function M.clear(c,scan)
 local s=c.current;local w=c.walker.state(s)
 -- No unanswered IH, incomplete list, partial update or quiet-watch clearance.
 if not M.inspected(c,scan)or not w.active then return false end
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
function M.room(c,info,changed)
 local s=c.current;local w=c.walker.state(s)
 w.room_sequence=(w.room_sequence or 0)+1;w.inspection=nil
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
   if ok then w.arrival_hold=true;w.arrival_version=s.room.item_version or 0 end
  elseif w.active or w.offer then M.revoke(c,'manual/unexpected room change')end
 end
end
local function resources(c)
 local s=c.current;local r=c.runner;local m=s.mental or {};local b=s.buffs or {};local g=c.elemental_recovery or {};local co=c.containers_data or {}
 local tr=c.travel_owner or {};local ink=c.tattoo_owner or {};local root=r.root or c.root or {}
 if c.transport_unknown or root.transport_unknown or root.dispatching or root.action_dispatching or r.transport_unknown or r.waiting or r.fault or r.dispatching or r.transport_commit or r.transport_barrier or m.eq_pending or m.pending or m.fault or m.dispatching or b.pending or b.fault or b.dispatching or g.committed or g.dispatching or g.pending or g.fault or co.barrier or co.action_dispatching then return true end
 if tr.pending or tr.dispatching or tr.fault or tr.follow_pending or tr.follow_fault or tr.recall_due or tr.intent or tr.route or ink.txn or ink.pending or ink.dispatching or ink.fault then return true end
 if c.convenience and (c.convenience.busy(c)or c.convenience.hold(c))then return true end
 if c.lunch_boot and c.lunch_boot.busy(c)then return true end
end
local function inspected_now(c)
 local s=c.current;local w=c.walker.state(s);local i=w.inspection
 return i and i.room==sid(s.room.id)and i.area==s.room.area and i.items==s.room.items and i.version==s.room.item_version and i.sequence==(w.room_sequence or 0)
end
local function no_npcs(c)
 for _,it in pairs(c.current.room.items or {})do
  local a=tostring(it.attrib or '')
  if not a:find('d',1,true)and not a:find('x',1,true)and (a:find('m',1,true)or it.icon=='monster')then return false end
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
function M.step(c)
 local s=c.current;local w=c.walker.state(s)
 c.walker.expire(s)
 if not w.active or M.offense_held(c)or not w.clear then return false end
 if globe(c)then M.revoke(c,'GLOBE requires stationary room');return false end
 if w.clear.version~=(s.room.item_version or 0)then w.clear=nil;combat_v2_start_ih('room contents changed',true);return false end
 -- Freshly vetted enemies always interrupt movement.
 if c.bashing.watch_select(s)then w.clear=nil;s.hunting.verified_generation=s.target_generation;return false end
 local p=s.player
 if not s.connected or p.dead or s.training_battle_ended then M.revoke(c,'session unavailable');return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then M.revoke(c,'disconnected');return false end end
 if not c.policy.allowed(s)or resources(c)or not c.runner_module.ready(c.runner)then return false end
 if c.walker_defense_hold and c.walker_defense_hold(s)then return false end
 local hp,max=tonumber(p.hp)or 0,tonumber(p.maxhp)or 0
 if max<=0 or hp/max*100<math.max(s.config.health_resume or 60,s.config.defense_health_resume or 65)or p.prone then return false end
 for k,v in pairs(p.afflictions or {})do if v and v~=0 and v~='0'and (k:match('^writhe_')or ({paralysis=true,paresis=true,asleep=true,stun=true,stunned=true,frozen=true,lameness=true,left_leg_crippled=true,right_leg_crippled=true,left_leg_broken=true,right_leg_broken=true})[k])then return false end end
 local rm=restock_module(c)
 if rm and rm.movement_reserved and rm.movement_reserved(c)then return false end
 local hop=c.walker.next(s);if not hop then return false end
 local info=gmcp and gmcp.Room and gmcp.Room.Info
 if not info or sid(info.num)~=sid(s.room.id)or type(info.exits)~='table'or sid(info.exits[hop.direction])~=hop.to then M.revoke(c,'live exit mismatch');w.fault='live exit mismatch';return false end
 if not c.walker.begin_step(s,hop)then return false end
 -- dispatching survives synchronous arrival, Stop, nested tick and reconsent.
 local pending=w.pending;w.dispatching=pending
 local ok,result=pcall(c.walk_sender or send,hop.direction)
 w.dispatching=nil
 if not ok or result==false then
  w.pending=w.pending or pending;w.fault='movement transport unknown';M.revoke(c,w.fault);return false
 end
 w.sent=(w.sent or 0)+1
 return true
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
 -- Preserve the published state, runner, waits, and every previously installed guard.
 if not c.walker.state(c.current).restock_checkpoint then M.revoke(c,'installed; stationary BASH')end
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
  if action=='on'and (w.active or w.offer or w.restock_checkpoint or M.offense_held(c))then return false,'Walking and GLOBE are mutually exclusive; walk off first'end
  return oldglobe(action,...)
 end
 local oldtick=combat_v2_tick
 combat_v2_tick=function(...)
  M.bind_guards(c)
  local s=c.current;local w=c.walker.state(s);c.walker.expire(s)
  if not s.connected or s.player.dead or (tonumber(s.player.hp)or 0)<=0 or s.training_battle_ended then M.revoke(c,'session unavailable')end
  if M.offense_held(c)then
   c.defense.service(s,c.defense_sender or send);c.runner_module.update_balance(c.runner)
   c.buffs.service(s,c.runner,c.buff_sender or send,true,'settle')
   c.mental.tick(s,c.mental_sender or send,true)
   -- Arrival is real, but room players AND a fresh solicited IH remain mandatory.
   if w.arrival_hold and not M.held(c)and c.mode=='BASH'and c.policy.allowed(s)then combat_v2_start_ih('arrival inspection',true)end
   c.runner.status='WALK: location / fresh room evidence unresolved';c.gui.refresh(s,c.runner,c.cure);return false,c.runner.status
  end
  if w.ask_on_bash then M.offer(c)end
  if w.active and w.reinspect and c.policy.allowed(s)then w.reinspect=nil;combat_v2_start_ih('fresh Room.Info invalidated clearance',true)end
  if w.active and w.clear and M.step(c)then return false,'walking'end
  return oldtick(...)
 end
 local oldmode=combat_v2_set_mode
 combat_v2_set_mode=function(mode)
  local wanted=tostring(mode):upper();local own=owned_transition(c)and (wanted=='OFF'or wanted=='BASH')
  if not own then M.revoke(c,'explicit mode selection')end;local bash=wanted=='BASH'
  if tostring(mode):upper()~='OFF'and M.held(c)then return false,'movement unresolved'end
  c.current.walker.ask_on_bash=bash and not own
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
  if cmd=='off'then M.revoke(c,'stationary BASH');return true end
  if cmd=='on'then if c.mode~='BASH'then return false,'enable BASH first'end;return M.offer(c)end
  if cmd=='yes'or cmd=='no'then local o=c.current.walker.offer;return M.answer(c,o and o.token,cmd=='yes')end
  if cmd==''or cmd=='status'or cmd==nil then print('WALK: '..tostring(c.current.walker.status));return true end
  return false,'cv2 walk on|off|status|yes|no'
 end
 -- Session-only XP cutoff owns the outer GLOBE guard; never replay cached XP.
 local q=c.xp_globe_cutoff;if q and q.module and q.module.bind then q.module.bind(c)end
 return true
end
return M
