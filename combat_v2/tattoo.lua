-- OFFLINE candidate: explicit ink TYPE [NAME]; owned pause, FIRSTAID OFF, exact receipts, genuine completion, FIRSTAID ON.
local M={}
local native_on=setmetatable({},{__mode="k"})
local owned=setmetatable({},{__mode="k"})
local recovery=setmetatable({},{__mode="k"})
local on_proofs=setmetatable({},{__mode="k"})
local colors={blue=true,red=true,yellow=true,green=true,purple=true,gold=true,obsidian=true}
local function yes(x) return x==true or tonumber(x)==1 end
local function owner(c)
 c.tattoo_owner=c.tattoo_owner or {handles={},serial=0,status='idle'}
 return c.tattoo_owner
end
local function api(c) return c.tattoo_api or _G end
local function now(c) local a=api(c);return (a.clock or a.getEpoch or os.time)() end
local function note(c,s) owner(c).status=s;local f=api(c).notify or api(c).print;if f then f(s) end end
function M.busy(c) return owner(c).txn~=nil end
function M.status(c) return owner(c).status,owner(c).txn end
local function nonempty(t) return t~=nil and (type(t)~='table' or next(t)~=nil) end
local function read_only_globe(g)
 local p=g.pending
 return not g.committed and not g.dispatching and ((p and p.kind=='recovery' and p.phase=='probe' and (g.phase==nil or g.phase=='probe')) or (not p and g.phase=='idle' and g.fault=='recovery timeout'))
end
local function physically_ready(c)
 local p=(c.current or {}).player or {}
 for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[k]) then return false,'not ready: '..k end end
 return true
end
function M.parse(input)
 if type(input)~='string' or #input>100 or input:find('[%c]') then return nil,'usage: ink TYPE [NAME]' end
 local typ,name=input:match('^%s*([A-Za-z]+)%s+([A-Za-z]+)%s*$')
 if not typ then typ=input:match('^%s*([A-Za-z]+)%s*$');name='me' end
 if not typ or #typ>30 or #name>30 then return nil,'usage: ink TYPE [NAME] (one alphabetic name)' end
 return {type=typ:lower(),target=name}
