-- Deterministic, opt-in bashing restock. No network/provider dependency; no action at load.
-- Integration contract: other discretionary controllers must respect restock_data.busy;
-- call controller.user_stop() for explicit operator OFF, even if already OFF. Never
-- replace this owner while busy. FIRSTAID remains independent. new() is pure injected IO.
-- attach() installs OFF hooks; start()/off() are independent permission toggles.
-- Reservation blocks only next hops/spawns; busy lease blocks discretionary actions.
-- Native unknown directory/wares formats fail CLOSED, never guessed purchases.
-- Walker/native integration contract:
-- c.restock_data is the exact activity lease and cp.lease; never alias lunch data.
-- movement_reserved(c): drain/resume lease blocks NEW hops/spawns, not fight offense.
-- busy(c): owned pause/shopping/return or unresolved transactions; settle-only holds.
-- owns_transition(c): trusted dispatch only in pausing / exact route / resume phases.
-- movement_borrowed(c): actual native PT owner + destination + serial, not manual PT.
-- c.walker_boot.restock_ready(c,d) must settle hop AND post-arrival IH before capture.
-- restock_suspend(c,d) -> cp (or false for stationary), nil,reason means fail CLOSED.
-- cp.lease==d; cp.room/area are exact current anchor. Opaque cursor/visited/token/
-- intent fields remain owned by walker_boot; never reconstruct route or consent.
-- restock_resume(c,cp,d) occurs once after exact return, fresh solo players, real IH,
-- unmounted recovery and owned BASH mode restoration. No popup/new activation grant.
-- restock_cancel(c,cp,d,why) revokes intent without dropping issued-hop barriers.
local M={}
local function yes(v) return v==true or tonumber(v)==1 end
local function integer(v) local n=tonumber(v);if n and n>=0 and n<=100000000 and n==math.floor(n) then return n end end
local function class_known(v) return type(v.class)=='string' and v.class~='' end
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
 body=trim(body) -- Native fixed-width descriptions are padded before the price.
 for _,desc in ipairs(k=='health' and {'a refill of an elixir of health'} or {'an anabiotic pill','anabiotic pill','anabiotic'}) do
  local owner=body:sub(1,#body-#desc)
  if body:sub(-#desc):lower()==desc and owner:match('%S') and owner:match('%s$') then
   return {room=id,price=tonumber(price),description=desc}
  end
 end
end
local function waresrow(k,line)
 local id,desc,stock,price=line:match('^%s*([%w]+)%s+(.+)%s+(%d+)%s+(%d+)gp%s*$')
 if id and #id<=40 and description(k,desc) and unit(k,desc) and integer(stock) and integer(price) and tonumber(price)>0 then
  if k=='health' and not id:match('^cask%d+$') then return end
  if k=='anabiotic' and id~='anabiotic' and not id:match('^pill%d+$') then return end
  return {id=id,stock=tonumber(stock),price=tonumber(price),description=desc}
 end
end
M.directory_row=dirrow;M.wares_row=waresrow
-- Strict flat JSON, no loadstring/eval, duplicate/unknown keys fail closed.
-- Private config never persists permission or armed controller state.
function M.settings_json(raw)
 if type(raw)~='string' or #raw>1024 then return nil,'invalid restock settings' end
 local body=raw:match('^%s*{%s*(.-)%s*}%s*$');if not body then return nil,'invalid restock JSON' end
 local result={};local count=0
 while body~='' do
  local name,value,tail=body:match('^"([a-z_]+)"%s*:%s*("[0-9]+")%s*(.*)$')
  if not name then name,value,tail=body:match('^"([a-z_]+)"%s*:%s*(%a+)%s*(.*)$') end
  if not name or result[name]~=nil then return nil,'invalid/duplicate restock setting' end
  if name=='haven_room' then
   local room=value:match('^"([1-9]%d*)"$');if not room or #room>9 or not integer(room) then return nil,'invalid Haven room' end
   result[name]=room
  elseif name=='globe_haven_return' and (value=='true' or value=='false') then result[name]=value=='true'
  else return nil,'unsupported restock setting' end
  count=count+1
  if tail=='' then body='' elseif tail:sub(1,1)==',' and tail:sub(2):match('%S') then body=tail:sub(2):match('^%s*(.-)%s*$') else return nil,'invalid restock JSON separator' end
 end
 if count~=2 or not result.haven_room or result.globe_haven_return==nil then return nil,'incomplete restock settings' end
 return result
end
function M.read_settings(api)
 if type(api.getMudletHomeDir)~='function' then return {} end -- injected offline runtime has no persisted profile
 local ok,home=pcall(api.getMudletHomeDir);if not ok or type(home)~='string' then return {},'restock settings home unavailable' end
 local open=api.open_file or io.open
 local good,f,err,code=pcall(open,home..'/combat_v2/restock-settings.json','r')
 if not good then return {},'restock settings open failed: '..tostring(f) end
 if not f then
  if code==2 or (err==nil and code==nil) then return {} end -- absent: legacy ordinary trips
  return {},'restock settings open failed: '..tostring(err)
 end
 local read,raw=pcall(f.read,f,1025);local closed=pcall(f.close,f)
 if not read or not closed then return {},'restock settings read/close failed' end
 local cfg,why=M.settings_json(raw)
 return cfg or {},why
end
function M.new(io,settings,state,configuration_error)
 io=io or {};settings=settings or {}
 local d=state or {enabled=false,active=false,busy=false,phase='idle',prompt=0,serial=0,status='disabled'}
 d.prompt=d.prompt or 0;d.serial=d.serial or 0;d.phase=d.phase or 'idle'
 d.configuration_error=configuration_error or d.configuration_error
 if d.configuration_error then d.enabled=false;d.active=false;d.status='configuration error: '..d.configuration_error end
 local t={state=d,io=io,settings=settings}
 local function now() return (io.now or os.time)() end
 local function view() return io.view() end
 -- Remember location for event classification only, never action authority.
 local function located(v) return not d.scope_unknown and v.room~=nil and v.area~=nil end
 local function fail(why,recoverable)
  d.active=false;d.resume_consent=false;d.reserved=false;d.fault=why;d.status='held: '..why
  if d.checkpoint and io.revoke_checkpoint and not d.checkpoint_revoked then d.checkpoint_revoked=true;pcall(io.revoke_checkpoint,d.checkpoint,d,why) end
  -- All unresolved sends, including resource transactions and routes, survive OFF.
  -- Only positively completed read-only/no-resource failures release this lease.
  if recoverable and not d.pending and not d.purchase and not d.dispatching and (not io.safe_release or io.safe_release(d)) then
   d.busy=false;d.owned_pause=false;d.route_owner=nil;d.route_serial=nil;d.route_destination=nil
   d.recoverable=true;d.status='FAULT (automatic trip stopped; explicit controls available): '..why
  end
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
  if not v.players_known or not same(v.players_room,d.return_room) then return false end
  for n in pairs(v.players or {}) do if n~=v.self_name then return false end end
  return true
 end
 local function intent(v)
  if not d.active then return false end
  if d.original_class and v.class~=d.original_class then return fail('operator class changed; no automatic restart') end
  if d.original_session~=nil and v.session~=d.original_session then return fail('session changed; no automatic restart') end
  if d.intent_epoch~=nil and v.intent_epoch~=d.intent_epoch then return fail('operator intent changed; no automatic restart') end
  if not v.connected or v.dead then return fail('disconnected/dead; no automatic restart') end
  if d.phase=='monitor' then return true end
  if d.phase=='drain' then
   if v.mode~='BASH' then return fail('operator changed BASH mode') end
  elseif d.phase=='pausing' then
   if (v.mode~='BASH' and not (d.dispatching and v.mode=='OFF')) or (located(v) and (not same(v.room,d.origin_room or d.return_room) or not same(v.area,d.origin_area or d.return_area))) then return fail('operator changed scope before owned pause') end
  elseif d.phase=='resume' or d.phase=='initial_wait' then
   if v.mode~='BASH' or (located(v) and (not same(v.room,d.return_room) or (not d.haven_mode and not same(v.area,d.return_area)))) then return fail('operator changed resumed mode/room/area') end
  elseif v.mode~='OFF' then return fail('operator changed paused intent') end
  if located(v) and d.phase~='monitor' and d.phase~='drain' and d.phase~='route' and d.phase~='pausing' and d.phase~='resume' and d.phase~='initial_wait' and d.phase~='return_check' and d.phase~='haven_exit' and d.phase~='haven_wait' and d.phase~='haven_return' then
   local expected=d.phase=='directory' and 12669 or d.candidate and d.candidate.room
   if not same(v.room,expected) or (d.stage_area~=nil and not same(v.area,d.stage_area)) then return fail('shopping room/area changed') end
  end
  if io.owned and not io.owned(d) then return fail('activity lease lost') end
  return true
 end
 local function commit(kind,command,fn)
  if d.dispatching or d.pending then return false end
  local v=view();if not intent(v) then return false end
  if not located(v) or not ready(v) then return false end
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
  if d.pending~=p then return false end
  p.transport_ok=true;p.finalized_prompt=d.prompt
  return true
 end
 local function query(kind,command) return commit(kind,command) end
 local function route(room,nextphase)
  d.after_route=nextphase;d.destination=tostring(room);d.phase='route'
  return commit('route',tostring(room),function(dest) return io.travel(dest) end)
 end
 local function returning()
  if not d.haven_mode then return route(d.return_room,'return_check') end
  if not d.resume_globe then return fail('Haven return intent revoked; remains OFF',true) end
  local v=view();d.last_shop_room=v.room;d.last_shop_area=v.area
  d.phase='haven_wait';d.haven_wait_at=d.haven_wait_at or now();d.status='Haven return waiting: full HP, full mana and readiness required'
  return true
 end
 local function nextkind()
  d.index=d.index+1;d.kind=kinds[d.index];d.candidates=nil;d.candidate=nil;d.tries=0
  while d.kind do local st=stock(d.kind);if not st or st.count<target[d.kind] then break end;d.index=d.index+1;d.kind=kinds[d.index] end
  if not d.enabled or not d.kind then return returning() end
  return route(12669,'directory')
 end
 local function choose()
  if not d.enabled then return returning() end
  d.tries=(d.tries or 0)+1
  local c=d.candidates and d.candidates[d.tries]
  if not c or d.tries>3 then return fail('no verified stocked affordable '..d.kind..' candidate (maximum 3)',true) end
  d.candidate=c;return route(c.room,'wares')
 end
 local function getbaseline()
  if not d.enabled then return returning() end
  local s=stock(d.kind);if not s or s.version==nil then return fail('authoritative stock version unavailable',true) end
  d.baseline_version=s.version;d.phase='baseline'
  return commit('baseline',d.kind,function(k) return io.query_stock(k) end)
 end
 local function afterpurchase()
  d.phase='readback'
  local s=stock(d.kind);d.readback_version=s and s.version
  return commit('readback',d.kind,function(k) return io.query_stock(k) end)
 end
 -- Permission is independent of current mode, GLOBE and saved preferences.
 function t.start()
  local context=view();if context.post_reset and (context.session==nil or context.scope_source_known~=true or type(context.class)~='string' or context.class=='' or context.room==nil or context.area==nil) then return false,'fresh native class/session/room source required after reset' end
  if d.configuration_error then return false,'configuration error: '..d.configuration_error end
  if d.dispatching then return false,'dispatch in progress' end
  if d.fault then return false,'unresolved fault requires reviewed recovery' end
  d.enabled=true
  if not d.active and not d.busy and not d.pending and not d.purchase then d.phase='monitor';d.active=true;d.status='enabled; waiting actual BASH and strict cache <200' end
  return true
 end
 function t.off()
  d.enabled=false
  if not d.busy and not d.pending and not d.purchase then
   -- Cancelling only restock before the handoff must not cancel prior GLOBE
   -- permission. Restore the same internally suppressed owner, never public ON.
   if d.phase=='drain' and d.resume_consent and d.resume_globe and io.restore_spawn then io.restore_spawn(d) end
   d.active=false;d.reserved=false;d.original_class=nil;d.original_session=nil;d.intent_epoch=nil;d.return_room=nil;d.return_area=nil;d.phase='idle';d.status='disabled; BASH unchanged'
  else d.status='disabled; finishing issued transaction and exact return only' end
  return true
 end
 function t.globe_off() d.resume_globe=false;return true end
 function t.user_stop(why)
  -- OFF always revokes intent, but an idle permission toggle is not a failed
  -- transaction. Never erase an existing fault or an idle-looking commitment.
  if d.fault or d.query_quarantine or d.pending or d.purchase or d.busy or d.dispatching or d.checkpoint or d.owned_pause or d.route_owner then return fail(d.fault or why or 'operator stopped BASH; resume revoked') end
  d.active=false;d.resume_consent=false;d.reserved=false;d.resume_globe=false
  d.original_class=nil;d.original_session=nil;d.intent_epoch=nil;d.return_room=nil;d.return_area=nil
  d.phase='idle';d.status='operator stopped BASH; permission requires ON'
  return true
 end
 function t.room_changed(room,area,borrowed)
  local full=room~=nil and area~=nil
  d.scope_unknown=not full
  local prior_room,prior_area=d.last_room or d.reservation_room or d.return_room,d.last_area or d.reservation_area or d.return_area
  if full then d.last_room=room;d.last_area=area end
  if not d.busy and not d.reserved then return true end
  if d.phase=='haven_exit' or d.phase=='haven_return' then
   local p=d.pending
   if p and full and ((p.kind=='haven_exit' and not same(room,p.room)) or (p.kind=='haven_return' and same(room,d.return_room))) then
    p.arrival_room=room;p.arrival_area=area;p.arrival_prompt=d.prompt
   end
   return true -- Wrong/partial arrival never settles issued transport.
  end
  if d.haven_mode and (d.phase=='return_check' or d.phase=='resume' or d.phase=='initial_wait') then
   if room~=nil and not same(room,d.return_room) then return fail('unexpected Haven room number') end
   return true -- Labels/area never authorize a private room.
  end
  local function mismatch(r,a) return (room~=nil and r~=nil and not same(room,r)) or (area~=nil and a~=nil and not same(area,a)) end
  if d.phase=='route' then
   if borrowed and d.pending and d.pending.kind=='route' then return true end
   if mismatch(prior_room,prior_area) then return fail('unexpected room/area change during route') end
   return true
  end
  if d.phase=='drain' then
   if room~=nil and io.walker_arriving and io.walker_arriving(room,area or prior_area or d.reservation_area) then
    if full then d.reservation_room=room;d.reservation_area=area end
    return true
   end
   if mismatch(d.reservation_room,d.reservation_area) then return fail('unexpected reservation room/area change') end
   return true
  end
  local expected=d.return_room;local expected_area=d.return_area
  if d.phase~='pausing' and d.phase~='return_check' and d.phase~='resume' and d.phase~='initial_wait' then expected=d.phase=='directory' and 12669 or d.candidate and d.candidate.room;expected_area=d.stage_area end
  if d.phase=='pausing' then expected=d.origin_room or expected;expected_area=d.origin_area or expected_area end
  if d.phase=='haven_wait' then expected=d.last_shop_room;expected_area=d.last_shop_area end
  if mismatch(expected,expected_area) then return fail('unexpected room/area change') end
  return true
 end
 function t.disconnect() return fail('disconnected; unresolved transaction retained') end
 function t.tick()
  if d.dispatching or d.pumping then return false end
  -- Even revoked consent cannot unsend a known route. Settle only location, never
  -- continue the itinerary, resume or release an unresolved purchase on this path.
  if not d.active then
   local p=d.pending;local v=view()
   if p and p.kind=='route' and p.transport_ok and located(v) and not v.travel_fault and v.travel_idle and same(v.room,d.destination) and d.prompt>p.prompt then d.pending=nil;d.route_settled=true end
   if p and (p.kind=='haven_exit' or p.kind=='haven_return') and p.transport_ok and p.arrival_room and located(v) and same(v.room,p.arrival_room) and ready(v) and d.prompt>p.arrival_prompt then d.pending=nil;d.haven_settled=true end
   return false
  end
  d.pumping=true
  local ok,res,why=pcall(function()
   local v=view();if not intent(v) then return false end
   if v.globe_resume_allowed==false then d.resume_globe=false end
   if d.trip_at and now()-d.trip_at>1800 then return fail('bounded shopping duty deadline exceeded') end
   if d.drain_at and d.phase=='drain' and now()-d.drain_at>600 then return fail('safe fight-clear/readiness gap not proven within 600 seconds') end
   local p=d.pending
   if p and now()-p.at>(p.kind=='route' and 300 or ((p.kind=='haven_exit' or p.kind=='haven_return') and 120 or 60)) then return fail('timeout: '..p.kind..'; no retry') end
   if not located(v) then return end -- unknown context holds; leases still expire
   d.last_room=v.room;d.last_area=v.area
   if p then
    if p.kind=='haven_exit' or p.kind=='haven_return' then
     if not p.transport_ok or not p.arrival_room or not same(v.room,p.arrival_room) or not ready(v) or d.prompt<=p.arrival_prompt then return end
     d.pending=nil;d.stage_area=v.area
     if p.kind=='haven_exit' then return nextkind() end
     d.return_area=v.area;d.return_ih=v.ih_evidence;d.return_item_version=v.item_version;d.phase='return_check'
    elseif p.kind=='initial summon' then
     if v.globe_fault then return fail('native initial summon fault; barrier retained') end
     if not v.globe_idle or v.globe_pool_ready==false then return end
     d.pending=nil;d.busy=false;d.route_owner=nil;d.route_serial=nil;d.route_destination=nil;d.checkpoint=nil;d.checkpoint_restored=nil;d.checkpoint_revoked=nil;if io.release then io.release(d) end
     d.original_class=nil;d.original_session=nil;d.intent_epoch=nil;d.reserved=false;d.phase=d.enabled and 'monitor' or 'idle';d.active=d.enabled;d.pending_restock=false;d.owned_pause=false;d.trip_at=nil;d.status='exact return and saved GLOBE restored';return true
    elseif p.kind=='route' then
     if v.travel_refusal and v.travel_refusal.kind=='find_cooldown' and v.travel_idle then
      d.pending=nil;return fail(v.travel_refusal.reason,true)
     end
     if v.travel_fault then return fail('route fault: '..tostring(v.travel_fault)) end
     if v.travel_idle and same(v.room,d.destination) and d.prompt>p.prompt then
      d.pending=nil;d.phase=d.after_route;d.stage_area=v.area
      if d.phase=='return_check' then
       if not d.haven_mode and not same(v.area,d.return_area) then return fail('return area mismatch') end
       d.return_ih=v.ih_evidence;d.return_item_version=v.item_version
      end
     else return end
    elseif p.kind=='baseline' or p.kind=='readback' then
     local s=stock(d.kind);local old=p.kind=='baseline' and d.baseline_version or d.readback_version
     if d.prompt<=p.prompt or not s or s.version==nil or s.version==old or s.pending then return end
     d.pending=nil
     if p.kind=='baseline' then d.phase='inventory_before';d.before=s.count;if not d.enabled then return returning() end
     else
      -- IC is absolute. BUY text alone cannot increase this count. INCALL may leave
      -- excess carried pills at cap; the cache itself is the only target proof.
      if s.count<d.purchase.expected or s.count>d.purchase.maximum then return fail('cache readback outside verified purchase bounds') end
      d.purchase.cache_after=s.count;d.phase='inventory_after'
     end
    elseif d.prompt>p.prompt and p.complete then
     if p.kind=='directory' or p.kind=='wares' or p.kind=='inventory_before' then d.last_readonly=p end
     d.pending=nil
     if not d.enabled and not d.purchase then return returning() end
     if p.kind=='directory' then
      if p.bad or not p.header or not p.divider or #p.rows==0 then return fail('unproved directory framing/rows',true) end
      table.sort(p.rows,function(a,b) if a.price==b.price then return tonumber(a.room)<tonumber(b.room) end;return a.price<b.price end)
      d.candidates=p.rows;d.tries=0;return choose()
     elseif p.kind=='wares' then
      if p.bad or not p.header or not p.proprietor or not p.divider then return fail('unproved wares framing',true) end
      table.sort(p.rows,function(a,b) return a.price<b.price end)
      local row=p.rows[1];local s=stock(d.kind)
      local n=s and math.ceil((target[d.kind]-s.count)/(d.kind=='health' and 50 or 1)) or 0
      if not row or row.stock<n or n<=0 or row.price~=d.candidate.price then
       if n<=0 and s then return nextkind() end
       return choose()
      end
      d.item=row;return getbaseline()
     elseif p.kind=='inventory_before' then
      if not p.gold then return fail('carried gold not proven',true) end
      local s=stock(d.kind)
      if not s or s.count~=d.before then return fail('cache changed after baseline; purchase cancelled',true) end
      local n=math.ceil((target[d.kind]-d.before)/(d.kind=='health' and 50 or 1))
      if n<=0 then return nextkind() end
      if n>d.item.stock then return fail('insufficient native wares stock',true) end
      local cost=n*d.item.price
      if cost>p.gold then return fail('insufficient carried gold; no bank/org funds',true) end
      d.purchase={kind=d.kind,count=n,cost=cost,gold_before=p.gold,before=d.before,expected=target[d.kind],maximum=d.before+n*(d.kind=='health' and 50 or 1),item=d.item.id}
      d.phase='buy'
     elseif p.kind=='buy' then
      if d.kind=='health' then
       if not view().post_reset and (not p.receipt or p.receipt.cost~=d.purchase.cost or p.receipt.sips~=d.purchase.count*50) then return fail('health purchase receipt mismatch') end
       return afterpurchase()
      end
      -- No invented anabiotic purchase ACK. A real subsequent prompt only schedules
      -- INCALL; fresh absolute IC and wallet readback settle the resource barrier.
      d.phase='incall';return query('incall','incall')
     elseif p.kind=='incall' then return afterpurchase()
     elseif p.kind=='inventory_after' then
      if p.gold==nil or p.gold~=d.purchase.gold_before-d.purchase.cost then return fail('wallet readback mismatch; transaction retained') end
      if view().post_reset then
       local purchase=d.purchase;purchase.outcome='CURRENT_POSTCONDITION_OBSERVED_UNATTRIBUTED';purchase.settled=false
       d.postcondition_history=d.postcondition_history or{};d.postcondition_history[#d.postcondition_history+1]=purchase
       d.last_postcondition=purchase;d.purchase=nil;d.enabled=false;d.active=false;d.resume_consent=false;d.resume_globe=false
       if d.checkpoint and io.revoke_checkpoint then io.revoke_checkpoint(d.checkpoint,d,'post-reset objective observed; no old automation restore');d.checkpoint_revoked=true end
       if io.release then io.release(d)end
       d.busy=false;d.reserved=false;d.owned_pause=false;d.phase='idle';d.status='current stock/wallet postcondition observed; sent BUY remains UNSETTLED; no return/resume'
       return true
      end
      d.last_purchase=d.purchase;d.purchase=nil;return nextkind()
     end
    else return end
   end
   v=view();if not intent(v) then return false end
   -- Graceful OFF does not revoke the trip's resume grant. Settle any pending
   -- query first, then bypass remaining discovery and all unissued purchases.
   if not d.enabled and d.busy and not d.pending and not d.purchase and d.phase~='route' and d.phase~='return_check' and d.phase~='resume' and d.phase~='initial_wait' and d.phase~='haven_exit' and d.phase~='haven_wait' and d.phase~='haven_return' then return returning() end
   if not d.enabled and d.phase=='buy' and not d.pending then d.purchase=nil;return returning() end
   if d.phase=='monitor' then
    if not d.enabled or v.mode~='BASH' then return end
    if not class_known(v) or v.room==nil or v.area==nil then return end
    local h,a=stock('health'),stock('anabiotic')
    if not h or not a or h.pending or a.pending or (h.count>=200 and a.count>=200) then return end
    d.need={health=h.count<200,anabiotic=a.count<200};d.phase='drain';d.reserved=true
    d.return_room=nil;d.return_area=nil;d.reservation_room=v.room;d.reservation_area=v.area;d.checkpoint=nil;d.checkpoint_restored=nil;d.checkpoint_revoked=nil
    d.status='low cache; reserving next hop/spawn, finishing current NPC'
    d.original_class=v.class;d.original_session=v.session;d.intent_epoch=v.intent_epoch
    local desired=v.globe_desired;if desired==nil then desired=v.globe_armed end
    d.resume_globe=desired==true and v.globe_resume_allowed~=false;d.original_globe=d.resume_globe;d.resume_consent=true
    d.haven_mode=d.resume_globe and settings.globe_haven_return==true and type(settings.haven_room)=='string' and settings.haven_room:match('^[1-9]%d*$')~=nil
    d.haven_room=d.haven_mode and settings.haven_room or nil;d.haven_wait_at=nil
    d.drain_at=now();d.pending_restock=true
   end
   if d.phase=='drain' then
    -- Suppress only uncommitted future spawn intent. Native committed recovery
    -- continues under its own owner; the next drain tick suppresses it afterward.
    if io.disarm_spawn then io.disarm_spawn(d) end
    v=view()
    if d.drain_at and now()-d.drain_at>600 then return fail('safe fight-clear/readiness gap not proven within 600 seconds') end
    -- A pending walker hop and its arrival/IH barrier must settle before freezing.
    if io.walker_arriving and io.walker_arriving(v.room,v.area) then d.reservation_room=v.room;d.reservation_area=v.area end
    if not same(v.room,d.reservation_room) or not same(v.area,d.reservation_area) then return fail('unexpected reservation room/area changed') end
    if io.walker_ready and not io.walker_ready(d) then return end
    if not v.empty or not v.room_known or not ready(v) then return end
    if not d.enabled then return t.off() end
    d.origin_room=v.room;d.origin_area=v.area;d.return_room=d.haven_room or v.room;d.return_area=d.haven_mode and nil or v.area;d.departure_players=v.players
    d.resume_master=v.upkeep_master==true;d.globe_rearmed=nil
    if io.acquire and io.acquire(d)==false then return fail('another activity owns client') end
    if not d.active or not d.resume_consent or not d.enabled or not intent(view()) then if io.release then io.release(d) end;return false end
    d.busy=true;d.trip_at=now();d.phase='pausing'
    if d.haven_mode and io.walker_active and io.walker_active() then return fail('Haven GLOBE handoff cannot borrow an active walker',true) end
    if not d.haven_mode and io.checkpoint then
     d.capturing_checkpoint=true
     local good,cp,why=pcall(io.checkpoint,d)
     d.capturing_checkpoint=nil
     if not good then return fail('walker checkpoint error: '..tostring(cp)) end
     if cp==nil then return fail('walker checkpoint refused: '..tostring(why)) end
     if cp~=false then
      if cp.lease~=d or not same(cp.room,d.return_room) or not same(cp.area,d.return_area) then return fail('walker checkpoint lease/anchor mismatch') end
      d.checkpoint=cp
     end
    end
    if not d.active or not d.resume_consent then
     if d.checkpoint and io.revoke_checkpoint and not d.checkpoint_revoked then d.checkpoint_revoked=true;pcall(io.revoke_checkpoint,d.checkpoint,d,'scope revoked during checkpoint') end
     return false
    end
    if not intent(view()) then return false end
    d.dispatching=true
    local good,result=pcall(io.pause);d.dispatching=false
    if not good or result==false or view().mode~='OFF' then return fail('could not pause offense') end
    if not d.resume_consent or not d.active then return false end
    d.owned_pause=true;d.original_mode='BASH';d.paused_at=now();d.index=0
    if d.haven_mode and same(v.room,d.haven_room) then
     d.phase='haven_exit';d.status='Haven exit pending';return query('haven_exit','exit haven')
    end
    return nextkind()
   elseif d.phase=='haven_wait' then
    if not d.resume_globe then return fail('Haven return intent revoked; remains OFF',true) end
    if now()-(d.haven_wait_at or now())>120 then return fail('full HP/mana not proven for Haven return',true) end
    if not same(v.room,d.last_shop_room) or not same(v.area,d.last_shop_area) then return fail('Haven return waiting scope changed',true) end
    if not v.full_resources or not ready(v) then return end
    d.phase='haven_return';d.status='Haven return pending: awaiting actual configured Room.Info';return query('haven_return','return to haven')
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
    if not same(v.room,d.return_room) or (not d.haven_mode and not same(v.area,d.return_area)) then return fail('return room/area mismatch') end
    if not d.resume_consent then return fail('resume consent revoked') end
    if not safeplayers(v) or v.players==d.departure_players then return fail('return blocked: fresh solo player list required; stays OFF') end
    if not ready(v) then return end
    d.phase='resume';d.dispatching=true
    local good,result=pcall(io.resume,d.resume_master);d.dispatching=false
    if not d.active or not d.resume_consent then return false end
    if not good or view().mode~='BASH' then return fail('resume failed') end
    d.status='BASH restored; awaiting genuine fresh return IH/recovery'
   elseif d.phase=='resume' then
    if not safeplayers(v) then return fail('players changed before checkpoint restore') end
    if not ready(v) or v.mounted or not v.room_known or v.ih_evidence==nil or v.ih_evidence==d.return_ih or v.item_version==d.return_item_version then return end
    if d.checkpoint and not v.empty then return end -- finish a newly arrived NPC before walker restoration
    if d.checkpoint and not d.checkpoint_restored then
     if not io.restore_checkpoint then return fail('walker restore API missing') end
     d.dispatching=true;local ok,result,why=pcall(io.restore_checkpoint,d.checkpoint,d);d.dispatching=false
     if not d.active or not d.resume_consent then return false end
     if ok and result==false and type(why)=='string' and why:match('^awaiting ') then return end
     if not ok or result~=true then return fail('walker checkpoint restore refused: '..tostring(why or result)) end
     d.checkpoint_restored=true
    end
    if d.resume_globe and not d.globe_rearmed then
     if not v.hp_percent or v.hp_percent<80 then return end
     d.dispatching=true;local good,result=pcall(io.arm_globe);d.dispatching=false
     if not d.active or not d.resume_consent then return false end
     if view().globe_resume_allowed==false then d.resume_globe=false end
     if not good or (result==false and d.resume_globe) then return fail('GLOBE could not safely rearm') end
     d.globe_rearmed=result~=false and d.resume_globe or nil
    end
    v=view();if not intent(v) then return false end
    if v.globe_resume_allowed==false then d.resume_globe=false end
    if d.resume_globe then
     if not v.globe_armed then return fail('saved GLOBE intent could not be restored') end
     if v.globe_pool_ready==false then return end
     if v.empty then
      if not v.globe_idle then return end
      d.initial_summon=true;d.phase='initial_wait';d.pending={kind='initial summon',at=now(),prompt=d.prompt};d.dispatching=true
      local sent,r=pcall(io.summon);d.dispatching=false
      if not sent or r==false then return fail('initial summon transport unknown') end
      return true
     end
    end
    d.original_class=nil;d.original_session=nil;d.intent_epoch=nil;d.busy=false;d.reserved=false;d.route_owner=nil;d.route_serial=nil;d.route_destination=nil;if io.release then io.release(d) end
    d.phase=d.enabled and 'monitor' or 'idle';d.active=d.enabled;d.pending_restock=false;d.owned_pause=false;d.trip_at=nil;d.checkpoint=nil;d.checkpoint_restored=nil;d.checkpoint_revoked=nil;d.status='exact return and original BASH intent restored'

   end
  end)
  d.pumping=false
  if not ok then return fail('controller error: '..tostring(res)) end
  return res,why
 end
 function t.text(line)
  local p=d.pending;if not d.active or not p or type(line)~='string' or d.fault then return end
  if p.kind=='route' or p.kind=='initial summon' or p.kind=='haven_exit' or p.kind=='haven_return' then return end -- native owners enforce their own finite leases
  p.lines=p.lines+1
  local inventory=p.kind=='inventory_before' or p.kind=='inventory_after'
  -- Mudlet receives logical inventory body lines, not the GUI's wrapped rows.
  -- A genuine 116-item holding list exceeds the normal protocol-line bound.
  -- Permit bounded opaque body text only after the native inventory headers;
  -- never parse a large body as balance/receipt/cache evidence. Other protocols
  -- retain their strict 1000-byte line limit, including BUY and shop listings.
  if inventory then
   p.bytes=(p.bytes or 0)+#line
   if p.bytes>65536 then return fail('bounded response exceeded') end
  end
  if p.lines>300 then return fail('bounded response exceeded') end
  if #line>1000 then
   if not inventory or not p.inventory_body or #line>16384 then return fail('bounded response exceeded') end
   p.large_body_lines=(p.large_body_lines or 0)+1
   if p.large_body_lines>16 then return fail('bounded response exceeded') end
   return -- opaque, ignored inventory contents; no authoritative observations
  end
  if inventory then
   if line=='You are wielding:' then p.inventory_header=true;p.inventory_body=false
   elseif p.inventory_header and (line=='You are holding:' or line=='You are wearing:') then p.inventory_body=true
   elseif line=='Summary:' then p.inventory_body=false end
  end
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
   elseif p.header and p.divider then
    local row=waresrow(d.kind,line)
    if row then
     for _,old in ipairs(p.rows) do if old.id==row.id then p.bad=true end end
     p.rows[#p.rows+1]=row;if #p.rows>100 then return fail('too many wares rows') end
    end
   end
  elseif p.kind=='inventory_before' or p.kind=='inventory_after' then
   if view().post_reset then
    if not p.transport_ok or d.dispatching then return end
    local stage=p.inventory_stage
    if line=='You are wielding:' and not stage then p.inventory_stage='hands'
    elseif line=='You are holding:' and stage=='hands' then p.inventory_stage='holding'
    elseif line=='You are wearing:' and stage=='holding' then p.inventory_stage='wearing'
    elseif line=='Summary:' and stage=='wearing' then p.inventory_stage='summary'
    elseif stage=='summary' and line:match('^You have %d+ types of items in the cache%.$') then p.inventory_stage='cache'
    elseif stage=='cache' and line:match('^You possess %d+ items%.$') then p.inventory_stage='items' end
    if p.inventory_stage~='items' then return end
   end
   local n=line:match('^You are carrying (%d+) gold sovereigns%.$')
   if n then n=integer(n);if p.gold~=nil then return fail('ambiguous inventory balance') end;p.gold=n;p.complete=n~=nil end
  elseif p.kind=='buy' and d.kind=='health' and not view().post_reset then
   local cost,sips=line:match('^You pay (%d+) gold sovereigns to add (%d+) sips of an elixir of health to your fluidcache%.$')
   if cost then if p.receipt then return fail('duplicate health receipt') end;p.receipt={cost=integer(cost),sips=integer(sips)};p.complete=true end
  end
 end
 function t.prompt()
  d.prompt=d.prompt+1
  local p=d.pending
  if p and view().post_reset and (p.kind=='buy' or p.kind=='incall') then
   if p.transport_ok==true and not d.dispatching and d.prompt>(p.finalized_prompt or math.huge) then p.complete=true end
  elseif p and (p.kind=='incall' or (p.kind=='buy' and d.kind=='anabiotic')) then p.complete=true end
  return t.tick()
 end
 return t
end

-- Native snapshot adapter: all observations come from the existing native owners.
function M.adapter(c,api)
 api=api or c.restock_api or _G
 local function connected()
  if api.connected then return api.connected()==true end
  if not api.getConnectionInfo then return false end
  local ok,_,_,tcp=pcall(api.getConnectionInfo);return ok and tcp==true
 end
 local function view()
  if c.travel and c.travel.io and c.travel.io.mount_deferred then c.travel.io.mount_deferred() end
  local s=c.current or {};local p=s.player or {};local r=c.runner or {};local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {};local g=c.elemental_recovery or {};local cd=c.containers_data or {};local tr=c.travel_owner or {};local root=r.root or c.root or {}
  local q=g.pool or {};local exhausted=false
  local terminal=c.travel_module and c.travel_module.terminal_globe_exhaustion
  if terminal~=nil then
   if type(terminal)=='function' then local ok,v=pcall(terminal,c);exhausted=ok and v==true end
  else
   -- Legacy standalone adapters have no travel module. Only their fully known
   -- pool can qualify; missing helpers never infer revoked inventory authority.
   local gp=g.pending
   local unsent=gp and gp.phase==g.phase and ((g.phase=='waiting' and gp.kind==nil) or (g.phase=='normal' and gp.kind==nil))
   exhausted=g.fault=='all carried globes exhausted' and g.armed==false and not g.committed and not g.dispatching and (not gp or unsent) and q.enabled==true and q.known==true and q.ever_owned==true and q.query==nil and not q.dispatching and type(q.owned)=='table' and type(q.exhausted)=='table'
   if exhausted then
    local count=0
    for key,value in pairs(q.owned) do
     count=count+1
     local number=tonumber(key)
     if count>32 or type(key)~='string' or not number or number<=0 or number~=math.floor(number) or string.format('%.0f',number)~=key or value~=true or q.exhausted[key]~=true then exhausted=false;break end
    end
   end
  end
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
  if room.id==nil or room.area==nil or (c.restock_data or {}).scope_unknown then rd=false end
  local known=ih and same(ih.room_id,room.id) and not ih.pending and ih.responded==true and ih.items==room.items and (room.item_version or 0)>(ih.start_version or math.huge)
  local empty=known==true
  for _,it in pairs(room.items or {}) do if not c.areas or type(c.areas.navigation_blocked)~='function' or c.areas.navigation_blocked(s,it) then empty=false end end
  local pol=s.policy or {}
  local xp=c.xp_globe_cutoff;local globe_allowed=not(xp and xp.enabled and xp.triggered)
  local desired=g.desiredOnCurrent;if desired==nil then desired=g.armed==true end
  -- A closed exhausted owner is not authority to restore stale GLOBE intent.
  if exhausted and desired==true and not (q.enabled==true and q.known==true and not q.query) then rd=false end
  return {post_reset=c.operator_abandoned_jobs==true,scope_source_known=s.class_observations and s.class_observations.class and s.class_observations.class.value==p.class and s.class_observations.cache and s.class_observations.cache['Char.Status'] and s.class_observations.cache['Char.Status'].source=='Char.Status',full_resources=(tonumber(p.maxhp) or 0)>0 and (tonumber(p.maxmana) or 0)>0 and (tonumber(p.hp) or 0)>=(tonumber(p.maxhp) or math.huge) and (tonumber(p.mana) or 0)>=(tonumber(p.maxmana) or math.huge),globe_desired=desired,globe_resume_allowed=globe_allowed,class=p.class,globe_armed=g.armed==true,upkeep_master=b.master==true,globe_pool_ready=not (c.elementals and c.elementals.pool_enable) or (q.enabled==true and q.known==true and not q.query),mode=c.mode,room=room.id,area=room.area,session=(c.operator_abandoned_jobs and c.haven_session_token) or c.session_generation or s.session_generation or s.session_id,intent_epoch=c.restock_intent_epoch,ih_evidence=ih,item_version=room.item_version,connected=connected() and yes(s.connected),dead=yes(p.dead) or (tonumber(p.hp) or 0)<=0,ready=rd,blocked=blocked,empty=empty,room_known=known==true,mounted=p.mounted~=false and tonumber(p.mounted)~=0,hp_percent=(tonumber(p.maxhp) or 0)>0 and p.hp/p.maxhp*100 or nil,players_known=pol.players_known==true,players_room=pol.players_room,players=pol.players,self_name=pol.self_name,
   supplies_busy=c.supplies_data and c.supplies_data.pending,globes_exhausted=exhausted,globe_fault=g.fault,travel_refusal=tr.refusal,travel_fault=tr.fault or tr.follow_fault,travel_idle=tr.phase=='idle' and not (tr.pending or tr.dispatching or tr.intent or tr.route or tr.follow_pending or tr.follow_due or tr.recall_due),globe_idle=not g.pending and not g.committed and not g.fault and (g.phase==nil or g.phase=='idle')}
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
  safe_release=function() local v=view();return not v.blocked and v.travel_idle end,
  walker_active=function() return ((c.current or {}).walker or {}).active==true end,
  owned=function(d) return not c.user_activity or c.user_activity==d end,
  walker_arriving=function(room,area)
   local w=(c.current or {}).walker or {}
   return w.active==true and not w.fault and same(w.area,area) and ((w.pending and same(w.pending.to,room)) or (w.arrival_hold==true and not w.pending and same(((c.current or {}).room or {}).id,room))) or false
  end,
  walker_ready=function(d)
   local walker=c.walker_boot or c.walker_module
   if walker and walker.restock_ready then return walker.restock_ready(c,d) end
   local w=(c.current or {}).walker or {}
   return not (w.active or w.pending or w.dispatching or w.arrival or w.fault),'walker suspension API unavailable'
  end,
  checkpoint=function(d)
   local w=(c.current or {}).walker or {}
   -- Stationary BASH has no walker consent to borrow. An inactive checkpoint
   -- would incorrectly interlock saved GLOBE restoration on the return.
   if not w.active and not (w.pending or w.dispatching or w.arrival_hold or w.fault or w.restock_checkpoint) then return false end
   local walker=c.walker_boot or c.walker_module
   if walker and walker.restock_suspend then return walker.restock_suspend(c,d) end
   if w.active or w.pending or w.dispatching or w.arrival or w.fault then return nil,'walker suspension API unavailable' end
   return false -- explicit stationary case, distinct from a failed checkpoint
  end,
  restore_checkpoint=function(cp,d)
   local walker=c.walker_boot or c.walker_module
   if walker and walker.restock_resume then return walker.restock_resume(c,cp,d) end
   return false,'walker suspension API unavailable'
  end,
  revoke_checkpoint=function(cp,d,why) local walker=c.walker_boot or c.walker_module;if walker and walker.restock_cancel then return walker.restock_cancel(c,cp,d,why) end end,
  acquire=function(d) if c.user_activity and c.user_activity~=d then return false end;c.user_activity=d;return true end,
  release=function(d) if c.user_activity==d then c.user_activity=nil end end,
  disarm_spawn=function(d)
   local g=c.elemental_recovery
   if not g or g.committed or g.dispatching or g.fault then return false end
   local p=g.pending
   if p then
    -- Unsent normal/waiting intent is cancellable. A sent read-only recovery
    -- probe settles only after its real ACK and later prompt. Never erase an
    -- unknown phase, failed transport or committed DRAIN/SUMMON.
    local unsent=(g.phase=='normal' or g.phase=='waiting') and p.phase==g.phase and not p.kind
    local readback=g.phase=='probe' and p.phase=='probe' and p.kind=='recovery' and p.ack and p.ready_prompt
    if not unsent and not readback then return false end
    g.pending=nil;g.phase='idle'
   end
   if g.armed then d.spawn_owner=g;d.spawn_suppressed=true end
   g.armed=false
   return true
  end,
  restore_spawn=function(d)
   local g=c.elemental_recovery;local v=view()
   if not d.spawn_suppressed or g~=d.spawn_owner or not d.resume_globe or not d.resume_consent or g.fault or g.pending or g.committed or g.dispatching then return false end
   if not v.connected or v.dead or v.mode~='BASH' or v.class~=d.original_class or v.session~=d.original_session or v.intent_epoch~=d.intent_epoch or not same(v.room,d.reservation_room) or not same(v.area,d.reservation_area) or v.globe_resume_allowed==false then return false end
   g.armed=true;d.spawn_suppressed=nil;return true
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
  travel=function(dest)
   if not c.travel or not c.travel.request then return false end
   local d=c.restock_data;local tr=c.travel_owner
   -- Publish route identity before native request: synchronous Room.Info/ACK
   -- callbacks may arrive before request() returns. Native destination must still
   -- match before movement_borrowed can recognize the lease.
   if d and tr then d.route_owner=tr;d.route_serial=tr.serial;d.route_destination=tostring(dest) end
   local result=c.travel.request('pt',dest)
   if d and tr then d.route_serial=tr.serial;d.route_destination=tr.destination end
   return result
  end,
  query_stock=function(k) if not c.supplies or not c.supplies.audit then return false end;return c.supplies.audit(c,nil,true,k=='health' and 'fluidcache' or 'ic') end,
  send=function(cmd) return (c.restock_sender or api.send)(cmd) end,
  resume=function(master) c.current.buffs=c.current.buffs or {};c.current.buffs.master=master==true;return api.combat_v2_set_mode('BASH') end,
  arm_globe=function()
   local v=view();if not class_known(v) or v.globe_resume_allowed==false or v.mode~='BASH' or not same(v.room,c.restock_data and c.restock_data.return_room) then return false end
   if api.combat_v2_globe('on')==false then return false end
   if c.elementals and c.elementals.pool_enable then return c.elementals.pool_enable(c,true) end
   return true
  end,
  summon=function()
   local g=c.elemental_recovery
   if view().globe_resume_allowed==false or not g or not c.elementals or not c.elementals.service or not g.armed or g.pending or g.committed or g.fault then return false end
   -- Delegate the single authorized initial summon to the native commit/receipt
   -- owner. Never bypass its ledger or choose/probe/drain a globe ourselves.
   g.pending={phase='normal',started=(api.getEpoch or api.clock or os.time)()};g.phase='normal'
   c.elementals.service(c)
   return not g.fault
  end}
end

-- Never-issued idle OFF disconnect is cancellation, not transaction failure.
-- Strict schema/roots; do not call adapter.view (it plans defenses).
function M.idle_disconnect_clear(c,d)
 if type(c)~='table'or c.restock_data~=d or not c.restock_controller or c.restock_controller.state~=d then return false end
 local s=c.current;local r=c.runner
 if not s or not r or r.state~=s or c.mode~='OFF'or s.mode~='OFF'or r.mode~='OFF'then return false end
 local allowed={enabled=true,active=true,busy=true,phase=true,prompt=true,serial=true,status=true,reserved=true,resume_consent=true,resume_globe=true,scope_unknown=true,last_room=true,last_area=true}
 for k in pairs(d)do if not allowed[k]then return false end end
 if d.serial~=0 or d.enabled~=false or d.active~=false or d.busy~=false or d.phase~='idle' or d.reserved~=nil and d.reserved~=false or d.resume_consent~=nil and d.resume_consent~=false or d.resume_globe~=nil and d.resume_globe~=false or d.scope_unknown~=nil and d.scope_unknown~=false then return false end
 if type(d.prompt)~='number'or d.prompt<0 or d.prompt%1~=0 or type(d.status)~='string'then return false end
 local fields={'pending','purchase','fault','query','waiting','busy','dispatching','action_dispatching','actionDispatching','physical_dispatch','physical_transport','transport_unknown','transportUnknown','transport_commit','transportCommit','unknown_commit','committed','transport_barrier','transportBarrier','barrier','txn','deposit','resource_pending','eq_pending','movement_pending','arrival','arrival_hold','route','intent','follow_pending','follow_due','recall_due','follow_fault','physical_commit','movement_commit','drain_pending','ink_pending','pumping','route_pausing','capturing_checkpoint','find_quarantine','haven_refresh','restock_checkpoint','checkpoint','reservation','lease','return_ih','resource','stopping','ability_listing','native_listing','ab','racial_frame','def_metadata','text_def_list'}
 local function clear(o)
  if o==nil then return true end;if type(o)~='table'then return false end
  for _,k in ipairs(fields)do local v=rawget(o,k);if v~=nil and v~=false then return false end end
  for _,k in ipairs({'transport_barriers','transportBarriers','native_pending'})do local v=rawget(o,k);if v~=nil and v~=false and(type(v)~='table'or next(v)~=nil)then return false end end
  return true
 end
 local owners={controller=c,current=s,runner=r,travel=c.travel_owner,buffs=s.buffs,walker=s.walker,mental=s.mental,defense=s.defense,emergency=c.emergency_numb,globe=c.elemental_recovery,containers=c.containers_data,supplies=c.supplies_data,lunch=c.lunch_data,lunch_duty=c.lunch_duty,tattoo=c.tattoo_owner,tour=c.tour and c.tour.state,haven=c.haven_handoff,physical=c.physical,current_physical=s.physical,runner_physical=r.physical,fallback=c.fallback,runner_fallback=r.fallback,shared=c.shared,current_shared=s.shared,runner_shared=r.shared}
 for _,o in pairs(owners)do if not clear(o)or not clear(o.root)then return false end end
 return true
end
local function disconnect_wrapper(c,d,prior,stop)
 return function(...)
  if M.idle_disconnect_clear(c,d)then return stop('disconnected while never-issued idle OFF')end
  return prior(...)
 end
end
local function closure_value(fn,wanted)
 for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==wanted then return v end end
end
local function normalized_dump(fn)
 -- 5.4 strips source metadata; 5.1 has no strip flag, so remove only its
 -- root prototype source string (not instructions, constants or upvalues).
 local raw=string.dump(fn,true)
 if raw:byte(5)==0x51 then
  local size=raw:byte(9);local little=raw:byte(7)==1;local n=0
  for i=1,size do local index=little and (12+size+1-i)or(12+i);n=n*256+raw:byte(index)end
  raw=raw:sub(1,12)..string.rep(string.char(0),size)..raw:sub(13+size+n)
 end
 return raw
end
local function authentic_leaf(fn,expected,first,last)
 if type(fn)~='function'or not debug or not debug.getinfo or not string.dump then return false end
 local info=debug.getinfo(fn,'S');if info.what~='Lua'or info.linedefined~=first or info.lastlinedefined~=last then return false end
 return normalized_dump(fn)==normalized_dump(expected)
end
function M.fix_idle_disconnect(c)
 local t=c.restock_controller;local d=c.restock_data
 if not t or t.state~=d then return false,'restock canonical owner required'end
 local prior=t.disconnect;local stop=t.user_stop
 local probe=disconnect_wrapper(c,d,prior,stop)
 if type(prior)=='function'and debug.getinfo(prior,'S').what=='Lua'and string.dump(prior)==string.dump(probe)then
  if closure_value(prior,'c')~=c or closure_value(prior,'d')~=d or closure_value(prior,'stop')~=stop then return false,'restock disconnect wrapper identity mismatch'end
  prior=closure_value(prior,'prior')
 end
 -- Reference factory is pure: separate unpublished tables, no IO methods
 -- invoked. Never replace or initialize the retained live owner/state/adapter.
 local reference=M.new({}, {}, {})
 if not authentic_leaf(prior,reference.disconnect,272,272)or not authentic_leaf(stop,reference.user_stop,225,233)or closure_value(prior,'fail')~=closure_value(stop,'fail')or closure_value(stop,'d')~=d then return false,'restock disconnect/user_stop prototype or captured owner mismatch'end
 t.disconnect=disconnect_wrapper(c,d,prior,stop)
 c.restock_disconnect_status='bound never-issued idle-OFF cancellation; real transactions retain original fail'
 return true
end

function M.attach(c,settings)
 if c.restock_controller then local ok,why=M.fix_idle_disconnect(c);if not ok then return nil,why end;return c.restock_controller end
 if c.restock_data and (c.restock_data.busy or c.restock_data.pending or c.restock_data.purchase) then return nil,'unfinished restock owner retained' end
 local old=c.restock_data;local api=c.restock_api or _G
 for _,k in ipairs({'tempRegexTrigger','tempPromptTrigger','tempTimer','registerAnonymousEventHandler','killTrigger','killTimer','killAnonymousEventHandler'}) do if type(api[k])~='function' then return nil,'Mudlet API unavailable: '..k end end
 if settings~=nil then c.restock_settings_error=nil end -- explicit reviewed valid configuration
 if settings==nil then settings=c.restock_settings;if settings==nil then local why;settings,why=M.read_settings(api);c.restock_settings_error=why end end
 c.restock_settings=settings or {}
 local t=M.new(M.adapter(c,api),c.restock_settings,nil,c.restock_settings_error);c.restock_controller=t;c.restock_data=t.state;t.handles={};t.attached=true
 local function add(kind,id) assert(handle(id),'invalid '..kind..' registration ID');t.handles[#t.handles+1]={kind,id} end
 local ok,why=pcall(function()
  add('trigger',api.tempRegexTrigger('^.*$',function() t.text(api.line or line or '') end))
  add('trigger',api.tempPromptTrigger(function() t.prompt() end))
  add('event',api.registerAnonymousEventHandler('sysDisconnectionEvent',function() t.disconnect() end))
  -- Installed after core ingestion: inspect genuine Room.Info, never replay GMCP.
  add('event',api.registerAnonymousEventHandler('gmcp.Room.Info',function()
   local raw=(api.gmcp or _G.gmcp or {}).Room
   local info=raw and raw.Info
   if type(info)=='table' then t.room_changed(info.num,info.area,M.movement_borrowed(c))
   else local v=t.io.view();t.room_changed(v.room,v.area,M.movement_borrowed(c)) end
  end))
  local function tick()
   if not t.attached then return end
   t.timer=nil;t.tick()
   local good,id=pcall(api.tempTimer,1,tick)
   if not good or not handle(id) then t.user_stop();return end
   t.timer=id
  end
  local id=api.tempTimer(1,tick);assert(handle(id),'invalid timer registration ID');t.timer=id
 end)
 if not ok then t.state.active=false;M.detach(c);c.restock_data=old;return nil,tostring(why) end
 local fixed,reason=M.fix_idle_disconnect(c);if not fixed then return nil,reason end
 -- No legacy owner is retired here. Parent migration must retire it only idle.

 return t
end
function M.user_stop(c)
 c.restock_intent_epoch=(c.restock_intent_epoch or 0)+1
 if c.restock_controller then return c.restock_controller.user_stop() end
 return true
end
function M.busy(c) local d=c.restock_data;return d and (d.busy or d.pending~=nil or d.purchase~=nil) or false end
function M.movement_reserved(c) local d=c.restock_data;return d and (d.reserved==true or M.busy(c)) or false end
function M.owns_transition(c)
 local d=c.restock_data
 if not d or not d.active or not d.resume_consent or d.fault or c.user_activity~=d then return false end
 if d.route_pausing and M.movement_borrowed(c) then return true end
 if not d.dispatching then return false end
 return d.phase=='pausing' or (d.phase=='route' and d.pending and d.pending.kind=='route') or (d.phase=='resume' and not d.purchase and not d.pending)
end
function M.movement_borrowed(c)
 local d=c.restock_data;local tr=c.travel_owner
 return not not(d and d.active and d.resume_consent and not d.fault and d.phase=='route' and d.pending and d.pending.kind=='route' and c.user_activity==d and tr and d.route_owner==tr and d.route_serial and tr.serial and tr.serial>=d.route_serial and same(tr.destination,d.destination) and same(d.route_destination,d.destination) and (tr.intent=='pt' or tr.route or (tr.phase=='idle' and same((c.current and c.current.room or {}).id,d.destination))))
end
function M.room_changed(c,room,area)
 if c.restock_controller then return c.restock_controller.room_changed(room,area,M.movement_borrowed(c)) end
 return true
end
function M.globe_off(c) if c.restock_controller then return c.restock_controller.globe_off() end;return true end
function M.command(c,action)
 local t=c.restock_controller
 if not t then return false,'restock hooks not attached' end
 action=tostring(action or 'status'):lower()
 if action=='on' then return t.start() elseif action=='off' then return t.off() elseif action=='status' then
  local d=t.state;return true,string.format('Bashing Restock %s; busy=%s; phase=%s; %s',d.enabled and 'ON' or 'OFF',tostring(M.busy(c)),d.phase,d.status or '')
 end
 return false,'use cv2 restock on|off|status'
end
function M.tick(c) if c.restock_controller then return c.restock_controller.tick() end;return false end
function M.text(c,line) if c.restock_controller then return c.restock_controller.text(line) end end
function M.prompt(c) if c.restock_controller then return c.restock_controller.prompt() end end
function M.detach(c)
 local t=c.restock_controller;if not t then return true end
 local d=t.state;if d.busy or d.pending or d.purchase or d.dispatching then return false,'unfinished restock owner retained' end
 local api=c.restock_api or _G;t.attached=false;d.active=false;d.enabled=false;d.reserved=false
 for _,h in ipairs(t.handles or {}) do if h[1]=='event' then api.killAnonymousEventHandler(h[2]) else api.killTrigger(h[2]) end end
 if t.timer then api.killTimer(t.timer) end
 c.restock_controller=nil;return true
end
return M
