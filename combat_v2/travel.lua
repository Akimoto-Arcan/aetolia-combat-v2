-- Explicit native mount/travel convenience. No startup actions or guessed text ACKs.
-- Native PATH FIND framing is verified. Completion uses fresh destination Room.Info
-- plus prompt; optional exact-own route_done/route_stopped callbacks may add proof.
-- Unknown stop acknowledgements retain the movement barrier; never guess text.
local M={}
local directions={n=true,ne=true,e=true,se=true,s=true,sw=true,w=true,nw=true,u=true,d=true,['in']=true,out=true}
local function route_line(p,line)
 if p.ack then return end
 local name,n=line:match('^Distance to (.-): (%d+)%.$')
 if name then
  if p.route_header or #name==0 or #name>200 or tonumber(n)<1 or tonumber(n)>10000 then p.invalid=true;return end
  p.route_header=true;p.target_name=name;p.distance=tonumber(n);p.steps=0;return
 end
 if not p.route_header or p.invalid then return end
 if line=='Use PATH GO to travel there.' then
  if p.steps>0 then return true end;p.invalid=true;return
 end
 local row=line:match('^Path: (.*)$')
 if row then p.path_started=true
 elseif p.path_started then row=line:match('^%s*(.-)%s*$') end
 if row and row~='' then
  if #row>2000 or row:find('[^a-z,%s]') then p.invalid=true;return end
  local count=0
  for word in row:gmatch('[^,%s]+') do
   if not directions[word] then p.invalid=true;return end
   count=count+1
  end
  if count==0 then p.invalid=true;return end
  p.steps=p.steps+count;if p.steps>10000 then p.invalid=true end
 end
end
local function yes(v) return v==true or tonumber(v)==1 end
local function id(v) local n=tonumber(v);if n and n>0 and n==math.floor(n) then return string.format('%.0f',n) end end
local function mounted(v) if v==false or v==nil then return nil end;if tonumber(v)==0 then return '0' end;return id(v) end
local function destination(v)
 if type(v)~='string' or #v>120 or v:find('[%c]') then return nil end
 v=v:match('^%s*(.-)%s*$')
 if v=='' then return nil end
 if v:match('^%d+$') then if id(v) then return v end;return nil end
 if not v:match("^[A-Za-z][A-Za-z '%-]*$") then return nil end
 return v
