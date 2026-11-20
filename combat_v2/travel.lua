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
  if s.dispatching or (s.haven_refresh and s.haven_refresh.dispatching) or s.pending or s.fault then return false,'travel unresolved' end
  if t.io.mount_deferred and t.io.mount_deferred() then return false,'outside Haven proof pending' end
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
   local deferred=t.io.mount_deferred and t.io.mount_deferred()
   -- Only pump may issue this bounded read. Views/attachment remain passive.
   local witness=s.haven_outside
   local f=deferred and witness and t.io.deferred_refresh_ready and t.io.deferred_refresh_ready(witness)
   if f and (not s.haven_refresh or (s.haven_refresh.owner~=f and not s.haven_refresh.quarantine and not s.haven_refresh.dispatching)) and t.io.refresh_items then
    local q={owner=f,witness=witness,room=s.room,version=s.item_version or 0,at=clock(),dispatching=true}
    s.haven_refresh=q -- Reserve BEFORE transport: nested prompts cannot retry/release.
    local ok,result=pcall(t.io.refresh_items,witness)
    q.dispatching=nil
    if not ok or result==false then q.quarantine='outside mount refresh transport unavailable';s.status=q.quarantine end
    q.transport_ok=ok and result~=false
    q.finalized_prompt=s.prompt -- Reentrant prompts precede transport finalization.
    deferred=t.io.mount_deferred and t.io.mount_deferred()
   end
   if s.refresh_due and not deferred and not s.refresh_dispatching and (not t.io.refresh_ready or t.io.refresh_ready()) then
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
   if not deferred and s.follow_due and s.mount and (known_here() or s.mounted==s.mount) then
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

    elseif p.kind=='find' and p.rejected and s.prompt>p.rejected_prompt then
     -- Exact owned rejection + later prompt settles only this read-only query.
     -- Never reuse a previous proof or turn the backoff timer into GO permission.
     s.route_proof=nil;s.last_find_rejection=p;resolve()
     if t.io.route_allowed and not t.io.route_allowed() then
      s.intent=nil;s.route=nil;s.status='read-only FIND settled; route consent revoked';return
     end
     if (s.find_attempts or 0)>=3 then
      s.refusal={kind='find_cooldown',recoverable=true,reason='PATH FIND cooldown after 3 attempts',serial=p.serial}
      s.intent=nil;s.route=nil;s.status=s.refusal.reason;return
     end
     s.find_retry_at=clock()+2;s.route='finding';return
    elseif p.kind=='find' and p.ack and s.prompt>p.ack_prompt then
     if t.io.route_allowed and not t.io.route_allowed() then
      s.last_readonly=p;resolve();s.intent=nil;s.route=nil;s.route_proof=nil;s.status='read-only FIND settled; route consent revoked';return
     end
     local ok=ready();if not ok then return end
     if s.mounted~=s.mount or s.room~=p.room then return end
     s.route_proof=p;resolve();s.route='walking';return commit('go','path go gallop')
    elseif (p.kind=='go' or p.kind=='stop') and p.ack and s.prompt>p.ack_prompt then
     local ok=ready();if not ok then return end
     resolve();s.route=nil;s.intent=nil;s.status='travel complete; offense remains OFF'
    else return end
   end
   if s.pending or s.fault then return end
   if deferred then return end -- Unsent outside-plane intention, never an ACK reset.
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
    if t.io.route_allowed and not t.io.route_allowed() then s.intent=nil;s.route=nil;s.find_retry_at=nil;s.route_proof=nil;return end
    if s.find_retry_at and clock()<s.find_retry_at then return end
    s.find_retry_at=nil;s.route_proof=nil;s.find_attempts=(s.find_attempts or 0)+1
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
  if action~='pt' and s.haven_refresh and s.haven_refresh.dispatching then return false,'read-only refresh dispatching' end
  if busy() or s.intent or s.route then return false,'travel unresolved' end
  if action=='pt' then
   arg=destination(arg);if not arg then return false,'use pt AREA or positive ROOM number (maximum 120 characters)' end
  end
  if not ({pt=true,qm=true,qd=true,rh=true})[action] then return false,'unknown convenience action' end
  if not s.mount and s.mounted and s.mounted~='0' then s.mount=s.mounted end
  if not s.mount then return false,'own mount is unknown; configure mount_id' end
  local ok,why=ready();if not ok then return false,why end
  ok,why=pause();if not ok then return false,why end
  s.refusal=nil;s.find_attempts=0;s.find_retry_at=nil;s.route_proof=nil
  if action=='pt' and id(arg) and id(arg)==id(s.room) then
   s.destination=arg;s.phase='idle';s.status='already at exact numeric destination; offense remains OFF';return true
  end
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
  -- This method receives actual Room.Info, never a timer or cached view.
  if t.io.haven_exit_witness then s.haven_outside=t.io.haven_exit_witness(room) end
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
  local q=s.haven_refresh
  if q and not q.complete and full and q.room==s.room then
   if clock()-q.at>(tonumber(t.settings.timeout) or 20) and (s.full_item_version or -1)<=q.version then q.quarantine='outside mount refresh timeout';s.status=q.quarantine end
   local valid=type(items)=='table'
   if valid then for _,item in pairs(items) do if type(item)~='table' or not id(item.id) then valid=false;break end end end
   if not valid then q.quarantine='malformed outside mount refresh';s.status=q.quarantine;return false end
   if not q.response_version and version>q.version then
    q.response_version=version;q.itemResponsePromptSequence=s.prompt
   end
  end
  s.item_version=version
  if full then s.full_item_version=version;s.full_item_prompt=s.prompt end
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
  if p.kind=='find' and line=='You cannot find a new path so soon.' then
   p.rejected=true;p.rejected_prompt=s.prompt;p.ack=nil;s.route_proof=nil;return
  end
  if p.rejected then return end
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
  local q=s.haven_refresh
  if q and not q.complete and not q.quarantine and clock()-q.at>(tonumber(t.settings.timeout) or 20) and (s.full_item_version or -1)<=q.version then
   q.quarantine='outside mount refresh timeout';s.status=q.quarantine
  end
  if s.follow_pending and clock()-s.follow_pending.at>(tonumber(t.settings.timeout) or 20) then s.follow_fault='acknowledgement timeout: follow';s.status=s.follow_fault;return false end
  local timeout=s.pending and s.pending.kind=='go' and (tonumber(t.settings.route_timeout) or 300) or (tonumber(t.settings.timeout) or 20)
  if s.pending and clock()-s.pending.at>timeout then return fault('acknowledgement timeout: '..s.pending.kind) end
  return t.pump()
 end
 return t
