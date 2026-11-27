-- Explicit new duty after UNLOCK; no action at load/attach. Never revives a checkpoint.
local M={}
local attached=setmetatable({},{__mode='k'})
local used=setmetatable({},{__mode='k'})
local function session(c) local s=c.current or {};return c.haven_session_token or c.session_generation or s.session_generation or s.session_id end
local function same(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
local function present(v)return v~=nil and v~=false end
local function occupied(v)return type(v)=='table' and next(v)~=nil or type(v)~='table' and present(v)end
local fields={'pending','waiting','dispatching','action_dispatching','actionDispatching','transportUnknown','transportCommit','transportBarrier','transport_unknown','physical_transport','transport_commit','unknown_commit','committed','transport_barrier','barrier','txn','purchase','deposit','resource_pending','eq_pending','movement_pending','arrival','arrival_hold','route','intent','follow_pending','follow_due','recall_due','follow_fault','query','physical_commit','movement_commit','drain_pending','ink_pending','pumping','route_pausing','capturing_checkpoint'}
local function barrier(name,o)
 if o==nil then return end
 if type(o)~='table' then return name..' malformed' end
 for _,k in ipairs(fields)do if present(o[k])then return name..'.'..k end end
 for _,k in ipairs({'transportBarriers','transport_barriers','todo','cancel'})do if type(o[k])~='function' and occupied(o[k])then return name..'.'..k end end
 if o.busy==true then return name..'.busy' end
end
local function solo(v)
 if v.players_known~=true or not same(v.players_room,v.room) or type(v.players)~='table' or not v.self_name then return false end
 for n in pairs(v.players)do if n~=v.self_name then return false end end
 return true
end
local function archive(c)
 if not c.release_lock or type(c.release_lock.archives)~='function' then return nil end
 local a=c.release_lock.archives();return a[#a]
end
local function preflight(c,probe)
 local t=c and c.restock_controller;local d=c and c.restock_data;local s=c and c.current
 if type(t)~='table' or type(d)~='table' or t.state~=d or type(s)~='table' or type(t.io)~='table' then return false,'owner unavailable' end
 local r=archive(c);local cp=r and r.checkpoint;local p=r and r.pending;local rec=r and r.receipt
 if not r or used[r] or r.owner~=d or r.controller~=t or r.fault~='bounded response exceeded' or r.query_quarantine~=r.fault or d.fault~=r.fault or d.recoverable~=true or d.phase~='idle' or d.enabled~=false or d.active~=false or d.busy~=false or (d.reserved~=false and not(probe and d.reserved==true)) or d.resume_consent~=false then return false,'no unused same-owner completed-readonly retirement' end
 if type(cp)~='table' or not cp.cancelled or r.checkpoint_revoked~=true or cp.lease~=d or d.checkpoint~=cp or d.checkpoint_revoked~=true or not same(r.return_room,cp.room) or cp.area==nil or cp.was_active~=true then return false,'cancelled hunting anchor unavailable' end
 if type(p)~='table' or p.command~='inventory' or (p.kind~='inventory_before' and p.kind~='inventory_after') or p.transport_ok~=true or not rec or rec.pending~=p or rec.owner~=d or rec.controller~=t or rec.serial~=p.serial or rec.invalid or rec.complete~=true or rec.prompt_seen~=true or session(c)==nil or rec.session~=session(c) then return false,'archive provenance/session mismatch' end
 -- This version only restarts the no-purchase failure, not a settled shopping transaction.
 if type(r.prior_state)~='table' or r.prior_state.purchase or r.prior_state.last_purchase or d.purchase or d.last_purchase then return false,'prior purchase requires separate review' end
 if c.mode~='OFF' or s.mode~='OFF' or (c.user_activity~=nil and not(probe and c.user_activity==d)) or d.owned_pause~=false or d.query_quarantine~=nil then return false,'requires already OFF, released idle owner' end
 if d.route_owner~=nil and (d.route_owner~=c.travel_owner or type(c.travel_owner)~='table' or c.travel_owner.phase~='idle')then return false,'foreign or active retained route metadata' end
 local roots={restock=d,controller=c,current=s,current_root=s.root,controller_root=c.root,runner=c.runner,runner_root=c.runner and c.runner.root,travel=c.travel,travel_root=c.travel and c.travel.root,travel_owner=c.travel_owner,walker=s.walker,buffs=s.buffs,mental=s.mental,containers=c.containers_data,supplies=c.supplies_data,tattoo=c.tattoo_owner,lunch=c.lunch_data,globe=c.elemental_recovery}
 for name,o in pairs(roots)do
  local why=barrier(name,o);if why then return false,why end
  if name~='restock' and o.fault then
   local terminal=name=='globe' and c.travel_module and c.travel_module.terminal_globe_exhaustion
   if not(type(terminal)=='function' and terminal(c)==true)then return false,name..'.fault' end
  end
 end
 local w=s.walker or {};local g=c.elemental_recovery or {}
 if w.active or w.offer or w.restock_checkpoint or w.fault or w.enabled~=true or g.armed or (g.phase and g.phase~='idle') then return false,'walker/GLOBE not settled and WALK-enabled' end
 if g.pool then local why=barrier('globe.pool',g.pool);if why then return false,why end end
 for k,v in pairs((c.supplies_data or {}).sources or {})do if type(v)~='table' or v.pending or v.frame then return false,'supplies source '..k end end
 if c.travel_owner and c.travel_owner.phase~='idle' then return false,'travel not idle' end
 if c.runner and c.runner.mode~='OFF' then return false,'runner not OFF' end
 if (s.mental or {}).needs_cease then return false,'mental cease unresolved' end
 return true,r
end
M.preflight=preflight -- pure: never calls native view/defense planner
local function safe(v,rec,proof)
 return v.connected==true and not v.dead and v.mode=='OFF' and v.ready==true and not v.blocked and (proof or v.empty and v.room_known) and v.room~=nil and v.area~=nil and not v.mounted and type(v.class)=='string' and v.class~='' and solo(v) and same(v.room,rec.room)
end
local probes=setmetatable({},{__mode='k'})
local proofs=setmetatable({},{__mode='k'})
function M.ready(c)
 local ok,r=preflight(c);if not ok then return false,r end
 local t=c.restock_controller;local v=t.io.view();local q=proofs[c]
 local proof=q and q.archive==r and q.session==session(c) and q.class==v.class and q.epoch==v.intent_epoch and same(v.room,q.room) and same(v.area,q.area) and c.current.room.items==q.items and c.current.room.item_version==q.version and t.io.now()-q.at<=10
 if not proof or not safe(v,r.receipt,proof)then return false,'fresh safe solo unmounted shop proof required' end
 if type(c.walker_boot)~='table' or type(c.walker_boot.offer)~='function' or type(c.walker_boot.answer)~='function' then return false,'fresh WALK consent API unavailable' end
 for _,k in ipairs({'health','ic:anabiotic'})do local st=t.io.stocks()[k];if not st or st.version==nil or st.pending then return false,'stock version unavailable' end end
 return true,r,v
end
local function hold(c,g,why)
 local d=c.restock_data;g.failed=why;d.active=false;d.resume_consent=false;d.fault=why;d.status='retry held: '..why
 -- Retain all outstanding query/resource/movement barriers and lease.
 return false,why
end
local function raw(c)
 local a=c.restock_retry_api or c.restock_api or _G
 return a.gmcp or _G.gmcp or {},a
end
local function accepted(c,q)
 local room=c.current.room;local gm=raw(c);local ri=(gm.Room or {}).Info;local payload=((gm.Char or {}).Items or {}).List
 if type(ri)~='table' or not same(ri.num or ri.id,q.room) or not same(room.id,q.room) or not same(room.area,q.area) then return end
 if not c.areas or type(c.areas.complete)~='function' or not c.areas.complete(payload) or type(room.item_version)~='number' or room.item_version<=q.version then return end
 local snap=(c.current.hunting or {}).area_snapshot
 if not snap or snap.items~=room.items or snap.version~=room.item_version or not same(snap.room,room.id) or not same(snap.area,room.area) then return end
 local n=0
 for _,it in ipairs(payload.items)do
  local actual=room.items[tostring(it.id)]
  if not actual or actual.name~=it.name or actual.attrib~=tostring(it.attrib or '') or actual.icon~=it.icon then return end
  if c.areas.navigation_blocked(c.current,actual) then return end
  n=n+1
 end
 local count=0;for _ in pairs(room.items)do count=count+1 end
 if count~=n then return end
 return room.items,room.item_version
end
local function release_probe(c,q,reason)
 if c.restock_retry_probe~=q then return false,reason end
 c.restock_retry_probe=nil;probes[c]=nil; q.finished=true;q.reason=reason;c.restock_retry_last_probe=q
 -- This query has no physical command or restock transaction. Drop only its own
 -- unissued reservation; never touch other roots, faults, pending or quarantine.
 local d=c.restock_data
 local unissued=d.phase=='idle' and d.busy==false and d.active==false and not barrier('restock',d)
 if unissued then
  if q.reserved and d.reserved==true then d.reserved=false end
  if c.user_activity==d then c.user_activity=nil end
 end
 return false,reason
end
function M.retry(c)
 if c.restock_retry_probe then return false,'retry inspection already pending' end
 if c.restock_retry_grant then return false,'existing retry duty metadata' end
 local base,r=preflight(c);if not base then return false,r end
 local ok,why,v=M.ready(c)
 if not ok then
  if why~='fresh safe solo unmounted shop proof required' then return false,why end
  v=c.restock_controller.io.view()
  if not safe(v,r.receipt,true)then return false,'current native readiness/occupancy unsafe' end
  local _,api=raw(c)
  if type(api.sendGMCP)~='function' then return false,'GMCP room query unavailable' end
  local d=c.restock_data;local t=c.restock_controller
  local q={archive=r,session=session(c),class=v.class,epoch=v.intent_epoch,room=v.room,area=v.area,version=c.current.room.item_version or 0,prompt=d.prompt,at=t.io.now(),reserved=true}
  c.restock_retry_probe=q;probes[c]=q;d.reserved=true;c.user_activity=d
  q.dispatching=true
  local good,result=pcall(api.sendGMCP,[[Char.Items.Room ""]]);q.gmcp_ok=good and result~=false
  if q.gmcp_ok then good,result=pcall(t.io.send,'look');q.look_ok=good and result~=false end
  q.dispatching=false
  if not q.gmcp_ok or not q.look_ok then return release_probe(c,q,'retry read-only inspection transport failed') end
  return true,'Fresh OFF shop inspection requested; refill starts only after accepted FULL and genuine later prompt'
 end
 local r=why
 local d=c.restock_data;local io=c.restock_controller.io
 local g={archive=r,session=session(c),class=v.class,epoch=v.intent_epoch,room=r.checkpoint.room,area=r.checkpoint.area,visited=r.checkpoint.visited,graph=r.checkpoint.graph,steps=r.checkpoint.steps,refresh=1,at=io.now(),shop=v.room,shop_area=v.area}
 used[r]=g;c.restock_retry_grant=g
 g.prior_route_metadata=d.route_owner
 if d.route_owner then g.prior_route_metadata_snapshot={};for k,value in pairs(d.route_owner)do g.prior_route_metadata_snapshot[k]=value end end
 d.route_owner=nil;proofs[c]=nil
 -- Old cp and its false resume consent remain in immutable archive; new grant owns no cp.
 for _,k in ipairs({'fault','checkpoint','checkpoint_revoked','checkpoint_restored','trip_at','drain_at','paused_at','haven_wait_at','return_ih','return_item_version','before','baseline_version','readback_version','candidates','candidate','item','last_readonly','destination','after_route','route_serial','route_destination','scope_unknown','spawn_owner','spawn_suppressed','globe_rearmed','initial_summon'})do d[k]=nil end
 d.enabled=true;d.active=true;d.busy=true;d.reserved=true;d.resume_consent=true;d.resume_globe=false;d.original_globe=false;d.haven_mode=false;d.haven_room=nil
 d.original_class=v.class;d.original_session=nil;d.intent_epoch=v.intent_epoch;d.return_room=g.room;d.return_area=g.area;d.origin_room=g.shop;d.origin_area=g.shop_area;d.stage_area=g.shop_area;d.departure_players=v.players;d.resume_master=false;d.owned_pause=true;d.recoverable=false;d.trip_at=g.at;d.index=1;d.kind='health';d.phase='baseline';d.candidate={room=g.shop};d.status='explicit retry: refreshing BOTH caches before fresh shop/wallet proof'
 c.user_activity=d
 return true,'New refill/return duty granted; prior checkpoint remains cancelled. Fresh WALK Yes required at anchor.'
end
function M.attach(c)
 local t=c and c.restock_controller;local mod=c and c.restock_module;local wb=c and c.walker_boot
 if not t or t.state~=c.restock_data or type(t.tick)~='function' or not mod or type(mod.command)~='function' or not wb or type(wb.answer)~='function' then return false,'retained owner slots unavailable' end
 if attached[c] then return true,'already attached' end
 if c.restock_retry_source or c.restock_retry_probe or c.restock_retry_grant then return false,'foreign/stale retry helper metadata' end
 -- Fresh Lua sessions have no recovery archive yet. Install the inert command
 -- now; retry() still requires a proven future UNLOCK archive before any action.
 if archive(c) then
  local pure,why=preflight(c);if not pure then return false,why end
 else
  local d=c.restock_data
  if d.pending or d.purchase or d.dispatching or d.busy or d.active or d.reserved or c.user_activity then return false,'fresh retry attachment requires idle owners' end
 end
 local tick,command,answer,prompt=t.tick,mod.command,wb.answer,t.prompt
 t.prompt=function(...)
  local result=prompt(...)
  local q=c.restock_retry_probe
  if q and probes[c]==q and not q.finished then
   local items,version=accepted(c,q)
   if items and c.restock_data.prompt>q.prompt then q.items=items;q.accepted_version=version;q.prompt_seen=true end
  end
  return result
 end
 t.tick=function(...)
  local q=c.restock_retry_probe;local d=c.restock_data
  if q then
   if probes[c]~=q then return false,'foreign retry probe metadata untouched' end
   if q.dispatching then return false end
   local ok,why=preflight(c,q)
   if not ok then return release_probe(c,q,'retry inspection revoked: '..tostring(why)) end
   local v=t.io.view()
   if session(c)~=q.session or v.class~=q.class or v.intent_epoch~=q.epoch or not same(v.room,q.room) or not same(v.area,q.area) or not safe(v,q.archive.receipt,true)then return release_probe(c,q,'retry inspection scope changed') end
   if t.io.now()-q.at>15 then return release_probe(c,q,'retry read-only inspection deadline exceeded') end
   local items,version=accepted(c,q)
   if q.gmcp_ok and q.look_ok and q.prompt_seen and items==q.items and version==q.accepted_version then
    release_probe(c,q,'fresh OFF shop proof complete')
    proofs[c]={archive=q.archive,session=q.session,class=q.class,epoch=q.epoch,room=q.room,area=q.area,items=items,version=version,at=t.io.now()}
    return M.retry(c)
   end
   return false
  end
  local g=c.restock_retry_grant
  if not g or g.finished or g.failed then return tick(...) end
  if session(c)~=g.session then return hold(c,g,'retry session changed; scope revoked') end
  local v=t.io.view()
  if v.class~=g.class or v.intent_epoch~=g.epoch then return hold(c,g,'retry operator/class intent changed') end
  if d.fault or not d.active or not d.resume_consent then g.failed=d.fault or 'retry revoked';return tick(...) end
  if g.refresh then
   if d.dispatching or d.pumping then return false end
   if not v.connected or v.dead or v.mode~='OFF' or not same(v.room,g.shop) or not same(v.area,g.shop_area) then return hold(c,g,'retry baseline scope changed') end
   if t.io.now()-g.at>120 then return hold(c,g,'retry baseline deadline exceeded') end
   local k=g.refresh==1 and 'health' or 'anabiotic';local sk=k=='health' and k or 'ic:anabiotic';local st=t.io.stocks()[sk]
   local p=d.pending
   if p then
    if p.kind~='baseline' or p.retry_grant~=g then return hold(c,g,'retry baseline owner mismatch') end
    if not p.transport_ok or d.prompt<=p.prompt or not st or st.pending or st.version==p.version then return false end
    d.pending=nil;g.refresh=g.refresh+1
    if g.refresh>2 then g.refresh=nil;d.kind='health';d.phase='wares';g.current_wares=true;return false end
    k='anabiotic';sk='ic:anabiotic';st=t.io.stocks()[sk]
   end
   if v.ready~=true or v.blocked or v.supplies_busy or not st or st.pending or st.version==nil then return false end
   d.kind=k;d.serial=d.serial+1
   p={kind='baseline',command=k,at=t.io.now(),serial=d.serial,prompt=d.prompt,room=v.room,lines=0,rows={},version=st.version,retry_grant=g}
   d.pending=p;d.dispatching=true;local good,result=pcall(t.io.query_stock,k);d.dispatching=false
   if not good or result==false then return hold(c,g,'retry baseline transport unknown') end
   p.transport_ok=true;return true
  end
  if g.current_wares and d.pending and d.pending.kind=='wares' and d.pending.complete then
   local p=d.pending
   if not p.bad and p.header and p.proprietor and p.divider and #p.rows>0 then table.sort(p.rows,function(a,b)return a.price<b.price end);d.candidate.price=p.rows[1].price end
   g.current_wares=nil
  end
  local a,b=tick(...)
  if not d.busy and not d.pending and not d.purchase and d.active and d.phase=='monitor' then
   g.finished=true;g.offer_epoch=(c.current.walker or {}).intent_epoch
   local good,why=wb.offer(c);g.offer=good and (c.current.walker or {}).offer or nil;g.offer_error=why
   d.status='fresh refill and exact return complete; WALK awaits fresh Yes'
  end
  return a,b
 end
 mod.command=function(root,action,...)
  if root==c and tostring(action):lower()=='retry' then return M.retry(c) end
  return command(root,action,...)
 end
 wb.answer=function(root,token,yes,...)
  local g=root==c and c.restock_retry_grant;local w=c.current.walker or {};local o=w.offer
  local seed=g and g.finished and not g.failed and g.offer==o and o and tonumber(token)==o.token and g.session==session(c) and same(c.current.room.id,g.room) and same(c.current.room.area,g.area) and w.intent_epoch==g.offer_epoch
  local ok,why=answer(root,token,yes,...)
  if seed and ok and yes==true and w.active and type(g.visited)=='table' then
   -- Historical visits influence routing only, never inspection or clearance.
   for id,val in pairs(g.visited)do if val==true and w.graph.nodes[tostring(id)] then w.visited[tostring(id)]=true end end
   w.steps=g.steps or 0;w.clear=nil;w.inspection=nil;w.reinspect=true;g.seeded=true
  end
  return ok,why
 end
 attached[c]={tick=tick,command=command,answer=answer}
 return true,'explicit retry installed inertly; no commands or state reconstruction'
end
return M
