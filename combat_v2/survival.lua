-- Shared survival lease authority. No recipes, timers, native keyboard or FIRSTAID hook.
-- Native/cold binders must supply actual verified incoming IO edges, never a ready flag.
local M={}
local owners=setmetatable({},{__mode='k'})
local guard_originals=setmetatable({},{__mode='k'})
function M.unwrap_owned_guard(fn)
 local seen={};while guard_originals[fn]and not seen[fn]do seen[fn]=true;fn=guard_originals[fn]end;return fn
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function flag(v)return v==true or v==1 or v=='1'end
local function present(v)return v~=nil and v~=false end
local function read(node)
 if node.edge=='field'then return rawget(node.parent,node.key)end
 if node.edge=='upvalue'then local name,value=debug.getupvalue(node.parent,node.key);if name~=node.name then return nil end;return value end
end
local function write(node,value)
 if node.edge=='field'then rawset(node.parent,node.key,value)
 else assert(debug.setupvalue(node.parent,node.key,value)==node.name,'IO upvalue publication failed')end
end
local function firstaid(command)
 return type(command)=='string'and(command:lower()=='firstaid'or command:lower():match('^firstaid [%w_ %-]+$')~=nil)
end
local flags={'pending','waiting','fault','dispatching','action_dispatching','actionDispatching','transport_unknown','transportUnknown','transport_commit','transportCommit','transport_barrier','transportBarrier','committed','physical_commit','physical_transport','physical_dispatch','movement_commit','movement_pending','transport_pending','arrival_hold','arrival','eq_pending','txn','purchase','deposit','resource_pending','reserved','owned_pause','checkpoint','restock_checkpoint','route','intent','follow_pending','follow_fault','query','quarantine','query_quarantine','reserving','drain_pending','ink_pending','listing','native_listing','ability_listing','capturing_checkpoint','barrier','action_pending','haven_refresh'}
local maps={'transport_barriers','transportBarriers','native_pending'}
local function collision(o,skip)
 if type(o)~='table'then return 'malformed owner'end
 for _,k in ipairs(flags)do if present(o[k])and not(skip and skip[k])then return k end end
 for _,k in ipairs(maps)do
  local v=o[k]
  if type(v)=='table'then for name,value in pairs(v)do
   if not(k=='transport_barriers'and name=='cv2_earthcaller_resources'and skip and skip.earth_resource==value)then return k end
  end elseif present(v)then return k end
 end
 if o.busy==true or o.pumping==true then return 'busy/pumping'end
end
local function roots(c)
 local s=c.current;local r=c.runner
 local result={earth_defense=s.earth_defense_pending,controller=c,current=s,current_root=s.root,controller_root=c.root,runner=r,runner_root=r.root,walker=s.walker,buffs=s.buffs,mental=s.mental,defense=s.defense,travel=c.travel_owner,travel_controller=c.travel,travel_root=c.travel and c.travel.root,tattoo=c.tattoo_owner,containers=c.containers_data,globe=c.elemental_recovery,restock=c.restock_data,restock_state=c.restock_controller and c.restock_controller.state,lunch=c.lunch_duty,lunch_state=c.lunch_controller and c.lunch_controller.state,tour=c.tour and c.tour.state,supplies=c.supplies_data}
 local extra={}
 for name,o in pairs(result)do if type(o)=='table'then
  for _,field in ipairs({'root','state'})do local nested=rawget(o,field);if not(name=='controller'and field=='state')and type(nested)=='table'and nested~=o then extra[name..'.'..field]=nested end end
 end end
 for name,o in pairs(extra)do result[name]=o end
 return result
end
local function ready_channels(p)
 for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if not flag(p[k])then return false end end;return true
end
local numb_hinders={'blackout','sensitivity','prone','fallen','paralysis','paresis','asleep','unconscious','unconsciousness','stun','stunned','frozen','webbed','bound','transfixed','impaled','impalement','entangled','roped','left_arm_crippled','right_arm_crippled','left_arm_broken','right_arm_broken','left_arm_mangled','right_arm_mangled'}
local shift_hinders={'prone','fallen','paralysis','paresis','asleep','unconscious','unconsciousness','stun','stunned','frozen','webbed','bound','transfixed','impaled','impalement','entangled','roped'}
local function numkey(v)return tostring(v or ''):lower():gsub('[ %-]+','_')end
local function readonly_ok(fn,...)
 if type(fn)~='function'then return false end;local ok,value=pcall(fn,...);return ok and value==true
