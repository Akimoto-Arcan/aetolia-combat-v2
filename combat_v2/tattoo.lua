-- Explicit ink TYPE [NAME]. No gameplay at load/attach, no retries or auto-resume.
-- Runtime integration must gate other action controllers on busy(c)/user_activity.
-- Inject c.tattoo_api for offline adapters; native defaults are resolved at attach.
local M={}
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
local function fault(c,why)
 local t=owner(c).txn;if t then t.unknown=true;t.reason=why end
 local advice=t and t.phase=='query' and not t.paused and not t.committed and '; use ink cancel to release this read-only query (further inking remains quarantined).' or '; no retries. Combat/upkeep remain OFF if paused; review unresolved transaction.'
 note(c,'Tattoo held: '..why..advice)
 return false,why
end
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
 local room=s.room or {};local scan=(s.hunting or {}).ih
 if room.id==nil or type(room.items)~='table' then return false,'room unknown' end
 -- Fresh completed IH or a later authoritative room-items version.
 if not scan or scan.room_id~=room.id or not (scan.responded==true or (room.item_version or 0)>(scan.start_version or math.huge)) then return false,'fresh room inspection required' end
 for _,it in pairs(room.items) do
  local flags=tostring(it.attrib or '')
  if (flags:find('m',1,true) or it.icon=='monster') and not flags:find('d',1,true) and not flags:find('x',1,true) then return false,'living hostile NPC present' end
 end
 return true
end
local function scoped(c,t)
 if not connected(c) or not c.current or not c.current.room or c.current.room.id~=t.room then return false,'room/session changed' end
 if c.user_activity~=t then return false,'activity ownership changed' end
 if not t.paused and c.mode~=t.original_mode then return false,'operator changed mode during AB query' end
 if t.paused and (c.mode~='OFF' or c.current.mode~='OFF' or (c.runner or {}).mode~='OFF' or (c.current.buffs or {}).master or c.containers_refill_enabled~=false) then return false,'operator changed paused intent' end
 if t.paused and c.elemental_recovery and c.elemental_recovery.armed then return false,'GLOBE rearmed during tattoo' end
 return true
end
local function untimer(c)
 local o=owner(c);if o.timer then local f=api(c).killTimer;if f then pcall(f,o.timer) end;o.timer=nil end
end
local function arm(c,t,seconds)
 untimer(c);t.deadline=now(c)+seconds
 local a=api(c);if a.tempTimer then owner(c).timer=a.tempTimer(seconds,function() if owner(c).txn==t then M.tick(c) end end) end
end
-- Commit before transport, including synchronous/reentrant receive callbacks.
local function dispatch(c,t,phase,command,timeout)
 t.phase=phase;t.command=command;t.ack=nil;t.dispatching=true;t.committed=phase~='query'
 arm(c,t,timeout)
 local sendfn=api(c).send
 local ok,result=pcall(function() if not sendfn then error('sender unavailable') end;return sendfn(command) end)
 t.dispatching=false
 if not ok or result==false then return fault(c,'transport unknown for '..command) end
 return true
end
function M.request(c,input)
 if input=='status' then
  local o=owner(c);local t=o.txn
  if t then note(c,'Tattoo '..t.phase..': '..(t.reason or 'awaiting own acknowledgement / genuine ready prompt')..(t.phase=='query' and not t.paused and '; ink cancel releases read-only query only' or '; issued actions cannot be cancelled'))
  elseif o.query_quarantine then note(c,'Tattoo query cancelled; further inking quarantined pending review. Other activities are available.')
  else note(c,'Tattoo idle') end
  return true
 end
 if input=='cancel' then
  local o=owner(c);local t=o.txn
  if not t then return false,'no tattoo transaction' end
  if t.phase~='query' or t.committed or t.paused or t.dispatching then return false,'issued resource action retained; cannot cancel uncertainty' end
  untimer(c);o.query_quarantine=t;o.txn=nil
  if c.user_activity==t then c.user_activity=nil end
  note(c,'Read-only tattoo query cancelled; no inks used. Inking query quarantined pending review; other activities remain available.')
  return true
 end
 if owner(c).query_quarantine then return false,'inking query quarantined; review before another ink request' end
 local spec,why=M.parse(input);if not spec then return false,why end
 if M.busy(c) then return false,'tattoo transaction already pending; review status' end
 local ok;ok,why=M.safe(c);if not ok then return false,why end
 local o=owner(c);o.serial=o.serial+1
 local t={id=o.serial,type=spec.type,target=spec.target,room=c.current.room.id,original_mode=c.mode,lines=0,receipts={},started=now(c)}
 o.txn=t;c.user_activity=t
 note(c,'Tattoo: verifying learned ability and current recipe (no resource action yet)')
 return dispatch(c,t,'query','ab tattoos '..t.type,12)
end
local function pause(c,t)
 local ok,why=M.safe(c);if not ok then return fault(c,why) end
 local a=api(c);local stop=a.set_mode or a.combat_v2_set_mode
 if not stop then return fault(c,'safe OFF adapter unavailable') end
 -- No restoration: wanted defenses survive native stop; FIRSTAID untouched.
 t.saved_refill=c.containers_refill_enabled;t.paused=true
 local g=c.elemental_recovery;local preserved
 if g and read_only_globe(g) then preserved={pending=g.pending,phase=g.phase,fault=g.fault,status=g.status} end
 local success,result=pcall(stop,'OFF')
 -- OFF may discard a timed-out read-only PROBE. Preserve its evidence; do
 -- not clear quarantine or manufacture a successful globe reconciliation.
 if preserved then g.pending=preserved.pending;g.phase=preserved.phase;g.fault=preserved.fault;g.status=preserved.status;g.armed=false end
 c.containers_refill_enabled=false
 if not success or result==false or c.mode~='OFF' or c.current.mode~='OFF' or (c.runner or {}).mode~='OFF' or (c.current.buffs or {}).master or (g and g.armed) then return fault(c,'OFF not verified') end
 return true
