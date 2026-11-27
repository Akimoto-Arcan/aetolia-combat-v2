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
  if #row>2000 or line:find('[%c]') or row:find('[^a-z,%s]') then p.invalid=true;return end
  -- Native PATH GO owns these queue entries; never send their literal text.
  -- Preserve comma-delimited compounds, while retaining ordinary whitespace
  -- direction rows and the native trailing comma used by wrapped responses.
  local special={['enter portal']=true,['ride elevator']=true,['wait']=true,['enter fissure']=true,['enter crevice']=true}
  local count,compounds=0,0
  local body=row:match('^%s*(.-)%s*$')
  if body:sub(-1)==',' then body=body:sub(1,-2) end
  for entry in (body..','):gmatch('(.-),') do
   entry=entry:match('^%s*(.-)%s*$')
   if entry=='' then p.invalid=true;return end
   if special[entry] then count=count+1;compounds=compounds+1
   else
    for word in entry:gmatch('%S+') do
     if not directions[word] then p.invalid=true;return end
     count=count+1
    end
   end
  end
  if count==0 then p.invalid=true;return end
  if compounds>0 then p.has_special=true;p.compound_count=(p.compound_count or 0)+compounds end
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

 -- Fresh-cohort same-session travel reconciliation. No saved route or request.
 -- Clear ACK is a new barrier receipt, NEVER settlement of the old incident.
 local reconcile,clear_serial=nil,0
 local function clear_scope(q)
  return q==reconcile and q.session~=nil and t.io.session and q.session==t.io.session()
   and q.stamp~=nil and t.io.intent_stamp and q.stamp==t.io.intent_stamp()
 end
 function t.reconcile_begin()
  if s.pending or s.dispatching or s.pumping or reconcile and reconcile.dispatching then return false,'active travel cannot be overwritten' end
  clear_serial=clear_serial+1
  reconcile={stage='new',serial=clear_serial}
  return true
 end
 function t.reconcile_status()
  local q=reconcile
  return q and {stage=q.stage,serial=q.serial,ready=q.stage=='complete',outcome='UNSETTLED'} or {ready=true}
 end
 local function reconcile_send(q,command,stage)
  if q~=reconcile or q.dispatching then return false,'reconcile dispatch active' end
  q.stage=stage;q.dispatching=true
  local ok,result=pcall(t.io.send,command)
  if q~=reconcile then return false,'reconcile owner replaced during dispatch' end
  q.dispatching=false;q.finalized=s.prompt
  if not ok or result==false or not clear_scope(q) then q.stage='failed';return false,'reconcile transport/scope unknown; no evidence adopted' end
  q.transport_ok=true;return true
 end
 local function reconcile_pump()
  local q=reconcile;if not q then return false end
  if q.dispatching then return false end
  if q.stage~='new' and not clear_scope(q) then q.stage='invalid';return false end
  if q.stage=='acked' and s.prompt>q.ack_prompt and s.prompt>q.finalized then
   q.transport_ok=nil;q.room=nil;q.full=nil;q.version=s.item_version or -1
   return reconcile_send(q,'look','look')
  end
  if q.stage=='look' and q.transport_ok and q.room and q.full
   and q.room==s.room and s.prompt>q.room_prompt and s.prompt>q.full_prompt and s.prompt>q.finalized then
   q.stage='complete'
  end
  return false
 end
 local function reconcile_request(action,arg)
  if not ({pt=true,qm=true,qd=true,rh=true})[action] then return false,'unknown convenience action' end
  if action=='pt' and arg~='stop' and arg~='cancel' and not destination(arg) then return false,'invalid explicit destination' end
  local q=reconcile;if not q then return true end
  if q.dispatching then return false,'reconcile dispatch active' end
  if action=='pt' and (arg=='stop' or arg=='cancel') then q.stage='cancelled';return false,'reconciliation cancelled; no old request retained' end
  if q.stage~='new' and not clear_scope(q) then q.stage='invalid' end
  if q.stage=='complete' and clear_scope(q) then reconcile=nil;return true end
  if q.stage=='cancelled' or q.stage=='failed' or q.stage=='invalid' then
   local ok,why=t.reconcile_begin();if not ok then return false,why end;q=reconcile
  end
  if q.stage=='new' then
   q.session=t.io.session and t.io.session();q.stamp=t.io.intent_stamp and t.io.intent_stamp()
   if q.session==nil or q.stamp==nil or not t.io.ready or not t.io.ready() then return false,'fresh current travel context required' end
   local ok,why=reconcile_send(q,'path clear','clear')
   return false,ok and 'PATH CLEAR requested; wait for owned ACK, LOOK/current FULL and later prompt, then make NEW explicit request' or why
  end
  return false,'travel reconciliation '..q.stage..'; no route/new job retained; explicit reinitialization required after failure/cancel'
 end
 -- Death is a send veto, not proof that a previously issued action failed.
 local function dead()
  return s.dead==true or (t.io.dead and t.io.dead()==true)
 end
 local function revoke_unsent(reason)
  if s.intent or s.follow_due or s.recall_due or s.refresh_due then
   s.last_revoked_intent={intent=s.intent,route=s.route,destination=s.destination,follow_due=s.follow_due,recall_due=s.recall_due,refresh_due=s.refresh_due,reason=reason,prompt=s.prompt}
  end
  if reason=='death preflight' and t.io.revoke_on_death then t.io.revoke_on_death() end
  s.convenience_revoked=true
  s.intent=nil;s.follow_due=nil;s.recall_due=nil;s.refresh_due=nil
  s.continuity=nil;s.loss_refresh=nil;s.icy_fallback=nil;s.find_retry_at=nil
  -- Destination/proof remain necessary for an already-issued GO/STOP.
  if not s.pending then s.route=nil;s.destination=nil;s.route_proof=nil end
 end
 local function clock() return t.io.now and t.io.now() or os.clock() end
 local function fault(why) s.fault=why;s.status=why;return false,why end
 local function busy() return s.dispatching or s.pending or s.fault or s.follow_pending or s.follow_fault or s.follow_due or s.recall_due end
 local function ready()
  if t.io.ready then return t.io.ready() end
  return false,'readiness adapter unavailable'
 end
 local function commit(kind,command,recall_context)
  if dead() then revoke_unsent('death preflight');return false,'dead / no health' end
  if s.dispatching or (s.haven_refresh and s.haven_refresh.dispatching) or s.pending or s.fault then return false,'travel unresolved' end
  if t.io.mount_deferred and t.io.mount_deferred() then return false,'outside Haven proof pending' end
  local ok,why=ready();if not ok then return false,why end
  local p={kind=kind,command=command,at=clock(),prompt=s.prompt,room=s.room,serial=s.serial+1}
  if kind=='go' or kind=='find' then
   p.destination=s.destination;p.proof=s.route_proof
   p.session=t.io.session and t.io.session()
   p.intent_stamp=t.io.intent_stamp and t.io.intent_stamp()
  end
  if kind=='recall' then p.recall_context=recall_context;p.mount=s.mount;p.command=command end
  s.serial=p.serial;s.pending=p;s.phase=kind;s.dispatching=true
  local good,result=pcall(kind=='recall' and (t.io.send_recall or t.io.send) or t.io.send,command)
  p.transport_ok=good and result~=false
  p.finalized_prompt=s.prompt
  s.dispatching=false
  if not good or result==false then
   if kind=='find' then t.cancel_find('read-only FIND transport unknown');return false,s.status end
   return fault('transport unknown: '..kind)
  end
  -- Synchronous observation may ACK, but never dispatch another stage until return.
  t.pump();return true
 end
 local function pause()
  if not t.io.pause then return false,'pause adapter unavailable' end
  return t.io.pause()
 end
 local function resolve() s.pending=nil;s.phase='idle' end
 local function known_here() return s.present==true and s.presence_room==s.room end
 -- Only a freshly issued, owned gallop may lend authority to one downgrade.
 -- Queue-cleared is NOT a usable route: solicit a new FIND from the actual room.
 local function icy_scope(p)
  return p and p.destination==s.destination and s.intent=='pt' and s.route=='walking'
   and p.session~=nil and t.io.session and p.session==t.io.session()
   and p.intent_stamp~=nil and t.io.intent_stamp and p.intent_stamp==t.io.intent_stamp()
   and p.proof==s.route_proof and p.proof and p.proof.transport_ok==true
   and not s.icy_fallback and not s.follow_pending and not s.follow_due and not s.recall_due
   and s.mounted==s.mount and s.mount~=nil
   and (not t.io.route_allowed or t.io.route_allowed())
 end
 local function icy_continue_scope(e)
  return e and s.icy_fallback==e and s.intent=='pt' and s.destination==e.destination
   and s.room==e.room and s.mounted==s.mount and s.mount~=nil
   and e.session~=nil and t.io.session and e.session==t.io.session()
   and e.intent_stamp~=nil and t.io.intent_stamp and e.intent_stamp==t.io.intent_stamp()
   and not s.follow_pending and not s.follow_due and not s.recall_due
   and (not t.io.route_allowed or t.io.route_allowed())
   and t.io.icy_ready and t.io.icy_ready(e.room)
 end
 -- Goal proof belongs to this exact controller transaction, not a generic ACK.
 -- Old runtimes lack transport_ok; their explicit unknown faults still fence us.
 local function sequence(v) return type(v)=='number' and v>=0 and v<math.huge and v==math.floor(v) end
 local function recall_owned(p)
  return type(p)=='table' and p.kind=='recall' and s.phase=='recall'
   and type(s.mount)=='string' and id(s.mount)==s.mount
   and type(p.serial)=='number' and p.serial>0 and p.serial<math.huge and p.serial==math.floor(p.serial) and p.serial==s.serial
   and type(p.room)=='string' and p.room~='' and sequence(p.prompt)
   and (p.mount==nil or p.mount==s.mount) and p.transport_ok~=false
 end
 local function recall_arrived(p)
  return recall_owned(p) and not p.recall_unconfirmed_timeout and p.arrived==true and sequence(p.arrival_prompt) and p.arrival_prompt>=p.prompt
 end
 local function recall_rejected(p)
  return recall_owned(p) and p.outside_rejected==true and p.command=='recall '..s.mount
   and sequence(p.rejected_prompt) and p.rejected_prompt>=p.prompt
 end
 local function recall_mounted(p)
  -- RECALL was issued only while confirmed unmounted. A newer exact own-ID
  -- Vitals observation therefore proves its loyal-location goal already met,
  -- even after manual travel. Boolean mounted alone is never sufficient.
  return recall_owned(p) and p.transport_ok==true and sequence(p.finalized_prompt)
   and p.finalized_prompt>=p.prompt and p.mount==s.mount
   and (p.command=='recall mount' or p.command=='recall '..s.mount)
   and s.mounted==s.mount and sequence(s.mount_event) and s.mount_event>p.serial
   and t.io.own_mounted_goal and t.io.own_mounted_goal(s.mount,s.room)==true
 end
 local function settle_recall()
  local p=s.pending
  local rejected=recall_rejected(p)
  local achieved=recall_mounted(p)
  if s.dispatching or not (recall_arrived(p) or rejected or achieved) or not sequence(s.prompt) or s.prompt<=(achieved and p.finalized_prompt or (rejected and p.rejected_prompt or p.arrival_prompt)) then return false end
  if s.fault and s.fault~='acknowledgement timeout: recall' and s.fault~='unexpected room change during recall' then return false end
  local good,can=pcall(ready);if not good or can~=true then return false end
  -- A completed old-room goal cannot lend authority to unsent work here.
  if achieved then
   local record={pending=p,fault=s.fault,phase=s.phase,intent=s.intent,route=s.route,destination=s.destination,follow_due=s.follow_due,recall_due=s.recall_due,refresh_due=s.refresh_due,reason='exact own-mounted recall goal achieved; no automatic continuation',mount=s.mount,mount_event=s.mount_event,prompt=s.prompt,room=s.room,settled=true}
   s.recall_goal_archive=s.recall_goal_archive or {};s.recall_goal_archive[#s.recall_goal_archive+1]=record
   p.mounted_goal={mount=s.mount,event=s.mount_event,room=s.room,prompt=s.prompt}
   revoke_unsent('own-mounted recall goal achieved; no automatic continuation')
  end
  if achieved or rejected or s.room~=p.room then
   s.follow_due=nil;s.intent=nil;s.route=nil;s.destination=nil
   s.route_proof=nil;s.find_retry_at=nil;s.refresh_due=nil
  elseif s.intent=='rh' then s.intent=nil end
  s.recall_due=nil;s.fault=nil;s.last_recall=p;resolve()
  s.status=achieved and 'exact own-mounted recall goal settled; no automatic continuation' or (rejected and 'numeric recall rejected: mount already outside; no automatic retry' or 'own mount arrival settled')
  return true
 end
 local function recall(context)
  if not s.mount then return false,'own mount is unknown; configure mount_id' end
  if s.mounted~='0' then return false,'recall requires confirmed unmounted state' end
  if s.recalled then return false,'recall already issued; awaiting fresh own mount arrival' end
  local ok,why=ready();if not ok then return false,why end
  if t.io.recall_ready then ok,why=t.io.recall_ready();if not ok then return false,why end end
  s.recalled=true
  -- RECALL # retrieves a stabled loyal. Normal outside recovery is literal MOUNT.
  -- Numeric form requires a one-request explicit operator stable context, never
  -- a persisted setting or a guessed GMCP stable flag. No retry/fallback syntax.
  return commit('recall',context=='stable' and ('recall '..s.mount) or 'recall mount',context)
 end
 -- Cancel only the exact read-only transaction. Its parser lane remains reserved
 -- until a native prompt AFTER outer transport finalization closes the stream.
 -- Never store it as a physical pending/fault, or let a newer intent reuse it.
 function t.cancel_find(reason,token)
  local p=s.pending
  if not p or p.kind~='find' or p.serial~=s.serial or (token and token~=p) then return false,'no matching read-only FIND' end
  local owned_fault=s.fault==nil or s.fault=='unexpected room change during find' or s.fault=='acknowledgement timeout: find' or s.fault=='transport unknown: find' or s.fault=='route acknowledgement parser failed'
  p.cancelled=reason or 'operator cancelled read-only FIND';p.cancel_prompt=s.prompt
  s.find_quarantine=p;s.last_readonly=p;s.pending=nil;s.phase='idle'
  s.intent=nil;s.route=nil;s.destination=nil;s.route_proof=nil;s.find_retry_at=nil;s.icy_fallback=nil
  if owned_fault then s.fault=nil end
  s.status=p.cancelled..'; lookup response finishing'
  return true,s.status
 end
 local function drain_find()
  local q=s.find_quarantine
  if not q or s.dispatching or q.finalized_prompt==nil or s.prompt<=q.finalized_prompt then return false end
  -- A real server prompt is the end-of-response frame, including empty/error
  -- responses. Timers, text ACKs and reentrant prompts cannot close this lane.
  if s.prompt<=(q.cancel_prompt or q.prompt) then return false end
  q.drained_prompt=s.prompt;s.find_quarantine=nil
  s.status='read-only FIND retired; fresh travel request required';return true
 end
 function t.unresolved() return busy() and true or false end
 function t.pump()
  if reconcile then return reconcile_pump() end
  if s.dispatching or s.pumping then return false end
  if dead() then revoke_unsent('death preflight');return false end
  if t.io.observe_alive then t.io.observe_alive() end
  drain_find()
  local query=s.pending
  if query and query.kind=='find' and ((query.session~=nil and t.io.session and query.session~=t.io.session()) or (query.intent_stamp~=nil and t.io.intent_stamp and query.intent_stamp~=t.io.intent_stamp())) then
   t.cancel_find('read-only FIND source intent changed',query);return false
  end
  -- Settlement is passive and always precedes refresh/FOLLOW/new physical work.
  if settle_recall() then return true end
  if s.convenience_revoked then
   revoke_unsent('operator/death revocation')
   if s.pending and s.pending.kind=='find' then return t.cancel_find('operator/death revocation: read-only FIND continuation cancelled',s.pending) end
   if not s.pending then return false end
  end
  if s.fault or s.follow_fault then return false end
  if recall_arrived(s.pending) or recall_rejected(s.pending) then return false end
  s.pumping=true
  local function step()
   local deferred
   if not s.convenience_revoked then
   deferred=t.io.mount_deferred and t.io.mount_deferred()
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
   -- ORDER requires equilibrium, but must not stop BASH/upkeep or erase waits.
   -- Fresh positive presence retires only an UNSENT absence reservation.
   if known_here() and not s.pending then s.recall_due=nil end
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
    if p and p.kind~='go' and p.kind~='stop' and p.kind~='find' and p.kind~='dismount' then return end
    local ok=(t.io.follow_ready or ready)();if not ok then return end
    s.follow_pending={at=clock(),prompt=s.prompt,episode=s.follow_episode};s.dispatching=true
    local good,result=pcall(t.io.send_follow or t.io.send,'order '..s.mount..' follow me')
    s.dispatching=false
    if not good or result==false then s.follow_fault='transport unknown: follow';s.status=s.follow_fault end
    return
   end
   end -- No unissued refresh/FOLLOW after consent revocation.
   local p=s.pending
   if p then
    if p.kind=='go' and p.icy_stage==3 then
     if p.command~='path go gallop' or p.serial~=s.serial or s.phase~='go'
      or p.transport_ok~=true or p.finalized_prompt==nil or s.prompt<=p.finalized_prompt
      or s.prompt<=p.icy_prompt or p.icy_room~=s.room or not icy_scope(p) then return end
     local ok=ready();if not ok or not t.io.icy_ready or not t.io.icy_ready(s.room) then return end
     local e={go=p,destination=s.destination,session=p.session,intent_stamp=p.intent_stamp,room=s.room}
     s.last_icy_go=p;s.icy_fallback=e;s.route_proof=nil;resolve()
     s.route='finding';s.find_attempts=1;s.find_retry_at=nil
     return commit('find','path find '..e.destination)
    elseif p.kind=='mount' and s.mounted==s.mount and (s.mount_event or 0)>p.serial then resolve()
    elseif p.kind=='dismount' and s.mounted=='0' and (s.mount_event or 0)>p.serial then resolve()

    elseif p.kind=='find' and p.rejected and s.prompt>p.rejected_prompt and p.finalized_prompt~=nil and s.prompt>p.finalized_prompt then
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
    elseif p.kind=='find' and p.ack and s.prompt>p.ack_prompt and p.transport_ok==true and p.finalized_prompt~=nil and s.prompt>p.finalized_prompt then
     local e=s.icy_fallback
     if e then
      if not icy_continue_scope(e) then
       -- Revocation may settle this read, never resurrect the old route.
       if not s.intent or s.destination~=e.destination or (t.io.session and e.session~=t.io.session()) or (t.io.route_allowed and not t.io.route_allowed()) then
        s.last_readonly=p;resolve();s.intent=nil;s.route=nil;s.route_proof=nil
       end
       return
      end
      if p.transport_ok~=true or p.finalized_prompt==nil or s.prompt<=p.finalized_prompt then return end
     end
     if t.io.route_allowed and not t.io.route_allowed() then
      s.last_readonly=p;resolve();s.intent=nil;s.route=nil;s.route_proof=nil;s.status='read-only FIND settled; route consent revoked';return
     end
     local ok=ready();if not ok then return end
     if s.mounted~=s.mount or s.room~=p.room then return end
     s.route_proof=p;resolve();s.route='walking';return commit('go',(e or p.has_special) and 'path go' or 'path go gallop')
    elseif (p.kind=='go' or p.kind=='stop') and p.ack and s.prompt>p.ack_prompt then
     local ok=ready();if not ok then return end
     resolve();s.route=nil;s.intent=nil;s.status='travel complete; offense remains OFF'
    else return end
   end
   if s.pending or s.fault then return end
   if deferred then return end -- Unsent outside-plane intention, never an ACK reset.
   if known_here() then s.recall_due=nil end -- No issued pending remains here.
   if (s.follow_due or s.recall_due) and s.mount then
    if s.mounted=='0' and s.present==false and s.presence_room==s.room and (s.full_item_version or -1)>(s.absence_after_version or -2) then
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
     if s.present==false and s.presence_room==s.room and (s.full_item_version or -1)>(s.absence_after_version or -2) then return recall() end
     return
    end
    return commit('mount','quickmount '..s.mount)
   end
   if s.intent=='qm' then s.intent=nil;s.status='own mount confirmed';return end
   if s.intent=='pt' then
    if s.icy_fallback and not icy_continue_scope(s.icy_fallback) then return end
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
  if reconcile then local ok,why=reconcile_request(action,arg);if not ok then return false,why end end
  if dead() then revoke_unsent('death preflight');return false,'dead / no health' end
  if action=='pt' and (arg=='cancel' or arg=='stop') then return t.cancel() end
  if s.find_quarantine then return false,'lookup response finishing; wait for a real server prompt, then request travel again' end
  if action~='pt' and s.haven_refresh and s.haven_refresh.dispatching then return false,'read-only refresh dispatching' end
  if busy() or s.intent or s.route then return false,'travel unresolved' end
  if action=='rh' and arg~=nil and arg~='stable' then return false,'recall context must be explicit stable or omitted' end
  if action=='pt' then
   arg=destination(arg);if not arg then return false,'use pt AREA or positive ROOM number (maximum 120 characters)' end
  end
  if not ({pt=true,qm=true,qd=true,rh=true})[action] then return false,'unknown convenience action' end
  if not s.mount and s.mounted and s.mounted~='0' then s.mount=s.mounted end
  if not s.mount then return false,'own mount is unknown; configure mount_id' end
  local ok,why=ready();if not ok then return false,why end
  ok,why=pause();if not ok then return false,why end
  s.convenience_revoked=nil -- Only a new explicit accepted operator request rearms.
  s.refusal=nil;s.find_attempts=0;s.find_retry_at=nil;s.route_proof=nil;s.icy_fallback=nil
  if action=='pt' and id(arg) and id(arg)==id(s.room) then
   s.destination=arg;s.phase='idle';s.status='already at exact numeric destination; offense remains OFF';return true
  end
  s.intent=action;s.destination=arg;s.status=action..' requested'
  if action=='rh' then
   if s.mounted==s.mount then s.intent=nil;return false,'already riding own mount' end
   if s.last_recall and s.last_recall.outside_rejected==true then s.recalled=nil end -- Explicit new request only; never pump retry.
   local sent,reason=recall(arg);if not sent and not s.pending then s.intent=nil end;return sent,reason
  elseif action=='qd' then
   if not s.mounted then s.intent=nil;return false,'mounted state unknown' end
   if s.mounted=='0' then s.intent=nil;return true,'already unmounted' end
   return commit('dismount','quickdismount')
  end
  if s.mounted and s.mounted~='0' and s.mounted~=s.mount then s.intent=nil;return false,'riding a different mount' end
  t.pump();return not s.fault and not s.find_quarantine,s.status
 end
 -- Explicit operator revocation is NOT an acknowledgement or timeout reset.
 -- A known-successful own loyal recall cannot move the avatar or buy/use resources.
 -- Keep its exact object/fault in a journal; forbid automatic continuation/replay.
 function t.operator_unlock()
  if s.dispatching or s.pumping or s.follow_pending or s.follow_fault
   or s.stopping or s.haven_refresh or s.find_quarantine then return false,'travel transport/query retained' end
  local p=s.pending
  if p then
   if not recall_owned(p) or p.transport_ok~=true or p.finalized_prompt==nil
    or (p.command~='recall mount' and p.command~='recall '..s.mount)
    or (s.fault and s.fault~='unexpected room change during recall' and s.fault~='acknowledgement timeout: recall') then
    return false,'issued/unknown avatar or unrecognized transaction retained'
   end
  elseif s.fault then return false,'unassociated travel fault retained' end
  local record={pending=p,fault=s.fault,phase=s.phase,reason='operator revoked non-avatar convenience; NOT settled',settled=false,prompt=s.prompt}
  s.recall_quarantine=s.recall_quarantine or {};s.recall_quarantine[#s.recall_quarantine+1]=record
  s.last_recall_quarantine=record
  revoke_unsent('operator UNLOCK')
  if p then s.pending=nil;s.fault=nil;s.phase='idle' end
  s.route=nil;s.destination=nil;s.route_proof=nil;s.recalled=nil
  s.status='automation revoked; loyal recall journal retained; no automatic resume'
  return true,record
 end
 function t.cancel()
  if reconcile then reconcile.stage="cancelled";return true end
  if dead() then revoke_unsent('death preflight');return false,'dead / issued transaction retained' end
  if s.pending and s.pending.kind=='find' then return t.cancel_find('operator cancelled read-only FIND',s.pending) end
  s.intent=nil
  local go_fault=s.pending and s.pending.kind=='go' and (s.fault=='acknowledgement timeout: go' or s.fault=='transport unknown: go')
  if s.dispatching or (s.fault and not go_fault) or s.follow_pending or s.follow_fault then return false,'unresolved transport retained' end
  local p=s.pending
  if p and (p.kind=='go' or p.kind=='stop') then
   if p.kind=='stop' then return false,'path stop already committed' end
   -- Cancel cannot erase the in-flight route. Retain it inside stop transaction.
   local ok,why=ready();if not ok then return false,why end
   p.stop_fault=s.fault;s.fault=nil;s.pending=nil;s.stopping=p
   local sent,reason=commit('stop','path stop')
   if not sent and not s.pending then s.pending=p;s.fault=p.stop_fault;s.stopping=nil end
   return sent,reason
  end
  if p then return false,'committed action retained until acknowledgement' end
  s.route=nil;return true
 end
 function t.vitals(value,is_dead,hp)
  if is_dead~=nil or hp~=nil then s.dead=yes(is_dead) or (hp~=nil and (tonumber(hp) or 0)<=0) end
  local v=mounted(value);if not v then return end
  local old=s.mounted;s.mounted=v;s.mount_event=s.serial+1
  if not s.mount and v~='0' then s.mount=v end
  if v==s.mount then s.continuity=true;s.recalled=nil;s.recall_due=nil end
  if old and old~='0' and v=='0' and old==s.mount then
   s.follow_due=true;s.follow_episode=(s.follow_episode or 0)+1
   -- A pre-dismount FULL may omit the ridden mount. Never reuse it as loss.
   s.absence_after_version=s.item_version or -1
   if s.present==false then s.present=nil;s.presence_room=nil end
  end
  t.pump()
 end
 function t.room(room,name)
  if reconcile then
   local q=reconcile;if id(room) then s.room=tostring(room) end
   if q.stage=="look" and q.transport_ok and not q.dispatching and clear_scope(q) then q.room=s.room;q.room_prompt=s.prompt;q.full=nil end
   return
  end
  room=tostring(room or '')
  if room=='' or room==s.room then return end
  if s.room and s.pending and s.pending.kind=='find' then t.cancel_find('manual room change cancelled read-only FIND',s.pending)
  elseif s.room and s.pending and s.pending.kind~='go' and s.pending.kind~='stop' and not recall_arrived(s.pending) then fault('unexpected room change during '..s.pending.kind) end
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
  if reconcile then
   local q=reconcile
   if q.stage=="look" and q.transport_ok and not q.dispatching and clear_scope(q) and full==true and type(items)=="table" and type(version)=="number" and version>q.version and tostring(room or "")==q.room then
    local valid=true;for _,v in pairs(items)do if type(v)~="table" or not id(v.id) or type(v.name)~="string" then valid=false end end
    if valid then q.full=true;q.full_prompt=s.prompt;s.item_version=version end
   end
   return
  end
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
   local p=s.pending
   if p and p.kind=='recall' and p.room==s.room and p.serial==s.serial and s.phase=='recall' and not p.arrived then p.arrived=true;p.arrival_prompt=s.prompt end
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
  if reconcile then
   local q=reconcile
   if q.stage=="clear" and q.transport_ok and not q.dispatching and clear_scope(q) and line=="You have cleared your path queue." then q.stage="acked";q.ack_prompt=s.prompt end
   return
  end
  if s.find_quarantine then
   local q=s.find_quarantine
   -- Consume old output only in the old parser frame; never invoke a custom
   -- callback with the newer destination or lend its proof to another FIND.
   if line=='You cannot find a new path so soon.' then q.rejected=true;q.rejected_prompt=s.prompt
   elseif route_line(q,line)==true then q.ack=true;q.ack_prompt=s.prompt end
   return
  end
  local p=s.pending
  -- Generic death text is diagnostic only: manual LOOK may share its frame.
  if p and recall_owned(p) and line=='You are dead and cannot do that.' then p.dead_diagnostic_prompt=s.prompt end
  -- Exact native own sequence only. Quoted speech/near matches cannot arm it.
  -- Reentrant evidence is recorded but cannot settle until transport + later prompt.
  if p and not s.fault and p.kind=='go' and p.command=='path go gallop'
   and p.serial==s.serial and s.phase=='go' and not p.ack and icy_scope(p) then
   if line=='The icy ground is far too slippery to gallop upon.' and not p.icy_stage then p.icy_stage=1
   elseif line=='You have moved away from your path.' and p.icy_stage==1 then p.icy_stage=2
   elseif line=='You have cleared your path queue.' and p.icy_stage==2 then
    p.icy_stage=3;p.icy_prompt=s.prompt;p.icy_room=s.room
   end
  end
  -- Verified native own rejection, not a generic error or evidence of arrival.
  -- Bind it to the exact current numeric command; transport failure still wins.
  if p and line=='You already have a mount outside the stables. Use RECALL MOUNT.'
   and recall_owned(p) and p.room==s.room and p.command=='recall '..s.mount
   and (not s.fault or s.fault=='acknowledgement timeout: recall') then
   p.outside_rejected=true;p.rejected_prompt=s.prompt;return
  end
  -- This exact native rejection is diagnostic, not authority to erase an
  -- unconfirmed timeout. Fresh own arrival + later readiness still owns settlement.
  if p and line=="You begin to raise your fingers to your mouth to whistle for your mount before realising it's already with you!"
   and recall_owned(p) and p.room==s.room and p.command=='recall mount'
   and (not s.fault or s.fault=='acknowledgement timeout: recall') then
   p.already_here_rejected=true;p.rejected_prompt=s.prompt;return
  end
  if not p or s.fault then return end
  if p.kind=='find' and line=='You cannot find a new path so soon.' then
   p.rejected=true;p.rejected_prompt=s.prompt;p.ack=nil;s.route_proof=nil;return
  end
  if p.rejected then return end
  local fn=p.kind=='find' and t.settings.route_success or p.kind=='go' and t.settings.route_done or p.kind=='stop' and t.settings.route_stopped
  if p.kind=='find' and not fn then fn=function(v) return route_line(p,v) end end
  if fn and not p.ack then
   local ok,ack=pcall(fn,line,s.destination,s)
   if s.pending~=p or p.cancelled then return end
   if not ok then
    if p.kind=='find' then t.cancel_find('route acknowledgement parser failed',p) else fault('route acknowledgement parser failed') end
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
  if dead() then revoke_unsent('death preflight');return false end
  -- A late timer cannot relabel an already achieved goal as unknown transport.
  -- Do not pump twice: successful settlement never dispatches in the same call.
  if not s.pumping and settle_recall() then return true end
  if s.dispatching or s.fault then return false end
  local q=s.haven_refresh
  if q and not q.complete and not q.quarantine and clock()-q.at>(tonumber(t.settings.timeout) or 20) and (s.full_item_version or -1)<=q.version then
   q.quarantine='outside mount refresh timeout';s.status=q.quarantine
  end
  if s.follow_pending and clock()-s.follow_pending.at>(tonumber(t.settings.timeout) or 20) then s.follow_fault='acknowledgement timeout: follow';s.status=s.follow_fault;return false end
  local timeout=s.pending and s.pending.kind=='go' and (tonumber(t.settings.route_timeout) or 300) or (tonumber(t.settings.timeout) or 20)
  if s.pending and not recall_arrived(s.pending) and not recall_rejected(s.pending) and clock()-s.pending.at>timeout then
   if s.pending.kind=='find' then return t.cancel_find('read-only FIND acknowledgement timeout',s.pending) end
   if s.pending.kind=='recall' then s.pending.recall_unconfirmed_timeout=true end
   return fault('acknowledgement timeout: '..s.pending.kind)
  end
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
 local closed=g.fault=='all carried globes exhausted' and g.armed==false and g.phase=='idle' and (g.status=='disarmed' or g.status=='BASH scope ended') and gp==nil and not g.committed and not g.dispatching and not g.transport_unknown and type(q)=='table' and q.enabled==false and q.known==false and q.ever_owned==true and type(q.owned)=='table' and next(q.owned)==nil and type(q.exhausted)=='table' and q.query==nil and q.dispatching==false and not q.transport_unknown
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
 if f and f.revoked then return true end
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
-- Fallback-only shared-root fence: singular empty tables are identity tokens;
-- only the two plural barrier maps use nonemptiness. Keep this separate from
-- Haven's authorized resource/read-only views and never clear another owner.
local icy_root_fields={'pending','waiting','fault','transport_unknown','transportUnknown','dispatching','action_dispatching','actionDispatching','transport_barrier','transportBarrier','transport_commit','transportCommit','committed'}
local function icy_root_busy(root)
 if type(root)~='table' then return false end
 for _,key in ipairs(icy_root_fields)do
  local v=root[key];if v~=nil and v~=false then return true end
 end
 for _,key in ipairs({'transportBarriers','transport_barriers'})do
  local v=root[key]
  if type(v)=='table' then if next(v)~=nil then return true end
  elseif v~=nil and v~=false then return true end
 end
 return false
end
function M.adapter(c,settings)
 settings=settings or {}
 -- Only controllers constructed by this adapter from the canonical cold helper
 -- enter this private registry. A lookalike c.path_probe/callback is not authority.
 local probes=setmetatable({},{__mode='k'})
 local function probe_health()
  local probe=c.path_probe;local authorize=probe and probes[probe]
  if not authorize then return false end
  local ok,allowed=pcall(authorize,c.travel_owner)
  return ok and allowed==true
 end
 local function ready(follow)
  local blocked,why=M.blocked(c,follow);if blocked then return false,why end
  local s=c.current or {};local p=s.player or {}
  if not yes(s.connected) or not getConnectionInfo then return false,'disconnected' end
  local ok,_,_,tcp=pcall(getConnectionInfo);if not ok or tcp~=true then return false,'TCP disconnected' end
  if yes(p.dead) or (tonumber(p.hp) or 0)<=0 then return false,'dead / no health' end
  local hp,max=tonumber(p.hp),tonumber(p.maxhp)
  if probes[c.path_probe]and(not hp or not max or hp~=hp or max~=max or math.abs(hp)==math.huge or math.abs(max)==math.huge or max<=0)then return false,'invalid health' end
  if not follow then for _,key in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[key]) then return false,'not ready: '..key end end end
  local a=p.afflictions or {}
  if yes(p.prone) or a.prone or a.fallen or a.paralysis or a.asleep or a.unconsciousness or a.stun or a.stunned or (a.anorexia and a.asthma and a.slickness) then return false,'hindered' end
  if not follow and c.defense and c.defense.plan then
   local d=c.defense.plan(s)
   if not d then return false,'own safety hold' end
   if d.hold then
    -- No mode/config/cure mutation: suppress ONLY this owner's health reason.
    local reason='survival pause; recover to '..((s.config or {}).defense_health_resume or 65)..'% HP'
    if d.fault or not d.low_health or d.phase~=reason or not probe_health()then return false,'own safety hold' end
   end
  end
  return true
 end
 return {revoke_on_death=function()
   if c.release_lock and c.release_lock.death then return c.release_lock.death(c) end
  end,observe_alive=function()
   if c.release_lock and c.release_lock.alive then return c.release_lock.alive(c) end
  end,own_mounted_goal=function(own,room)
   local s=c.current or {};local p=s.player or {};local v=gmcp and gmcp.Char and gmcp.Char.Vitals
   local r=c.runner or {}
   for _,owner in pairs({controller=c,current=s,runner=r,controller_root=c.root,current_root=s.root,runner_root=r.root})do
    if icy_root_busy(owner)then return false end
   end
   return tostring((s.room or {}).id)==room and p.mounted==true
    and type(p.mount_id)=='number' and id(p.mount_id)==own
    and type(v)=='table' and type(v.mounted)=='string' and v.mounted==own
    and (tonumber(v.hp) or 0)>0 and not yes(v.dead)
  end,dead=function()
   local p=(c.current or {}).player or {}
   local v=gmcp and gmcp.Char and gmcp.Char.Vitals
   -- Raw native Vitals closes the ingestion-order race with retained adapters.
   return yes(p.dead) or (p.hp~=nil and (tonumber(p.hp) or 0)<=0)
    or (type(v)=='table' and (yes(v.dead) or (v.hp~=nil and (tonumber(v.hp) or 0)<=0))) or false
  end,new_probe=function(opt)
   local path=getMudletHomeDir()..'/ui-recovery/path_probe.lua'
   local module=dofile(path)
   if type(module)~='table'or type(module.construct)~='function'then return nil,'canonical probe factory unavailable'end
   local probe=module.construct(c,opt)
   if type(probe)~='table'or type(probe.travel_health_evidence)~='function'then return nil,'canonical probe evidence unavailable'end
   probes[probe]=probe.travel_health_evidence
   return probe
  end,session=function() return haven_session(c) end,
  intent_stamp=function()
   local p=(c.current or {}).player or {};local w=(c.current or {}).walker or {}
   if type(p.class)~='string' or p.class=='' then return nil end
   return p.class..':'..tostring(c.restock_intent_epoch or 0)..':'..tostring(c.lunch_intent_epoch or 0)..':'..tostring(w.intent_epoch or 0)
  end,
  icy_ready=function(room)
   if c.mode~='OFF' or (c.runner and c.runner.mode~='OFF') then return false end
   local runner=c.runner or {}
   for _,root in ipairs({c,c.current or {},runner,c.root or {},runner.root or {}})do
    if icy_root_busy(root)then return false end
   end
   local r=(c.current or {}).room or {};local p=(c.current or {}).player or {}
   -- state.sync_gmcp owns the canonical boolean plus numeric mount ID.
   -- Never reinterpret the boolean as a raw GMCP mount ID or borrow cached GMCP.
   local own=(c.travel_owner or {}).mount
   local mount=p.mount_id
   if not id(room) or tostring(r.id)~=room or p.mounted~=true
    or type(mount)~='number' or mount~=mount or mount<=0 or mount==math.huge
    or mount~=math.floor(mount) or id(mount)~=own then return false end
   -- An idle enabled monitor is not a shopping commitment. Never borrow an
   -- active restock lease/checkpoint or another user activity for this fallback.
   local d=c.restock_data or {}
   if c.user_activity or d.reserved or d.busy or d.pending or d.purchase or d.dispatching
    or d.checkpoint or d.owned_pause or d.route_owner or d.fault or d.query_quarantine then return false end
   local lunch=c.lunch_duty or {}
   if lunch.busy or lunch.pending or lunch.purchase or lunch.dispatching or lunch.fault then return false end
   return ready()
  end,route_allowed=function()
   local d=c.restock_data;local tr=c.travel_owner
   if d and d.route_owner==tr and d.pending and d.pending.kind=='route' then return d.active==true and d.resume_consent==true and not d.fault end
   return true
  end,mount_deferred=function() return M.haven_deferred(c) end,ready=ready,follow_ready=function()
   if not yes(((c.current or {}).player or {}).equilibrium) then return false,'not ready: equilibrium' end
   return ready(true)
  end,
  recall_ready=function()
   if c.mode~='OFF' and c.mode~='BASH' then return false,'recall requires OFF or BASH' end
   if c.runner and c.runner.mode~=c.mode then return false,'mode mismatch' end
   local p=(c.current or {}).player or {}
   if p.mounted==nil or (p.mounted~=false and tonumber(p.mounted)~=0) then return false,'mounted state not unmounted' end
   return ready()
  end,
  send_recall=function(command)
   local owner=c.travel_owner;local own=id(owner and owner.mount or settings.mount_id)
   local pending=owner and owner.pending
   local stable=owner and owner.dispatching and pending and pending.kind=='recall' and pending.recall_context=='stable'
    and owner.phase=='recall' and type(pending.serial)=='number' and pending.serial>0 and pending.serial<math.huge and pending.serial==math.floor(pending.serial)
    and pending.serial==owner.serial and pending.room==owner.room and pending.prompt==owner.prompt and pending.mount==own
   local p=(c.current or {}).player or {}
   if not own or (command~='recall mount' and not (stable and command=='recall '..own)) or (c.mode~='OFF' and c.mode~='BASH') or (c.runner and c.runner.mode~=c.mode) then return false end
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
   if not yes(((c.current or {}).player or {}).equilibrium) then return false,'not ready: equilibrium' end
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
 if c.travel_state and (c.travel_state.find_quarantine or c.travel_state.pending or c.travel_state.dispatching or c.travel_state.fault or c.travel_state.intent or c.travel_state.route or c.travel_state.follow_due or c.travel_state.recall_due or c.travel_state.follow_pending or c.travel_state.follow_fault) then return nil,'unfinished travel owner; refuse replacement' end
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
  handler('gmcp.Char.Vitals',function() local v=gmcp and gmcp.Char and gmcp.Char.Vitals;if v then t.vitals(v.mounted,v.dead,v.hp) end end)
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
  handler('sysDisconnectionEvent',function() if t.state.pending and t.state.pending.kind=='find' then t.cancel_find('disconnected read-only FIND',t.state.pending) end;if t.unresolved() then t.state.fault='disconnected with travel unresolved' end;t.state.continuity=nil;t.state.present=nil end)
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
 if t.unresolved() or t.state.intent or t.state.route or t.state.find_quarantine then return false,'unfinished travel owner retained' end
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
