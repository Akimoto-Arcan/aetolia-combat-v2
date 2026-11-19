-- Deterministic, opt-in lunch duty. No network/provider dependency; no action at load.
-- Integration contract: other discretionary controllers must respect lunch_duty.busy;
-- call controller.user_stop() for explicit operator OFF, even if already OFF. Never
-- replace this owner while busy. FIRSTAID remains independent. new() is pure injected IO.
-- attach() installs owned hooks only; start() is the explicit user-grant boundary.
-- Native unknown directory/wares formats fail CLOSED, never guessed purchases.
local M={}
local function yes(v) return v==true or tonumber(v)==1 end
local function integer(v) local n=tonumber(v);if n and n>=0 and n<=100000000 and n==math.floor(n) then return n end end
local function monk(v) return type(v.class)=='string' and v.class:lower()=='monk' end
local function handle(id) return type(id)=='number' and id>0 and id<math.huge and id==math.floor(id) end
local function same(a,b) return a~=nil and b~=nil and tostring(a)==tostring(b) end
local function trim(s) return s:match('^%s*(.-)%s*$') end
local kinds={'health','anabiotic'}
local target={health=1500,anabiotic=2000}
local function key(k) return k=='health' and 'health' or 'ic:anabiotic' end
local function description(k,s)
 s=trim(s):lower()
 if k=='health' then return s=='a refill of an elixir of health' end
 return s=='an anabiotic pill' or s=='anabiotic pill' or s=='anabiotic'
