-- BASH-only emergency retreat. No globals/send, no PT, no OFF mapper probe.
-- Authority is captured privately by walker.new_emergency; diagnostic state is not a grant.
local E={}
local dirs={'n','ne','e','se','s','sw','w','nw','u','d','in','out'}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function flag(x)return x==true or tonumber(x)==1 end
local function present(x)return x~=nil and x~=false end
local function busy(o,passive,terminal)
 if type(o)~='table'then return o~=nil end
 for _,k in ipairs({'pending','waiting','fault','dispatching','action_dispatching','actionDispatching','transport_unknown','transportUnknown','transport_commit','transportCommit','transport_barrier','transportBarrier','committed','eq_pending','txn','purchase','reserved','checkpoint','owned_pause','route','intent','follow_pending','follow_fault','physical_dispatch','physical_commit','physical_transport','transport_pending','movement_pending','ink_pending','arrival_hold','barrier','action_pending','haven_refresh','query','quarantine','ability_listing','native_listing','listing'})do
  if present(o[k])and not(k=='fault'and passive)and not(k=='pending'and terminal)then return true end
 end
 for _,k in ipairs({'transport_barriers','transportBarriers','native_pending'})do
  local v=o[k];if type(v)=='table'and next(v)or v~=nil and v~=false and type(v)~='table'then return true end
 end
 return false
end
local function whole(x)return finite(x)and x>=0 and x%1==0 end
function E.passive_restock(c)
 local d=c.restock_data;local t=c.restock_controller
 if type(d)~='table'or type(t)~='table'or t.state~=d then return false end
 local allowed={enabled=true,reserved=true,busy=true,phase=true,scope_unknown=true,active=true,resume_consent=true,resume_globe=true,pumping=true,serial=true,fault=true,status=true,last_room=true,last_area=true,prompt=true}
 for k in pairs(d)do if not allowed[k]then return false end end
 if d.enabled~=true or d.reserved~=false or d.busy~=false or d.phase~='monitor'or d.scope_unknown~=false or d.active~=false or d.resume_consent~=false or d.resume_globe~=false or d.pumping~=false or d.serial~=0 then return false end
 return d.fault=='disconnected/dead; no automatic restart'and d.status=='held: disconnected/dead; no automatic restart'
  and whole(tonumber(d.last_room))and tonumber(d.last_room)>0 and type(d.last_area)=='string'and #d.last_area>0 and whole(d.prompt)
end
function E.terminal_globe(c)
 local m=c.travel_module
 if not m or type(m.terminal_globe_exhaustion)~='function'then return false end
 local ok,v=pcall(m.terminal_globe_exhaustion,c);return ok and v==true
end
-- Endpoint safety is deliberately stronger than the hunting/transit classifier.
-- Unknown NPC metadata and uncatalogued/passive scouts never become EMPTY.
function E.endpoint_empty(c)
 local s=c.current;local r=s.room;local tr=c.travel_owner or {}
 if type(r.items)~='table'then return false end
 for key,it in pairs(r.items)do
  if type(it)~='table'or type(it.name)~='string'or it.name==''or type(it.attrib)~='string'then return false end
  local a=it.attrib;local id=tostring(it.id or key)
  local loyal=a=='mx'and type(tr.mount)=='string'and id==tr.mount and tostring(key)==id and tr.present==true and tostring(tr.presence_room)==tostring(r.id)
  local corpse=a=='d'and (it.icon==nil or it.icon=='corpse')
  if loyal and flag((s.player.afflictions or {}).disfigurement)then return false,'own loyal '..id..' unsafe under known disfigurement'end
  if loyal and c.areas and c.areas.endpoint_loyal_hostile and c.areas.endpoint_loyal_hostile(s,id)then return false,'verified hostile own loyal '..id..' is not an EMPTY endpoint'end
  if not loyal and not corpse then
   if a=='mx'then return false,'loyal '..id..' lacks exact own ID/current presence proof'end
   return false,'entity '..id..' is neither independently proven own loyal nor corpse'
  end
 end
 return true
