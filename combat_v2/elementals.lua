-- Current-room, opt-in BASH sidecar. Own elemental kills request one guarded
-- summon. Never attacks, moves or scans; normal rejection uses fresh recovery.
-- A committed drain/summon barrier survives detach/reload, OFF and faults.
local M={}
local FAILURE='You do not have the power to summon forth an elemental.'
local KILL='You have slain a massive elemental.'
local SUCCESS='You concentrate on the raw elemental energy flowing about your body, coalescing some of its potential into a massive elemental.'
local elements={water=true,air=true,earth=true,fire=true}
local function now() return getEpoch and getEpoch() or os.clock() end
local function yes(v) return v==true or tonumber(v)==1 end
function M.new(c)
 if not c.elemental_recovery then c.elemental_recovery={armed=false,phase='idle',prompt=0,status='disarmed'} end
 return c.elemental_recovery
end
M.state=M.new
local function untimer(b)
 if b.timer then if killTimer then killTimer(b.timer) end;b.timer=nil end
end
local function fault(b,why)
 b.armed=false;b.fault=why;b.status=why;untimer(b)
 -- Do not erase pending or committed: uncertain sends cannot be undone.
end
local function scope(c,b)
 local s=c.current;local p=s and s.player
 if not s or c.mode~='BASH' or s.mode~='BASH' or not c.runner or c.runner.mode~='BASH' then return false,'BASH scope ended' end
 if not s.room or s.room.id==nil or s.room.id~=b.room then return false,'room scope ended' end
 if not yes(s.connected) or not p or yes(p.dead) or (tonumber(p.hp) or 0)<=0 or s.training_battle_ended then return false,'dead/disconnected/stopped' end
 if not getConnectionInfo then return false,'TCP evidence unavailable' end
 local ok,_,_,tcp=pcall(getConnectionInfo)
 if not ok or tcp~=true then return false,'TCP disconnected' end
 return true
end
local function checkscope(c,b)
 local ok,why=scope(c,b)
 if not ok then
  if b.pending and b.pending.phase=='normal' and not b.committed then
   b.pending=nil;b.phase='idle';b.armed=false;b.status=why;untimer(b)
  elseif b.pending then fault(b,why) else b.armed=false;b.status=why end
 end
 return ok
end
local function living(item)
 local f=tostring(item.attrib or '')
 return (f:find('m',1,true) or item.icon=='monster') and not f:find('d',1,true) and not f:find('x',1,true)
end
local function target_present(s)
 for _,item in pairs(s.room.items or {}) do
  if living(item) then return true end -- Any living NPC is reason not to consume a charge.
 end
 return false
end
local function quiet(s)
 local h=s.hunting or {};local scan=h.ih;local watch=h.watch
 if scan and (scan.active or scan.pending) then return false end
 if not scan or scan.room_id~=s.room.id then return false end
 local fresh=scan.responded==true or (s.room.item_version or 0)>(scan.start_version or math.huge)
 return fresh and ((watch and watch.room_id==s.room.id) or scan.responded==true)
end
local function gates(c)
 local s,r=c.current,c.runner
 if not c.policy or type(c.policy.allowed)~='function' then return false,'policy unavailable' end
 local ok,why=c.policy.allowed(s);if ok~=true then return false,why or 'policy hold' end
 if r.waiting or r.fault or r.pending then return false,'runner pending/fault' end
 if not c.runner_module or not c.runner_module.ready(r) then return false,'not ready' end
 local p=s.player;local a=p.afflictions or {}
 if p.prone or a.prone or a.fallen or a.paralysis or a.asleep or a.unconsciousness or a.stun or a.stunned or (a.anorexia and a.asthma and a.slickness) then return false,'true hinder' end
 for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[k]) then return false,'balance hold' end end
 if (s.buffs and (s.buffs.pending or s.buffs.fault)) or (s.mental and (s.mental.eq_pending or s.mental.fault)) or (s.walker and (s.walker.pending or s.walker.fault)) then return false,'protected pending' end
 if not c.defense or type(c.defense.plan)~='function' then return false,'defense unavailable' end
 local d=c.defense.plan(s);if not d or d.hold then return false,'defense hold' end
 if not quiet(s) then return false,'awaiting completed fresh room scan' end
 return true