end
M.destination=destination
function M.new(io,settings,state)
 local t={io=io or {},settings=settings or {},state=state or {phase='idle',prompt=0,serial=0}}
 local s=t.state;s.mount=id(t.settings.mount_id) or s.mount
 local function clock() return t.io.now and t.io.now() or os.clock() end
 local function fault(why) s.fault=why;s.status=why;return false,why end
 local function busy() return s.dispatching or s.pending or s.fault or s.follow_pending or s.follow_fault or s.follow_due or s.recall_due end
 local function ready()
  if t.io.ready then return t.io.ready() end
  return false,'readiness adapter unavailable'
 end
 local function commit(kind,command)
  if s.dispatching or s.pending or s.fault then return false,'travel unresolved' end
  local ok,why=ready();if not ok then return false,why end
  local p={kind=kind,at=clock(),prompt=s.prompt,room=s.room,serial=s.serial+1}
  s.serial=p.serial;s.pending=p;s.phase=kind;s.dispatching=true
  local good,result=pcall(kind=='recall' and (t.io.send_recall or t.io.send) or t.io.send,command)
  s.dispatching=false
  if not good or result==false then return fault('transport unknown: '..kind) end
  -- Synchronous observation may ACK, but never dispatch another stage until return.
  t.pump();return true
 end
 local function pause()
  if not t.io.pause then return false,'pause adapter unavailable' end
  return t.io.pause()
 end
 local function resolve() s.pending=nil;s.phase='idle' end
 local function known_here() return s.present==true and s.presence_room==s.room end
 local function recall()
  if not s.mount then return false,'own mount is unknown; configure mount_id' end
  if s.mounted~='0' then return false,'recall requires confirmed unmounted state' end
  if s.recalled then return false,'recall already issued; awaiting fresh own mount arrival' end
  local ok,why=ready();if not ok then return false,why end
  if t.io.recall_ready then ok,why=t.io.recall_ready();if not ok then return false,why end end
  s.recalled=true
  return commit('recall','recall '..s.mount)
 end
 function t.unresolved() return busy() and true or false end
 function t.pump()
  if s.dispatching or s.pumping or s.fault or s.follow_fault then return false end
  s.pumping=true
  local function step()
   if s.refresh_due and not s.refresh_dispatching and (not t.io.refresh_ready or t.io.refresh_ready()) then
    s.refresh_due=nil;s.refresh_dispatching=true
    local ok,result=pcall(t.io.refresh_items)
    s.refresh_dispatching=nil
    if not ok or result==false then s.status='mount loss refresh unavailable; awaiting full current-room snapshot' end
   end
   -- ORDER is balance-free and must not stop native BASH/upkeep or erase waits.
   -- Keep its transport independent of an already committed PATH GO/STOP.
   local fp=s.follow_pending
   if fp then
    local ok=(t.io.follow_ready or ready)()
    if s.prompt>fp.prompt and ok then
     s.follow_pending=nil;if fp.episode==s.follow_episode then s.follow_due=nil end
    else return end
   end
   if s.follow_due and s.mount and (known_here() or s.mounted==s.mount) then
    local p=s.pending
    if p and p.kind~='go' and p.kind~='stop' and p.kind~='find' and p.kind~='dismount' and not (p.kind=='recall' and p.arrived) then return end
    local ok=(t.io.follow_ready or ready)();if not ok then return end
    s.follow_pending={at=clock(),prompt=s.prompt,episode=s.follow_episode};s.dispatching=true
    local good,result=pcall(t.io.send_follow or t.io.send,'order '..s.mount..' follow me')
    s.dispatching=false
    if not good or result==false then s.follow_fault='transport unknown: follow';s.status=s.follow_fault end
    return
   end
   local p=s.pending
   if p then
    if p.kind=='mount' and s.mounted==s.mount and (s.mount_event or 0)>p.serial then resolve()
    elseif p.kind=='dismount' and s.mounted=='0' and (s.mount_event or 0)>p.serial then resolve()
    elseif p.kind=='recall' and p.arrived and s.prompt>(p.arrival_prompt or s.prompt) then
     local ok=ready();if not ok then return end
     s.recall_due=nil;resolve()

    elseif p.kind=='find' and p.ack and s.prompt>p.ack_prompt then
     local ok=ready();if not ok then return end
     if s.mounted~=s.mount or s.room~=p.room then return end
     s.route_proof=p;resolve();s.route='walking';return commit('go','path go gallop')
    elseif (p.kind=='go' or p.kind=='stop') and p.ack and s.prompt>p.ack_prompt then
     local ok=ready();if not ok then return end
     resolve();s.route=nil;s.intent=nil;s.status='travel complete; offense remains OFF'
    else return end
   end
   if s.pending or s.fault then return end
   if (s.follow_due or s.recall_due) and s.mount then
    if s.mounted=='0' and s.present==false and s.presence_room==s.room then
     -- Reserve a genuine ready gap without stopping BASH or clearing its wait.
     s.recall_due=true
     return recall()
    end
    return -- Await a fresh current-room full list before inferring loss.
   end
   if not s.intent then return end
   local ok=ready();if not ok then return end
   if s.intent=='qd' then s.intent=nil;return end
   if s.intent=='rh' then s.intent=nil;return end
   if not s.mounted then return end -- Await an actual mounted GMCP observation.
   if s.mounted~=s.mount then
    if not s.mount then return end
    if not known_here() then
     if s.present==false and s.presence_room==s.room then return recall() end
     return
    end
    return commit('mount','quickmount '..s.mount)
   end
   if s.intent=='qm' then s.intent=nil;s.status='own mount confirmed';return end
   if s.intent=='pt' then
    s.route='finding';return commit('find','path find '..s.destination)
   end
  end
  local ok,result=pcall(step);s.pumping=false
  if not ok then return fault('controller error: '..tostring(result)) end
  -- A nested ACK may have resolved the command while dispatch was active.
  return result
 end
 function t.request(action,arg)
  if action=='pt' and (arg=='cancel' or arg=='stop') then return t.cancel() end
  if busy() or s.intent or s.route then return false,'travel unresolved' end
  if action=='pt' then
   arg=destination(arg);if not arg then return false,'use pt AREA or positive ROOM number (maximum 120 characters)' end
  end
  if not ({pt=true,qm=true,qd=true,rh=true})[action] then return false,'unknown convenience action' end
  if not s.mount and s.mounted and s.mounted~='0' then s.mount=s.mounted end
  if not s.mount then return false,'own mount is unknown; configure mount_id' end
  local ok,why=ready();if not ok then return false,why end
  ok,why=pause();if not ok then return false,why end
  s.intent=action;s.destination=arg;s.status=action..' requested'
  if action=='rh' then
   if s.mounted==s.mount then s.intent=nil;return false,'already riding own mount' end
   local sent,reason=recall();if not sent and not s.pending then s.intent=nil end;return sent,reason
  elseif action=='qd' then
   if not s.mounted then s.intent=nil;return false,'mounted state unknown' end
   if s.mounted=='0' then s.intent=nil;return true,'already unmounted' end
   return commit('dismount','quickdismount')
  end
  if s.mounted and s.mounted~='0' and s.mounted~=s.mount then s.intent=nil;return false,'riding a different mount' end
  t.pump();return not s.fault,s.status
 end
 function t.cancel()
  s.intent=nil
  if s.dispatching or s.fault or s.follow_pending or s.follow_fault then return false,'unresolved transport retained' end
  local p=s.pending
  if p and (p.kind=='go' or p.kind=='stop') then
   if p.kind=='stop' then return false,'path stop already committed' end
   -- Cancel cannot erase the in-flight route. Retain it inside stop transaction.
   local ok,why=ready();if not ok then return false,why end
   s.pending=nil;s.stopping=p
   local sent,reason=commit('stop','path stop')
   if not sent and not s.pending then s.pending=p;s.stopping=nil end
   return sent,reason
  end
  if p then return false,'committed action retained until acknowledgement' end
  s.route=nil;return true
 end
 function t.vitals(value)
  local v=mounted(value);if not v then return end
  local old=s.mounted;s.mounted=v;s.mount_event=s.serial+1
  if not s.mount and v~='0' then s.mount=v end
  if v==s.mount then s.continuity=true;s.recalled=nil;s.recall_due=nil end
  if old and old~='0' and v=='0' and old==s.mount then
   s.follow_due=true;s.follow_episode=(s.follow_episode or 0)+1
  end
  t.pump()
 end
 function t.room(room,name)
  room=tostring(room or '')
  if room=='' or room==s.room then return end
  if s.room and s.pending and s.pending.kind~='go' and s.pending.kind~='stop' then fault('unexpected room change during '..s.pending.kind) end
  s.room=room;s.present=nil;s.presence_room=nil;s.loss_refresh=nil;s.refresh_due=nil
  if not s.pending then s.recall_due=nil end
  local p=s.pending
  if p and p.kind=='go' then
   p.moves=(p.moves or 0)+1
   local proof=s.route_proof
   if room==s.destination or room==id(s.destination) or (proof and proof.target_room and room==proof.target_room) or (proof and not proof.target_room and proof.steps==p.moves and name==proof.target_name) then p.ack=true;p.ack_prompt=s.prompt end
  end
 end
 -- Accept either independently scoped snapshots or Core's authoritative current-room
 -- view, delivered AFTER its world receiver advances item_version. The adapter must
 -- not authorize arbitrary cached data. QUICKMOUNT still needs a fresh mounted ACK.
 -- Only a fresh full snapshot explicitly associated with CURRENT room proves absence.
 -- Partial updates can establish arrival, never loss. An old-room snapshot is ignored.
 function t.items(room,items,full,version)
  if tostring(room or '')~=s.room or not version or version<=(s.item_version or -1) then return false end
  s.item_version=version
  local present=false
  for _,item in pairs(items or {}) do if id(item.id)==s.mount then present=true end end
  if present then
   s.present=true;s.presence_room=s.room;s.continuity=true;s.recalled=nil;s.loss_refresh=nil;s.refresh_due=nil
   if not s.pending then s.recall_due=nil end
   if s.pending and s.pending.kind=='recall' and not s.pending.arrived then s.pending.arrived=true;s.pending.arrival_prompt=s.prompt end
  elseif full then
   s.present=false;s.presence_room=s.room
   if s.continuity and s.mounted=='0' and not s.pending and not s.recalled then
    s.follow_due=s.follow_due or true
    s.recall_due=true
   end
  end
  t.pump();return true
 end
 -- REMOVE alone cannot prove absence: request one full snapshot per loss episode.
 function t.remove(room,item,version)
  if tostring(room or '')~=s.room or id(type(item)=='table' and item.id or item)~=s.mount or not s.continuity then return false end
  if not version or version<=(s.item_version or -1) then return false end
  s.item_version=version
  if s.loss_refresh then return true end
  s.present=nil;s.presence_room=nil
  s.loss_refresh=true
  if t.io.refresh_items then s.refresh_due=true;t.pump() end
  return true
 end
 function t.text(line)
  local p=s.pending;if not p or s.fault then return end
  local fn=p.kind=='find' and t.settings.route_success or p.kind=='go' and t.settings.route_done or p.kind=='stop' and t.settings.route_stopped
  if p.kind=='find' and not fn then fn=function(v) return route_line(p,v) end end
  if fn and not p.ack then
   local ok,ack=pcall(fn,line,s.destination,s)
   if not ok then fault('route acknowledgement parser failed')
   elseif ack==true then
    if p.kind=='find' and type(t.settings.resolve_target_room)=='function' then
     local good,room=pcall(t.settings.resolve_target_room,p.target_name,s.destination)
     if good and id(room) then p.target_room=tostring(room) end
    end
    p.ack=true;p.ack_prompt=s.prompt
   end
  end
 end
 function t.prompt() s.prompt=s.prompt+1;t.pump() end
 function t.tick()
  if s.follow_pending and clock()-s.follow_pending.at>(tonumber(t.settings.timeout) or 20) then s.follow_fault='acknowledgement timeout: follow';s.status=s.follow_fault;return false end
  local timeout=s.pending and s.pending.kind=='go' and (tonumber(t.settings.route_timeout) or 300) or (tonumber(t.settings.timeout) or 20)
  if s.pending and clock()-s.pending.at>timeout then return fault('acknowledgement timeout: '..s.pending.kind) end
  return t.pump()
 end
 return t