end
function E.foot_node(c,graph,id)
 local b=c.tour_boot
 if type(graph)~='table'or type(graph.nodes)~='table'or not graph.nodes[id]or type(id)~='string'or not id:match('^%d+$')or not b or type(b.dry_environment)~='function'then return false end
 for _,key in ipairs({'getRoomEnv','getRoomArea','roomLocked','getRoomWeight'})do if type(_G[key])~='function'then return false end end
 local special=(graph.special_edges or {})[id]
 for _,hop in pairs(special or {})do if hop.kind~='swim'or not c.special_exits or not c.special_exits.surface_endpoint(c,tonumber(id))then return false end end
 local ok,env=pcall(getRoomEnv,tonumber(id));local dry,yes=pcall(b.dry_environment,ok and env or nil)
 local area_ok,area=pcall(getRoomArea,tonumber(id));local lock_ok,locked=pcall(roomLocked,tonumber(id));local weight_ok,weight=pcall(getRoomWeight,tonumber(id))
 return ok and dry and yes==true and area_ok and finite(tonumber(graph.area))and finite(tonumber(area))and tonumber(area)==tonumber(graph.area)and lock_ok and locked==false and weight_ok and finite(tonumber(weight))and tonumber(weight)>=0 and tonumber(weight)<=1
end
function E.route_node(c,graph,id)
 if E.foot_node(c,graph,id)then return true end
 if not graph.nodes[id]or not c.special_exits or not c.special_exits.surface_endpoint then return false end
 local p=c.special_exits.surface_endpoint(c,tonumber(id))
 if not p or p.water~=true or p.locked~=false or not tonumber(p.weight)or tonumber(p.weight)>1 then return false end
 local incoming,outgoing=false,false
 for from,edges in pairs(graph.special_edges or {})do for dir,hop in pairs(edges)do
  if hop.kind=='swim'and graph.nodes[from]and graph.nodes[from][dir]==hop.to then
   if hop.to==id then incoming=true end;if from==id then outgoing=true end
  end
 end end
 return incoming and outgoing
end
function E.endpoint_policy(c,graph)
 local result={};local b=c.tour_boot
 for _,key in ipairs({'getRoomEnv','getRoomArea','roomLocked','getRoomWeight'})do if type(_G[key])~='function'then return result,'native reviewed dry-terrain/room codec unavailable'end end
 if type(graph)~='table'or type(graph.nodes)~='table'or not b or type(b.dry_environment)~='function'then return result,'native reviewed dry-terrain codec unavailable'end
 for id in pairs(graph.nodes)do
  if E.foot_node(c,graph,id)then result[id]='new native WALK grant; reviewed ordinary safe-foot terrain; recent inspected solo EMPTY certificate required'end
 end
 if next(result)then return result end
 return result,'no reviewed ordinary safe-foot waiting points'
end
function E.native_barriers(c)
 local s=c.current;local r=c.runner
 local owners={controller=c,current=s,runner=r,walker=s.walker or {},root=c.root or {},current_root=s.root or {},runner_root=r.root or {},restock_controller=c.restock_controller and c.restock_controller.state or {},lunch_controller=c.lunch_controller and c.lunch_controller.state or {},tour=c.tour and c.tour.state or {},defense=s.defense or {},mental=s.mental or {},buffs=s.buffs or {},globe=c.elemental_recovery or {},containers=c.containers_data or {},travel=c.travel_owner or {},tattoo=c.tattoo_owner or {},restock=c.restock_data or {},lunch=c.lunch_duty or {}}
 local passive=E.passive_restock(c);local terminal=E.terminal_globe(c)
 for name,o in pairs(owners)do
  local diagnostic=o==c.restock_data and passive or o==c.elemental_recovery and terminal
  if busy(o,diagnostic,o==c.elemental_recovery and terminal)then return false,'native owner barrier: '..name end
 end
 if s.walker and s.walker.restock_checkpoint or c.user_activity then return false,'borrowed movement owner'end
 if c.elemental_recovery and c.elemental_recovery.armed then return false,'GLOBE armed'end
 local n=c.emergency_numb
 if n and(n.pending or n.fault)then return false,'NUMB/SHIFT commitment unresolved'end
 return true