end
local schedule
-- Optional native owned-inventory selector. Presence proves identity, NEVER charges.
-- Only receive callbacks call inventory(); enable never reads cached gmcp tables.
local GLOBE='a globe of elemental energy'
local function itemid(id)
 return type(id)=='string' and id:match('^%d+$') and id:match('[1-9]') and id or nil
end
local function pool(c)
 local b=M.state(c)
 if not b.pool then b.pool={enabled=false,known=false,owned={},exhausted={}} end
 return b.pool
end
local function pool_revoke(c)
 local q=pool(c);q.enabled=false;q.known=false;q.query=nil;q.owned={}
end
local function pool_request(c)
 local b=M.state(c);local q=pool(c)
 if q.query then return true end
 q.known=false;q.query={started=now()};q.dispatching=true
 -- Install the query barrier BEFORE either adapter can synchronously deliver data.
 local ok,result=pcall(function()
  assert(type(sendGMCP)=='function','inventory query unavailable')
  local r=sendGMCP([[Char.Items.Inv ""]]);if r==false then return false end
  local sender=(c.runner and c.runner.sender) or send
  return sender('ii globe')
 end)
 q.dispatching=false
 if not ok or result==false then q.known=false;q.query=nil;fault(b,'owned inventory query failed');return false end
 if schedule then schedule(c) end
 return true
end
function M.pool_enable(c,on)
 local b=M.state(c);local q=pool(c)
 if on~=true then q.enabled=false;q.query=nil;return true,b end
 local room=c.current and c.current.room and c.current.room.id
 local valid=scope(c,{room=room})
 if not valid or tostring(c.current.player.class or ''):lower()~='monk' then return false,b end
 if q.enabled then return true,b end
 local attached=M.pool_attach(c);if not attached then return false,b end
 q.enabled=true;q.room=room;q.known=false;q.owned={};q.exhausted={};q.ever_owned=false
 if b.fault=='globe exhausted' and not b.committed and b.pending and b.pending.phase=='probe' then
  -- Explicit opt-in may continue the OLD helper's proven read-only zero.
  -- It does not forgive a timeout, physical commit or unknown phase.
  local p=b.pending;p.count=0;p.ack=true;p.ready_prompt=nil;p.started=now();p.dispatch_prompt=b.prompt
  b.last_probe={targetID=p.targetID,count=0,readonly=true}
  if p.targetID then q.exhausted[p.targetID]=true end
  b.fault=nil;b.armed=true;b.room=room
 end
 -- An existing generic or committed request is deliberately not retargeted.
 return pool_request(c),b
end
function M.inventory(c,kind,payload)
 local b=M.state(c);local q=pool(c)
 if type(payload)~='table' or payload.location~='inv' then return b end
 -- Pool OFF prevents new selection, not revocation of an in-flight exact
 -- target's proof. Disconnect/detach revoke known entirely and cannot replay it.
 if not q.enabled and not (q.known and b.pending and b.pending.targetID) then return b end
 local valid=scope(c,{room=q.room})
 if not valid or tostring(c.current.player.class or ''):lower()~='monk' then
  pool_revoke(c);fault(b,'owned inventory scope ended');return b
 end
 local function invalid() q.known=false;q.query=nil;fault(b,'invalid owned inventory');return b end
 if kind=='List' then
  if type(payload.items)~='table' then return invalid() end
  local owned,seen,n={},{},0
  for _,v in pairs(payload.items) do
   if type(v)~='table' then return invalid() end
   if v.name==GLOBE then
    local id=itemid(v.id);if not id or seen[id] then return invalid() end
    seen[id]=true;owned[id]=true;n=n+1;if n>32 then return invalid() end
   end
  end
  q.owned=owned;q.known=true;q.query=nil
  if n>0 then q.ever_owned=true end
 elseif kind=='Add' or kind=='Update' or kind=='Remove' then
  -- A partial event cannot establish the initial full owned set.
  if not q.known then return b end
  local v=payload.item;local id=itemid(type(v)=='table' and v.id or v)
  if not id then return invalid() end
  if kind=='Remove' then q.owned[id]=nil
  elseif type(v)~='table' then return invalid()
  elseif v.name==GLOBE then
   if not q.owned[id] then
    local n=0;for _ in pairs(q.owned) do n=n+1 end
    if n>=32 then return invalid() end
   end
   q.owned[id]=true;q.ever_owned=true
  elseif v.name~=nil then q.owned[id]=nil end
 end
 return b