end
local function ratio(c)
 local p=c.current.player;local hp,max=tonumber(p.hp),tonumber(p.maxhp)
 if not finite(hp)or not finite(max)or hp<=0 or max<=0 or hp>max then return nil end
 return hp/max
end
function M.is_current(c,api)local x=owners[c];return x~=nil and x.api==api and c.survival_arbiter==api end
-- Definition-only initial cold reload preflight. No planner/readiness/IO calls.
function M.preflight_initial(c,classifiers)
 if c==nil or c.current==nil then return true end
 if type(c.current)~='table'or type(c.runner)~='table'then return false,'malformed retained core'end
 local ok,all=pcall(roots,c);if not ok then return false,'malformed retained owner roots'end
 classifiers=classifiers or {}
 local passive=type(classifiers.passive_restock)=='function'and classifiers.passive_restock(c)==true
 local terminal=type(classifiers.terminal_globe)=='function'and classifiers.terminal_globe(c)==true
 local readonly=type(classifiers.readonly_supplies)=='function'and classifiers.readonly_supplies(c)==true
 for name,o in pairs(all)do
  local skip
  if o==c.restock_data and passive then skip={fault=true}end
  if o==c.elemental_recovery and terminal then skip={fault=true}end
  if o==c.supplies_data and readonly then skip={pending=true}end
  if o==c.current.defense and o.low_health==true then skip={waiting=true}end
  local why=collision(o,skip);if why then return false,name..':'..why end
 end
 return true
end
-- Same-process source upgrade after the retained authority issued its settled
-- reload token. Transfer ONLY the private weak ownership/guard registries; never
-- clear an action, copy readiness, or adopt a foreign public arbiter.
function M.upgrade(previous,c,token)
 if previous==nil then return c.survival_arbiter==nil,'cold startup' end
 if type(previous)~='table'or c.survival_module~=previous or type(previous.is_current)~='function'then return false,'canonical previous survival module required'end
 local function capture(fn,key)
  if type(fn)~='function'then return nil end
  for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name==key then return value end end
 end
 local oldowners=capture(previous.bind,'owners')
 local oldguards=capture(previous.unwrap_owned_guard,'guard_originals')
 local x=type(oldowners)=='table'and oldowners[c]
 -- An earlier unavailable native binder never owned an arbiter or IO guards.
 if type(oldowners)=='table'and type(oldguards)=='table'and not x and c.survival_arbiter==nil and token==nil then return true,'previous source never bound'end
 if not token or not previous.is_current(c,c.survival_arbiter)then return false,'owned settled reload token required'end
 if type(oldguards)~='table'or not x or x.api~=c.survival_arbiter or x.c~=c or x.s~=c.current or x.r~=c.runner
  or x.reload_token~=token or x.active or x.fault or x.binding or x.retired then return false,'retained survival transfer identity/token refused'end
 -- The retained producer itself must still identify these exact registries.
 if capture(previous.is_current,'owners')~=oldowners then return false,'retained authority registry mismatch'end
 owners=oldowners;guard_originals=oldguards
 return true,'private settled authority transferred; no commitments cleared'