end
function E.construct(c,opt,io)
 local supplied=opt or {};opt={require_new_grant=supplied.require_new_grant==true,require_shared_arbiter=supplied.require_shared_arbiter==true,endpoint_policy=supplied.endpoint_policy,safe_endpoints=supplied.safe_endpoints,defense_barrier=supplied.defense_barrier}
 local s=c.current;local w=c.walker.state(s);local walker=c.walker;local boot=c.walker_boot
 local endpoints={};for id,p in pairs(opt.safe_endpoints or {})do
  if type(id)=='string'and type(p)=='string'and #p>0 then endpoints[id]=p end
 end
 local owner={state={phase='idle',reason='no emergency',shield='unverified; no automatic TOUCH SHIELD'}}
 local records={};local episode;local in_service=false;local selected;local lease
 local areas=c.areas;local pressure_reader=areas and areas.incoming_pressure
 local pressure;local pressure_floor=0
 local certificate_issued=0;local certificate_rejected=0;local certificate_last
 -- Shared NUMB/SHIFT arbiter remains the only defense sender. This adapter can
 -- add a barrier only; it cannot relax native readiness or authorize movement.
 local defense_barrier=opt.defense_barrier;local defense_owner=c.defense
 local attached_version=s.room.item_version or 0;local attached_sequence=w.room_sequence or 0
 local enrollment_offers=w.offers or 0;local enrollment_graph=w.graph;local workflow;local same
 local function clock()return walker.movement_clock(s)end
 local function scope()
  if c.current~=s or c.walker~=walker or c.walker_boot~=boot or s.walker~=w then return false,'canonical walker changed'end
  if pressure_reader and(c.areas~=areas or areas.incoming_pressure~=pressure_reader)then return false,'canonical incoming evidence provider changed'end
  if c.mode~='BASH'or s.mode~='BASH'or not c.runner or c.runner.state~=s or c.runner.mode~='BASH'then return false,'BASH not selected'end
  if not flag(s.connected) or type(s.player.class)~='string' or s.player.class=='' or flag(s.player.dead)or s.training_battle_ended then return false,'session/death barrier'end
  if not w.active or w.enabled~=true or not w.graph or not w.movement_session then return false,'no current WALK consent'end
  if opt.require_new_grant and (not workflow or not same(workflow))then return false,'passive enrollment; genuinely NEW native WALK/tour grant required'end
  if c.tour and (type(c.tour.state)~='table'or type(c.tour.io)~='table')then return false,'unknown tour owner'end
  if c.tour and c.tour.state.slot and (c.tour.state.slot.active_graph==w.graph or c.tour.state.slot.graph==w.graph) then
   local t=c.tour;local st=t.state;local slot=st.slot
   if st.phase~='hunt'or not st.grant or slot.grant~=st.grant or slot.token~=w.offers or slot.epoch~=(w.intent_epoch or 0)or type(t.io.scope)~='function'or t.io.scope(st.grant)~=true then return false,'tour grant cancelled or expired'end
  end
  return true
 end
 local function health()
  local p=s.player;local hp,m=tonumber(p.hp),tonumber(p.maxhp)
  if not finite(hp)or not finite(m)or m<=0 or hp<=0 then return nil end
  local pct=hp/m*100
  if not finite(pct)then return nil end
  return pct
 end
 local function fresh()
  local r=s.room;local p=s.policy or {};local q=s.hunting.area_snapshot
  -- Emergency departure consumes the Core-accepted FULL certificate, not normal
  -- hunting clearance: a newly arriving attacker legitimately invalidates IH.
  return finite(attached_version)and finite(r.item_version)and r.item_version>attached_version and (w.room_sequence or 0)>=attached_sequence
   and q and tostring(q.room)==tostring(r.id)and q.area==r.area and q.items==r.items and q.version==r.item_version
   and p.players_known==true and tostring(p.players_room)==tostring(r.id)
   and c.policy and c.policy.allowed(s)==true and c.areas and c.areas.fresh(s)==true and not not c.areas.scope(s)
 end
 local function solo()
  for name in pairs((s.policy or {}).players or {})do if name~=s.policy.self_name then return false end end
  return true
 end
 local function empty()return E.endpoint_empty(c)end
 local function fingerprint()
  local t=c.tour;return {session=w.movement_session,epoch=w.intent_epoch or 0,graph=w.graph,offers=w.offers,class=s.player.class,tour=t,slot=t and t.state.slot,grant=t and t.state.grant,generation=t and t.state.generation}
 end
 same=function(a)
  local b=fingerprint();for _,k in ipairs({'session','epoch','graph','offers','class','tour','slot','grant','generation'})do if a[k]~=b[k]then return false end end;return true
 end
 local function barriers(preview)
  local p=s.player;local a=p.afflictions or {};local d=s.defense or {}
  if defense_barrier~=nil then
   if c.defense~=defense_owner or type(defense_barrier)~='function'then return false,'emergency defense adapter owner changed'end
   local ok,held,reason=pcall(defense_barrier,c,s,defense_owner,lease,preview)
   if not ok or type(held)~='boolean'or held then return false,reason or 'NUMB/SHIFT arbiter unresolved'end
  end
  if type(getConnectionInfo)~='function'then return false,'TCP proof unavailable'end
  local ok,_,_,tcp=pcall(getConnectionInfo);if not ok or tcp~=true then return false,'TCP disconnected'end
  for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if not flag(p[k])then return false,'not ready: '..k end end
  if flag(p.prone)then return false,'prone'end
  for k,v in pairs(a)do
   if v~=nil and v~=false and v~=0 and v~='0'and (k:match('^writhe_')or ({prone=true,fallen=true,paralysis=true,paresis=true,asleep=true,unconsciousness=true,stun=true,stunned=true,frozen=true,webbed=true,bound=true,transfixed=true,impaled=true,impalement=true,entangled=true,roped=true,rooted=true,immobilized=true,unconscious=true,lameness=true,left_leg_mangled=true,right_leg_mangled=true,left_leg_crippled=true,right_leg_crippled=true,left_leg_broken=true,right_leg_broken=true})[k])then return false,'hindered: '..k end
  end
  if a.anorexia and a.asthma and a.slickness then return false,'cure-lock'end
  if d.fault then return false,'defense fault'end
  if d.hold and not (d.low_health==true and d.phase=='survival pause; recover to '..((s.config or {}).defense_health_resume or 65)..'% HP')then return false,'non-health defense hold'end
  -- Enumerate direct native owners; unsent pet recall/follow/mount preferences are
  -- not physical work. Issued recall/FOLLOW and all opaque commitments stay fenced.
  local clear,why=E.native_barriers(c);if not clear then return false,why end
  if p.mounted~=false and p.mounted~=0 then return false,'unmounted foot proof required'end
  if opt.endpoint_policy=='reviewed_ordinary_empty'and not E.route_node(c,w.graph,tostring(s.room.id))then return false,'current terrain is not reviewed safe-foot/surface route'end
  return true
 end
 local function hold(reason)
  owner.state.phase='blocked';owner.state.reason=reason;owner.state.shield='last resort unavailable: fresh AB/ownership/charges/readiness/ACK required'
  return true,false,reason,episode and episode.path~=nil and not episode.terminal
 end
 local function pressure_receipt()
  if not pressure_reader or c.areas~=areas or areas.incoming_pressure~=pressure_reader then return nil end
  return pressure_reader(s)
 end
 local function observe_pressure()
  local r=pressure_receipt();local tm=clock()
  if not r or not finite(r.at)or not r.generation or not finite(tm)or r.seq<=pressure_floor then pressure=nil;return end
  if pressure and(pressure.generation~=r.generation or pressure.room~=r.room or pressure.area~=r.area or pressure.id~=r.id or pressure.name~=r.name or pressure.attrib~=r.attrib or pressure.icon~=r.icon
   or pressure.offense~=c.runner.last_send or r.at<pressure.last or r.at-pressure.last>8)then pressure=nil end
  if pressure and(pressure.seq==r.seq or pressure.last==r.at)then pressure.seq=r.seq;return end -- polling/equal timestamps are not new timed hits
  if not pressure then
   pressure={first=r.at,first_seen=tm,count=0,generation=r.generation,room=r.room,area=r.area,id=r.id,name=r.name,attrib=r.attrib,icon=r.icon,offense=c.runner.last_send}
  end
  pressure.seq=r.seq;pressure.last=r.at;pressure.last_seen=tm;pressure.count=pressure.count+1
 end
 local function pressure_ready()
  if episode and episode.cause=='incoming-stall'and not episode.terminal and same(episode.scope)then return true end
  local r=pressure_receipt()
  return pressure and r and r.generation==pressure.generation and r.seq==pressure.seq and r.seq>pressure_floor and pressure.offense==c.runner.last_send
   and pressure.last-pressure.first>=8 and pressure.count>=3 or false
 end
 local function reject_certificate(reason)
  certificate_rejected=certificate_rejected+1
  certificate_last={room=tostring(s.room.id),version=s.room.item_version,sequence=w.room_sequence,reason=reason}
 end
 local function observe()
  local current=tostring(s.room.id);local old=records[current]
  if old and(old.version~=s.room.item_version or not empty()or not solo())then records[current]=nil end
  if not scope()then return reject_certificate('no current privately observed NEW grant')end
  if not fresh()then return reject_certificate('fresh post-grant FULL/policy/player evidence required')end
  if not solo()then return reject_certificate('another player present')end
  local is_empty,empty_reason=empty()
  if not is_empty then return reject_certificate('not EMPTY: '..(empty_reason or 'malformed or unknown entities'))end
  if opt.endpoint_policy=='reviewed_ordinary_empty'and not E.route_node(c,w.graph,tostring(s.room.id))then return reject_certificate('unreviewed route terrain')end
  local i=w.inspection
  if not i or i.room~=tostring(s.room.id)or i.area~=s.room.area or i.items~=s.room.items or i.version~=s.room.item_version or i.sequence~=(w.room_sequence or 0)then return reject_certificate('current native inspection identity/version/sequence required')end
  local tm=clock();if not finite(tm)then return reject_certificate('invalid movement clock')end
  local id=tostring(s.room.id);local previous=records[id]
  if previous and previous.version==s.room.item_version and previous.sequence==w.room_sequence then return end
  local loyal
  for key,it in pairs(s.room.items)do if it.attrib=='mx'then loyal=tostring(it.id or key)end end
  records[id]={scope=fingerprint(),at=tm,version=s.room.item_version,sequence=w.room_sequence,loyal=loyal}
  certificate_issued=certificate_issued+1;certificate_last={room=id,version=s.room.item_version,sequence=w.room_sequence,at=tm,reason='issued from genuine post-grant native inspection'}
 end
 local function safe(id,tm)
  if opt.endpoint_policy=='reviewed_ordinary_empty'and not E.route_node(c,w.graph,id)then return false end
  local r=records[id]
  if r and r.loyal and(flag((s.player.afflictions or {}).disfigurement)or areas and areas.endpoint_loyal_dependency_hostile and areas.endpoint_loyal_dependency_hostile(s,r.loyal))then return false end
  return r and same(r.scope)and finite(tm)and tm>=r.at and tm-r.at<=30 and (w.visited or {})[id]==true
 end
 local function plan(avoid,limit,preview_time)
  avoid=avoid or {};limit=limit or 8
  local current=tostring(s.room.id);local tm=preview_time or clock();local graph=w.graph
  local queue={{room=current,path={}}};local seen={[current]=true};local head=1
  while head<=#queue and head<=3000 do
   local entry=queue[head];head=head+1
   if entry.room~=current and endpoints[entry.room]and safe(entry.room,tm)then return entry.path,entry.room end
   if #entry.path<limit then
    for _,dir in ipairs(dirs)do
     local to=(graph.nodes[entry.room]or {})[dir]
     local typed=((graph.special_edges or {})[entry.room]or {})[dir]
     if to and not seen[to]and not avoid[to]and safe(to,tm)and(not typed or typed.kind=='swim')then
      seen[to]=true;local path={};for i,h in ipairs(entry.path)do path[i]=h end
      path[#path+1]=typed or {from=entry.room,to=to,direction=dir};queue[#queue+1]={room=to,path=path}
     end
    end
   end
  end
 end
 local function authorize(hop)
  if not in_service or not episode or episode.terminal or not same(episode.scope)or selected~=hop or episode.path[episode.index]~=hop then return false end
  if not scope()or not health()or (health()>=20 and not pressure_ready())or not fresh()or not solo()then return false end
  if tostring(s.room.id)~=hop.from or not safe(hop.to,clock())then return false end
  return barriers()==true
 end
 local function arbiter()
  local a=c.survival_arbiter
  if type(a)~='table'or a.schema~='survival-v1'or a.owner~=c then return nil end
  for _,key in ipairs({'clear','choose','reserve','owns','release','transport','settle'})do if type(a[key])~='function'then return nil end end
  return a
 end
 local function peek()
  if not scope()or not health()or (health()>=20 and not pressure_ready())or not fresh()or not solo()or w.pending or w.dispatching or w.arrival_hold then return false end
  if episode and(episode.terminal or not same(episode.scope)or episode.hops>=8)then return false end
  local tm=walker.peek_movement_clock and walker.peek_movement_clock(s)
  if not finite(tm)or episode and(tm<episode.started or tm-episode.started>30)then return false end
  -- One COUNT is a qualified read while the cast owns EQ. Keep original
  -- episode/grant/room/deadline checks, but do not require recovered EQ for it.
  local a=arbiter();local status=a and a.status(c)
  if episode and episode.shield_only and status and status.kind=='ribcage'then
   return true,{kind='ribcage',session=w.movement_session,owner=owner,cause=episode.cause}
  end
  if not barriers(true)then return false end
  local hop=selected
  if not hop and episode then
   local index=episode.index;hop=episode.path and episode.path[index]
   if hop and tostring(s.room.id)==hop.to then index=index+1;hop=episode.path[index]end
   if not hop and empty()then return false end
  end
  if not hop then local path=plan(episode and episode.avoid,episode and(8-episode.hops)or 8,tm);hop=path and path[1]end
  if not hop and episode and episode.shield_only and s.player.class=='Earthcaller'then
   return true,{kind='ribcage',session=w.movement_session,owner=owner,cause=episode.cause}
  end
  if not hop or hop.from~=tostring(s.room.id)or not safe(hop.to,tm)then return false end
  return true,{hop=hop,session=w.movement_session,transport=io.move,owner=owner,cause=pressure_ready()and 'incoming-stall'or 'low-health'}
 end
 local function last_resort(reason)
  owner.state.shield='last resort held: '..reason
  local a=arbiter()
  if not episode or s.player.class~='Earthcaller'or not a or type(a.ribcage)~='function'then
   if episode then episode.terminal=true end;return hold(reason)
  end
  episode.shield_only=true
  local status=a.status(c)
  if episode.shield_attempted and status.kind~='ribcage'then episode.terminal=true;return hold('Ribcage episode completed; no automatic resume or attack-compatible claim')end
  local issued,why=a.ribcage(c,owner)
  if issued then episode.shield_attempted=true end
  owner.state.phase='blocked';owner.state.reason=why;owner.state.shield=why
  return true,issued==true,why,false
 end
 function owner.service()
  if in_service then return true,false,'emergency reentry held'end
  local arb=arbiter()
  if lease then
   if not arb then return hold('owned survival authority unavailable; commitment retained')end
   arb.settle(c)
   if arb.owns(c,lease)then return hold('awaiting owned native escape settlement')end
   lease=nil
  end
  local valid,why=scope()
  if episode and not same(episode.scope)then
   episode.terminal=true;owner.state.phase='revoked';owner.state.reason='newer operator/session/tour intent retained'
   return false,false,owner.state.reason
  end
  if not valid then
   if episode then episode.terminal=true;return hold(why)end
   return false,false,why
  end
  observe();observe_pressure()
  local pct=health()
  if not pct then if episode then episode.terminal=true end;return hold('invalid finite health')end
  local stalled=pressure_ready()
  if not episode and pct>=20 and not stalled then return false,false end
  if not episode then
   local path,destination=plan()
   local cause=stalled and 'incoming-stall'or 'low-health'
   episode={scope=fingerprint(),path=path,index=1,destination=destination,started=clock(),hops=0,avoid={[tostring(s.room.id)]=true},cause=cause}
   owner.state.cause=cause
   if not path then return last_resort('no recently certified consented backedge path to reviewed safe endpoint')end
  end
  if episode.terminal then return true,false,owner.state.reason or 'emergency episode terminal; fresh authorization required' end
  if not same(episode.scope)then episode.terminal=true;return hold('newer operator/session/tour intent retained')end
  if not finite(clock())or clock()-episode.started>30 then episode.terminal=true;return hold('bounded emergency deadline exhausted; preserve native commitments')end
  if episode.shield_only then return last_resort('no certified escape path; bounded last-resort shield episode')end
  if w.pending or w.dispatching or w.arrival_hold then return hold('awaiting exact native movement and arrival evidence settlement')end
  local hop=episode.path[episode.index]
  -- Advance only after native pending retirement AND a newly certified current room.
  if hop and tostring(s.room.id)==hop.to and fresh()then episode.index=episode.index+1;hop=episode.path[episode.index]end
  if not hop then
   if fresh()and solo()and empty()and(opt.endpoint_policy~='reviewed_ordinary_empty'or E.foot_node(c,w.graph,tostring(s.room.id)))then episode.terminal=true;owner.state.phase='arrived';owner.state.reason='fresh endpoint clear; safety not guaranteed; no automatic resume';return true,false,owner.state.reason end
   -- A follower invalidates that endpoint. Continue only to a DIFFERENT recent
   -- certified backedge within the ORIGINAL hop/deadline budget; never loop.
   local nextpath,destination
   if (pct<20 or pressure_ready())and fresh()and solo()and episode.hops<8 then nextpath,destination=plan(episode.avoid,8-episode.hops)end
   if not nextpath then return last_resort('endpoint unsafe or follower present; no remaining certified path; no protection claimed')end
   episode.path=nextpath;episode.index=1;episode.destination=destination;hop=nextpath[1]
  end
  if episode.hops>=8 then episode.terminal=true;return hold('bounded emergency hop budget exhausted; no protection claimed')end
  if pct>=20 and not pressure_ready()then episode.terminal=true;return hold('HP recovered to at least 20%; no additional emergency movement')end
  if not fresh()or not solo()then return hold('fresh current-room inspection and solo occupancy required')end
  if opt.require_shared_arbiter and not arb then return hold('complete shared survival authority unavailable')end
  local ready,reason=barriers();if not ready then return hold(reason)end
  if not safe(hop.to,clock())then episode.terminal=true;return hold('safe-path evidence expired')end
  selected=hop;in_service=true
  local ok,result,reason
  if arb then
   local accepted,cap=pcall(arb.reserve,c,'escape',{hp_ratio=tonumber(s.player.hp)/tonumber(s.player.maxhp),session=w.movement_session})
   if not accepted or cap~=false and type(cap)~='table'then
    in_service=false;selected=nil;return hold('escape reservation unknown; native commitments retained')
   end
   if cap==false then in_service=false;selected=nil;return hold('escape reservation declined; no movement issued')end
   lease=cap
   ok,result,reason=pcall(arb.transport,c,lease,'escape',io.move,owner,hop)
  else ok,result,reason=pcall(io.move,owner,hop)end
  in_service=false;selected=nil
  if not ok or result~=true then return hold(ok and (reason or 'native emergency dispatch refused')or 'native emergency dispatch raised; preserve commitments')end
  episode.hops=episode.hops+1;episode.avoid[hop.from]=true;episode.avoid[hop.to]=true
  owner.state.hops=episode.hops;owner.state.phase='moving';owner.state.reason='native emergency backedge issued; awaiting actual arrival'
  return true,true,owner.state.reason
 end
 function owner.diagnostics()
  -- Observational only: no service, expiry, clock creation, query or certificate renewal.
  local tm=walker.peek_movement_clock and walker.peek_movement_clock(s)
  local out={issued=certificate_issued,rejected_checks=certificate_rejected,certificates={},path={},cause=episode and episode.cause,terminal=episode and episode.terminal or false,raw_hp=s.player.hp,raw_maxhp=s.player.maxhp}
  local valid,scope_reason=scope();out.scope_current=valid==true;out.scope_reason=scope_reason
  local aff=s.player.afflictions or {};out.health_trust=(aff.recklessness or aff.blackout)and 'compromised; raw pools retained'or 'not independently verified'
  if certificate_last then out.last_check={};for k,v in pairs(certificate_last)do out.last_check[k]=v end end
  for id,r in pairs(records)do
   out.certificates[#out.certificates+1]={room=id,version=r.version,sequence=r.sequence,at=r.at,loyal=r.loyal,age=finite(tm)and tm-r.at or nil,eligible=scope()==true and safe(id,tm)or false}
  end
  table.sort(out.certificates,function(a,b)return a.room<b.room end)
  if pressure then out.pressure={hits=pressure.count,received_span=pressure.last-pressure.first,seen_age=finite(tm)and tm-pressure.last_seen or nil,seen_span=finite(tm)and tm-pressure.first_seen or nil,attacker=pressure.id,room=pressure.room,no_offense=pressure.offense==c.runner.last_send}end
  if episode then
   out.episode_age=finite(tm)and tm-episode.started or nil;out.destination=episode.destination
   for _,hop in ipairs(episode.path or {})do
    local r=records[hop.to];out.path[#out.path+1]={from=hop.from,to=hop.to,direction=hop.direction,certificate_age=r and finite(tm)and tm-r.at or nil,eligible=scope()==true and safe(hop.to,tm)or false}
   end
  end
  return out
 end
 local function grant(token,offer)
  if not opt.require_new_grant then return end
  if s.connected~=true or flag(s.player.dead)or not finite(tonumber(s.player.hp))or tonumber(s.player.hp)<=0 or not c.runner or c.runner.state~=s or c.runner.mode~='BASH'then return end
  if c.current~=s or c.walker~=walker or s.walker~=w or not w.active or w.enabled~=true or not whole(token)or token<=enrollment_offers or not offer or offer.token~=token or w.offers~=token or offer.graph~=w.graph or w.graph==enrollment_graph or c.mode~='BASH'or s.mode~='BASH'then return end
  workflow=fingerprint();records={};episode=nil;pressure=nil
  local r=pressure_receipt();pressure_floor=r and r.seq or 0
  certificate_issued=0;certificate_rejected=0;certificate_last=nil;owner.state.cause=nil
  attached_version=s.room.item_version or 0;attached_sequence=w.room_sequence or 0
  if opt.endpoint_policy=='reviewed_ordinary_empty'then endpoints,owner.state.endpoint_policy_reason=E.endpoint_policy(c,w.graph)end
  local n=0;for _ in pairs(endpoints)do n=n+1 end;owner.state.potential_endpoints=n
  owner.state.hops=0;owner.state.phase='collecting';owner.state.reason='NEW native grant; waiting for genuine post-grant EMPTY certificates'
 end
 return owner,authorize,grant,peek
end
return E