end

-- Runtime adapter: inspect unresolved state BEFORE invoking native OFF (STOP clears waits).
function M.blocked(c,follow)
 local s=c.current or {};local r=c.runner or {};local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {}
 local g=c.elemental_recovery or {};local d=c.containers_data or (c.containers and c.containers.data and c.containers.data(c)) or {}
 local root=r.root or c.root or {}
 if c.transport_unknown or root.transport_unknown or root.dispatching or root.action_dispatching or r.transport_unknown or r.transport_barrier or (r.waiting and not follow) or r.pending or r.dispatching or r.fault then return true,'runner unresolved' end
 local tattoo=c.tattoo_owner
 if tattoo then
  local active=tattoo.pending or tattoo.txn or tattoo.dispatching or tattoo.fault or (tattoo.phase and tattoo.phase~='idle' and tattoo.phase~='done')
  if type(tattoo.busy)=='function' then local ok,v=pcall(tattoo.busy);active=active or not ok or v end
  if active then return true,'tattoo unresolved' end
 end
 if b.pending or b.fault or b.dispatching or m.eq_pending or m.pending or m.fault or m.dispatching or m.physical_transport or w.pending or w.fault or w.dispatching then return true,'protected action unresolved' end
 local gp=g.pending
 local read_only_probe=not g.committed and not g.dispatching and g.phase=='probe' and gp and gp.phase=='probe' and gp.kind=='recovery'
 local read_only_idle=not gp and not g.committed and not g.dispatching and g.phase=='idle' and g.fault=='recovery timeout'
 local known_unsent=gp and gp.phase==g.phase and ((g.phase=='waiting' and gp.kind==nil) or (g.phase=='normal' and gp.kind==nil))
 if g.committed or g.dispatching or (g.fault and not read_only_probe and not read_only_idle) or (gp and not read_only_probe and not known_unsent) then return true,'globe unresolved' end
 if d.barrier or d.action_dispatching then return true,'container unresolved' end
 return false
