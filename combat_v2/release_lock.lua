-- Portable, passive restock inventory receipt observer. Loading sends nothing.
-- Call text(c,line) BEFORE restock.text and prompt(c) on GENUINE prompts only.
-- Observer state and retired receipts deliberately live outside action state.
local M={}
local receipts=setmetatable({},{__mode='k'})
local archive={}
local function present(v) return v~=nil and v~=false end
local function occupied(v) if type(v)=='table' then return next(v)~=nil end;return present(v) end
local function session(c) local s=c.current or {};return c.haven_session_token or c.session_generation or s.session_generation or s.session_id end
local function room(c) return ((c.current or {}).room or {}).id end
local function query(p) return type(p)=='table' and (p.kind=='inventory_before' or p.kind=='inventory_after') and p.command=='inventory' end
local function scope(c,r)
 return r and c.restock_data==r.owner and c.restock_controller==r.controller and r.controller.state==r.owner and r.owner.pending==r.pending and r.pending.serial==r.serial and r.pending.command=='inventory' and r.pending.kind==r.kind and r.pending.room==r.room and room(c)==r.room and session(c)~=nil and session(c)==r.session
end
local fields={'transport_unknown','transportUnknown','dispatching','action_dispatching','actionDispatching','physical_dispatch','physical_transport','transport_commit','transportCommit','unknown_commit','committed','transport_barrier','transportBarrier','barrier','pending','waiting','txn','purchase','deposit','resource_pending','eq_pending','movement_pending','arrival','arrival_hold','route','intent','follow_pending','follow_due','recall_due','follow_fault','query','physical_commit','movement_commit','drain_pending','ink_pending','pumping','route_pausing','capturing_checkpoint'}
local maps={'transport_barriers','transportBarriers'}
local function barrier(name,o,skip)
 if o==nil then return end
 if type(o)~='table' then return name..' malformed owner' end
 for _,k in ipairs(fields) do if not (skip and skip[k]) and present(o[k]) then return name..'.'..k end end
 for _,k in ipairs(maps) do if occupied(o[k]) then return name..'.'..k end end
 -- Public adapter methods named cancel are API, not queued cancel state.
 if (type(o.todo)~='function' and occupied(o.todo)) or (type(o.cancel)~='function' and occupied(o.cancel)) or (type(o.sequence)~='function' and present(o.sequence)) then return name..' queued work' end
end
local function gates(c,r)
 if type(c)~='table' then return 'controller missing' end
 local d=c.restock_data;local t=c.restock_controller;local s=c.current
 if type(d)~='table' or type(t)~='table' or t.state~=d or type(s)~='table' then return 'restock owner identity unavailable' end
 if c.mode~='OFF' or (s.mode~=nil and s.mode~='OFF') then return 'active combat untouched: this retirement version supports an already-OFF restock only; no STOP or mode change was performed' end
 if c.user_activity~=d then return 'not the sole owned restock activity lease' end
 if d.active~=false or d.resume_consent~=false or d.reserved~=false or d.busy~=true or d.owned_pause~=true then return 'restock must be stopped, revoked, and own its pause' end
 if not query(d.pending) then return 'unsupported restock command: '..tostring(d.pending and d.pending.command or d.phase)..'; BUY/GO/INK are never force-cleared' end
 if d.pending.transport_ok~=true then return 'inventory transport unknown' end
 if d.phase~=d.pending.kind then return 'query phase mismatch' end
 if d.checkpoint and (d.checkpoint_revoked~=true or not d.checkpoint.cancelled) then return 'checkpoint is not positively cancelled' end
 if not scope(c,r) then return 'no same-owner/session/room completed inventory receipt; timeout is not proof' end
 if not r.complete or not r.prompt_seen then return 'inventory footer and genuine completion prompt not observed' end
 if d.fault~='bounded response exceeded' or d.query_quarantine~=d.fault then return 'unsupported or unassociated restock fault/quarantine' end
 local why=barrier('restock',d,{pending=true});if why then return why end
 local roots={controller=c,current=s,current_root=s.root,runner=c.runner,controller_root=c.root,runner_root=c.runner and c.runner.root,restock_controller=t,restock_root=t.root,travel_owner=c.travel_owner,travel=c.travel,travel_root=c.travel and c.travel.root,walker=s.walker,buffs=s.buffs,mental=s.mental,containers=c.containers_data,supplies=c.supplies_data,globe=c.elemental_recovery,tattoo=c.tattoo_owner,lunch=c.lunch_data}
 for name,o in pairs(roots) do
  why=barrier(name,o);if why then return why end
  if name~='restock_controller' and o.fault then
   local closed=name=='globe' and o.fault=='all carried globes exhausted' and o.armed==false and not o.pending and not o.committed and not o.dispatching and (o.phase==nil or o.phase=='idle')
   if not closed then return name..'.fault: '..tostring(o.fault) end
  end
  if o.busy==true then return name..'.busy' end
 end
 local w=s.walker or {};if w.active then return 'walker active' end
 local g=c.elemental_recovery or {};if g.armed or (g.phase and g.phase~='idle') then return 'GLOBE armed/nonidle' end
 if g.pool then why=barrier('globe.pool',g.pool);if why then return why end end
 local cd=c.containers_data or {};if cd.query then return 'containers query' end
 local sd=c.supplies_data or {}
 for k,v in pairs(sd.sources or {}) do if type(v)~='table' or v.pending or v.frame then return 'supplies source '..tostring(k)..' pending' end end
 if d.route_owner and d.route_owner~=c.travel_owner then return 'unrecognized prior route owner' end
 local tr=c.travel_owner;if tr and tr.phase~='idle' then return 'travel owner not idle' end
 if c.runner and c.runner.mode and c.runner.mode~='OFF' then return 'runner mode not OFF' end
 if (s.mental or {}).needs_cease then return 'mental cease unresolved' end
 return nil
