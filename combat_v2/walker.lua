-- Pure planner/state machine. The caller alone owns policy, scans and execution.
local W = {}
-- Private cold-factory enrollment; a lookalike controller or copied callback is not authority.
local emergencies=setmetatable({},{__mode='k'})
local emergency_module
local emergency_watchers=setmetatable({},{__mode='k'})
function W.emergency_valid(c,owner,hop)
 local e=emergencies[owner]
 if not e or e.controller~=c or e.state~=c.current or c.walker~=W then return false end
 local ok,result=pcall(e.authorize,hop);return ok and result==true
end
function W.emergency_owner(c,owner)
 local e=emergencies[owner];return e and e.controller==c and e.state==c.current and c.walker==W or false
end
function W.service_emergency(c,owner)
 local e=emergencies[owner];if not W.emergency_owner(c,owner)then return false,false,'unregistered BASH escape owner'end
 return e.service()
end
function W.emergency_candidate(c,owner)
 local e=emergencies[owner]
 if not W.emergency_owner(c,owner)or type(e.peek)~='function'then return false end
 return e.peek()
end
function W.new_emergency(c,opt)
 if c.walker~=W or not c.walker_boot or type(c.current)~='table'or type(c.current.room)~='table'or type(c.current.player)~='table'or type(c.current.hunting)~='table'or type(c.runner)~='table'or c.runner.state~=c.current then return nil,'canonical walker/current/runner required'end
 -- Constructor options are not consent or a readiness exception. Canonical
 -- factories always require a NEW native grant and the same private authority.
 local policy=c.walker_boot.emergency_options(c)
 opt={require_new_grant=true,require_shared_arbiter=true,endpoint_policy='reviewed_ordinary_empty',defense_barrier=policy.defense_barrier}
 local module=emergency_module
 if not module then
  if type(getMudletHomeDir)~='function'then return nil,'canonical profile directory unavailable'end
  local ok,result=pcall(dofile,getMudletHomeDir()..'/combat_v2/bash_escape.lua')
  if not ok then return nil,'canonical BASH escape module unavailable: '..tostring(result)end
  module=result
 end
 if type(module)~='table'or type(module.construct)~='function'then return nil,'canonical BASH escape factory unavailable'end
 emergency_module=module
 local owner,authorize,grant,peek=module.construct(c,opt,{move=function(o,hop)return c.walker_boot.emergency_step(c,o,hop)end})
 if type(owner)~='table'or type(authorize)~='function'or type(grant)~='function'then return nil,'canonical BASH escape evidence unavailable'end
 emergencies[owner]={controller=c,state=c.current,authorize=authorize,service=owner.service,peek=peek}
 emergency_watchers[c.current]={grant=grant,owner=owner}
 return owner
end
local directions = {'n','ne','e','se','s','sw','w','nw','u','d','in','out'}
local reverse = {n='s',ne='sw',e='w',se='nw',s='n',sw='ne',w='e',nw='se',u='d',d='u',['in']='out',out='in'}
local aliases = {north='n',northeast='ne',east='e',southeast='se',south='s',southwest='sw',west='w',northwest='nw',up='u',down='d',['in']='in',out='out'}
for _, d in ipairs(directions) do aliases[d] = d end
local function id(v)
 if type(v)=='string' and v~='' then return v end
 if type(v)=='number' then return tostring(v) end
end
local function direction(v)
 return type(v)=='string' and aliases[v:lower()] or nil
end
local function now() return getEpoch and getEpoch() or os.time() end
function W.state(s)
 s.walker = s.walker or {active=false,offers=0,enabled=false}
 -- Session intent is not consent. Older state migrates without arming travel.
 if s.walker.enabled==nil then s.walker.enabled=false end
 return s.walker
end
-- Movement pacing is independent of combat cooldown and arrival proof. Prefer a
-- client monotonic stopwatch; standalone adapters may provide only a fake epoch.
function W.movement_clock(s)
 local w=W.state(s)
 if not w.movement_watch and type(createStopWatch)=='function' and type(startStopWatch)=='function' and type(getStopWatchTime)=='function' then
  local ok,watch=pcall(createStopWatch)
  if not ok or type(watch)~='number' or watch<=0 then return nil end
  local started,result=pcall(startStopWatch,watch)
  if not started or result==false then return nil end
  w.movement_watch=watch
 end
 local ok,value=pcall(function()
  if w.movement_watch then return getStopWatchTime(w.movement_watch) end
  return getEpoch and getEpoch() or os.clock()
 end)
 if not ok or type(value)~='number' or value~=value or value==math.huge or value<0 then return nil end
 -- A clock rollback never shortens the gap. Keep the high-water in owned state
 -- across STOP, arrival and reconsent; no timer callback can certify movement.
 w.movement_clock_high=math.max(w.movement_clock_high or value,value)
 return w.movement_clock_high