end
-- Units may only be inferred from an explicit singular pill on the actual WARES row.
local function unit(k,s) return k=='health' or trim(s):lower():match('^an anabiotic pill$') or trim(s):lower()=='anabiotic pill' end
local function dirrow(k,line)
 local id,body,price=line:match('^%s*(%d+)%s+(.+)%s+(%d+)gp%s*$')
 if not id or not integer(id) or tonumber(id)<1 or not integer(price) or tonumber(price)<1 then return end
 for _,desc in ipairs(k=='health' and {'a refill of an elixir of health'} or {'an anabiotic pill','anabiotic pill','anabiotic'}) do
  local owner=body:sub(1,#body-#desc)
  if body:sub(-#desc):lower()==desc and owner:match('%S') and owner:match('%s$') then
   return {room=id,price=tonumber(price),description=desc}
  end
 end
end
local function waresrow(k,line)
 local id,desc,stock,price=line:match('^%s*([%a]*%d+)%s+(.+)%s+(%d+)%s+(%d+)gp%s*$')
 if id and #id<=40 and description(k,desc) and unit(k,desc) and integer(stock) and integer(price) and tonumber(price)>0 then
  if k=='health' and not id:match('^cask%d+$') then return end
  return {id=id,stock=tonumber(stock),price=tonumber(price),description=desc}
 end
end
M.directory_row=dirrow;M.wares_row=waresrow
function M.new(io,settings,state)
 io=io or {};settings=settings or {}
 local d=state or {active=false,busy=false,phase='idle',prompt=0,serial=0,status='disabled'}
 d.prompt=d.prompt or 0;d.serial=d.serial or 0;d.phase=d.phase or 'idle'
 local t={state=d,io=io}
 local function now() return (io.now or os.time)() end
 local function view() return io.view() end
 local function fail(why)
  d.active=false;d.fault=why;d.status='held: '..why
  -- All unresolved sends, including resource transactions and routes, survive OFF.
  if not d.pending and not d.purchase and not d.busy then d.busy=false end -- owned pause retains lease on faults
  d.query_quarantine=d.pending and (d.pending.kind=='directory' or d.pending.kind=='wares' or d.pending.kind=='baseline' or d.pending.kind=='readback' or d.pending.kind=='inventory_before' or d.pending.kind=='inventory_after') and why or d.query_quarantine
  if io.release and not d.busy then io.release(d) end
  return false,why
 end
 local function stock(k)
  local v=(io.stocks() or {})[key(k)]
  if v and integer(v.count) then return v end
 end
 local function ready(v) return v.ready==true and not v.blocked end
 local function safeplayers(v)
  if not v.players_known or not same(v.players_room,55290) then return false end
  for n in pairs(v.players or {}) do if n~=v.self_name then return false end end
  return true
 end
 local function intent(v)
  if not d.active then return false end
  if not monk(v) then return fail('operator class changed; no automatic restart') end
  if not v.connected or v.dead then return fail('disconnected/dead; no automatic restart') end
  if d.phase=='monitor' or d.phase=='drain' then
   if v.mode~='BASH' or not same(v.room,55290) then return fail('operator mode/room changed') end
  elseif d.phase=='resume' or d.phase=='initial_wait' then
   if v.mode~='BASH' or not same(v.room,55290) then return fail('operator changed resumed mode/room') end
  elseif v.mode~='OFF' then return fail('operator changed paused intent') end
  if d.phase~='monitor' and d.phase~='drain' and d.phase~='route' and d.phase~='pausing' and d.phase~='resume' and d.phase~='initial_wait' and d.phase~='return_check' then
   local expected=d.phase=='directory' and 12669 or d.candidate and d.candidate.room
   if not same(v.room,expected) then return fail('shopping room changed') end
  end
  if io.owned and not io.owned(d) then return fail('activity lease lost') end
  return true
 end
 local function commit(kind,command,fn)
  if d.dispatching or d.pending then return false end
  local v=view();if not intent(v) then return false end
  if not ready(v) then return false end
  if (kind=='baseline' or kind=='readback') and v.supplies_busy then return false end
  if kind=='baseline' or kind=='readback' then
   local s=stock(d.kind);if not s or s.version==nil or s.pending then return false end
   if kind=='baseline' then d.baseline_version=s.version else d.readback_version=s.version end
  end
  d.serial=d.serial+1
  local p={kind=kind,command=command,at=now(),serial=d.serial,prompt=d.prompt,room=v.room,lines=0,rows={}}
  d.pending=p;d.dispatching=true -- Reserve before sender: nested callbacks cannot send twice.
  local ok,result=pcall(fn or io.send,command)
  d.dispatching=false
  if not ok or result==false then return fail('transport unknown: '..kind) end
  return true
 end
 local function query(kind,command) return commit(kind,command) end
 local function route(room,nextphase)
  d.after_route=nextphase;d.destination=tostring(room);d.phase='route'
  return commit('route',tostring(room),function(dest) return io.travel(dest) end)
 end
 local function nextkind()
  d.index=d.index+1;d.kind=kinds[d.index];d.candidates=nil;d.candidate=nil;d.tries=0
  if not d.kind then return route(55290,'return_check') end
  return route(12669,'directory')
 end
 local function choose()
  d.tries=(d.tries or 0)+1
  local c=d.candidates and d.candidates[d.tries]
  if not c or d.tries>3 then return fail('no verified stocked affordable '..d.kind..' candidate (maximum 3)') end
  d.candidate=c;return route(c.room,'wares')
 end
 local function getbaseline()
  local s=stock(d.kind);if not s or s.version==nil then return fail('authoritative stock version unavailable') end
  d.baseline_version=s.version;d.phase='baseline'
  return commit('baseline',d.kind,function(k) return io.query_stock(k) end)
 end
 local function afterpurchase()
  d.phase='readback'
  local s=stock(d.kind);d.readback_version=s and s.version
  return commit('readback',d.kind,function(k) return io.query_stock(k) end)
 end
 function t.start()
  if d.busy or d.pending or d.purchase or d.fault or d.active then return false,'owner unresolved or already active' end
  local v=view();if not monk(v) or v.globe_armed~=true or not v.connected or v.dead or v.mode~='BASH' or not same(v.room,55290) then return false,'start requires living connected Monk BASH/GLOBE in authorized room' end
  if not stock('health') or not stock('anabiotic') then return false,'both cache counts must be authoritative' end
  d.resume_master=v.upkeep_master==true
  d.active=true;d.phase='monitor';d.status='monitoring strict cache <200';d.return_room=55290;d.low=200;d.health_target=1500;d.anabiotic_target=2000;d.buy_globes=false
  return true
 end
 function t.user_stop() return fail('operator stopped duty') end
 -- A bare pending_restock flag cannot distinguish cutoff OFF from manual OFF.
 -- Adoption requires a parent-recorded owned pause and unchanged intent epoch.
 function t.adopt_pause(grant)
  if d.active or d.busy or d.pending or d.purchase or d.fault then return false,'owner unresolved' end
  if not io.paused_owned or not io.paused_owned(grant) then return false,'owned pause/unchanged operator intent unproved' end
  local v=view();if not monk(v) or v.mode~='OFF' or not v.connected or not same(v.room,55290) or not v.empty or not ready(v) then return false,'owned pause not safely adoptable' end
  if not stock('health') or not stock('anabiotic') then return false,'stock unknown' end
  d.active=true;d.busy=true;d.phase='pausing';d.index=0;d.status='adopted verified owned cutoff pause'
  d.trip_at=now();d.resume_master=v.upkeep_master==true
  if io.acquire and io.acquire(d)==false then return fail('activity lease unavailable') end
  return nextkind()
 end
 function t.disconnect() return fail('disconnected; unresolved transaction retained') end
 function t.tick()
  if not d.active or d.dispatching or d.pumping then return false end
  d.pumping=true
  local ok,res,why=pcall(function()
   local v=view();if not intent(v) then return false end
   if d.trip_at and now()-d.trip_at>1800 then return fail('bounded shopping duty deadline exceeded') end
   if v.globes_exhausted and (d.phase=='monitor' or d.phase=='drain') then
    d.phase='drain';d.done_pending=true;io.disarm_spawn()
    if not v.empty or not ready(v) then return end
    d.busy=true;d.dispatching=true;local good,r=pcall(io.pause);d.dispatching=false
    if not good or r==false or view().mode~='OFF' then return fail('could not safely stop exhausted duty') end
    d.active=false;d.busy=false;d.phase='done';d.status='done: native owned-globe exhaustion proven'
    if io.release then io.release(d) end
    return true
   end
   if (d.phase=='monitor' or d.phase=='initial_wait' or (d.phase=='resume' and d.globe_rearmed)) and v.globe_armed~=true then return fail('operator GLOBE intent changed; no automatic restart') end
   local p=d.pending
   if p then
    local timeout=p.kind=='route' and 300 or 60
    if now()-p.at>timeout then return fail('timeout: '..p.kind..'; no retry') end
    if p.kind=='initial summon' then
     if v.globe_fault then return fail('native initial summon fault; barrier retained') end
     if not v.globe_idle or v.globe_pool_ready==false then return end
     d.pending=nil;d.busy=false;if io.release then io.release(d) end
     d.phase='monitor';d.pending_restock=false;d.owned_pause=false;d.trip_at=nil;d.status='restock verified; BASH/GLOBE resumed';return true
    elseif p.kind=='route' then
     if v.travel_fault then return fail('route fault: '..tostring(v.travel_fault)) end
     if v.travel_idle and same(v.room,d.destination) and d.prompt>p.prompt then d.pending=nil;d.phase=d.after_route else return end
    elseif p.kind=='baseline' or p.kind=='readback' then
     local s=stock(d.kind);local old=p.kind=='baseline' and d.baseline_version or d.readback_version
     if d.prompt<=p.prompt or not s or s.version==nil or s.version==old or s.pending then return end
     d.pending=nil
     if p.kind=='baseline' then d.phase='inventory_before';d.before=s.count
     else
      -- IC is absolute. BUY text alone cannot increase this count. INCALL may leave
      -- excess carried pills at cap; the cache itself is the only target proof.
      if s.count<d.purchase.expected then return fail('cache readback below verified purchase target') end
      d.purchase.cache_after=s.count;d.phase='inventory_after'
     end
    elseif d.prompt>p.prompt and p.complete then
     d.pending=nil
     if p.kind=='directory' then
      if p.bad or not p.header or not p.divider or #p.rows==0 then return fail('unproved directory framing/rows') end
      table.sort(p.rows,function(a,b) if a.price==b.price then return tonumber(a.room)<tonumber(b.room) end;return a.price<b.price end)
      d.candidates=p.rows;d.tries=0;return choose()
     elseif p.kind=='wares' then
      if p.bad or not p.header or not p.proprietor or not p.divider then return fail('unproved wares framing') end
      table.sort(p.rows,function(a,b) return a.price<b.price end)
      local row=p.rows[1];local s=stock(d.kind)
      local n=s and math.floor((target[d.kind]-s.count)/(d.kind=='health' and 50 or 1)) or 0
      if not row or row.stock<n or n<=0 or row.price~=d.candidate.price then
       if n<=0 and s then return nextkind() end
       return choose()
      end
      d.item=row;return getbaseline()
     elseif p.kind=='inventory_before' then
      if not p.gold then return fail('carried gold not proven') end
      local s=stock(d.kind)
      if not s or s.count~=d.before then return fail('cache changed after baseline; purchase cancelled') end
      local n=math.floor((target[d.kind]-d.before)/(d.kind=='health' and 50 or 1))
      if n<=0 then return nextkind() end
      if n>d.item.stock then return fail('insufficient native wares stock') end
      local cost=n*d.item.price
      if cost>p.gold then return fail('insufficient carried gold; no bank/org funds') end
      d.purchase={kind=d.kind,count=n,cost=cost,gold_before=p.gold,before=d.before,expected=d.before+n*(d.kind=='health' and 50 or 1),item=d.item.id}
      d.phase='buy'
     elseif p.kind=='buy' then
      if d.kind=='health' then
       if not p.receipt or p.receipt.cost~=d.purchase.cost or p.receipt.sips~=d.purchase.count*50 then return fail('health purchase receipt mismatch') end
       return afterpurchase()
      end
      -- No invented anabiotic purchase ACK. A real subsequent prompt only schedules
      -- INCALL; fresh absolute IC and wallet readback settle the resource barrier.
      d.phase='incall';return query('incall','incall')
     elseif p.kind=='incall' then return afterpurchase()
     elseif p.kind=='inventory_after' then
      if p.gold==nil or p.gold~=d.purchase.gold_before-d.purchase.cost then return fail('wallet readback mismatch; transaction retained') end
      d.last_purchase=d.purchase;d.purchase=nil;return nextkind()
     end
    else return end
   end
   v=view();if not intent(v) then return false end
   if d.phase=='monitor' then
    local h,a=stock('health'),stock('anabiotic')
    if not h or not a then
     d.hold_reason='cache count became unknown';d.phase='drain';d.status='unknown cache: finishing current NPC, then OFF without travel'
    else
     if h.count>=200 and a.count>=200 then return end
     d.need={health=h.count<200,anabiotic=a.count<200};d.phase='drain';d.status='low cache; finishing current NPC without new summons'
    end
    d.drain_at=now();d.pending_restock=not d.hold_reason
    -- Disarm ONLY the next spawn flag. Never call globe OFF here: it can clear
    -- read-only/unsent state, and it must not erase committed DRAIN/SUMMON.
    io.disarm_spawn()
   end
   if d.phase=='drain' then
    io.disarm_spawn()
    if d.drain_at and now()-d.drain_at>600 then return fail('safe fight-clear/readiness gap not proven within 600 seconds') end
    if not v.empty or not ready(v) then return end
    if io.acquire and io.acquire(d)==false then return fail('another activity owns client') end
    d.resume_master=v.upkeep_master==true;d.globe_rearmed=nil
    d.busy=true;d.trip_at=now();d.phase='pausing';d.dispatching=true
    local good,result=pcall(io.pause);d.dispatching=false
    if not good or result==false or view().mode~='OFF' then return fail('could not pause offense') end
    d.owned_pause=true;d.original_mode='BASH';d.paused_at=now()
    if d.hold_reason then return fail(d.hold_reason..'; safely OFF; no automatic trip') end
    d.index=0
    -- Fill both caches to their respective targets once either original cache is low.
    return nextkind()
   elseif d.phase=='route' then return commit('route',d.destination,function(dest) return io.travel(dest) end)
   elseif d.phase=='baseline' then return commit('baseline',d.kind,function(k) return io.query_stock(k) end)
   elseif d.phase=='readback' then return commit('readback',d.kind,function(k) return io.query_stock(k) end)
   elseif d.phase=='incall' then return query('incall','incall')
   elseif d.phase=='directory' then return query('directory','directory '..d.kind)
   elseif d.phase=='wares' then return query('wares','wares '..d.kind)
   elseif d.phase=='inventory_before' then return query('inventory_before','inventory')
   elseif d.phase=='buy' then
    local cmd=d.kind=='health' and ('buy '..d.purchase.count..' refill of health for fluidcache') or ('buy '..d.purchase.count..' '..d.purchase.item)
    return query('buy',cmd)
   elseif d.phase=='inventory_after' then return query('inventory_after','inventory')
   elseif d.phase=='return_check' then
    if not same(v.room,55290) then return fail('return room mismatch') end
    if not safeplayers(v) then return fail('return blocked: unknown/present other players; stays OFF') end
    if not ready(v) then return end
    d.phase='resume';d.dispatching=true
    local good,result=pcall(io.resume,d.resume_master);d.dispatching=false
    if not good or (result==false and view().mode~='BASH') or view().mode~='BASH' then return fail('resume failed') end
    d.status='BASH restored; waiting genuine recovery/room evidence'
   elseif d.phase=='resume' then
    if not safeplayers(v) then return fail('players changed before GLOBE resume') end
    if not ready(v) or v.mounted or not v.hp_percent or v.hp_percent<80 or not v.room_known then return end
    if not d.globe_rearmed then
     d.dispatching=true;local good,result=pcall(io.arm_globe);d.dispatching=false
     if not good or result==false then return fail('GLOBE could not safely rearm') end
     d.globe_rearmed=true
    end
    v=view();if not intent(v) then return false end
    if not safeplayers(v) or not ready(v) or v.mounted or not v.hp_percent or v.hp_percent<80 then return fail('intent/readiness changed during GLOBE resume') end
    if v.globe_armed~=true then return fail('operator GLOBE intent changed during resume') end
    if v.globe_pool_ready==false then return end
    -- One initial summon only if the real room is empty and GLOBE fully idle.
    if v.empty then
     if not v.globe_idle then return fail('unproved GLOBE state; no initial summon') end
     d.initial_summon=true;d.phase='initial_wait';d.pending={kind='initial summon',at=now(),prompt=d.prompt};d.dispatching=true
     local sent,r=pcall(io.summon);d.dispatching=false
     if not sent or r==false then return fail('initial summon transport unknown') end
     return true
    end
    d.busy=false;if io.release then io.release(d) end
    d.phase='monitor';d.pending_restock=false;d.owned_pause=false;d.trip_at=nil;d.status='restock verified; BASH/GLOBE resumed'
   end
  end)
  d.pumping=false
  if not ok then return fail('controller error: '..tostring(res)) end
  return res,why
 end
 function t.text(line)
  local p=d.pending;if not d.active or not p or type(line)~='string' or d.fault then return end
  if p.kind=='route' or p.kind=='initial summon'then return end -- native owners enforce their own finite leases
  p.lines=p.lines+1
  if p.lines>300 or #line>1000 then return fail('bounded response exceeded') end
  if p.kind=='directory' then
   if line:match('^%s*VNum%s+Owner%s+Description%s+Price%s*$') then if p.header then p.bad=true end;p.header=true
   elseif p.header and line:match('^%s*[%-%=]+%s*$') then p.divider=true
   elseif line=='You can locate the listed shops by doing PATH FIND <vnum>.' then p.complete=true
   elseif p.header and p.divider then
    local row=dirrow(d.kind,line)
    if row then
     if #p.rows>=100 then return fail('too many directory rows') end
     local duplicate=false;for _,r in ipairs(p.rows) do if r.room==row.room then duplicate=true;if r.price~=row.price then p.bad=true end end end
     if not duplicate then p.rows[#p.rows+1]=row end
    end
   end
  elseif p.kind=='wares' then
   if line:match('^Proprietor:%s*%S') then if p.proprietor then p.bad=true end;p.proprietor=true
   elseif line:match('^%-+%(Item%)%-+%(Description%)%-+%(Stock%)%-+%(Price%)%-$') then if p.header or not p.proprietor then p.bad=true end;p.header=true;p.divider=true
   elseif line:match('^%s*Item%s+Description%s+Stock%s+Price%s*$') or line:match('^%s*Item%s+Description%s+Amount%s+Price%s*$') then if p.header then p.bad=true end;p.header=true
   elseif p.header and line:match('^%s*[%-%=]+%s*$') then p.divider=true
   elseif line:match('^You can see %d+ item%(s%) being sold in this location%.$') then p.complete=true
   elseif p.header and p.divider then local row=waresrow(d.kind,line);if row then p.rows[#p.rows+1]=row;if #p.rows>100 then return fail('too many wares rows') end end end
  elseif p.kind=='inventory_before' or p.kind=='inventory_after' then
   local n=line:match('^You are carrying (%d+) gold sovereigns%.$')
   if n then n=integer(n);if p.gold~=nil then return fail('ambiguous inventory balance') end;p.gold=n;p.complete=n~=nil end
  elseif p.kind=='buy' and d.kind=='health' then
   local cost,sips=line:match('^You pay (%d+) gold sovereigns to add (%d+) sips of an elixir of health to your fluidcache%.$')
   if cost then if p.receipt then return fail('duplicate health receipt') end;p.receipt={cost=integer(cost),sips=integer(sips)};p.complete=true end
  end
 end
 function t.prompt()
  d.prompt=d.prompt+1
  local p=d.pending
  if p and (p.kind=='incall' or (p.kind=='buy' and d.kind=='anabiotic')) then p.complete=true end
  return t.tick()
 end
 return t
end

-- Native snapshot adapter: all observations come from the existing native owners.
function M.adapter(c,api)
 api=api or c.lunch_api or _G
 local function connected()
  if api.connected then return api.connected()==true end
  if not api.getConnectionInfo then return false end
  local ok,_,_,tcp=pcall(api.getConnectionInfo);return ok and tcp==true
 end
 local function view()
  local s=c.current or {};local p=s.player or {};local r=c.runner or {};local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {};local g=c.elemental_recovery or {};local cd=c.containers_data or {};local tr=c.travel_owner or {};local root=r.root or c.root or {}
  local q=g.pool or {};local exhausted=g.fault=='all carried globes exhausted' and q.enabled==true and q.known==true and q.ever_owned==true and not q.query
  if exhausted then for id in pairs(q.owned or {}) do if not (q.exhausted or {})[id] then exhausted=false end end end
  local blocked=c.transport_unknown or root.transport_unknown or root.dispatching or root.action_dispatching or r.pending or r.waiting or r.dispatching or r.fault or r.transport_unknown or r.transport_barrier or b.pending or b.fault or b.dispatching or m.eq_pending or m.pending or m.physical_transport or m.fault or m.dispatching or w.pending or w.fault or w.dispatching or cd.barrier or cd.action_dispatching or g.committed or g.dispatching or tr.pending or tr.dispatching or tr.intent or tr.route or tr.fault or tr.follow_fault or tr.follow_pending or tr.follow_due or tr.recall_due
  -- Known unsent waiting/normal and read-only probes remain intact; unknown phases block.
  if g.pending and not ((g.phase=='probe' and g.pending.phase=='probe' and g.pending.kind=='recovery') or (g.phase=='waiting' and not g.pending.kind) or (g.phase=='normal' and not g.pending.kind)) then blocked=true end
  if g.fault and not exhausted and not (g.fault=='recovery timeout' and (g.phase=='idle' or g.phase=='probe')) then blocked=true end
  local tattoo=c.tattoo_owner;if tattoo and (tattoo.txn or tattoo.pending or tattoo.dispatching or tattoo.fault) then blocked=true end
  local rd=connected() and yes(s.connected) and not blocked and not yes(p.dead) and (tonumber(p.hp) or 0)>0
  if (r.mode and r.mode~=c.mode) or (s.mode and s.mode~=c.mode) then rd=false end
  for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[k]) then rd=false end end
  if yes(p.prone) then rd=false end
  for _,v in pairs(p.afflictions or {}) do if yes(v) then rd=false end end
  if c.defense and c.defense.plan then local plan=c.defense.plan(s);if not plan or plan.hold then rd=false end else rd=false end
  local room=s.room or {};local h=s.hunting or {};local ih=h.ih
  local known=ih and same(ih.room_id,room.id) and not ih.active and not ih.pending and (ih.responded==true or (room.item_version or 0)>(ih.start_version or math.huge))
  local empty=known==true
  for _,it in pairs(room.items or {}) do local f=tostring(it.attrib or '');if (f:find('m',1,true) or it.icon=='monster') and not f:find('d',1,true) and not f:find('x',1,true) then empty=false end end
  local pol=s.policy or {}
  return {class=p.class,globe_armed=g.armed==true,upkeep_master=b.master==true,globe_pool_ready=not (c.elementals and c.elementals.pool_enable) or (q.enabled==true and q.known==true and not q.query),mode=c.mode,room=room.id,connected=connected() and yes(s.connected),dead=yes(p.dead) or (tonumber(p.hp) or 0)<=0,ready=rd,blocked=blocked,empty=empty,room_known=known==true,mounted=p.mounted~=false and tonumber(p.mounted)~=0,hp_percent=(tonumber(p.maxhp) or 0)>0 and p.hp/p.maxhp*100 or nil,players_known=pol.players_known==true,players_room=pol.players_room,players=pol.players,self_name=pol.self_name,
   supplies_busy=c.supplies_data and c.supplies_data.pending,globes_exhausted=exhausted,globe_fault=g.fault,travel_fault=tr.fault or tr.follow_fault,travel_idle=tr.phase=='idle' and not (tr.pending or tr.dispatching or tr.intent or tr.route or tr.follow_pending or tr.follow_due or tr.recall_due),globe_idle=not g.pending and not g.committed and not g.fault and (g.phase==nil or g.phase=='idle')}
 end
 return {now=api.getEpoch or api.clock or os.time,view=view,
  stocks=function()
   local raw=c.supplies_data or {};local result={}
   local snap=c.supplies and c.supplies.state and c.supplies.state(c)
   for _,k in ipairs({'health','ic:anabiotic'}) do local v=snap and snap.stocks and snap.stocks[k];local r=raw.stocks and raw.stocks[k]
    if v and r and v.count==r.count then local src=raw.sources and raw.sources[k=='health' and 'fluidcache' or 'ic'];result[k]={count=v.count,version=r.version,pending=src and (src.pending or src.frame~=nil)} end
   end
   return result
  end,
  owned=function(d) return not c.user_activity or c.user_activity==d end,
  paused_owned=function(grant)
   local old=grant and grant.owner;local clock=(api.getEpoch or api.clock or os.time)()
   return old and old==c.lunch_cutoff_handoff and old.pending_restock==true and old.owned_pause==true and old.original_mode=='BASH' and type(old.paused_at)=='number' and clock>=old.paused_at and clock-old.paused_at<=10 and old.intent_epoch~=nil and old.intent_epoch==grant.intent_epoch and old.intent_epoch==c.lunch_intent_epoch
  end,
  acquire=function(d) if c.user_activity and c.user_activity~=d then return false end;c.user_activity=d;return true end,
  release=function(d) if c.user_activity==d then c.user_activity=nil end end,
  disarm_spawn=function()
   local g=c.elemental_recovery
   if g and not g.committed and not g.dispatching and not (g.pending and (g.pending.phase=='drain' or g.pending.phase=='summon')) then g.armed=false end
  end,
  pause=function()
   if not view().ready then return false end
   if c.travel and c.travel.io and c.travel.io.pause then return c.travel.io.pause() end
   local g=c.elemental_recovery;local saved
   if g and not g.committed and g.phase=='probe' and g.pending and g.pending.phase=='probe' and g.pending.kind=='recovery' then saved={pending=g.pending,phase=g.phase,fault=g.fault,status=g.status} end
   local ok,result=pcall(api.combat_v2_set_mode,'OFF')
   if saved then for k,v in pairs(saved) do g[k]=v end;g.armed=false end
   return ok and result~=false and c.mode=='OFF'
  end,
  travel=function(dest) if not c.travel or not c.travel.request then return false end;return c.travel.request('pt',dest) end,
  query_stock=function(k) if not c.supplies or not c.supplies.audit then return false end;return c.supplies.audit(c,nil,true,k=='health' and 'fluidcache' or 'ic') end,
  send=function(cmd) return (c.lunch_sender or api.send)(cmd) end,
  resume=function(master) c.current.buffs=c.current.buffs or {};c.current.buffs.master=master==true;return api.combat_v2_set_mode('BASH') end,
  arm_globe=function()
   local v=view();if not monk(v) or v.mode~='BASH' or not same(v.room,55290) then return false end
   if api.combat_v2_globe('on')==false then return false end
   if c.elementals and c.elementals.pool_enable then return c.elementals.pool_enable(c,true) end
   return true
  end,
  summon=function()
   local g=c.elemental_recovery
   if not g or not c.elementals or not c.elementals.service or not g.armed or g.pending or g.committed or g.fault then return false end
   -- Delegate the single authorized initial summon to the native commit/receipt
   -- owner. Never bypass its ledger or choose/probe/drain a globe ourselves.
   g.pending={phase='normal',started=(api.getEpoch or api.clock or os.time)()};g.phase='normal'
   c.elementals.service(c)
   return not g.fault
  end}
end
function M.attach(c,settings)
 if c.lunch_controller then return c.lunch_controller end
 if c.lunch_duty and (c.lunch_duty.busy or c.lunch_duty.pending or c.lunch_duty.purchase) then return nil,'unfinished lunch owner retained' end
 local old=c.lunch_duty;local api=c.lunch_api or _G
 for _,k in ipairs({'tempRegexTrigger','tempPromptTrigger','tempTimer','registerAnonymousEventHandler','killTrigger','killTimer','killAnonymousEventHandler'}) do if type(api[k])~='function' then return nil,'Mudlet API unavailable: '..k end end
 local t=M.new(M.adapter(c,api),settings);c.lunch_controller=t;c.lunch_duty=t.state;t.handles={};t.attached=true
 local function add(kind,id) assert(handle(id),'invalid '..kind..' registration ID');t.handles[#t.handles+1]={kind,id} end
 local ok,why=pcall(function()
  add('trigger',api.tempRegexTrigger('^.*$',function() t.text(api.line or line or '') end))
  add('trigger',api.tempPromptTrigger(function() t.prompt() end))
  add('event',api.registerAnonymousEventHandler('sysDisconnectionEvent',function() t.disconnect() end))
  local function tick()
   if not t.attached then return end
   t.timer=nil;t.tick()
   local good,id=pcall(api.tempTimer,1,tick)
   if not good or not handle(id) then t.user_stop();return end
   t.timer=id
  end
  local id=api.tempTimer(1,tick);assert(handle(id),'invalid timer registration ID');t.timer=id
 end)
 if not ok then t.state.active=false;M.detach(c);c.lunch_duty=old;return nil,tostring(why) end
 -- Retire ONLY the prior cutoff timer once all new hooks have been installed.
 -- Attachment itself never authorizes travel, purchases, BASH or GLOBE.
 if old then
  if old.cutoff_timer then api.killTimer(old.cutoff_timer);old.cutoff_timer=nil end
  old.active=false;c.lunch_cutoff_handoff=old
 end
 return t
end
function M.user_stop(c)
 c.lunch_intent_epoch=(c.lunch_intent_epoch or 0)+1
 if c.lunch_controller then return c.lunch_controller.user_stop() end
 return true
end
function M.busy(c) local d=c.lunch_duty;return d and (d.busy or d.pending~=nil or d.purchase~=nil) or false end
function M.tick(c) if c.lunch_controller then return c.lunch_controller.tick() end;return false end
function M.text(c,line) if c.lunch_controller then return c.lunch_controller.text(line) end end
function M.prompt(c) if c.lunch_controller then return c.lunch_controller.prompt() end end
function M.detach(c)
 local t=c.lunch_controller;if not t then return true end
 local d=t.state;if d.busy or d.pending or d.purchase or d.dispatching then return false,'unfinished lunch owner retained' end
 local api=c.lunch_api or _G;t.attached=false;d.active=false
 for _,h in ipairs(t.handles or {}) do if h[1]=='event' then api.killAnonymousEventHandler(h[2]) else api.killTrigger(h[2]) end end
 if t.timer then api.killTimer(t.timer) end
 c.lunch_controller=nil;return true
end
return M