end

-- Pure diagnostic classification shared with physical resource gates. Never clears
-- fault/pending bookkeeping and never admits an outstanding inventory query.
function M.terminal_globe_exhaustion(c)
 local g=c.elemental_recovery or {};local gp=g.pending;local q=g.pool
 -- Explicit OFF revokes live pool authority but can leave a settled exhausted
 -- owner diagnostic. This proves no resources or actions, never inventory readiness.
 local closed=g.fault=='all carried globes exhausted' and g.armed==false and g.phase=='idle' and g.status=='disarmed' and gp==nil and not g.committed and not g.dispatching and not g.transport_unknown and type(q)=='table' and q.enabled==false and q.known==false and q.ever_owned==true and type(q.owned)=='table' and next(q.owned)==nil and type(q.exhausted)=='table' and q.query==nil and q.dispatching==false and not q.transport_unknown
 if closed then return true end
 local known_unsent=gp and gp.phase==g.phase and ((g.phase=='waiting' and gp.kind==nil) or (g.phase=='normal' and gp.kind==nil))
 local exhausted=g.fault=='all carried globes exhausted' and g.armed==false and not g.committed and not g.dispatching and (not gp or known_unsent) and type(q)=='table' and q.enabled==true and q.known==true and q.ever_owned==true and q.query==nil and not q.dispatching and type(q.owned)=='table' and type(q.exhausted)=='table'
 if exhausted then
  local count=0
  for key,value in pairs(q.owned) do
   count=count+1
   if count>32 or type(key)~='string' or id(key)~=key or value~=true or q.exhausted[key]~=true then exhausted=false;break end
  end
 end
 return exhausted==true
end