end
function M.adapter(c,settings)
 settings=settings or {}
 local function ready(follow)
  local blocked,why=M.blocked(c,follow);if blocked then return false,why end
  local s=c.current or {};local p=s.player or {}
  if not yes(s.connected) or not getConnectionInfo then return false,'disconnected' end
  local ok,_,_,tcp=pcall(getConnectionInfo);if not ok or tcp~=true then return false,'TCP disconnected' end
  if yes(p.dead) or (tonumber(p.hp) or 0)<=0 then return false,'dead / no health' end
  if not follow then for _,key in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[key]) then return false,'not ready: '..key end end end
  local a=p.afflictions or {}
  if yes(p.prone) or a.prone or a.fallen or a.paralysis or a.asleep or a.unconsciousness or a.stun or a.stunned or (a.anorexia and a.asthma and a.slickness) then return false,'hindered' end
  if not follow and c.defense and c.defense.plan then local d=c.defense.plan(s);if not d or d.hold then return false,'own safety hold' end end
  return true
 end
 return {ready=ready,follow_ready=function() return ready(true) end,
  recall_ready=function()
   if c.mode~='OFF' and c.mode~='BASH' then return false,'recall requires OFF or BASH' end
   if c.runner and c.runner.mode~=c.mode then return false,'mode mismatch' end
   local p=(c.current or {}).player or {}
   if p.mounted==nil or (p.mounted~=false and tonumber(p.mounted)~=0) then return false,'mounted state not unmounted' end
   return ready()
  end,
  send_recall=function(command)
   local own=c.travel_owner and c.travel_owner.mount or id(settings.mount_id)
   local p=(c.current or {}).player or {}
   if not own or command~='recall '..own or (c.mode~='OFF' and c.mode~='BASH') or (c.runner and c.runner.mode~=c.mode) then return false end
   if p.mounted==nil or (p.mounted~=false and tonumber(p.mounted)~=0) or not ready() then return false end
   return (settings.sender or c.travel_sender or send)(command)
  end,
  refresh_items=function()
   local ok=ready(true);if not ok then return false end
   local gmcp_sender=settings.gmcp_sender or sendGMCP
   if type(gmcp_sender)~='function' then return false end
   if gmcp_sender([[Char.Items.Room ""]])==false then return false end
   return (settings.sender or c.travel_sender or send)('ih')
  end,
  refresh_ready=function() return ready(true) end,
  send_follow=function(command)
   local ok=ready(true);if not ok then return false end
   local own=c.travel_owner and c.travel_owner.mount or id(settings.mount_id)
   if not own or command~='order '..own..' follow me' then return false end
   return (settings.sender or c.travel_sender or send)(command)
  end,now=function() return getEpoch and getEpoch() or os.clock() end,
  send=function(command)
   if c.mode~='OFF' or (c.runner and c.runner.mode~='OFF') then return false end
   return (settings.sender or c.travel_sender or send)(command)
  end,
  pause=function()
   local blocked,why=M.blocked(c);if blocked then return false,why end
   if type(combat_v2_set_mode)~='function' then return false,'native OFF unavailable' end
   local g=c.elemental_recovery;local saved
   if g and not g.committed and not g.dispatching and g.phase=='probe' and g.pending and g.pending.phase=='probe' and g.pending.kind=='recovery' then
    saved={pending=g.pending,phase=g.phase,fault=g.fault,status=g.status}
   end
   local ok,result=pcall(combat_v2_set_mode,'OFF')
   -- Native OFF may discard a read-only probe. Preserve its diagnostic record,
   -- without rearming GLOBE or resurrecting any timer/master.
   if saved then g.pending=saved.pending;g.phase=saved.phase;g.fault=saved.fault;g.status=saved.status;g.armed=false end
   if not ok or result==false or c.mode~='OFF' then return false,'could not stop offense' end
   return true
  end}
