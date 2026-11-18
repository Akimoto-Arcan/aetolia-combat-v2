-- Current-room, opt-in BASH sidecar. Never attacks, moves, scans or handles kills.
-- A committed drain/summon barrier survives detach/reload, OFF and faults.
local M={}
local FAILURE='You do not have the power to summon forth an elemental.'
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
  if b.pending then fault(b,why) else b.armed=false;b.status=why end
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
function M.arm(c,on)
 local b=M.state(c)
 if on~=true then
  if b.pending and b.committed then fault(b,'disarmed with recovery unresolved') else b.pending=nil;b.phase='idle';b.armed=false;b.status='disarmed';untimer(b) end
  return true,b
 end
 if b.fault or b.pending then return false,b end
 b.room=c.current and c.current.room and c.current.room.id
 if not checkscope(c,b) then return false,b end
 b.armed=true;b.status='armed (waiting for own summon failure)';return true,b
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
 if line==FAILURE then
  if p then
   if p.phase=='summon' then fault(b,'summon recovery failed; review required') end
  else
   b.pending={phase='waiting',started=now()};b.phase='waiting';b.status='waiting for guarded empty room';schedule(c)
  end
 elseif p and p.phase=='probe' then
  local element,count=line:match('^This globe is infused with (%a+) and can be drained another (%d+) times%.$')
  if element and elements[element] and tonumber(count)<=4 then
   if tonumber(count)==0 then fault(b,'globe exhausted') else p.count=tonumber(count);p.ack=true end
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
 local b=M.state(c);local p=b.pending
 if b.armed and not b.fault and checkscope(c,b) and p and p.phase=='summon' and kind=='Add' and type(payload)=='table' and payload.location=='room' then
  local item=payload.item
  if type(item)=='table' and item.id and not p.old_ids[tostring(item.id)] and item.name=='a massive elemental' and living(item) then p.ack=true end
 end
 return b
end
local function dispatch(c,b,phase,command,sender)
 local p={phase=phase,started=now(),dispatch_prompt=b.prompt,old_ids={}}
 if phase=='summon' then for id in pairs(c.current.room.items or {}) do p.old_ids[tostring(id)]=true end end
 b.pending=p;b.phase=phase;b.status='awaiting '..phase
 if phase=='drain' or phase=='summon' then b.committed=true end
 -- Phase is committed before any recorder/sender can reenter.
 if c.state and c.state.record then c.state.record(c.current,'elemental_recovery',command) end
 if b.fault or not b.armed or b.pending~=p or not checkscope(c,b) then return end
 local ok,result=pcall(sender,command)
 if not ok or result==false then fault(b,'recovery send failed (commit unknown)') end
end
local function service(c,sender)
 local b=M.state(c)
 if not b.armed or b.fault or not checkscope(c,b) then return b end
 local p=b.pending;if not p then return b end
 -- Confirmed summon completion is bookkeeping, not another action. BASH may
 -- already be using its balances; do not hold settlement behind the next fight.
 if (p.phase=="summon"or p.external_success_prompt)and p.ack and p.ready_prompt then
  b.pending=nil;b.committed=nil;b.phase="idle";b.status="recovered; armed for next independent failure";untimer(b);return b
 end
 local elapsed=now()-p.started
 if (not p.ack and p.phase~='waiting' and elapsed>=12) or elapsed>=60 then fault(b,'recovery timeout');return b end
 if p.external_success_prompt then b.status='awaiting post-success prompt';return b end
 local safe,why=gates(c)
 if not safe then b.status=why;return b end
 if (p.phase=='waiting' or p.phase=='probe') and target_present(c.current) then
  b.pending=nil;b.phase='idle';b.status='cancelled: living target present';untimer(b);return b
 end
 if p.phase=='waiting' then dispatch(c,b,'probe','probe globe',sender)
 elseif p.ack and p.ready_prompt then
  if p.phase=='probe' then
   if p.count and p.count>0 then dispatch(c,b,'drain','drain globe',sender) end
  elseif p.phase=='drain' then
   if target_present(c.current) then b.status='waiting for empty room before spawning another enemy';return b end
   local hp,maxhp=tonumber(c.current.player.hp),tonumber(c.current.player.maxhp)
   if not hp or not maxhp or maxhp<=0 or hp/maxhp<.8 then b.status='waiting for 80% health before spawning another enemy';return b end
   dispatch(c,b,'summon','summon elemental',sender)
  elseif p.phase=='summon' then
   b.pending=nil;b.committed=nil;b.phase='idle';b.status='recovered; armed for next independent failure';untimer(b)
  end
 end
 return b
end
function M.service(c,sender)
 local b=M.state(c);if b.servicing then return b end
 b.servicing=true
 local ok,result=pcall(service,c,sender or (c.runner and c.runner.sender) or send)
 b.servicing=false
 if not ok then fault(b,'recovery service error: '..tostring(result)) end
 if b.pending and b.armed and not b.fault then schedule(c) end
 return b
end
schedule=function(c)
 local b=M.state(c)
 if b.attached and b.pending and b.armed and not b.fault and not b.timer and tempTimer then
  b.timer=tempTimer(.25,function() b.timer=nil;M.service(c) end)
 end
end
function M.detach(c)
 local b=M.state(c);M.arm(c,false);untimer(b)
 for _,h in ipairs(b.handles or {}) do
  local killer=({trigger=killTrigger,event=killAnonymousEventHandler,alias=killAlias})[h.kind]
  if killer then killer(h.id) end
 end
 b.handles={};b.attached=false;return b
end
function M.attach(c)
 local b=M.detach(c) -- Always OFF, including reload. Preserve unresolved barriers.
 b.attached=true
 local function own(kind,id) b.handles[#b.handles+1]={kind=kind,id=id} end
 if tempRegexTrigger then own('trigger',tempRegexTrigger('^.*$',function() M.text(c,line) end)) end
 if tempPromptTrigger then own('trigger',tempPromptTrigger(function() M.prompt(c);M.service(c) end)) end
 if registerAnonymousEventHandler then
  for _,event in ipairs({'gmcp.Char.Defences.Add','gmcp.Char.Items.Add','gmcp.Room.Info','sysDisconnectionEvent'}) do
   local event_name=event
   own('event',registerAnonymousEventHandler(event_name,function()
    if event_name=='gmcp.Char.Defences.Add' then M.defence(c,'Add',gmcp and gmcp.Char and gmcp.Char.Defences and gmcp.Char.Defences.Add)
    elseif event_name=='gmcp.Char.Items.Add' then M.item(c,'Add',gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items.Add)
    elseif event_name=='sysDisconnectionEvent' then
     if b.pending then fault(b,'disconnected during recovery') else M.arm(c,false) end
    elseif gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num~=b.room then
     if b.pending then fault(b,'room changed during recovery') else M.arm(c,false) end
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
 return b
end
return M