end
local function next_action(c,t)
 if t.unknown or t.dispatching then return false end
 local ok,why=scoped(c,t);if not ok then return fault(c,why) end
 ok,why=M.safe(c,true);if not ok then return fault(c,why) end
 if not physically_ready(c) then return false end -- finite current-phase lease still applies
 t.index=(t.index or 0)+1
 local row=t.recipe[t.index]
 if row then return dispatch(c,t,'withdraw','outc '..row.count..' '..row.color..'ink',10) end
 return dispatch(c,t,'ink','ink '..t.type..' on any of '..t.target,40)
end
function M.tick(c)
 local t=owner(c).txn;if not t then return true end
 if t.unknown then return false,t.reason end
 local ok,why=scoped(c,t);if not ok then return fault(c,why) end
 if now(c)>=t.deadline then return fault(c,'missing '..t.phase..' acknowledgement') end
 return true
end
function M.text(c,line)
 local t=owner(c).txn;if not t or t.unknown or type(line)~='string' then return end
 if not M.tick(c) then return end
 if #line>1000 then return fault(c,'oversized response') end
 line=line:match('^%s*(.-)%s*$')
 if t.phase=='query' then
  t.lines=t.lines+1;if t.lines>200 then return fault(c,'unbounded AB response') end
  local name,known=line:match('^%s*([A-Za-z]+)%s+%(Tattoos%)%s+Known:%s*(%a+)%s*$')
  if not name then name,known=line:match('^%s*([A-Za-z]+)%s+%(Tattoos%)%s+Known:%s*(%a+)%s+%(%d+ lessons?%)%s*$')end
  if not name then name=line:match('^%s*([A-Za-z]+)%s+%(Tattoos%)%s*$') end
  if name then
   if t.header or name:lower()~=t.type then return fault(c,'AB identity mismatch/duplicate') end
   t.header=true;if known then t.known=known=='Yes' end
  elseif t.header then
   known=line:match('^%s*Known:%s*(%a+)%s*$');if known then if t.known~=nil then return fault(c,'duplicate Known field') end;t.known=known=='Yes' end
   if line:match('^Required inks:') then
    if t.recipe then return fault(c,'duplicate recipe') end
    t.recipe=M.recipe(line);if not t.recipe then return fault(c,'unknown or malformed ink cost') end
   end
  end
 elseif t.phase=='withdraw' then
  local n,color,total=line:match('^You remove (%d+) ([a-z]+)ink, bringing the total in the cache to (%d+)%.$')
  if n then
   local row=t.recipe[t.index]
   if tonumber(n)~=row.count or color~=row.color then return fault(c,'withdrawal receipt mismatch') end
   if t.ack then return fault(c,'duplicate withdrawal receipt') end
   t.ack=true;t.receipts[#t.receipts+1]={color=color,count=tonumber(n),remaining=tonumber(total)}
  end
 elseif t.phase=='ink' then
  local typ=line:match("^As the ([A-Za-z]+) tattoo's shape is codified, the last of the ink leaves the air, and you pause for a moment to admire your handiwork%.$")
  if typ then if typ:lower()~=t.type then return fault(c,'ink completion mismatch') end;t.ack=true end
 end
 -- Rejections not yet source-validated are deliberately NOT guessed into success
 -- or automatic retry. Missing exact receipts terminate at the bounded timeout.
end
function M.prompt(c)
 local t=owner(c).txn;if not t or t.unknown then return end
 if not M.tick(c) or t.dispatching then return end
 if t.phase=='query' then
  if not t.header or t.known~=true or not t.recipe then return fault(c,'AB lacks exact learned identity/current recipe') end
  local ok,why=M.safe(c,true);if not ok then return fault(c,why) end
  if not physically_ready(c) then return end
  if not pause(c,t) then return end
  return next_action(c,t)
 elseif t.phase=='withdraw' and t.ack then return next_action(c,t)
 elseif t.phase=='ink' and t.ack then
  -- Settle an already completed own action before preflight-only NPC/curing
  -- checks. Those checks still guard EVERY future withdrawal and INK dispatch.
  local s=c.current or {};local p=s.player or {}
  if not yes(s.connected) or yes(p.dead) or (tonumber(p.hp) or 0)<=0 or s.training_battle_ended then return fault(c,'completion outside living session') end
  if not physically_ready(c) then return end
  untimer(c);local o=owner(c);o.last=t;o.txn=nil
  if c.user_activity==t then c.user_activity=nil end
  note(c,'Tattoo complete (own acknowledgement + ready prompt). Combat, upkeep, GLOBE and custom refill remain OFF; FIRSTAID unchanged.')
  return true
 end
end
function M.disconnect(c) if M.busy(c) then return fault(c,'disconnected; issued actions unresolved') end end
function M.detach(c)
 local o=owner(c);local a=api(c);untimer(c)
 for _,h in ipairs(o.handles) do local f=a[h.kind];if f then pcall(f,h.id) end end
 o.handles={};o.attached=false
 if o.txn then fault(c,'detached with transaction retained') end
 return o
end
function M.attach(c)
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
