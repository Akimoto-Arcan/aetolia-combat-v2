-- Pure planner/state machine. The caller alone owns policy, scans and execution.
local W = {}
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
 s.walker = s.walker or {active=false,offers=0}
 return s.walker
end
function W.build(start, area, rooms)
 start = id(start)
 if not start or not tonumber(area) or type(rooms)~='table' then return nil,'unknown start or area' end
 local mapped, edges, doors = {}, {}, {}
 for key, room in pairs(rooms) do
  local k = id(key)
  if k and type(room)=='table' and tonumber(room.area)==tonumber(area) and not room.blocked then
   if mapped[k] then return nil,'ambiguous room ID' end
   mapped[k], edges[k], doors[k] = room, {}, {}
   for name, target in pairs(room.exits or {}) do
    local d, to = direction(name), id(target)
    if d and to then
     -- Conflicting long/short aliases cannot choose a route by pairs order.
     if edges[k][d] and edges[k][d]~=to then edges[k][d]=false
     elseif edges[k][d]~=false then edges[k][d]=to end
    end
   end
   for name, state in pairs(room.doors or {}) do
    local d = direction(name)
    if d and tonumber(state)~=0 then doors[k][d]=true end
   end
  end
 end
 if not mapped[start] then return nil,'unknown or blocked start' end
 local nodes = {}
 for k in pairs(mapped) do
  nodes[k] = {}
  for _, d in ipairs(directions) do
   local to = edges[k][d]
   if to and mapped[to] and edges[to][reverse[d]]==k and not doors[k][d] and not doors[to][reverse[d]] then
    nodes[k][d] = to
   end
  end
 end
 local queue, seen, component = {start}, {[start]=true}, {}
 local head = 1
 while head<=#queue do
  local k = queue[head]; head=head+1; component[k]=nodes[k]
  for _, d in ipairs(directions) do
   local to = nodes[k][d]
   if to and not seen[to] then seen[to]=true; queue[#queue+1]=to end
  end
 end
 return {start=start,area=area,nodes=component,room_count=#queue}
end
function W.stop(s, reason)
 local w = W.state(s)
 -- Consent can be revoked, but an issued direction cannot be unsent.
 w.active=false; w.offer=nil; w.clear=nil
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
 w.visited={}; w.steps=0; w.fault=nil; w.active=true
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
 w.visited[current]=true
 w.clear={room_id=current,version=version}
 return true
end
function W.next(s)
 W.expire(s)
 local w, current = scoped(s)
 if not w then return nil,current end
 if w.pending then return nil,'movement pending' end
 if not w.clear or w.clear.room_id~=current then return nil,'room not cleared' end
 local queue, seen, first = {current}, {[current]=true}, {}
 local head = 1
 while head<=#queue do
  local k=queue[head]; head=head+1
  if not w.visited[k] then return first[k] end
  for _, d in ipairs(directions) do
   local to = w.graph.nodes[k][d]
   if to and not seen[to] then
    seen[to]=true; queue[#queue+1]=to
    first[to]=first[k] or {from=current,to=to,direction=d}
   end
  end
 end
 W.stop(s,'complete')
 return nil,'complete'
end
function W.begin_step(s, step)
 W.expire(s)
 local w, current = scoped(s)
 if not w or w.pending or not w.clear or w.clear.room_id~=current or type(step)~='table' then return false end
 if step.from~=current or not reverse[step.direction] or not id(step.to)
  or w.graph.nodes[current][step.direction]~=step.to then return false end
 w.pending={from=current,to=step.to,direction=step.direction,at=now()}
 w.clear=nil; w.status='awaiting arrival'
 return true
end
function W.arrive(s, new_id)
 W.expire(s)
 local w = W.state(s); local current=s.room and id(s.room.id)
 -- Called only for a genuine changed Room.Info, never cached same-room data.
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
 if w.pending and not w.pending.timed_out and now()-w.pending.at>5 then
  w.pending.timed_out=true
  W.stop(s,'movement acknowledgement timed out')
  w.fault=w.status
  return true
 end
 return false
end
return W