-- Runtime adapter: inspect unresolved state BEFORE invoking native OFF (STOP clears waits).
function M.blocked(c,follow)
 local s=c.current or {};local r=c.runner or {};local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {}
 local g=c.elemental_recovery or {};local d=c.containers_data or (c.containers and c.containers.data and c.containers.data(c)) or {}
 -- Maps use nonemptiness, not table truthiness (an empty barrier map is idle).
 local function barrier(v) if type(v)=='table' then return next(v)~=nil end;return v~=nil and v~=false end
 local function uncertain(root)
  return root and (root.fault or root.transport_unknown or root.dispatching or root.action_dispatching or barrier(root.transportBarriers) or barrier(root.transport_barriers) or root.transport_barrier or root.transport_commit)
 end
 if c.transport_unknown or uncertain(r.root) or uncertain(c.root) or uncertain(r) or (r.waiting and not follow) or r.pending then return true,'runner unresolved' end
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
 -- A disarmed, fully proven terminal pool is a diagnostic, not unknown transport.
 -- Preserve the diagnostic and bookkeeping; never admit probes or query barriers.
 local exhausted=M.terminal_globe_exhaustion(c)
 if g.committed or g.dispatching or (g.fault=='all carried globes exhausted' and not exhausted) or (g.fault and not exhausted and not read_only_probe and not read_only_idle) or (gp and not read_only_probe and not known_unsent) then return true,'globe unresolved' end
 if d.barrier or d.action_dispatching then return true,'container unresolved' end
 return false
end
-- Passive runtime-only epoch: no game queries, no persistence, no fault clearing.
-- Hot adapters must call bind_session(c, api) before constructing the adapter.
function M.bind_session(c,api)
 api=api or _G
 if c.haven_session_binding then return true end
 if type(api.registerAnonymousEventHandler)~='function' or type(api.killAnonymousEventHandler)~='function' then return false,'session event API unavailable' end
 local binding={api=api}
 local ok,id=pcall(api.registerAnonymousEventHandler,'sysDisconnectionEvent',function()
  if c.haven_session_binding==binding then c.haven_session_token={} end
 end)
 if not ok or type(id)~='number' or id<=0 or id==math.huge or id~=math.floor(id) then return false,'session event registration failed' end
 binding.handle=id;c.haven_session_token={};c.haven_session_binding=binding
 return true
end
local function haven_session(c)
 return c.haven_session_token or c.session_generation or (c.current or {}).session_generation or (c.current or {}).session_id
end
-- Defer only UNSENT loyal convenience while the configured private plane owns us.
-- Pending FOLLOW/RECALL and unknown faults remain immutable barriers.
function M.haven_deferred(c)
 local cfg=c.restock_settings or {};local d=c.restock_data or {};local s=c.travel_owner or {}
 local room=(c.current or {}).room or {};local haven=d.haven_room or (cfg.globe_haven_return==true and cfg.haven_room)
 local private=haven and tostring(room.id)==tostring(haven)
 local h=c.haven_handoff;local f=h and h.deferred_follow
 if private then
  if (s.follow_due or s.recall_due) and not (s.pending or s.dispatching or s.fault or s.follow_pending or s.follow_fault) then
   c.haven_handoff=h or {};h=c.haven_handoff
   if not f then f={owner=s,episode=s.follow_episode,session=haven_session(c),version=s.item_version or 0};h.deferred_follow=f end
   if f.owner==s and f.episode~=nil and f.episode==s.follow_episode and f.session~=nil and f.session==haven_session(c) then
    f.follow_due=f.follow_due or s.follow_due;f.recall_due=f.recall_due or s.recall_due
    s.follow_due=nil;s.recall_due=nil
   end
  end
  return true
 end
 if f then
  -- Outside requires the same owner/session and genuinely newer full room items.
  if f.owner~=s or f.session==nil or haven_session(c)==nil or f.session~=haven_session(c) or f.episode==nil or f.episode~=s.follow_episode then return true end
  -- Unsolicited full lists are evidence, not a replacement for owned EXIT scope.
  -- Revalidate before restoring even unsent intent, including the no-query lane.
  if M.blocked(c) then return true end
  local w=s.haven_outside
  local p=d.pending
  if w then
   if M.haven_refresh_wait(c,w)~=f then return true end
  elseif p and p.kind=='haven_exit' then
   return true -- A known owned EXIT cannot fall back to manual provenance.
  end
  local q=s.haven_refresh
  if q and q.owner==f and (q.dispatching or q.quarantine or q.room~=tostring(room.id) or (s.full_item_version or -1)<=q.version) then return true end
  if q and q.owner==f and M.haven_refresh_wait(c,q.witness)~=f then return true end
  if not room.id or not s.presence_room or tostring(s.presence_room)~=tostring(room.id) or (s.full_item_version or -1)<=(f.version or -1) then return true end
  -- First accepted full response fixes the fence; duplicate lists cannot postpone
  -- readiness forever. A prompt inside the query sender never settles transport.
  if q and q.owner==f then
   if q.transport_ok~=true or not q.response_version or q.itemResponsePromptSequence==nil or q.finalized_prompt==nil or s.prompt<=q.itemResponsePromptSequence or s.prompt<=q.finalized_prompt then return true end
  else
   if f.itemResponsePromptSequence==nil then f.itemResponsePromptSequence=s.full_item_prompt end
   if f.itemResponsePromptSequence==nil or s.prompt<=f.itemResponsePromptSequence then return true end
  end
  if s.pending or s.dispatching or s.fault or s.follow_pending or s.follow_fault then return true end
  s.follow_due=s.follow_due or f.follow_due or true;s.recall_due=s.recall_due or f.recall_due
  if q and q.owner==f then q.complete=true end
  h.deferred_follow=nil
 end
 return false