end
function M.recipe(text)
 if type(text)~='string' or #text>300 then return nil end
 local body=text:match('^Required inks:%s*(.-)%s*$');if not body then return nil end
 body=body:gsub('%.$',''):gsub('%s+inks?$',''):gsub(',%s*and%s+',','):gsub('%s+and%s+',',')
 local rows,seen={},{}
 for token in (body..','):gmatch('(.-),') do
  token=token:match('^%s*(.-)%s*$'):gsub('%s+inks?$','')
  local n,color=token:match('^(%d+)%s+([a-z]+)$');n=tonumber(n)
  if not n or n<1 or n>100 or not colors[color] or seen[color] then return nil end
  seen[color]=true;rows[#rows+1]={count=n,color=color}
 end
 if #rows==0 or #rows>7 then return nil end
 return rows
end
local function connected(c)
 local a=api(c)
 if a.connected then return a.connected()==true end
 if not a.getConnectionInfo then return false end
 local ok,_,_,tcp=pcall(a.getConnectionInfo);return ok and tcp==true
end
-- Must be called BEFORE OFF: the native stop intentionally clears runner waits.
function M.safe(c,continuing)
 local s=c.current or {};local p=s.player or {};local r=c.runner or {}
 local root=r.root or c.root or {}
 -- Distinct roots and both native barrier spellings remain independent.
 for _,v in pairs({controller=c,current=s,root=c.root,runner_root=r.root})do
  for _,k in ipairs({'transport_unknown','transportUnknown','transport_barrier','transportBarrier','transport_commit','transportCommit','dispatching','action_dispatching','actionDispatching','committed'})do
   if v[k]~=nil and v[k]~=false then return false,'unresolved action barrier' end
  end
  for _,k in ipairs({'transport_barriers','transportBarriers'})do if v[k]~=nil and v[k]~=false and (type(v[k])~='table'or next(v[k])~=nil)then return false,'unresolved action barrier' end end
 end
 local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {};local g=c.elemental_recovery or {};local d=c.containers_data or {}
 if not connected(c) or not yes(s.connected) or yes(p.dead) or (tonumber(p.hp) or 0)<=0 or (tonumber(p.mana) or 0)<=0 or s.training_battle_ended then return false,'not living/connected' end
 if c.transport_unknown or root.transport_unknown or root.dispatching or root.action_dispatching or r.pending or r.waiting or r.dispatching or r.transport_barrier or r.transport_unknown or r.fault or b.pending or b.fault or b.dispatching or d.barrier or d.action_dispatching or m.pending or m.dispatching or m.physical_transport or m.eq_pending or m.fault or w.pending or w.fault or w.dispatching or g.committed or g.dispatching then return false,'unresolved action barrier' end
 if c.travel and c.travel.busy and c.travel.busy(c) then return false,'travel pending' end
 if c.travel_owner and (c.travel_owner.txn or c.travel_owner.pending or c.travel_owner.dispatching or c.travel_owner.intent or c.travel_owner.route or c.travel_owner.fault or c.travel_owner.follow_pending or c.travel_owner.follow_fault or c.travel_owner.follow_due or c.travel_owner.recall_due) then return false,'travel pending' end
 local phase=g.pending and g.pending.phase or g.phase
 if (g.pending or g.fault or (phase and phase~='idle')) and not read_only_globe(g) then return false,'unresolved GLOBE state' end
 if nonempty(b.todo) or nonempty(b.cancel) or b.sequence then return false,'queued upkeep' end
 if (m.status and m.status~='idle' and m.status~='stopped') or m.needs_cease then return false,'mental channel' end
 if c.user_activity and c.user_activity~=owner(c).txn then return false,'another user activity' end
 if p.mounted==nil or yes(p.mounted) or (tonumber(p.mounted) or 0)>0 then return false,'mounted or mounting state unknown' end
 if not continuing then
  for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do if not yes(p[k]) then return false,'not ready: '..k end end
 end
 if yes(p.prone) then return false,'prone' end
 for _,v in pairs(p.afflictions or {}) do if yes(v) then return false,'curing takes precedence' end end
 if c.defense and c.defense.hold and c.defense.hold(s) then return false,'defense hold' end
 local room=s.room or {}
 if room.id==nil then return false,'room unknown' end
 -- Explicit operator request does not require hunting IH or a room inspection.
 if not continuing and (w.active or w.running or w.route or w.checkpoint or w.arrival_hold) then return false,'walk must settle; fresh walk consent needed' end
 return true
end

-- Integration contract: pause_all must synchronously lease ALL action controllers,
-- without sending gameplay; paused verifies ownership/unchanged paused intent;
-- restore_all restores saved local intent without sending, ticking or resuming WALK.
-- The caller must gate competing action controllers with M.busy/user_activity.
-- No generic native OFF/ON mode setter: it destroys WALK state or ticks attacks.
local function session(c) local s=c.current or {};return c.haven_session_token or c.session_generation or s.session_generation or s.session_id end
local function snapshot(c)
 local s=c.current or {};local proof=native_on[c]
 if proof and (proof.session~=session(c) or proof.class~=(s.player or {}).class or proof.name~=(s.policy or {}).self_name) then proof=nil end
 return {firstaid_original_on=proof,mode=c.mode,upkeep=(s.buffs or {}).master,
 globe=(c.elemental_recovery or {}).armed,refill=c.containers_refill_enabled,
 session=session(c),room=(s.room or {}).id,class=(s.player or {}).class}
end
local function scope(c,t)
 local s=c.current or {}
 return connected(c) and session(c)==t.saved.session and (s.room or {}).id==t.saved.room and
 (s.player or {}).class==t.saved.class and c.user_activity==t and
 api(c).paused(c,t.token,t.saved)==true
end
local function untimer(c)
 local o=owner(c);if o.timer then if api(c).killTimer then pcall(api(c).killTimer,o.timer) end;o.timer=nil end
end
local function arm(c,t,seconds)
 untimer(c);t.deadline=now(c)+seconds
 if api(c).tempTimer then owner(c).timer=api(c).tempTimer(seconds,function() if owner(c).txn==t then M.tick(c) end end) end
end
local function release(c,t)
 untimer(c)
 -- Never clobber changed operator intent or resume a canceled walk checkpoint.
 local restored=false
 if scope(c,t) then
  local ok,result=pcall(api(c).restore_all,c,t.token,t.saved)
  restored=ok and result==true
 end
 local o=owner(c);o.last=t;o.txn=nil
 if c.user_activity==t then c.user_activity=nil end
 note(c,(t.completed and 'Tattoo complete' or 'Tattoo stopped')..
  (t.on_ack and '; FIRSTAID ON acknowledged' or '; WARNING FIRSTAID ON unconfirmed')..
  (restored and '; saved local intent restored' or '; changed scope/intent not restored; fresh operator consent needed'))
 return restored
end
local owned_curing_off=setmetatable({},{__mode='k'})
function M.operator_firstaid_off(c)
 -- Synchronous owned OFF is not newer manual intent.
 if owned_curing_off[c] then return false end
 native_on[c]=nil
 local t=owner(c).txn;local ownership=t and owned[t]
 if ownership then ownership.firstaid_superseded=true end
 return true
end
local function curing(c,on)
 local f=api(c).set_curing or api(c).combat_v2_set_curing
 if not f then return false end
 if not on then owned_curing_off[c]=true end
 local ok,r=pcall(f,on);owned_curing_off[c]=nil;return ok and r~=false
end
local function restore(c,t,why)
 if t.phase=='restore' then return false end
 t.reason=why;t.phase='restore';t.ack=nil;t.on_ack=nil;arm(c,t,10)
 -- FIRSTAID ON is an explicit user requirement, irrespective of saved cure flag.
 if not curing(c,true) then t.reason='FIRSTAID ON transport failed';return release(c,t) end
 return true
end
local function fault(c,why)
 local t=owner(c).txn;if not t then return false,why end
 if not t.resource then restore(c,t,why);return false,why end
 t.unknown=true;t.reason=why;untimer(c)
 note(c,'Tattoo resource action unresolved: '..why..'; no retry, no TOUCH; owner retained for review')
 return false,why
end
local function dispatch(c,t,phase,command,timeout)
 t.phase=phase;t.command=command;t.ack=nil;t.dispatching=true;t.resource=true
 arm(c,t,timeout)
 local ok,r=pcall(function() return assert(api(c).send,'sender unavailable')(command) end)
 t.dispatching=false
 if not ok or r==false then return fault(c,'transport unknown for '..command) end
 return true
end
function M.request(c,input)
 if input=='status' and recovery[c] then note(c,'INK query-only reconciliation: '..recovery[c].phase..'; no admitted physical job');return true end
 if input=='status' then note(c,owner(c).txn and ('Tattoo '..owner(c).txn.phase..': '..(owner(c).txn.reason or 'waiting for genuine acknowledgement')) or 'Tattoo idle');return true end
 if input=='cancel' and c.operator_abandoned_jobs and recovery[c] then recovery[c]=nil;return true,'read-only reconciliation cancelled; no old job resumed' end
 if input=='cancel' then
  local t=owner(c).txn;if not t then return false,'no tattoo transaction' end
  if t.resource then return false,'issued resource action retained; cannot cancel uncertainty' end
  return restore(c,t,'operator canceled before resource commit')
 end
 local spec,why=M.parse(input);if not spec then return false,why end
 if c.operator_abandoned_jobs then
  if M.busy(c) then return false,'current ink transaction already active' end
  local s=c.current or {};if not session(c) or not connected(c) or not (s.player or{}).class or not (s.room or{}).id then return false,'current known session/class/room required' end
  local q={scope=session(c),class=s.player.class,room=s.room.id,phase='readonly tattoos; no job admitted',dispatching=true};recovery[c]=q
  local sender=api(c).send;local ok,result=pcall(function()return assert(sender,'TATTOOS sender unavailable')('tattoos')end);q.dispatching=false;q.transport_ok=ok and result~=false
  return false,q.transport_ok and 'read-only TATTOOS requested; native IC full ink framing required before a NEW ink job; no old receipt accepted' or 'TATTOOS transport unknown; no job admitted'
 end
 if M.busy(c) then return false,'tattoo already pending' end
 local a=api(c)
 for _,k in ipairs({'pause_all','paused','restore_all'}) do if type(a[k])~='function' then return false,'owned pause adapter missing: '..k end end
 if not (a.set_curing or a.combat_v2_set_curing) then return false,'FIRSTAID setter unavailable' end
 local ok;ok,why=M.safe(c);if not ok then return false,why end
 local o=owner(c);o.serial=o.serial+1
 local t={id=o.serial,type=spec.type,target=spec.target,saved=snapshot(c),receipts={},phase='pause'}
 o.txn=t;owned[t]={controller=c,saved=t.saved,proof=t.saved.firstaid_original_on};c.user_activity=t
 -- Refill disabled BEFORE paused intent is asserted, preventing synchronous hook races.
 c.containers_refill_enabled=false
 local good,token=pcall(a.pause_all,c,t,t.saved)
 t.token=token
 if not good or not token then
  c.containers_refill_enabled=t.saved.refill;o.txn=nil;if c.user_activity==t then c.user_activity=nil end
  return false,'pause_all failed; adapter must roll back partial lease'
 end
 if not scope(c,t) then return fault(c,'pause ownership not verified') end
 t.phase='firstaid_off';arm(c,t,10)
 if not curing(c,false) then return fault(c,'FIRSTAID OFF transport failed') end
 return true
end
local function query(c,t)
 t.phase='query';t.lines=0;t.ack=nil;arm(c,t,12)
 local ok,r=pcall(function() return assert(api(c).send)('ab tattoos '..t.type) end)
 if not ok or r==false then return fault(c,'AB transport failed (no resource action)') end
 return true
end
local function next_action(c,t)
 if t.unknown or t.dispatching then return false end
 if not scope(c,t) then return fault(c,'room/session/class/intent changed') end
 local ok,why=M.safe(c,true);if not ok then return fault(c,why) end
 if not physically_ready(c) then return false end
 t.index=(t.index or 0)+1
 local row=t.recipe[t.index]
 if row then return dispatch(c,t,'withdraw','outc '..row.count..' '..row.color..'ink',10) end
 return dispatch(c,t,'ink','ink '..t.type..' on any of '..t.target,45)
end
function M.tick(c)
 local t=owner(c).txn;if not t then return true end
 if t.unknown then return false,t.reason end
 if t.phase=='restore' then if now(c)>=t.deadline then return release(c,t) end;return true end
 if not scope(c,t) then return fault(c,'room/session/class/intent changed') end
 if now(c)>=t.deadline then return fault(c,'missing '..t.phase..' acknowledgement') end
 return true
end
function M.text(c,line)
 local s=c.current or {};local scope_session=session(c)
 if line=='You will now begin to utilize first aid.' and scope_session~=nil and type((s.player or{}).class)=='string' and type((s.policy or{}).self_name)=='string' and (s.policy or{}).self_name~='' then
  native_on[c]={session=scope_session,class=s.player.class,name=s.policy.self_name,source='native exact FIRSTAID ON acknowledgement'}
  on_proofs[native_on[c]]={controller=c,session=scope_session,class=s.player.class,name=s.policy.self_name}
 elseif line=='You will no longer utilize your first aid knowledge.' then native_on[c]=nil end
 local q=recovery[c]
 if q and q.scope==scope_session and q.class==(s.player or{}).class and q.room==(s.room or{}).id and q.transport_ok and not q.dispatching then
  if line=='You have the following tattoos:' then q.rows={};q.header=true
  elseif q.header then local slot,typ,n=line:match('^([%a ]+):%s+(%a+)%s+Uses left:%s+(%d+)%s*$');if slot then q.rows[slot]={type=typ:lower(),uses=tonumber(n)} end end
 end
 local t=owner(c).txn;if not t or t.unknown or type(line)~='string' then return end
 if not M.tick(c) then return end
 if #line>1000 then return fault(c,'oversized response') end
 line=line:match('^%s*(.-)%s*$')
 if t.phase=='firstaid_off' then
  if line=='You will no longer utilize your first aid knowledge.' then t.ack=true end
 elseif t.phase=='restore' then
  -- Exact native ON acknowledgement captured by parent during manual Boar.
  local exact=api(c).firstaid_on_ack or 'You will now begin to utilize first aid.'
  if type(exact)=='string' and exact~='' and line==exact then t.on_ack=true end
 elseif t.phase=='query' then
  t.lines=t.lines+1;if t.lines>200 then return fault(c,'unbounded AB response') end
  local name,known=line:match('^([A-Za-z]+)%s+%(Tattoos%)%s+Known:%s*(%a+)%s*$')
  if not name then name,known=line:match('^([A-Za-z]+)%s+%(Tattoos%)%s+Known:%s*(%a+)%s+%(%d+ lessons?%)%s*$') end
  if not name then name=line:match('^([A-Za-z]+)%s+%(Tattoos%)%s*$') end
  if name then
   if t.header or name:lower()~=t.type then return fault(c,'AB identity mismatch/duplicate') end
   t.header=true;if known then t.known=known=='Yes' end
  elseif t.header then
   known=line:match('^Known:%s*(%a+)%s*$')
   if known then if t.known~=nil then return fault(c,'duplicate Known field') end;t.known=known=='Yes' end
   if line:match('^Required inks:') then
    if t.recipe then return fault(c,'duplicate recipe') end
    t.recipe=M.recipe(line);if not t.recipe then return fault(c,'malformed ink cost') end
   end
  end
 elseif t.phase=='withdraw' then
  local n,color,total=line:match('^You remove (%d+) ([a-z]+)ink, bringing the total in the cache to (%d+)%.$')
  if n then
   local row=t.recipe[t.index]
   if tonumber(n)~=row.count or color~=row.color or t.ack then return fault(c,'withdrawal receipt mismatch/duplicate') end
   t.ack=true;t.receipts[#t.receipts+1]={count=tonumber(n),color=color,remaining=tonumber(total)}
  end
 elseif t.phase=='ink' then
  local typ=line:match("^As the ([A-Za-z]+) tattoo's shape is codified, the last of the ink leaves the air, and you pause for a moment to admire your handiwork%.$")
  if typ then if typ:lower()~=t.type then return fault(c,'ink completion mismatch') end;t.ack=true end
 end
end
function M.prompt(c)
 local q=recovery[c];local s=c.current or{}
 if q and q.transport_ok and not q.dispatching and q.header and q.scope==session(c) and q.class==(s.player or{}).class and q.room==(s.room or{}).id then q.current_tattoos=q.rows;q.header=nil;q.phase='current tattoos observed; IC ink absolute framing required; no INK/OUTC job admitted' end
 local t=owner(c).txn;if not t or t.unknown or t.dispatching then return end
 if not M.tick(c) then return end
 if t.phase=='restore' then if t.on_ack then return release(c,t) end;return end
 if not physically_ready(c) then return end
 if t.phase=='firstaid_off' and t.ack then return query(c,t)
 elseif t.phase=='query' then
  if not t.header or t.known~=true or not t.recipe then return fault(c,'AB lacks exact learned identity/current recipe') end
  return next_action(c,t)
 elseif t.phase=='withdraw' and t.ack then return next_action(c,t)
 elseif t.phase=='ink' and t.ack then
  t.completed=true;t.resource=false;return restore(c,t,'genuine tattoo completion and ready prompt')
 end
end
function M.operator_reset_duty(c)
 local t=owner(c).txn
 if not t then return nil end
 local ownership=owned[t]
 if not ownership or ownership.controller~=c or ownership.saved~=t.saved or c.user_activity~=t or type(t.saved)~='table' then return nil,'untyped tattoo owner cannot mint FIRSTAID restoration duty' end
 local proof=t.saved.firstaid_original_on
 local native=proof and on_proofs[proof]
 if not native or native.controller~=c or ownership.proof~=proof or proof.session~=native.session or proof.class~=native.class or proof.name~=native.name or proof.session~=t.saved.session or proof.class~=t.saved.class then return nil,'owned tattoo lacks original native FIRSTAID ON proof; read-only FIRSTAID observation needed' end
 local s=c.current or{}
 if ownership.firstaid_superseded or session(c)==nil or not rawequal(proof.session,session(c)) or not connected(c) or proof.class~=(s.player or{}).class or proof.name~=(s.policy or{}).self_name then return nil,'original FIRSTAID duty superseded or current session/scope changed' end
 return {kind='owned-tattoo-original-FIRSTAID-ON',name=proof.name,class=proof.class,session=proof.session,room=tostring(t.saved.room)}
end
function M.operator_reconcile_status(c)return recovery[c]end
function M.disconnect(c) if M.busy(c) then return fault(c,'disconnected') end end
function M.detach(c)
 local o=owner(c);local a=api(c);untimer(c)
 for _,h in ipairs(o.handles) do local f=a[h.kind];if f then pcall(f,h.id) end end
 o.handles={};o.attached=false
 if o.txn then fault(c,'detached with transaction retained') end
 return o
end

-- Local-only pause adapter: preserve intent, no native mode setter/tick/send.
function M.native_pause(c)
 local a=c.tattoo_api
 if a and a.pause_all and a.paused and a.restore_all then return true end
 if a and (a.pause_all or a.paused or a.restore_all) then return false,'partial tattoo pause adapter' end
 if not a then a=setmetatable({},{__index=_G});c.tattoo_api=a end
 a.pause_all=function(root,t,saved)
  local s,r,g=root.current,root.runner,root.elemental_recovery
  if root.user_activity~=t or s.mode~=saved.mode or r.mode~=saved.mode then return nil end
  local token={txn=t,s=s,r=r,g=g,b=s.buffs,epoch=root.restock_intent_epoch,walk_epoch=(s.walker or{}).intent_epoch}
  root.mode='OFF';s.mode='OFF';r.mode='OFF';s.buffs.master=false;if g then g.armed=false end
  return token
 end
 a.paused=function(root,token,saved)
  return type(token)=='table' and root.user_activity==token.txn and root.current==token.s and root.runner==token.r
   and root.elemental_recovery==token.g and root.current.buffs==token.b
   and root.restock_intent_epoch==token.epoch and (root.current.walker or{}).intent_epoch==token.walk_epoch
   and root.mode=='OFF' and root.current.mode=='OFF' and root.runner.mode=='OFF'
   and root.current.buffs.master==false and (not token.g or token.g.armed==false) and root.containers_refill_enabled==false
 end
 a.restore_all=function(root,token,saved)
  if not a.paused(root,token,saved) then return false end
  root.mode=saved.mode;root.current.mode=saved.mode;root.runner.mode=saved.mode
  root.current.buffs.master=saved.upkeep;if token.g then token.g.armed=saved.globe end
  root.containers_refill_enabled=saved.refill
  return true
 end
 return true
end

function M.attach(c)
 local good,why=M.native_pause(c);if not good then return false,why end
 local o=owner(c)
 if o.txn then return false,'cannot replace pending tattoo owner' end
 M.detach(c);local a=api(c)
 local function own(kind,id) if not id or id==false then error('tattoo hook registration failed') end;o.handles[#o.handles+1]={kind=kind,id=id} end
 local ok,err=pcall(function()
  own('killAlias',a.tempAlias('^ink(?: +(.*))?$',function()
   local matches=a.matches or _G.matches or {};local good,why=M.request(c,matches[2] or '')
   if not good then note(c,why) end
  end))
  own('killTrigger',a.tempRegexTrigger('^.*$',function() M.text(c,a.line or _G.line or '') end))
  own('killTrigger',a.tempPromptTrigger(function() M.prompt(c) end))
  own('killAnonymousEventHandler',a.registerAnonymousEventHandler('gmcp.Room.Info',function() M.tick(c) end))
  own('killAnonymousEventHandler',a.registerAnonymousEventHandler('sysDisconnectionEvent',function() M.disconnect(c) end))
 end)
 if not ok then M.detach(c);return false,tostring(err) end
 o.attached=true;return true
end
return M
