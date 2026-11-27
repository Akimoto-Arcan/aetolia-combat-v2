-- Finite, consent-scoped range tour. Pure module; only injected IO acts.
local M={HEADER='******************************[ Areas by level ]*******************************'}
local threats={Safe=true,Moderate=true,Challenging=true,Dangerous=true,Lethal=true}
local function norm(v)return tostring(v or ''):lower()end
function M.bounds(command)
 if type(command)~='string'then return nil,'use bashMAX or bashMIN MAX (integers 1..200)'end
 command=command:gsub('^bash +','bash')
 local a,z=command:match('^bash(%d+)%s+(%d+)$')
 if not a then z=command:match('^bash(%d+)$');a=z and '1'end
 a,z=tonumber(a),tonumber(z)
 if not a or not z or a<1 or z>200 or a>z then return nil,'use bashMAX or bashMIN MAX (ordered integers 1..200)'end
 return a,z
end
function M.parser()return {rows={},seen={},names={},count=0}end
function M.line(q,text)
 if type(text)~='string'then return false end
 -- Even a rejected/retired frame must consume its real terminator before a
 -- second query can own this untagged wire stream.
 if q.open and text:match('^%*%*%*%*%*%*%*%*%*%*+$')then
  q.closed=true
  if not q.columns or q.count==0 then q.fault=q.fault or 'empty or unframed AREAS'end
  q.done=not q.fault;return q.done
 end
 if q.done or q.fault then return false end
 if text==M.HEADER then
  if q.open then q.fault='duplicate AREAS header';return false end
  q.open=true;return false
 end
 if not q.open then return false end

 if text:match('^%s*Lvl%s+Threat%s+Area name%s+VNum%s*$')then q.columns=true;return false end
 if text==''or text:match('^%-+$')or text=='Use AREAS DETAILS <area> for a per-area threat breakdown.'or text=='*** [ Recommended Areas ] ***'or text=='*** [ Other Areas ] ***'then return false end
 local level,plus,threat,name,entry=text:match('^%s*(%d+)(%+?)%s+(%a+)%s+(.-)%s+(%d+)%s*$')
 if not q.columns or not level or not threats[threat]or name==''or tonumber(level)<1 or tonumber(level)>200 then q.fault='malformed AREAS row';return false end
 local row={level=tonumber(level),rating=level..plus,open_ended=plus=='+',threat=threat,name=name,entry=entry,source=text}
 local k=norm(name);local sig=row.rating..'\0'..threat..'\0'..entry
 if q.names[k]and q.names[k]~=sig then q.fault='conflicting AREAS row';return false end
 q.names[k]=sig
 if not q.seen[k]then q.seen[k]=true;q.rows[#q.rows+1]=row;q.count=q.count+1 end
 if q.count>2000 then q.fault='AREAS row budget exceeded'end
 return false
end
function M.plan(rows,lo,hi,catalog,graph)
 local plan={ready={},skipped={},unsupported={},unmapped={},terrainexcluded={},held={},completed={},partial={}}
 for _,r in ipairs(rows)do
  if r.level>=lo and r.level<=hi then
   local slot={row=r,status='ready'}
   local ids={};for id,preset in pairs(catalog)do if preset.areas[norm(r.name)]then ids[#ids+1]=id end end;table.sort(ids)
   local bucket,why='ready',nil
   if r.open_ended then bucket,why='skipped','open-ended '..r.rating..' cannot prove bounded ceiling'
   elseif tonumber(r.entry)==0 then bucket,why='unmapped','server supplies no entrance VNum'
   elseif #ids~=1 then bucket,why='unsupported',#ids==0 and 'no reviewed exact area preset'or 'ambiguous reviewed preset'
   elseif catalog[ids[1]].disabled_reason then bucket,why='unsupported',catalog[ids[1]].disabled_reason
   elseif catalog[ids[1]].requires_rooms then bucket,why='unsupported','private reviewed room allowlist required'
   else
    slot.preset=ids[1]
    local ok,g,err=pcall(graph,r,slot.preset)
    if not ok then bucket,why='held','mapper parser fault: '..tostring(g)
    elseif not g then
     why=err or 'no validated safe foot graph'
     -- A mapped but rejected entrance is not missing map data. Preserve the
     -- exact adapter diagnostic and keep it unavailable, never invent a route.
     local mapped=why:find('entry mapper',1,true)or why:find('terrain unsupported',1,true)
      or why:match('^mapped entrance')or why:find('unknown or blocked start',1,true)
     bucket=mapped and 'unsupported'or 'unmapped'
    else
     slot.graph=g
     if (g.terrain_excluded or 0)>0 then plan.terrainexcluded[#plan.terrainexcluded+1]={row=r,count=g.terrain_excluded,reason='excluded from safe foot component'}end
    end
   end
   slot.status=bucket;slot.reason=why;plan[bucket][#plan[bucket]+1]=slot
  end
 end
 local function order(a,b)if a.row.level~=b.row.level then return a.row.level<b.row.level end;local x,y=norm(a.row.name),norm(b.row.name);if x~=y then return x<y end;return a.row.entry<b.row.entry end
 for _,list in pairs(plan)do table.sort(list,order)end
 return plan
end
function M.covered(w,g)
 if not g or w.graph~=g or w.active or w.status~='complete'or w.pending or w.dispatching or w.physical_dispatch or w.arrival_hold or w.restock_checkpoint or w.fault then return false end
 local n=0;for id in pairs(g.nodes or {})do if not(w.visited or {})[tostring(id)]then return false end;n=n+1 end
 local visited=0;for id,yes in pairs(w.visited or {})do if yes and g.nodes[tostring(id)]then visited=visited+1 end end
 return n>0 and n==visited
end
function M.new(io)
 local t={io=io,state={phase='off',generation=0}};local s=t.state
 local function hold(why)
  s.phase='held';s.reason=tostring(why or 'unproven state')
  if s.slot then s.slot.status='held';s.slot.reason=s.reason end
  if io.hold then pcall(io.hold,s.reason)end
  return false,s.reason
 end
 local function valid()return s.grant and io.scope(s.grant)==true end
 local function problem(why)
  s.reason=tostring(why);s.check=io.status and io.status()or {}
  local safe=io.can_retire and io.can_retire(s.slot,s.reason,s.check)
  if safe==true then s.phase='retiring';s.slot.status='retiring';s.slot.reason=s.reason;return false end
  return hold(s.reason)
 end
 local function call(fn,...)
  local generation=s.generation
  local ok,a,z=pcall(fn,...)
  if generation~=s.generation or s.phase=='cancelled'then return false,'newer operator intent retained'end
  if not ok then return hold('controller/transport unknown: '..tostring(a))end
  if a~=true then return hold(z or 'action not proven')end
  return true
 end
 function t.cancel(why,already_revoked)
  local live=s.grant~=nil and s.phase~='off'and s.phase~='cancelled'and s.phase~='done'
  s.generation=s.generation+1;s.grant=nil;s.phase='cancelled';s.reason=why or 'operator intent changed'
  if s.slot and s.slot.status~='completed'then s.slot.status='held';s.slot.reason=s.reason end
  if live and not already_revoked and io.cancel then io.cancel(s.reason)end
  -- Cancellation may revoke unsent consent, never travel/physical commitments.
  return true
 end
 function t.start(command)
  local lo,hi=M.bounds(command);if not lo then return false,hi end
  t.cancel('new explicit range')
  local session=io.stream_session and io.stream_session()
  if s.parser and s.parser.query_sent and not s.parser.closed and s.parser.session==session then return hold('prior AREAS stream not proven closed; no blind read retry')end
  local ready,why=io.start_ready();if not ready then return hold(why or 'start requires OFF and settled')end
  -- Only a new accepted explicit range arms permission; never on attach/tick.
  if io.arm_controls then
   local generation=s.generation
   local ok,armed,reason=pcall(io.arm_controls)
   if s.generation~=generation then return false,'newer operator intent retained'end
   if not ok then return hold('control activation unknown: '..tostring(armed))end
   if armed~=true then return hold(reason or 'control activation refused')end
  end
  s.lo,s.hi=lo,hi;s.plan=nil;s.slot=nil;s.index=0;s.reason=nil;s.parser=M.parser()
  s.grant=io.grant(s.generation,lo,hi);s.phase='ratings';s.started=io.now();s.reading=true;s.parser.query_sent=true;s.parser.session=session
  local ok=call(io.ratings);s.reading=nil;return ok
 end
 function t.line(text)
  if s.phase~='ratings'or not valid()then
   if s.parser and s.parser.query_sent and not s.parser.closed then M.line(s.parser,text)end
   return false
  end
  M.line(s.parser,text)
  if s.parser.fault then return hold(s.parser.fault)end
  return s.parser.done
 end
 function t.tick()
  if s.ticking or s.phase=='off'or s.phase=='cancelled'or s.phase=='done'or s.phase=='held'then return false end
  s.ticking=true
  local function step()
   if not valid()then t.cancel('session/class/operator grant expired');return false end
   if s.phase=='ratings'then
    if s.reading then return false end
    if not s.parser.done then if io.now()-s.started>15 then return hold('AREAS response incomplete/timeout')end;return false end
    s.plan=M.plan(s.parser.rows,s.lo,s.hi,io.catalog,io.graph);s.phase='next';return true
   end
   if s.phase=='next'then
    s.index=s.index+1;s.slot=s.plan.ready[s.index]
    if not s.slot then s.phase='done';s.reason='finite pass finished; see separate exclusions';return true end
    s.slot.status='transfer';s.phase='transfer';s.transfer=io.transfer_stamp()
    return call(io.transfer,s.slot,s.grant)
   end
   if s.phase=='transfer'then
    local ready,why=io.arrived(s.slot,s.transfer)
    if ready==nil then return problem(why)end
    if not ready then return false end
    s.phase='prepare';s.slot.status='prepare';return call(io.prepare,s.slot,s.grant)
   end
   if s.phase=='prepare'then
    local ready,why=io.prepared(s.slot,s.grant)
    if ready==nil then return problem(why)end
    if not ready then return false end
    s.phase='hunt';s.slot.status='hunting'
    if not call(io.begin,s.slot,s.grant)then return false end
    s.graph=s.slot.active_graph;s.progress_at=io.now();s.progress_key=nil;return true
   end
   if s.phase=='hunt'then
    local borrowed,why=io.borrowed(s.slot)
    if borrowed==nil then return hold(why)end
    if borrowed then s.slot.status='restock suspended';s.progress_at=io.now();return false end
    s.slot.status='hunting'
    local w=io.walker()
    if w.graph~=s.graph then return hold('walker graph identity changed')end
    if w.fault then return hold(w.fault)end
    if not w.active then
     if not M.covered(w,s.graph)then return problem('walker stopped without proven finite completion')end
     local ready,reason=io.finish_ready(s.slot)
     if not ready then s.reason=reason;return false end
     s.phase='finishing';return call(io.finish,s.slot,s.grant)
    end
    local why=io.hunt_fault(s.slot)
    if why then return problem(why)end
    local count=0;for id,yes in pairs(w.visited or {})do if yes and s.graph.nodes[tostring(id)]then count=count+1 end end
    local key=tostring(w.steps)..':'..count
    if key~=s.progress_key then s.progress_key=key;s.progress_at=io.now()end
    if io.now()-s.progress_at>=90 then return problem('bounded no-progress window (90 seconds)')end
    return false
   end
   if s.phase=='retiring'then
    s.check=io.status and io.status()or {}
    if not io.can_retire(s.slot,s.reason,s.check)then return hold('retirement safety changed: '..s.reason)end
    s.slot.retry_count=s.slot.retry_count or 0
    s.phase='retired';return call(io.retire,s.slot,s.grant)
   end
   if s.phase=='retired'then
    if not io.start_ready()then return false end
    s.slot.status='skipped';s.phase='next';return true
   end
   if s.phase=='finishing'then
    if not io.start_ready()then return false end
    local g=s.graph;local count=0;for _ in pairs(g.nodes or {})do count=count+1 end
     local partial=tonumber(g.mapped_count)and count<tonumber(g.mapped_count)
     local bucket=partial and 'partial'or 'completed'
     s.plan.partial=s.plan.partial or {};s.slot.status=bucket
     if partial then s.slot.reason=count..' reachable visited / '..g.mapped_count..' mapped; remainder not cleared' end
     s.plan[bucket][#s.plan[bucket]+1]=s.slot;s.phase='next';s.reason=nil;return true
   end
  end
  local ok,a,z=pcall(step);s.ticking=nil
  if not ok then return hold('tour parser/controller fault: '..tostring(a))end
  return a,z
 end
 return t
end
return M