end
local function observe_text(c,line,reviewed)
 local d=c and c.restock_data;local t=c and c.restock_controller;local p=d and d.pending
 if not t or t.state~=d or not query(p) or session(c)==nil or room(c)~=p.room or type(line)~='string' then return false end
 local r=receipts[d]
 if not scope(c,r) then
  if line~='You are wielding:' then return false end
  -- A late observer cannot bless a new frame as the already-failed old query.
  if not reviewed and (d.fault or d.query_quarantine or c.user_activity~=d) then return false end
  r={owner=d,controller=t,pending=p,serial=p.serial,kind=p.kind,room=p.room,session=session(c),dispatch_prompt=p.prompt,lines={},bytes=0,stage='hands'};receipts[d]=r
 end
 if r.invalid or r.complete then return false end
 r.bytes=r.bytes+#line;r.lines[#r.lines+1]=line
 if #line>8192 or r.bytes>65536 or #r.lines>256 then r.invalid='observer inventory bounds exceeded';return false end
 if line=='You are holding:' and r.stage=='hands' then r.stage='holding'
 elseif line=='You are wearing:' and r.stage=='holding' then r.stage='wearing'
 elseif line=='Summary:' and r.stage=='wearing' then r.stage='summary'
 elseif r.stage=='summary' and line:match('^You have %d+ types of items in the cache%.$') then r.stage='cache'
 elseif r.stage=='cache' and line:match('^You possess %d+ items%.$') then r.stage='items'
 elseif r.stage=='items' and line:match('^You are carrying %d+ gold sovereigns%.$') then r.stage='footer';r.complete=true
 elseif line=='You are wielding:' and #r.lines>1 then r.invalid='duplicate inventory header'
 elseif r.stage=='summary' or r.stage=='cache' or r.stage=='items' then r.invalid='malformed inventory summary' end
 return true
end
function M.text(c,line) return observe_text(c,line,false) end
function M.prompt(c)
 local d=c and c.restock_data;local r=d and receipts[d]
 if not scope(c,r) or r.invalid then return false end
 if r.complete and r.pending.transport_ok==true then r.prompt_seen=true;r.completion_prompt=r.owner.prompt;return true end
 r.invalid='prompt before positively completed inventory';return false