end
-- A trusted read-only lane, not general movement/readiness permission. The witness
-- is captured only by travel.room while an owned, successfully issued EXIT exists.
function M.haven_refresh_wait(c,w)
 local s=c.travel_owner or {};local d=c.restock_data or {};local h=c.haven_handoff or {};local f=h.deferred_follow
 local room=(c.current or {}).room or {}
 if not w or s.haven_outside~=w or w.follow~=f or w.lease~=d or not w.exit or w.exit.kind~='haven_exit' or w.exit.transport_ok~=true then return nil end
 if not d.haven_mode or not d.active or not d.resume_consent or not d.busy or not d.owned_pause or d.fault or d.dispatching or c.user_activity~=d or c.mode~='OFF' then return nil end
 if d.phase~='haven_exit' and not (d.phase=='route' and d.pending and d.pending.kind=='route' and d.route_owner==s) then return nil end
 if not room.id or room.area==nil or tostring(room.id)~=w.room or s.room~=w.room or tostring(d.haven_room)~=tostring(w.exit.room) or tostring(room.id)==tostring(d.haven_room) then return nil end
 if not f or f.owner~=s or f.session==nil or haven_session(c)==nil or f.session~=haven_session(c) or f.episode==nil or f.episode~=s.follow_episode then return nil end
 if s.pending or s.dispatching or s.fault or s.follow_pending or s.follow_fault or M.blocked(c) then return nil end
 return f
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
 return {route_allowed=function()
   local d=c.restock_data;local tr=c.travel_owner
   if d and d.route_owner==tr and d.pending and d.pending.kind=='route' then return d.active==true and d.resume_consent==true and not d.fault end
   return true
  end,mount_deferred=function() return M.haven_deferred(c) end,ready=ready,follow_ready=function() return ready(true) end,
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
  haven_exit_witness=function(room)
   local d=c.restock_data;local p=d and d.pending
   -- Successful issued EXIT is provenance even after STOP/revocation. Permission
   -- is checked separately at read/release time; never relabel it a manual exit.
   if d and d.phase=='haven_exit' and p and p.kind=='haven_exit' and p.transport_ok==true and tostring(room)~=tostring(p.room) then return {lease=d,exit=p,room=tostring(room),follow=(c.haven_handoff or {}).deferred_follow} end
  end,
  deferred_refresh_ready=function(w)
   if not ready(true) then return nil end
   return M.haven_refresh_wait(c,w)
  end,
  refresh_items=function(w)
   if w then
    if not ready(true) or not M.haven_refresh_wait(c,w) then return false end
    local gmcp_sender=settings.gmcp_sender or sendGMCP
    if type(gmcp_sender)~='function' then return false end
    return gmcp_sender([[Char.Items.Contents "room"]])
   end
   local ok=ready(true);if not ok then return false end
   local gmcp_sender=settings.gmcp_sender or sendGMCP
   if type(gmcp_sender)~='function' then return false end
   if gmcp_sender([[Char.Items.Room ""]])==false then return false end
   return (settings.sender or c.travel_sender or send)('ih')
  end,
  refresh_ready=function() return ready(true) end,
  send_follow=function(command)
   if M.haven_deferred(c) then return false,'Mount follow deferred outside private Haven' end
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
 local bound,reason=M.bind_session(c,_G);if not bound then return nil,reason end
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
 local binding=c.haven_session_binding
 if binding then binding.api.killAnonymousEventHandler(binding.handle);c.haven_session_binding=nil;c.haven_session_token=nil end
 c.travel=nil;return true
end
function M.pt(c,dest) if not c.travel then return false,'travel not attached' end;return c.travel.request('pt',dest) end
return M