end
function M.bind(c,binding)
 if type(c)~='table'or type(c.current)~='table'or type(c.runner)~='table'or c.runner.state~=c.current then return nil,'canonical state/runner required'end
 local previous=owners[c]
 if previous and(previous.active or not previous.reload_token or not binding or binding.reload_token~=previous.reload_token)then return nil,'existing shared authority: explicit settled reload required'end
 if c.survival_arbiter and(not previous or c.survival_arbiter~=previous.api)then return nil,'foreign survival authority refused'end
 if type(binding)~='table'or type(binding.nodes)~='table'or type(binding.classifiers)~='table'or type(binding.classifiers.passive_restock)~='function'or type(binding.classifiers.terminal_globe)~='function'then return nil,'actual IO bindings and strict pure classifiers required'end
 local x={c=c,s=c.current,r=c.runner,w=c.walker,boot=c.walker_boot,defense=c.defense,n=c.emergency_numb,nodes={},groups={},raw_wrappers={},captured_roots=roots(c),binding=true}
 if type(x.w)~='table'or type(x.boot)~='table'then return nil,'canonical walker/boot required'end
 x.escape_fn=x.w.emergency_candidate
 x.observer_fn=x.n and(x.n.observer_check or c.emergency_observer_check)
 -- Admission only: the retained canonical runner still validates/commits every action.
 -- Do not mint native contracts, substitute a selector or adopt a later router.
 local router=c.class_router;local runner_module=c.runner_module
 local adapter_modules=type(router)=='table'and router.modules
 local approved={}
 for _,class in ipairs({'Wayfarer','Earthcaller','Infiltrator','Archivist','Shapeshifter'})do
  local module=type(adapter_modules)=='table'and adapter_modules[class]
  if type(module)=='table'and module==c[class:lower()]then approved[class]=module end
 end
 local router_functions={}
 for _,key in ipairs({'supported','choose','validate','commit'})do router_functions[key]=type(router)=='table'and router[key]end
 local function canonical_adapter(r)
  local class=x.s.player.class
  if r~=x.r or not approved[class]or c.class_router~=router or x.r.class_router~=router or x.r.monk~=router
   or c.runner_module~=runner_module or not runner_module or runner_module.class_router~=router or router.modules~=adapter_modules
   or adapter_modules[class]~=approved[class]or c[class:lower()]~=approved[class]then return false end
  for key,fn in pairs(router_functions)do if type(fn)~='function'or router[key]~=fn then return false end end
  return type(router_functions.supported)=='function'and router_functions.supported(class)==true
 end
 local api={schema='survival-v1',owner=c};x.api=api
 local expected_api={};local groups_by_original={}
 local required={runner=true,walker=true,defense=c.defense and c.defense.numb_service~=nil,mental=c.mental~=nil,buffs=c.buffs~=nil,travel=c.travel~=nil,convenience=c.convenience~=nil,containers=c.containers~=nil,elementals=c.elementals~=nil,tattoo=c.tattoo_module~=nil,restock=c.restock_controller~=nil,lunch=c.lunch_controller~=nil,tour=c.tour~=nil,supplies=c.supplies~=nil}
 local covered={}
 for _,node in ipairs(binding.nodes)do
  if type(node)~='table'or(node.edge~='field'and node.edge~='upvalue')or(node.mode~='raw'and node.mode~='entry')or type(node.original)~='function'then return nil,'malformed verified IO edge'end
  if node.parent==_G then return nil,'native keyboard/global IO must never be wrapped'end
  if node.edge=='field'and type(node.parent)~='table'or node.edge=='upvalue'and(type(node.parent)~='function'or type(node.key)~='number'or type(node.name)~='string')then return nil,'malformed IO location'end
  local value=read(node)
  if value~=node.original and not(value==nil and node.fallback==true and node.edge=='field'and(node.parent==c or node.parent==c.runner)and node.original==send)then return nil,'actual IO edge mismatch: '..tostring(node.label)end
  local key=node.mode..':'..tostring(node.result or 'bool')..':'..tostring(node.direct_firstaid==true)
  groups_by_original[node.original]=groups_by_original[node.original]or{}
  for other in pairs(groups_by_original[node.original])do if other~=key then return nil,'one retained function has conflicting guard contracts'end end
  local group=groups_by_original[node.original][key]
  if not group then group={original=M.unwrap_owned_guard(node.original),mode=node.mode,result=node.result,direct_firstaid=node.direct_firstaid==true,roles={}};groups_by_original[node.original][key]=group;x.groups[#x.groups+1]=group end
  for _,role in ipairs(node.roles or {})do covered[role]=true;group.roles[role]=true end
  x.nodes[#x.nodes+1]={location=node,group=group,expected=value}
 end
 for name,needed in pairs(required)do if needed and not covered[name]then return nil,'incomplete actual IO census: '..name end end
 if (type(registerAnonymousEventHandler)=='function'or c.handlers and next(c.handlers))and type(binding.continuity)~='function'then return nil,'actual native callback/trigger continuity proof required'end
 local function identity()
  if c.current~=x.s or c.runner~=x.r or c.runner.state~=x.s or c.walker~=x.w or c.walker_boot~=x.boot or c.defense~=x.defense or c.emergency_numb~=x.n or c.survival_arbiter~=api then return false,'canonical survival owner changed'end
  if x.w.emergency_candidate~=x.escape_fn or x.n and(x.n.observer_check or c.emergency_observer_check)~=x.observer_fn then return false,'survival eligibility/observer provider identity changed'end
  for _,row in ipairs(binding.namespaces or {})do if rawget(row.owner,row.key)~=row.value then return false,'automated owner namespace changed: '..row.key end end
  for key,fn in pairs(expected_api)do if api[key]~=fn then return false,'shared API identity changed: '..key end end
  if x.binding or x.fault or x.retired or x.reload_token then return false,x.fault or 'IO binding incomplete/retired/reloading'end
  for _,node in ipairs(x.nodes)do if read(node.location)~=node.group.guard then return false,'retained IO fence changed: '..tostring(node.location.label)end end
  if binding.continuity and not readonly_ok(binding.continuity,c)then return false,'native callback/IO continuity lost'end
  return true
 end
 local function own_record(lease,kind)
  local a=x.active;return a and lease~=nil and lease==a.lease and(kind==nil or a.kind==kind)and a or nil
 end
 local function census(kind,lease,prospective)
  local ok,why=identity();if not ok then return false,why end
  local own=own_record(lease,kind)
  if x.active and not own then return false,'another survival action owns physical IO'end
  if x.foreign_dispatch then return false,'automated physical producer still dispatching'end
  local n=x.n;local pending=n and n.pending
  if n and(n.owner~=c or n.runner~=x.r or n.fault)then return false,'emergency defense owner/fault changed'end
  if pending and not(own and own.pending==pending or prospective and prospective==pending and pending.lease==nil and not pending.started and pending.transport_ok==nil and not pending.ack and pending.dispatching==true and pending.kind==kind and pending.session==n.session)then return false,'foreign emergency pending'end
  local all=roots(c);for name,o in pairs(x.captured_roots)do all['retained:'..name]=o end
  for name,o in pairs(binding.retained_roots or {})do all['captured:'..name]=o end
  local passive=readonly_ok(binding.classifiers.passive_restock,c);local terminal=readonly_ok(binding.classifiers.terminal_globe,c)
  for name,o in pairs(all)do
   local skip={}
   if own and(own.kind=='ribcage'or own.kind=='reinforce')and x.s.transport_barriers and router.owns_resource_barrier(x.s,own.pending,x.s.transport_barriers.cv2_earthcaller_resources)then skip.earth_resource=x.s.transport_barriers.cv2_earthcaller_resources end
   if o==c.restock_data and passive then skip.fault=true end
   if o==c.supplies_data and readonly_ok(binding.classifiers.readonly_supplies,c)then skip.pending=true end
   if o==c.elemental_recovery and terminal then skip.fault=true;skip.pending=true end
   if own and(own.kind=='ribcage'or own.kind=='reinforce')and o==own.pending then skip.committed=true end
   if own and own.kind=='escape'and o==x.s.walker then
    if o.pending and o.pending==own.pending then skip.pending=true end
    if o.dispatching and o.dispatching==own.pending then skip.dispatching=true end
    if own.pending and not o.pending and tostring(x.s.room.id)==own.pending.to then skip.arrival_hold=true end
   end
   local fault=collision(o,skip);if fault then return false,name..'.'..fault end
  end
  if c.elemental_recovery and c.elemental_recovery.armed then return false,'GLOBE armed'end
  if c.user_activity then return false,'resource activity lease'end
  local q=(x.s.hunting or {}).ih;if q and q.active and q.pending then return false,'native IH query pending'end
  return true
 end
 local function observer()
  local n=x.n;if not n or not n.observers_ready then return false end
  local fn=n.observer_check or c.emergency_observer_check
  return readonly_ok(fn,c,n)
 end
 local function defense_eligible(kind,own)
  local n=x.n;local s=x.s;local p=s.player
  if not n or n.owner~=c or n.runner~=x.r or not n.live or n.fault or n.pending and n.pending~=own or not observer()then return false end
  if c.mode~='BASH'or s.mode~='BASH'or x.r.mode~='BASH'or s.connected~=true or p.dead or s.training_battle_ended or(s.config or {}).defense_enabled==false then return false end
  if type(getConnectionInfo)~='function'then return false end
  local connected,_,_,tcp=pcall(getConnectionInfo);if not connected or tcp~=true then return false end
  local t=(binding.now or getEpoch or os.clock)();local hp=ratio(c)
  if not finite(t)or not hp or not finite(n.hp_at)or t<n.hp_at or t-n.hp_at>2 or p.hp~=n.hp or p.maxhp~=n.maxhp or not n.affs_known or type(p.afflictions)~='table'or p.prone then return false end
  if not ready_channels(p)then return false end
  for _,key in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if n.balances[key]~=true then return false end end
  for _,key in ipairs(kind=='numb'and numb_hinders or shift_hinders)do if p.afflictions[key]then return false end end
  if kind=='numb'then return hp<.30 and n.optin==true and n.class=='monk'and numkey(p.class)=='monk'and n.known==true and n.known_session==n.session and n.active==false and n.defs_session==n.session and finite(n.cooldown_until)and t>=n.cooldown_until end
  local protocol=n.shift_protocol
  return hp<=.25 and n.shift_optin==true and n.race=='azudim'and n.shift_known==true and n.racial_known==true and n.shift_known_session==n.session
   and finite(n.mana)and n.mana>n.hp and p.mana==n.mana and finite(n.mana_at)and t>=n.mana_at and t-n.mana_at<=2
   and type(protocol)=='table'and protocol.schema=='shift-observed-v1'and protocol.owner==c and protocol.session==n.session and protocol.source=='native SHIFT activation/rejection/cooldown observations'
   and readonly_ok(protocol.ready,c,own)
 end
 local function escape_candidate()
  if type(x.escape_fn)~='function'then return false end
  local ok,eligible,meta=pcall(x.escape_fn,c,c.bash_emergency)
  return ok and eligible==true and type(meta)=='table',meta
 end
 local function reinforce_eligible(own)
  local s=x.s;local n=x.n;local cfg=s.config or {};local hp=ratio(c)
  local threshold=cfg.earthcaller_reinforce_health or 50
  if not finite(threshold)or threshold<=20 or threshold>100 then return false end
  if cfg.earthcaller_reinforce_enabled==false or cfg.defense_enabled==false or c.mode~='BASH'or s.mode~='BASH'or x.r.mode~='BASH'
   or s.player.class~='Earthcaller'or s.connected~=true or s.player.dead or s.training_battle_ended or not hp or hp<.20 or hp>=threshold/100 then return false end
  if not n or n.fault or not observer()or not n.live or not n.affs_known or n.affs_session~=n.session then return false end
  local t=(binding.now or getEpoch or os.clock)()
  if not finite(t)or not finite(n.hp_at)or t<n.hp_at or t-n.hp_at>2 or s.player.hp~=n.hp or s.player.maxhp~=n.maxhp then return false end
  if type(getConnectionInfo)~='function'then return false end
  local ok,_,_,tcp=pcall(getConnectionInfo);if not ok or tcp~=true then return false end
  local ready,meta=escape_candidate();if ready and meta.cause=='incoming-stall'then return false end
  if own then return own==s.earth_defense_pending and not own.invalidated and not own.fault and router.earth_contract(s,'reinforce')~=nil end
  return type(router.reinforce_ready)=='function'and router.reinforce_ready(s)==true
 end
 local function choose(kind,hp,lease,prospective)
  local actual=ratio(c);if not actual or not finite(hp)or hp~=actual then return nil,'fresh canonical ratio mismatch'end
  local clear,why=census(kind,lease,prospective);if not clear then return nil,why end
  local record=own_record(lease,kind)
  if record then
   if kind=='reinforce'then return reinforce_eligible(record.pending)and 'reinforce'or nil end
   if kind=='escape'then local ready,meta=escape_candidate();return ready and meta.kind~='ribcage'and 'escape'or nil end
   if kind=='ribcage'then local ready,meta=escape_candidate();return ready and meta.kind=='ribcage'and x.s.player.class=='Earthcaller'and 'ribcage'or nil end
   return defense_eligible(kind,record.pending)and kind or nil
  end
  -- The captured canonical private escape provider may certify a separate
  -- NEW-grant incoming-pressure episode. Never infer a numeric HP crossing.
  local ready,meta=escape_candidate()
  if ready and meta.kind~='ribcage'and(actual<.20 or meta.cause=='incoming-stall')then return 'escape'end
  if reinforce_eligible()then return 'reinforce'end
  if defense_eligible('shift',prospective)then return 'shift'end
  if defense_eligible('numb',prospective)then return 'numb'end
  if ready and meta.kind=='ribcage'and(actual<.20 or meta.cause=='incoming-stall')
   and observer()and x.n.affs_known==true and x.n.affs_session==x.n.session
   and (x.s.config or {}).defense_enabled~=false and x.s.player.class=='Earthcaller'and router==c.class_router and type(router.ribcage_ready)=='function'and router.ribcage_ready(x.s)==true then return 'ribcage'end
  return nil,'no genuinely eligible survival action'
 end
 function api.clear(controller,kind,lease)if controller~=c then return false,'foreign controller'end;return census(kind,lease)end
 function api.choose(controller,kind,hp,lease)if controller~=c then return nil end;return choose(kind,hp,lease)end
 function api.owns(controller,lease)return controller==c and own_record(lease)~=nil end
 function api.reserve(controller,kind,args)
  if controller~=c or x.active or type(args)~='table'or(kind~='numb'and kind~='shift'and kind~='escape'and kind~='ribcage'and kind~='reinforce')then return false end
  local pending=x.n and x.n.pending
  if kind=='reinforce'then pending=x.reinforce_prospective;if not pending or pending.owner~=x.defense then return false end end
  if kind=='ribcage'then pending=x.ribcage_prospective;if not pending or pending.owner~=c.bash_emergency then return false end end
  if kind~='escape'and kind~='ribcage'and kind~='reinforce'and(not pending or pending.kind~=kind or pending.lease~=nil or pending.dispatching~=true)then return false end
  local choice=choose(kind,args.hp_ratio,nil,kind~='escape'and pending or nil);if choice~=kind then return false end
  local meta
  if kind=='escape'or kind=='ribcage'then local ready;ready,meta=escape_candidate();if not ready or args.session~=meta.session or(kind=='ribcage')~=(meta.kind=='ribcage')then return false end
  elseif args.session~=x.n.session then return false end
  local lease={};local a={lease=lease,kind=kind,pending=kind~='escape'and pending or nil,session=args.session,meta=meta,issued=false,finalized=false}
  x.active=a -- Atomic fencing point: no callbacks/IO/public writes after this assignment.
  return lease
 end
 local function command_allowed(a,command)
  if a.kind=='reinforce'then return command=='DIRGE REINFORCE'and not a.issued and reinforce_eligible(a.pending)end
  if a.kind=='ribcage'then
   local p=a.pending
   return c.mode=='BASH'and x.s.mode=='BASH'and x.r.mode=='BASH'and x.s.player.class=='Earthcaller'
    and p==x.s.earth_defense_pending and not p.invalidated and not p.fault and
    (command=='OSSO RIBCAGE'and not a.issued or command=='OSSO COUNT'and a.issued and p.query_dispatching==true and not p.query_issued and router.ribcage_ack(x.s,p))
  end
  if a.kind=='numb'or a.kind=='shift'then return command==a.kind:upper()and a.pending==x.n.pending and a.pending.started==true and a.pending.dispatching==true end
  local p=x.s.walker.pending;local hop=a.meta and a.meta.hop
  if not p or not hop then return false end
  local graph=x.s.walker.graph
  local typed=hop.kind=='swim'and hop.special==true and graph and graph.special_edges and graph.special_edges[hop.from]and graph.special_edges[hop.from][hop.direction]==hop
  if x.s.walker.dispatching~=p or p.from~=hop.from or p.to~=hop.to or p.command~=command or command~=(typed and hop.command or hop.direction)or p.session~=a.session then return false end
  if a.pending and a.pending~=p then return false end
  a.pending=p;return true
 end
 for _,g in ipairs(x.groups)do
  local group=g
  group.guard=function(...)
   local command=select(1,...)
   if x.retired or x.reload_token then return false,'retired/reloading automated IO owner'end
   if group.mode=='raw'and group.direct_firstaid and firstaid(command)then return group.original(...)end
   local a=x.active
   if x.binding or x.fault then return false,'shared survival IO held'end
   local intact,why=identity();if not intact then return false,why end
   if group.mode=='entry'and group.roles.runner and numkey(x.s.player.class)~='monk'and not canonical_adapter(select(1,...))then return false,'current class has no approved offense adapter'end
   if a then
    if group.mode=='entry'then if group.result=='busy'then return {busy=true,status='shared survival lease owns physical IO'}elseif group.result=='list'then return {}end;return false,'shared survival lease owns physical IO'end
    if a.kind=='escape'and not group.roles.walker or a.kind~='escape'and not group.roles.defense then return false,'foreign automated emit role'end
    local query=a.kind=='ribcage'and command=='OSSO COUNT'
    if not a.scope or a.issued and not query or not command_allowed(a,command)then return false,'conflicting survival IO fenced'end
    local clear,reason=census(a.kind,a.lease);if not clear then return false,reason end
    if query then a.pending.query_issued=true end
    a.issued=true;a.dispatching=true
    local ok,result=pcall(group.original,...);a.dispatching=false;a.finalized=true;a.transport_ok=ok and result~=false
    if not ok then error(result)end;return result
   end
   if command=='NUMB'or command=='SHIFT'or command=='OSSO RIBCAGE'or command=='DIRGE REINFORCE'then return false,'emergency recipe requires an actual owned survival lease'end
   x.foreign_dispatch=(x.foreign_dispatch or 0)+1
   local ok,one,two,three=pcall(group.original,...)
   x.foreign_dispatch=x.foreign_dispatch-1;if x.foreign_dispatch==0 then x.foreign_dispatch=nil end
   if not ok then error(one)end;return one,two,three
  end
  if group.mode=='raw'then x.raw_wrappers[group.guard]=group end
  guard_originals[group.guard]=group.original
 end
 function api.transport(controller,lease,kind,sender,...)
  local a=controller==c and own_record(lease,kind)
  if not a or a.scope or a.issued or type(sender)~='function'then return false,'invalid survival transport capability'end
  local clear,why=census(kind,lease);if not clear then return false,why end
  if kind=='escape'then if sender~=a.meta.transport then return false,'foreign escape continuation'end
  else
   local found=x.raw_wrappers[sender]
   if not found then for _,group in ipairs(x.groups)do if group.mode=='raw'and group.original==sender and group.roles.defense then found=group;sender=group.guard;break end end end
   if not found or not found.roles.defense then return false,'existing defense sender identity unproved'end
  end
  a.scope=true
  local ok,one,two=pcall(sender,...);a.scope=false
  if not ok then error(one)end;return one,two
 end
 -- Existing emergency episode is the ONLY producer. No new timer or HP policy.
 function api.ribcage(controller,owner)
  if controller~=c or owner~=c.bash_emergency or router~=c.class_router or type(router.reserve_ribcage)~='function'then return false,'foreign last-resort owner'end
  local a=x.active
  if a then
   if a.kind~='ribcage'or a.pending.owner~=owner then return false,'another survival action owns IO'end
   if api.settle(c)then return true,'Ribcage shield/debit/channel settled; no automatic resume'end
   local p=a.pending
   local ready,meta=escape_candidate()
   if not p.query_issued and a.transport_ok and ready and meta.kind=='ribcage'and router.ribcage_ack(x.s,p)then
    local clear,why=census('ribcage',a.lease);if not clear then return false,why end
    p.query_dispatching=true;a.scope=true
    local ok,result=pcall(c.defense_sender,'OSSO COUNT')
    a.scope=false;p.query_dispatching=nil
    if not ok or result==false then p.fault='Ribcage COUNT transport unknown'end
   end
   return false,'Ribcage committed; awaiting exact shield/debit/recovery/later prompt'
  end
  local ready,meta=escape_candidate()
  if not ready or meta.kind~='ribcage'then return false,'no private last-resort episode'end
  local p={owner=owner,committed=true,session=meta.session}
  x.ribcage_prospective=p
  local cap=api.reserve(c,'ribcage',{hp_ratio=ratio(c),session=meta.session})
  x.ribcage_prospective=nil
  if not cap then return false,'last-resort reservation declined'end
  a=x.active
  if not router.reserve_ribcage(x.s,p)then x.active=nil;return false,'Ribcage resource reservation declined'end
  x.s.earth_defense_pending=p
  local ok,result=pcall(api.transport,c,cap,'ribcage',c.defense_sender,'OSSO RIBCAGE')
  p.transport_ok=ok and result~=false
  if not p.transport_ok then p.fault='Ribcage transport unknown; commitment retained'end
  return p.transport_ok,p.transport_ok and 'Ribcage issued once; awaiting native settlement'or p.fault
 end
 -- Called by the existing defense service only; no new callback or timer.
 function api.reinforce(controller)
  if controller~=c then return false,'foreign controller'end
  local a=x.active
  if a then
   if a.kind~='reinforce'then return false,'another survival owner'end
   if api.settle(c)then return true,'Reinforce settled'end
   return true,'Reinforce committed; awaiting own heal/debits/EQ/later prompt'
  end
  if not reinforce_eligible()then return false,'Reinforce not eligible'end
  local p={owner=x.defense,committed=true,session=x.n.session,kind='reinforce'}
  x.reinforce_prospective=p
  local lease=api.reserve(c,'reinforce',{hp_ratio=ratio(c),session=p.session})
  x.reinforce_prospective=nil
  if not lease then return false,'Reinforce lease declined'end
  if not router.reserve_reinforce(x.s,p)then x.active=nil;return false,'Reinforce resource reservation declined'end
  p.lease=lease;x.s.earth_defense_pending=p
  local ok,result=pcall(api.transport,c,lease,'reinforce',c.defense_sender,'DIRGE REINFORCE')
  p.transport_ok=ok and result~=false
  if not p.transport_ok then p.fault='Reinforce transport failed/unknown; commitment retained'end
  return true,p.fault or 'Reinforce issued once; awaiting native settlement'
 end
 function api.release(controller,lease)
  local a=controller==c and own_record(lease)
  if not a or a.scope or a.dispatching then return false end
  local ok=census(a.kind,lease);if not ok then return false end
  local p=a.pending
  if not a.issued then
   if a.kind~='escape'or x.s.walker.pending or x.s.walker.dispatching then return false end
  elseif not a.finalized or not a.transport_ok or not p or p.transport_ok~=true then return false
  elseif a.kind=='ribcage'or a.kind=='reinforce'then
   if x.s.earth_defense_pending~=p or p.fault or not router.earth_retire(x.s,p)then return false end
   x.s.earth_defense_pending=nil
  elseif a.kind=='escape'then
   local w=x.s.walker;local r=x.s.room;local i=w.inspection
   if w.pending or w.dispatching or w.arrival_hold or w.fault or p.session~=a.session or tostring(r.id)~=p.to or r.area~=p.area or not i or i.room~=tostring(r.id)or i.area~=r.area or i.items~=r.items or i.version~=r.item_version or i.sequence~=(w.room_sequence or 0)then return false end
  else
   local n=x.n;local recovered=false
   for key in pairs(p.lost or {})do if(p.recovered or {})[key]then recovered=true end end
   if n.pending~=p or n.fault or n.session~=a.session or p.invalidated or not p.started or not p.ack or not p.prompt_after_ack or not recovered or not ready_channels(x.s.player)then return false end
  end
  x.active=nil;return true
 end
 function api.settle(controller)
  if controller~=c then return false end;local a=x.active
  if a and(a.kind=='escape'or a.kind=='ribcage'or a.kind=='reinforce')then return api.release(c,a.lease)end
  return false
 end
 function api.busy(controller)return controller~=c or x.active~=nil or x.fault~=nil or x.binding end
 function api.status(controller)
  if controller~=c then return {held=true,reason='foreign controller'}end
  local intact,why=identity();return {held=x.active~=nil or not intact,kind=x.active and x.active.kind,issued=x.active and x.active.issued,reason=x.fault or why or 'idle'}
 end
 function api.prepare_reload(controller)
  if controller~=c or x.active or x.fault or x.binding or c.mode~='OFF'or x.s.mode~='OFF'or x.r.mode~='OFF'or x.s.walker.active or x.s.walker.offer then return false,'settled OFF survival reload required'end
  local clear,why=census('reload');if not clear then return false,why end
  x.reload_token={};return x.reload_token
 end
 for key,value in pairs(api)do if type(value)=='function'then expected_api[key]=value end end
 -- Validate every old edge before the first mutation. Publication failures latch;
 -- no controller, real commitment, native global or diagnostic is ever cleared.
 if previous then previous.retired=true end
 c.survival_arbiter=api;owners[c]=x
 local ok,err=pcall(function()
  for _,node in ipairs(x.nodes)do local got=read(node.location);if got~=node.expected and got~=node.group.guard then error('IO changed during publication: '..tostring(node.location.label))end;write(node.location,node.group.guard)end
  x.binding=false;local good,why=identity();assert(good,why)
 end)
 if not ok then x.fault='partial shared IO binding: '..tostring(err);x.binding=true;return nil,x.fault end
 return api
end
return M