end
local function pool_target(c)
 local b=M.state(c);local q=pool(c)
 if q.query then b.status='awaiting fresh owned inventory';return nil end
 if not q.known then fault(b,'owned inventory unavailable');return nil end
 local ids={}
 for id in pairs(q.owned) do if not q.exhausted[id] then ids[#ids+1]=id end end
 table.sort(ids)
 if ids[1] then return ids[1] end
 if q.ever_owned then fault(b,'all carried globes exhausted')
 else fault(b,'no carried globes verified') end
 return nil
end
-- Bind separately for in-place upgrades: no owner restart or cached replay.
function M.pool_attach(c)
 local b=M.state(c)
 if b.pool_handles and #b.pool_handles>0 then return true,b end
 b.pool_handles={}
 local ok,err=pcall(function()
  for _,kind in ipairs({'List','Add','Update','Remove'}) do
   local k=kind
   local id=registerAnonymousEventHandler('gmcp.Char.Items.'..k,function()
    M.inventory(c,k,gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items[k]);M.service(c)
   end)
   assert(type(id)=='number' and id>0 and id<math.huge and id==math.floor(id),'invalid pool hook')
   b.pool_handles[#b.pool_handles+1]=id
  end
  local id=registerAnonymousEventHandler('sysDisconnectionEvent',function()
   pool_revoke(c);M.arm(c,false)
  end)
  assert(type(id)=='number' and id>0 and id<math.huge and id==math.floor(id),'invalid pool lifecycle hook')
  b.pool_handles[#b.pool_handles+1]=id
 end)
 if not ok then
  for _,id in ipairs(b.pool_handles) do if killAnonymousEventHandler then killAnonymousEventHandler(id) end end
  b.pool_handles={};pool_revoke(c);return false,err
 end
 return true,b
end
function M.arm(c,on)
 local b=M.state(c)
 if on==true and b.fault=='all carried globes exhausted' and pool(c).enabled then
  local q=pool(c);local eligible=false
  if q.known then for id in pairs(q.owned) do if not q.exhausted[id] then eligible=true end end end
  if not eligible then return false,b end
 end
 -- Only known unsent/read-only phases are safe to discard without a commit flag.
 local unresolved=b.pending and b.pending.phase~='waiting' and b.pending.phase~='probe' and b.pending.phase~='normal'
 if on~=true then
  if b.committed or unresolved then fault(b,'disarmed with recovery unresolved') else b.pending=nil;b.phase='idle';b.armed=false;b.status='disarmed';untimer(b) end
  return true,b
 end
 if b.committed or unresolved then return false,b end
 -- Validate the proposed scope before discarding any fault or read-only proof.
 local room=c.current and c.current.room and c.current.room.id
 local valid,why=scope(c,{room=room})
 if not valid then b.armed=false;b.status=why;return false,b end
 -- Only explicit ON cancels a known unsent/read-only attempt. It sends nothing;
 -- a timeout never proves a physical recovery.
 untimer(b);b.pending=nil;b.fault=nil;b.phase='idle';b.room=room
 b.armed=true;b.status='armed (waiting for own elemental kill or summon failure)';return true,b
end
function M.prompt(c)
 local b=M.state(c);b.prompt=b.prompt+1
 if b.armed and not checkscope(c,b) then return b end
 local p=b.pending
 if not b.fault and p and p.ack and b.prompt>(p.external_success_prompt or p.dispatch_prompt) and (p.phase=="summon"or p.external_success_prompt or gates(c))then p.ready_prompt=b.prompt end
 return b
end
function M.text(c,line)
 local b=M.state(c)
 if not b.armed or b.fault or not checkscope(c,b) then return b end
 local p=b.pending
 if line==KILL then
  if not p then
   -- Core may already have cleared the killed target and begun IH. Keep the
   -- last accepted attack generation, not the mutable current target pointer.
   -- A repeated frame cannot earn another summon after success or OFF/ON;
   -- another real BASH attack generation is required after the first kill.
   local attack
   for i=#(c.current.history or {}),1,-1 do
    local h=c.current.history[i]
    -- Stable BASH offense is a COMBO; dismount/stance preparation is not a
    -- fresh attack and must not turn a repeated kill frame into a new intent.
    if h.kind=='send' and type(h.detail)=='string' and h.detail:match('^combo ') and h.generation~=nil then attack=h;break end
   end
   local generation=attack and attack.generation or false
   if b.kill_state~=c.current or b.kill_generation==nil or (attack and generation~=b.kill_generation) then
    b.kill_state=c.current;b.kill_generation=generation
    b.pending={phase='normal',started=now()};b.phase='normal';b.status='waiting for guarded own-kill summon';schedule(c)
   end
  end
 elseif line==FAILURE then
  if p then
   if p.phase=='summon' then
    if p.kind=='normal' and not p.ack then
     -- Exact rejection proves this normal SUMMON did not commit a spawn.
     -- Discard that send, never a recovery send, and acquire a fresh count.
     b.committed=nil;b.pending={phase='waiting',started=now()};b.phase='waiting';b.status='normal summon rejected; awaiting fresh recovery';schedule(c)
    else fault(b,'summon recovery failed; review required') end
   end
  else
   b.pending={phase='waiting',started=now()};b.phase='waiting';b.status='waiting for guarded empty room';schedule(c)
  end
 elseif p and p.phase=='probe' then
  local element,count,unit=line:match('^This globe is infused with (%a+) and can be drained another (%d+) (times?)%.$')
  if not element then count,unit=line:match('^This globe can be drained another (%d+) (times?)%.$') end
  -- Fresh globes have no named infusion: DRAIN chooses the element. Accept
  -- only exact single-digit native counts, not padded or coerced numbers.
  if (not element or elements[element]) and count and count:match('^[0-4]$') and (unit=='times' or count=='1') then
   if not p.ack then
    if count=='0' and not pool(c).enabled then fault(b,'globe exhausted')
    else
     p.count=tonumber(count);p.ack=true
     if count=='0' then
      b.last_probe={targetID=p.targetID,count=0,readonly=true}
      if p.targetID then pool(c).exhausted[p.targetID]=true end
      -- Refresh once, not once per watchdog/kill. A generic zero identifies
      -- no item; its first successor must be an explicitly owned ID probe.
      pool_request(c)
     end
    end
   end
  elseif line=='I do not see that here.' or line=='You see no such thing.' then fault(b,'globe not found') end
 elseif p and p.phase=='drain' then
  local element=line:match('^As you place a hand upon the globe, the energy within surges in response%. Tendrils of energy quickly escape their prison, infusing your body with the element of (%a+)%.$')
  if element and elements[element] then p.ack=true end
  -- The existing own-kill trigger may have spent this confirmed infusion.
  -- Only exact own success plus a later prompt releases the committed barrier.
  if line==SUCCESS and p.ack and not p.external_success_prompt then
   p.external_success_prompt=b.prompt;p.ready_prompt=nil
  end
 elseif p and p.phase=='summon' and line==SUCCESS then p.ack=true end
 return b
end
-- Only fresh Add events, never cached List, can acknowledge an expected action.
function M.defence(c,kind,payload)
 local b=M.state(c);local p=b.pending
 if b.armed and not b.fault and checkscope(c,b) and p and p.phase=='drain' and kind=='Add' then
  local name=type(payload)=='table' and payload.name or payload
  if type(name)=='string' and elements[name:match('^(%a+)_infused$')] then p.ack=true end
 end
 return b
end
function M.item(c,kind,payload)
 if type(payload)=='table' and payload.location=='inv' then return M.inventory(c,kind,payload) end
 local b=M.state(c);local p=b.pending
 if b.armed and not b.fault and checkscope(c,b) and p and p.phase=='summon' and kind=='Add' and type(payload)=='table' and payload.location=='room' then
  local item=payload.item
  if type(item)=='table' and item.id and not p.old_ids[tostring(item.id)] and item.name=='a massive elemental' and living(item) then p.ack=true end
 end
 return b
end
local function dispatch(c,b,phase,command,sender,kind,targetID)
 local p={phase=phase,kind=kind or 'recovery',targetID=targetID,started=now(),dispatch_prompt=b.prompt,old_ids={}}
 if phase=='summon' then for id in pairs(c.current.room.items or {}) do p.old_ids[tostring(id)]=true end end
 b.pending=p;b.phase=phase;b.status='awaiting '..phase
 if phase=='drain' or phase=='summon' then b.committed=true end
 -- Phase is committed before any recorder/sender can reenter.
 if c.state and c.state.record then c.state.record(c.current,'elemental_recovery',command) end
 if b.fault or not b.armed or b.pending~=p or not checkscope(c,b) then return end
 if phase=='drain' and targetID and (not pool(c).known or not pool(c).owned[targetID]) then
  fault(b,'probed globe ownership lost');return
 end
 local ok,result=pcall(sender,command)
 if not ok or result==false then fault(b,'recovery send failed (commit unknown)') end
end
local function service(c,sender,policy)
 local b=M.state(c)
 local q=pool(c)
 if q.enabled or (q.known and b.pending and b.pending.targetID) then
  local valid=scope(c,{room=q.room})
  if not valid or tostring(c.current.player.class or ''):lower()~='monk' then
   pool_revoke(c);M.arm(c,false);return b
  end
  if q.query and now()-q.query.started>=12 then
   q.known=false;q.query=nil;fault(b,'owned inventory query timeout');return b
  end
 end
 if q.dispatching then return b end
 if not b.armed or b.fault or not checkscope(c,b) then return b end
 local p=b.pending;if not p then return b end
 -- Confirmed summon completion is bookkeeping, not another action. BASH may
 -- already be using its balances; do not hold settlement behind the next fight.
 if (p.phase=="summon"or p.external_success_prompt)and p.ack and p.ready_prompt then
  b.pending=nil;b.committed=nil;b.phase="idle";b.status="recovered; armed for next independent failure";untimer(b);return b
 end
 local elapsed=now()-p.started
 if (not p.ack and p.phase~='waiting' and p.phase~='normal' and elapsed>=12) or elapsed>=60 then fault(b,'recovery timeout');return b end
 if p.external_success_prompt then b.status='awaiting post-success prompt';return b end
 -- Only the owned drain-to-summon continuation may use a reserved recall gap.
 if policy and not (policy=='continue' and b.committed and p.phase=='drain') then return b end
 local safe,why=gates(c)
 if not safe then b.status=why;return b end
 if (p.phase=='waiting' or p.phase=='probe') and target_present(c.current) then
  b.pending=nil;b.phase='idle';b.status='cancelled: living target present';untimer(b);return b
 end
 if p.phase=='normal' then
  if target_present(c.current) then b.status='waiting for empty room before spawning another enemy';return b end
  local hp,maxhp=tonumber(c.current.player.hp),tonumber(c.current.player.maxhp)
  if not hp or not maxhp or maxhp<=0 or hp/maxhp<.8 then b.status='waiting for 80% health before spawning another enemy';return b end
  dispatch(c,b,'summon','summon elemental',sender,'normal')
 elseif p.phase=='waiting' then
  if q.enabled then
   local id=pool_target(c);if id then dispatch(c,b,'probe','probe '..id,sender,nil,id) end
  else dispatch(c,b,'probe','probe globe',sender) end
 elseif p.ack and p.ready_prompt then
  if p.phase=='probe' then
   if p.count==0 and q.enabled then
    local id=pool_target(c);if id then dispatch(c,b,'probe','probe '..id,sender,nil,id) end
   elseif p.count and p.count>0 then
    if p.targetID and (not q.known or not q.owned[p.targetID]) then fault(b,'probed globe ownership lost');return b end
    dispatch(c,b,'drain',p.targetID and ('drain '..p.targetID) or 'drain globe',sender,nil,p.targetID)
   end
  elseif p.phase=='drain' then
   if target_present(c.current) then b.status='waiting for empty room before spawning another enemy';return b end
   local hp,maxhp=tonumber(c.current.player.hp),tonumber(c.current.player.maxhp)
   if not hp or not maxhp or maxhp<=0 or hp/maxhp<.8 then b.status='waiting for 80% health before spawning another enemy';return b end
   dispatch(c,b,'summon','summon elemental',sender,nil,p.targetID)
  elseif p.phase=='summon' then
   b.pending=nil;b.committed=nil;b.phase='idle';b.status='recovered; armed for next independent failure';untimer(b)
  end
 end
 return b
end
function M.service(c,sender,policy)
 local b=M.state(c);if b.servicing then return b end
 b.servicing=true
 local ok,result=pcall(service,c,sender or (c.runner and c.runner.sender) or send,policy)
 b.servicing=false
 if not ok then fault(b,'recovery service error: '..tostring(result)) end
 if ((b.pending and b.armed) or (b.pool and b.pool.query)) and not b.fault then schedule(c) end
 return b
end
schedule=function(c)
 local b=M.state(c)
 if (b.attached or #(b.pool_handles or {})>0) and ((b.pending and b.armed) or (b.pool and b.pool.query)) and not b.fault and not b.timer and tempTimer then
  b.timer=tempTimer(.25,function() b.timer=nil;M.service(c) end)
 end
end
function M.detach(c)
 local b=M.state(c);M.arm(c,false);untimer(b)
 pool_revoke(c)
 for _,id in ipairs(b.pool_handles or {}) do if killAnonymousEventHandler then killAnonymousEventHandler(id) end end
 b.pool_handles={}
 for _,h in ipairs(b.handles or {}) do
  local killer=({trigger=killTrigger,event=killAnonymousEventHandler,alias=killAlias})[h.kind]
  if killer then killer(h.id) end
 end
 b.handles={};b.attached=false;return b
end
function M.attach(c)
 local b=M.detach(c) -- Always OFF, including reload. Preserve unresolved barriers.
 local function own(kind,id)
  assert(type(id)=='number' and id>0 and id<math.huge and id==math.floor(id),'invalid elemental '..kind..' hook ID')
  b.handles[#b.handles+1]={kind=kind,id=id}
 end
 -- All receive/lifecycle hooks are essential. Failed registration must never
 -- advertise an attached owner; tear down only our successfully acquired IDs.
 local ok,err=pcall(function()
 assert(type(tempRegexTrigger)=='function' and type(tempPromptTrigger)=='function' and type(registerAnonymousEventHandler)=='function','essential elemental hook API unavailable')
 own('trigger',tempRegexTrigger('^.*$',function() M.text(c,line) end))
 own('trigger',tempPromptTrigger(function() M.prompt(c);M.service(c) end))
 if registerAnonymousEventHandler then
  for _,event in ipairs({'gmcp.Char.Defences.Add','gmcp.Char.Items.Add','gmcp.Room.Info','sysDisconnectionEvent'}) do
   local event_name=event
   own('event',registerAnonymousEventHandler(event_name,function()
    if event_name=='gmcp.Char.Defences.Add' then M.defence(c,'Add',gmcp and gmcp.Char and gmcp.Char.Defences and gmcp.Char.Defences.Add)
    elseif event_name=='gmcp.Char.Items.Add' then M.item(c,'Add',gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items.Add)
    elseif event_name=='sysDisconnectionEvent' then
     pool_revoke(c)
     if b.pending and b.pending.phase~='normal' then fault(b,'disconnected during recovery') else M.arm(c,false) end
    elseif gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num~=b.room then
     if b.pending and b.pending.phase~='normal' then fault(b,'room changed during recovery') else M.arm(c,false) end
    end
    M.service(c)
   end))
  end
 end
 if tempAlias then own('alias',tempAlias('^elementalkeep (on|off|status)$',function()
  local action=matches and matches[2]
  if action=='on' then M.arm(c,true) elseif action=='off' then M.arm(c,false) end
  if echo then echo('Elemental recovery: '..b.status..'\n') end
 end)) end
 end)
 if not ok then M.detach(c);error('elemental attachment failed: '..tostring(err),0) end
 b.attached=true
 return b
end
return M