end
-- Observational half of the same established clock. Never creates a watch,
-- calls W.state, or advances a high-water merely to preview survival priority.
function W.peek_movement_clock(s)
 local w=s.walker;if type(w)~='table'then return nil end
 if not w.movement_watch and type(createStopWatch)=='function'then return nil end
 local ok,value=pcall(function()
  if w.movement_watch then return getStopWatchTime(w.movement_watch)end
  return getEpoch and getEpoch()or os.clock()
 end)
 if not ok or type(value)~='number'or value~=value or math.abs(value)==math.huge or value<0 then return nil end
 return math.max(w.movement_clock_high or value,value)
end
function W.pace(s,reserve)
 local w=W.state(s);local value=W.movement_clock(s)
 if not value then return false end
 local gap=tonumber((s.config or {}).walk_min_hop_spacing)
 if not gap or gap~=gap or gap<1.2 or gap>5 then gap=1.2 end
 if w.last_movement_send and value-w.last_movement_send<gap then return false end
 if reserve then
  w.last_movement_send=value;w.movement_serial=(w.movement_serial or 0)+1
 end
 return true
end
-- Official aetolia-official.xml area 94 (Drakuum), SHA256 4717147cc4b0b9ddf01514120551343c0116f5a4c54eeb8269aaf629a444b5df.
-- Exact directional hidden=1 records only; no door/locked attributes. Native
-- census matched every one of these records to flag 3. This is not map3=hidden.
local hidden = {
 ['20079']={['e']='20086',['s']='20085',['sw']='20080'},
 ['20080']={['ne']='20079',['s']='20081'},
 ['20081']={['n']='20080',['se']='20082'},
 ['20082']={['e']='20083',['nw']='20081'},
 ['20083']={['se']='20090',['w']='20082'},
 ['20085']={['n']='20079'},
 ['20086']={['se']='20087',['w']='20079'},
 ['20087']={['e']='20088',['nw']='20086'},
 ['20088']={['sw']='20089',['w']='20087'},
 ['20089']={['ne']='20088',['s']='20090'},
 ['20090']={['n']='20089',['nw']='20083'},
 ['20107']={['n']='20110'},
 ['20111']={['d']='20119'},
}
function W.hidden_scope(preset,area,name,entry_area)
 return preset=='drakuum' and tonumber(area)==94 and tonumber(entry_area)==94
  and type(name)=='string' and name:lower()=='drakuum'
end
local function hidden_edge(k,d,to,room)
 return room.hidden_scope==true and tonumber(room.area)==94 and room.locked==false
  and tonumber(room.weight) and tonumber(room.weight)<=1 and not room.blocked
  and hidden[k] and hidden[k][d]==to