end
function M.status(c)
 local d=c and c.restock_data;local r=d and receipts[d]
 local reason=gates(c,r);local locks={}
 if type(c)=='table' then
  local owners={restock=d,tattoo=c.tattoo_owner,travel=c.travel_owner,runner=c.runner,globe=c.elemental_recovery,containers=c.containers_data,supplies=c.supplies_data,walker=(c.current or {}).walker,mental=(c.current or {}).mental,buffs=(c.current or {}).buffs}
  for name,o in pairs(owners) do
   if type(o)=='table' then
    local p=o.pending or o.txn or o.purchase
    local why=barrier(name,o)
    if why or o.fault or o.busy==true then locks[#locks+1]={owner=name,reason=why or tostring(o.fault or 'busy'),command=type(p)=='table' and (p.command or p.kind or p.phase) or nil,supported=name=='restock' and query(o.pending)} end
   end
  end
 end
 table.sort(locks,function(a,b)return a.owner<b.owner end)
 if M.revocation_plan then
  local p,why=M.revocation_plan(c)
  return {releasable=p~=nil,physical_releasable=reason==nil,reason=p and 'UNLOCK revokes all automation permission; issued/unknown commitments remain tracked; native manual movement is not intercepted' or why,owner='all automation',locks=locks}
 end
 return {releasable=reason==nil,reason=reason or 'Completed read-only inventory can be retired; remains OFF; no resume',owner='restock',command=d and d.pending and d.pending.command,serial=d and d.pending and d.pending.serial,locks=locks}
end
local attached=setmetatable({},{__mode='k'})
function M.attach(c)
 local t=c and c.restock_controller
 if type(t)~='table' or t.state~=c.restock_data or type(t.text)~='function' or type(t.prompt)~='function' then return false,'real restock dynamic text/prompt slots unavailable' end
 if attached[t] then return true,'observer already attached' end
 local oldtext,oldprompt=t.text,t.prompt
 local text=function(line,...) M.text(c,line);return oldtext(line,...) end
 local prompt=function(...) M.prompt(c);return oldprompt(...) end
 t.text=text;t.prompt=prompt
 attached[t]={text=text,prompt=prompt,original_text=oldtext,original_prompt=oldprompt}
 return true,'passive observer attached; no cached input, queries, or actions'
end
local function release_inventory(c)
 local d=c and c.restock_data;local r=d and receipts[d];local why=gates(c,r)
 if why then return false,why end
 -- No callbacks, parser replay, mode setter, IO, tick, timer or command here.
 local old={};for k,v in pairs(d) do old[k]=v end
 local record={owner=d,controller=c.restock_controller,prior_state=old,pending=d.pending,fault=d.fault,query_quarantine=d.query_quarantine,receipt=r,checkpoint=d.checkpoint,checkpoint_revoked=d.checkpoint_revoked,resume_consent=d.resume_consent,return_room=d.return_room,reason='operator UNLOCK: proven completed read-only inventory; failed trip terminated OFF'}
 archive[#archive+1]=record
 d.pending=nil;d.query_quarantine=nil;d.enabled=false;d.active=false;d.reserved=false;d.busy=false;d.owned_pause=false;d.phase='idle';d.recoverable=true
 d.status='FAULT (completed read-only inventory retired; trip terminated OFF; explicit controls available): '..d.fault
 if c.user_activity==d then c.user_activity=nil end
 receipts[d]=nil
 return true,record
end

-- All-automation UNLOCK revokes permission, never asserts physical settlement.
-- These writes are an explicit schema, not calls to native STOP/reset routines
-- (which can erase waits, query streams or restore a suspended owner).
local revocations={}
local function shallow(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
local function integer(v)return type(v)=='number'and v>=0 and v<math.huge and v==math.floor(v)end
local function recall_quarantine(c)
 local s=c.travel_owner;local p=s and s.pending
 if type(s)~='table'or not c.travel or c.travel.state~=s or type(p)~='table'then return end
 if p.kind~='recall'or s.phase~='recall'or type(s.mount)~='string'or not s.mount:match('^[1-9]%d*$')or p.mount~=s.mount
  or not integer(p.serial)or p.serial<=0 or p.serial~=s.serial or not integer(p.prompt)
  or type(p.room)~='string'or p.room==''or p.transport_ok~=true
  or p.transport_unknown or p.transportUnknown or p.unknown_commit
  or not integer(p.finalized_prompt)or p.finalized_prompt<p.prompt
  or(p.command~='recall mount'and p.command~='recall '..s.mount)
  or(s.fault~=nil and s.fault~='unexpected room change during recall'and s.fault~='acknowledgement timeout: recall')
  or s.follow_pending or s.follow_fault or s.haven_refresh or s.find_quarantine or s.stopping then return end
 local why=barrier('travel',s,{pending=true,intent=true,route=true,follow_due=true,recall_due=true})
 if why or s.transportUnknown or s.unknown_commit or s.physical_commit then return end
 return {pending=p,fault=s.fault,phase=s.phase,reason='explicit operator revocation: known-successful non-avatar loyal recall quarantined, NOT settled',settled=false}
end
local function plan(c,reason,operator)
 if type(c)~='table'or type(c.current)~='table'or type(c.runner)~='table'then return nil,'canonical controller/current/runner required'end
 if c.runner.state~=nil and c.runner.state~=c.current then return nil,'runner/current alias mismatch'end
 local s=c.current;local writes,owners={},{}
 local function add(name,o,values,nils)
  if o==nil then return true end
  if type(o)~='table'then return nil,name..' malformed owner'end
  owners[name]=o
  for k,v in pairs(values or{})do writes[#writes+1]={owner=o,key=k,value=v}end
  for _,k in ipairs(nils or{})do writes[#writes+1]={owner=o,key=k}end
  return true
 end
 local function must(...)local ok,why=add(...);if not ok then error(why,0)end end
 local function epoch(name,o,key)
  if o then local v=o[key];if v~=nil and not integer(v)then error(name..'.'..key..' invalid epoch',0)end;must(name,o,{[key]=(v or 0)+1})end
 end
 local ok,why=pcall(function()
  must('controller',c,{mode='OFF',containers_refill_enabled=false})
  must('current',s,{mode='OFF'});must('runner',c.runner,{mode='OFF'})
  must('controller.root',c.root);must('current.root',s.root);must('runner.root',c.runner.root)
  must('tattoo',c.tattoo_owner);must('containers',c.containers_data);must('supplies',c.supplies_data)
  epoch('controller',c,'restock_intent_epoch');epoch('controller',c,'lunch_intent_epoch')
  must('walker',s.walker,{enabled=false,active=false,ask_on_bash=false},{'offer','clear','transit'})
  epoch('walker',s.walker,'intent_epoch')
  -- Explicit UNLOCK releases arrival-readiness control state; it is not a
  -- command receipt. Death revocation deliberately preserves the incident.
  if operator and s.walker and s.walker.arrival_hold==true then
   must('walker',s.walker,nil,{'arrival_hold'})
  end
  must('hunting',s.hunting,{active=false})
  -- Buff commitment/query/listing are untouched, including canceled native config.
  must('buffs',s.buffs,{master=false,sequence=false,cancel={}},{'todo'})
  must('mental',s.mental,{enabled=false})
  must('globe',c.elemental_recovery,{armed=false})
  must('globe.pool',c.elemental_recovery and c.elemental_recovery.pool,{enabled=false})
  must('restock',c.restock_data,{enabled=false,active=false,resume_consent=false,resume_globe=false})
  must('lunch',c.lunch_data,{active=false,resume_master=false})
  if c.lunch_duty and c.lunch_duty~=c.lunch_data then must('lunch_duty',c.lunch_duty,{active=false,resume_master=false})end
  local tr=c.travel_owner
  if tr and (not c.travel or c.travel.state~=tr or c.travel_state and c.travel_state~=tr)then error('travel owner alias mismatch',0)end
  must('travel',tr,{convenience_revoked=true},{'intent','follow_due','recall_due','refresh_due','continuity','loss_refresh','find_retry_at','icy_fallback'})
  -- Keep issued GO's destination/proof/route and every pending/fault/query object.
  if tr and not tr.pending then must('travel',tr,nil,{'route','destination','route_proof'})end
  local h=c.haven_handoff
  if h and h.deferred_follow then
   must('haven deferred follow',h.deferred_follow,{revoked=true},{'follow_due','recall_due'})
   if not(tr and tr.haven_refresh)then must('haven handoff',h,nil,{'deferred_follow'})end
  end
  if c.tour then
   if type(c.tour)~='table'or type(c.tour.state)~='table'then error('tour owner malformed',0)end
   local ts=c.tour.state;epoch('tour',ts,'generation');must('tour',ts,{phase='cancelled',reason=reason},{'grant'})
   -- Parser, slot, physical transfer and query chronology remain intact.
  end
 end)
 if not ok then return nil,why end
 local quarantine=operator and recall_quarantine(c)
 if quarantine and c.travel_owner.recall_quarantine~=nil and type(c.travel_owner.recall_quarantine)~='table'then return nil,'travel recall quarantine malformed'end
 return {writes=writes,owners=owners,reason=reason,mode=c.mode,recall_quarantine=quarantine}
end
function M.revocation_plan(c,reason)return plan(c,reason or 'operator UNLOCK: revoke all automation')end
function M.revoke_all(c,reason,operator)
 local p,why=plan(c,reason or 'operator UNLOCK: revoke all automation',operator==true);if not p then return false,why end
 local record={reason=p.reason,prior={},writes={},retained={},mode=p.mode,settled=false}
 for name,o in pairs(p.owners)do record.prior[name]=shallow(o)end
 for i,w in ipairs(p.writes)do record.writes[i]={owner=w.owner,key=w.key,prior=w.owner[w.key],value=w.value}end
 -- Journal before the first permission write. No callbacks/IO/mode setters here.
 revocations[#revocations+1]=record;c.automation_revocation=record
 for _,w in ipairs(p.writes)do w.owner[w.key]=w.value end
 if p.recall_quarantine then
  local s=c.travel_owner;local q=p.recall_quarantine
  s.recall_quarantine=s.recall_quarantine or {};s.recall_quarantine[#s.recall_quarantine+1]=q;s.last_recall_quarantine=q
  s.pending=nil;s.fault=nil;s.phase='idle';s.route=nil;s.destination=nil;s.route_proof=nil;s.recalled=nil
  record.recall_quarantine=q
 end
 -- Retained commitment diagnostics are explicit, not advertised as cleared locks.
 for name,o in pairs(p.owners)do
  local why=barrier(name,o)
  if why or o.fault or o.busy==true then record.retained[#record.retained+1]={owner=name,reason=why or tostring(o.fault or 'busy')}end
 end
 table.sort(record.retained,function(a,b)return a.owner<b.owner end)
 record.reason=p.reason..(p.recall_quarantine and '; loyal recall quarantined, NOT settled' or '')..'; automation OFF; '..#record.retained..' unresolved owner(s) retained; native manual movement is not intercepted'
 return true,record
end
function M.revocation_archives()local out={};for i,r in ipairs(revocations)do out[i]=r end;return out end
function M.death(c)
 if c.automation_death_latch then return true,c.automation_death_latch end
 local ok,r=M.revoke_all(c,'death: revoke all unissued automation; issued/unknown commitments retained')
 if ok then c.automation_death_latch=r end
 return ok,r
end
function M.alive(c)c.automation_death_latch=nil end
function M.reset_cohort(c,authorization)
 if not c.operator_reset then return false,"reset support unavailable" end
 return c.operator_reset.request(c,authorization)
end
function M.release(c)
 if c.operator_reset then return c.operator_reset.request(c,"OPERATOR_ABANDON_CLIENT_JOBS_UNSETTLED")end
 -- Validate the complete revoke schema before an optional proven retirement.
 local p,why=plan(c,'operator UNLOCK: revoke all automation',true);if not p then return false,why end
 local r=c.restock_data and receipts[c.restock_data];local retired
 if gates(c,r)==nil then local ok,record=release_inventory(c);if ok then retired=record end end
 local ok,record=M.revoke_all(c,nil,true)
 if ok then record.inventory_retired=retired end
 return ok,record
end

function M.archives() local out={};for i,r in ipairs(archive) do out[i]=r end;return out end
-- Deliberately privileged review seam, NOT for a UI callback: caller must freshly
-- compare native retained history and same captured pending/controller/session.
function M.reviewed_receipt(c,proof)
 if type(proof)~='table' or proof.kind~='reviewed-native-inventory-history' or proof.pending~=(c.restock_data or {}).pending or proof.controller~=c.restock_controller or proof.session~=session(c) or proof.room~=room(c) or type(proof.lines)~='table' or proof.prompt_verified~=true then return false,'reviewed history scope mismatch' end
 for _,line in ipairs(proof.lines) do observe_text(c,line,true) end
 local r=receipts[c.restock_data]
 if not r or not r.complete or r.invalid then return false,'reviewed history has no complete inventory' end
 r.prompt_seen=true;r.provenance=proof.provenance;r.history=proof.lines
 return true
end
return M