end
function M.attach(c,settings)
 if c.travel and c.travel.attached then return c.travel end
 if c.travel_state and (c.travel_state.pending or c.travel_state.dispatching or c.travel_state.fault or c.travel_state.intent or c.travel_state.route or c.travel_state.follow_due or c.travel_state.recall_due or c.travel_state.follow_pending or c.travel_state.follow_fault) then return nil,'unfinished travel owner; refuse replacement' end
 settings=settings or c.convenience_settings or {}
 for _,name in ipairs({'tempAlias','registerAnonymousEventHandler','tempPromptTrigger','tempRegexTrigger','tempTimer','killAlias','killAnonymousEventHandler','killTrigger','killTimer'}) do
  if type(_G[name])~='function' then return nil,'Mudlet API unavailable: '..name end
 end
 local t=M.new(M.adapter(c,settings),settings);c.travel_state=t.state;c.travel_owner=t.state
 t.aliases={};t.handlers={};t.triggers={};t.attached=true;c.travel=t
 local function report(ok,why) if not ok and why then print('TRAVEL: '..tostring(why)) end end
 local function alias(pattern,fn) t.aliases[#t.aliases+1]=tempAlias(pattern,fn) end
 local function handler(event,fn) t.handlers[#t.handlers+1]=registerAnonymousEventHandler(event,fn) end
 local ok,why=pcall(function()
  alias('^pt (.+)$',function() report(t.request('pt',matches and matches[2] or '')) end)
  for _,action in ipairs({'qm','qd','rh'}) do local a=action;alias('^'..a..'$',function() report(t.request(a)) end) end
  handler('gmcp.Char.Vitals',function() local v=gmcp and gmcp.Char and gmcp.Char.Vitals;if v then t.vitals(v.mounted) end end)
  handler('gmcp.Room.Info',function() local r=gmcp and gmcp.Room and gmcp.Room.Info;if r then t.room(r.num or r.id,r.name) end end)
  local version=0
  local function items(full,field)
   local p=gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items[field];if not p then return end
   local room=p.room_id or p.room or (p.location~='room' and p.location)
   -- Native location=room has no room ID. room_for_items may delegate to Core's
   -- authoritative current-room view AFTER Core processes this event/version,
   -- or provide independent scope proof. Never return an arbitrary cached room.
   if not room and type(settings.room_for_items)=='function' then room=settings.room_for_items(p,c,full) end
   if not room then return end
   version=version+1
   if field=='Remove' then t.remove(room,p.item or p.id,version)
   else t.items(room,p.items or {p.item or p},full,version) end
  end
  handler('gmcp.Char.Items.List',function() items(true,'List') end)
  handler('gmcp.Char.Items.Add',function() items(false,'Add') end)
  handler('gmcp.Char.Items.Update',function() items(false,'Update') end)
  handler('gmcp.Char.Items.Remove',function() items(false,'Remove') end)
  handler('sysDisconnectionEvent',function() if t.unresolved() then t.state.fault='disconnected with travel unresolved' end;t.state.continuity=nil;t.state.present=nil end)
  t.triggers[#t.triggers+1]=tempRegexTrigger('^.*$',function() t.text(line or '') end)
  t.triggers[#t.triggers+1]=tempPromptTrigger(function() t.prompt() end)
  local function tick() if not t.attached then return end;t.tick();t.timer=tempTimer(1,tick) end
  t.timer=tempTimer(1,tick)
  -- Seed LOCATION only. Cached mounted/items cannot cause automatic mount actions.
  local room=c.current and c.current.room;if room then t.room(room.id) end
 end)
 if not ok then
  t.state.fault=nil;t.state.pending=nil;t.state.intent=nil;t.state.route=nil;M.detach(c);return nil,tostring(why)
 end
 return t
end
function M.detach(c)
 local t=c.travel;if not t then return true end
 if t.unresolved() or t.state.intent or t.state.route then return false,'unfinished travel owner retained' end
 t.attached=false
 for _,v in ipairs(t.aliases or {}) do killAlias(v) end
 for _,v in ipairs(t.handlers or {}) do killAnonymousEventHandler(v) end
 for _,v in ipairs(t.triggers or {}) do killTrigger(v) end
 if t.timer then killTimer(t.timer) end
 c.travel=nil;return true
end
function M.pt(c,dest) if not c.travel then return false,'travel not attached' end;return c.travel.request('pt',dest) end
return M