end
local function snapshot(room)
 local parts={tostring(room.area),tostring(room.env),tostring(room.weight),tostring(room.locked)}
 for _,field in ipairs({'exits','doors'})do
  local list={};for k,v in pairs(room[field]or{})do list[#list+1]=tostring(k)..'='..tostring(v)end
  table.sort(list);parts[#parts+1]=table.concat(list,',')
 end
 return table.concat(parts,'|')
end
-- Literal historical exclusion: documented omission, NOT a danger/safety claim.
W.historical_room_exclusions={['56349']={area=389,reason='Snakepit Autobasher explicitly removes 56349; reason undocumented',source='Aetolia legacy autosave/update3.0 Snakepit Autobasher: remove={tonumber(56349)}'}}
local function historical_exclusion(room,area)
 local e=W.historical_room_exclusions[tostring(room)];return e and tonumber(area)==e.area and e.reason or nil
end
function W.build(start, area, rooms, options)
 start = id(start)
 if historical_exclusion(start,area)then return nil,historical_exclusion(start,area)end
 if not start or not tonumber(area) or type(rooms)~='table' then return nil,'unknown start or area' end
 local mapped, edges, doors = {}, {}, {}
 local total,links=0,0
 for key, room in pairs(rooms) do
  total=total+1;if total>3000 then return nil,"room budget exceeded" end
  local k = id(key)
  if k and type(room)=='table' and tonumber(room.area)==tonumber(area) and not room.blocked and not historical_exclusion(k,area)then
   if mapped[k] then return nil,'ambiguous room ID' end
   mapped[k], edges[k], doors[k] = room, {}, {}
   for name, target in pairs(room.exits or {}) do
    links=links+1;if links>36000 then return nil,"edge budget exceeded" end
    local d, to = direction(name), id(target)
    if d and to then
     -- Conflicting long/short aliases cannot choose a route by pairs order.
     if edges[k][d] and edges[k][d]~=to then edges[k][d]=false
     elseif edges[k][d]~=false then edges[k][d]=to end
    end
   end
   for name, state in pairs(room.doors or {}) do
    local d = direction(name)
    if d and tonumber(state)~=0 then
     if not doors[k][d] then
      doors[k][d]=not(tonumber(state)==3 and hidden_edge(k,d,edges[k][d],room))
     end
    end
   end
  end
 end
 if not mapped[start] then return nil,'unknown or blocked start' end
 local nodes,certified = {},{}
 for k in pairs(mapped) do
  nodes[k] = {}
  for _, d in ipairs(directions) do
   local to = edges[k][d]
   -- Only a reverse exit pointing back is the same physical passage. An
   -- unrelated opposite exit must not veto a valid directed return loop.
   if to and mapped[to] and not mapped[k].wet and not mapped[to].wet and not doors[k][d]
    and not (edges[to][reverse[d]]==k and doors[to][reverse[d]]) then
    nodes[k][d] = to
    if hidden_edge(k,d,to,mapped[k]) and (function()for name,state in pairs(mapped[k].doors or {})do if direction(name)==d and tonumber(state)==3 then return true end end end)() then
     certified[k]=certified[k]or{}
     certified[k][d]={to=to,source=snapshot(mapped[k]),target=snapshot(mapped[to])}
    end
   end
  end
 end
 -- Special descriptors are trusted planner output, never command strings from map Lua.
 local special,used,conflicts={},{},{}
 for _,e in ipairs(type(options)=='table' and options.special_edges or {}) do
  links=links+1;if links>36000 then return nil,'edge budget exceeded' end
  if type(e)=='table' and e.special==true and type(e.from)=='string' and type(e.to)=='string'
   and e.from~=e.to and mapped[e.from] and mapped[e.to] and type(e.direction)=='string'
   and type(e.command)=='string' and e.command~='' and not e.command:find('[\r\n;|]')
   and type(e.capability)=='table' and e.capability.reviewed==true
   and e.capability.from==tonumber(e.from) and e.capability.to==tonumber(e.to)
   and e.capability.command==e.command and e.capability.kind==e.kind
   and e.capability.session and e.capability.epoch and e.capability.graph and e.provenance then
   local k,d,to=e.from,e.direction,e.to
   local ordinary=direction(d)
   local valid=(ordinary and ordinary==d and e.kind=='swim' and e.command=='swim '..d
     and edges[k][d]==to and not doors[k][d]
     and not(edges[to][reverse[d]]==k and doors[to][reverse[d]]))
    or (ordinary and ordinary==d and e.kind=='door' and e.command==d and edges[k][d]==to
      and mapped[k].locked==false and mapped[to].locked==false
      and (function()for key,value in pairs(mapped[k].doors or {})do if direction(key)==d and (tonumber(value)==1 or tonumber(value)==2)then return true end end end)())
     or (not ordinary and d=='special:'..e.command and (e.kind=='portal' or e.kind=='climb'))
     or (not ordinary and d=='special:kneel'and e.kind=='kneel'and e.command=='kneel'and tonumber(area)==338
      and ((k=='22801'and to=='26382')or(k=='26442'and to=='22801'))
      and e.provenance.digest=='a5e15d9e895450dc131277a1fb5be1770d894d3abd197d4106287c8d7d211f01')
   if valid then
    special[k]=special[k]or{};conflicts[k]=conflicts[k]or{}
    if special[k][d] and special[k][d]~=e then conflicts[k][d]=true end
    special[k][d]=e
   end
  end
 end
 for k,exits in pairs(special)do for d,e in pairs(exits)do
  if not conflicts[k][d]then nodes[k][d]=e.to else nodes[k][d]=nil;exits[d]=nil end
 end end
 -- Root SCC = forward reachable intersect reverse reachable. Both walks are
 -- iterative and bounded by the already validated room/edge budgets.
 local incoming={}
 for k in pairs(nodes) do incoming[k]={} end
 for k,exits in pairs(nodes) do
  for _,to in pairs(exits) do incoming[to][k]=true end
 end
 local backqueue,returns={start},{[start]=true}
 local head=1
 while head<=#backqueue do
  local k=backqueue[head];head=head+1
  for from in pairs(incoming[k]) do
   if not returns[from] then returns[from]=true;backqueue[#backqueue+1]=from end
  end
 end
 local queue, seen, component = {start}, {[start]=true}, {}
 head = 1
 while head<=#queue do
  local k = queue[head]; head=head+1; component[k]={}
  for d,to in pairs(nodes[k]) do
   if to and returns[to] then
    component[k][d]=to
    if special[k] and special[k][d]then used[k]=used[k]or{};used[k][d]=special[k][d]end
    if not seen[to] then seen[to]=true; queue[#queue+1]=to end
   elseif certified[k] then certified[k][d]=nil end
  end
 end
 for k in pairs(certified) do if not component[k] then certified[k]=nil end end
 return {start=start,area=area,nodes=component,room_count=#queue,special_edges=used,certified_hidden=certified,hidden_provenance='4717147cc4b0b9ddf01514120551343c0116f5a4c54eeb8269aaf629a444b5df'}
end
function W.stop(s, reason)
 local w = W.state(s)
 -- Consent can be revoked, but an issued direction cannot be unsent.
 w.active=false; w.offer=nil; w.clear=nil;w.transit=nil
 w.status=reason or 'stopped'
 return true
end
function W.offer(s, graph)
 local w = W.state(s)
 if w.pending then return nil,'movement unresolved; await arrival or cv2 reset after review' end
 if s.mode~='BASH' or not s.room or type(graph)~='table' or graph.start~=id(s.room.id)
  or not graph.nodes or not graph.nodes[graph.start] or s.room.area==nil then
  return nil,'offer requires BASH and mapped current room'
 end
 W.stop(s,'awaiting consent')
 w.offers=w.offers+1
 w.offer={token=w.offers,room_id=id(s.room.id),area=s.room.area,graph=graph}
 return w.offers
end
function W.accept(s, token, yes)
 local w = W.state(s); local offer = w.offer
 if w.pending or not offer or token~=offer.token or s.mode~='BASH' or not s.connected or s.training_battle_ended
  or not s.room or id(s.room.id)~=offer.room_id or s.room.area~=offer.area then
  return false,'stale consent or unavailable session'
 end
 W.stop(s,yes==true and 'walking' or 'declined')
 if yes~=true then return true end
 w.graph=offer.graph; w.area=offer.area; w.start=offer.room_id
 w.visited={};w.skipped={};w.cleared={}; w.steps=0; w.fault=nil; w.active=true
 local observer=emergency_watchers[s]
 if observer then
  local ok,why=pcall(observer.grant,token,offer)
  if not ok then observer.owner.state.phase='blocked';observer.owner.state.reason='new grant endpoint policy failed: '..tostring(why)end
 end
 return true
end
local function scoped(s)
 local w = W.state(s); local current = s.room and id(s.room.id)
 if not w.active then return nil,'inactive' end
 if s.mode~='BASH' or not s.connected or s.training_battle_ended or s.room.area~=w.area
  or not w.graph or not w.graph.nodes[current] then
  W.stop(s,'walking scope changed'); return nil,w.status
 end
 return w,current
end
function W.mark_clear(s, version)
 local w, current = scoped(s)
 if not w or w.pending or version==nil then return false end
 local p=s.policy
 if p and p.players_known and p.players_room==s.room.id then
  for name in pairs(p.players or {})do if name~=p.self_name then return false end end
 end
 w.visited[current]=true
 w.cleared=w.cleared or {};w.cleared[current]=true
 w.clear={room_id=current,version=version}
 return true
end
function W.coverage(s)
 local w=W.state(s);local out={total=0,visited=0,cleared=0,skipped=0,skipped_rooms={}};local seen={}
 for raw in pairs(w.graph and w.graph.nodes or {})do
  local room=id(raw)
  if room and not seen[room]then
   seen[room]=true;out.total=out.total+1
   if (w.visited or {})[room]then out.visited=out.visited+1 end
   local skip=(w.skipped or {})[room]
   if skip then
    out.skipped=out.skipped+1;local names={};for i,name in ipairs(skip.players or {})do names[i]=name end
    out.skipped_rooms[room]={reason=skip.reason,players=names}
   elseif (w.cleared or {})[room]then out.cleared=out.cleared+1 end
  end
 end
 out.unclassified_visits=out.visited-out.cleared-out.skipped
 return out
end
function W.next(s)
 W.expire(s)
 local w, current = scoped(s)
 if not w then return nil,current end
 if w.pending then return nil,'movement pending' end
 local certificate=w.transit or w.clear
 if not certificate or certificate.room_id~=current then return nil,'room not inspected for departure' end
 local queue, seen, first = {current}, {[current]=true}, {}
 local head = 1
 while head<=#queue do
  local k=queue[head]; head=head+1
  if not w.visited[k] then return first[k] end
  local keys={};for _,d in ipairs(directions)do keys[#keys+1]=d end
  local special=(w.graph.special_edges or {})[k] or {};local extra={}
  for d in pairs(special)do if not reverse[d] then extra[#extra+1]=d end end;table.sort(extra)
  for _,d in ipairs(extra)do keys[#keys+1]=d end
  for _, d in ipairs(keys) do
   local to = w.graph.nodes[k][d]
   if to and not seen[to] then
    seen[to]=true; queue[#queue+1]=to
    first[to]=first[k] or special[d] or {from=current,to=to,direction=d}
   end
  end
 end
 if w.transit then
  -- Finish in a re-inspected solo room, not by switching BASH OFF next to
  -- another player's live mobs. Every backtrack still needs fresh evidence.
  for _,k in ipairs(queue)do if k~=current and (w.cleared or {})[k]then return first[k]end end
  w.status='HOLD: finite pass visited; all available completion rooms skipped'
  return nil,w.status
 end
 w.graph.completion=W.coverage(s) -- preserved by the tour slot's same graph
 W.stop(s,'complete')
 return nil,'complete'
end
function W.begin_step(s, step, emergency)
 W.expire(s)
 local w, current = scoped(s)
 local certificate=w and (w.transit or w.clear)
 local enrolled=emergencies[emergency]
 local escaping=enrolled and enrolled.state==s and W.emergency_valid(enrolled.controller,emergency,step)
 if not w or w.pending or not escaping and (not certificate or certificate.room_id~=current)or type(step)~='table' then return false end
 local cert=((w.graph.special_edges or {})[current] or {})[step.direction]
 if step.from~=current or not id(step.to) or w.graph.nodes[current][step.direction]~=step.to then return false end
 if step.special then
  if cert~=step or not step.capability or type(step.command)~='string' or not step.provenance then return false end
 elseif not reverse[step.direction] then return false end
 w.pending={from=current,to=step.to,direction=step.direction,command=step.command,at=now(),timeout=step.special and math.min(30,math.max(5,(tonumber(step.metadata and step.metadata.legacy_delay) or 0)+5)) or 5}
 w.clear=nil;w.transit=nil; w.status='awaiting arrival'
 return true
end
function W.arrive(s, new_id)
 W.expire(s)
 local w = W.state(s); local current=s.room and id(s.room.id)
 -- Called only for a genuine changed Room.Info, never cached same-room data.
 if w.pending and w.pending.phase=='door-open'then W.stop(s,'room changed during unresolved OPEN');return false end
 if w.pending and id(new_id)==current and current==w.pending.to and current~=w.pending.from then
  local same_area=s.room.area==w.area
  w.pending=nil; w.steps=(w.steps or 0)+1; w.clear=nil
  if not same_area then W.stop(s,'walking scope changed');return false end
  w.status=w.active and 'awaiting clear' or 'arrival confirmed; walking disabled'
  return true
 end
 W.stop(s,'unexpected room change')
 return false
end
function W.expire(s)
 local w = W.state(s)
 if w.pending and not w.pending.timed_out and now()-w.pending.at>(w.pending.timeout or 5) then
  w.pending.timed_out=true
  W.stop(s,'movement acknowledgement timed out')
  w.fault=w.status
  return true
 end
 return false
end
return W
