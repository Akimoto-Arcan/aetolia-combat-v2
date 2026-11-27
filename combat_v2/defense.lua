-- Self-survival governor. Native FIRSTAID owns actual cures and cure balances.
-- No guessed herb tables, automatic ENEMY changes, or unverified class abilities.
local M={}
local function now()return getEpoch and getEpoch() or os.clock() end
local blockers={'anorexia','asthma','slickness','paralysis','paresis','impatience'}
function M.key(v)return tostring(v or ''):lower():gsub('%s+','_') end
function M.state(s)
 s.defense=s.defense or {requested={},blocked={},phase='monitoring',hold=false}
 return s.defense
end
local function connected(s)
 if not s.connected or s.player.dead or (tonumber(s.player.hp) or 0)<=0 then return false end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();return tcp==true end
 return true
end
-- Diagnostic-only reports. Counts are received messages, not inferred cures.
local function failure(s,channel,aff,text)
 local d=M.state(s);local t=now()
 d.failed_cures=d.failed_cures or {};d.failure_counts=d.failure_counts or {}
 d.failure_total=(d.failure_total or 0)+1
 local k=channel..':'..(aff or 'unknown')
 if not d.failure_counts[k]then
  local n=0;for _ in pairs(d.failure_counts)do n=n+1 end
  if n>=99 then k='other' end -- reserve one aggregate slot; at most 100 keys
 end
 d.failure_counts[k]=(d.failure_counts[k] or 0)+1
 local event={time=t,channel=channel,attempted_aff=aff,text=text,report=d.failure_total}
 table.insert(d.failed_cures,1,event);while #d.failed_cures>100 do table.remove(d.failed_cures)end
 d.last_failure=event
end
function M.failure_report(s)
 local d=M.state(s);local lines={'FIRSTAID failed-cure reports: '..(d.failure_total or 0)..' (latest 10; cause not inferred)'}
 for i=1,math.min(10,#(d.failed_cures or {}))do
  local e=d.failed_cures[i]
  lines[#lines+1]=os.date('%H:%M:%S',math.floor(e.time))..' '..e.channel..': '..(e.attempted_aff or 'unspecified')..' | '..e.text
 end
 if not d.failed_cures or #d.failed_cures==0 then lines[#lines+1]='No matching failures observed since tracking began/was cleared.' end
 return table.concat(lines,'\n')
end
function M.clear_failures(s)
 local d=M.state(s);d.failed_cures={};d.failure_counts={};d.failure_total=0;d.last_failure=nil
 -- Do not change afflictions, blocked-channel evidence, priorities or fault locks.
end
function M.attach(c)
 if type(tempAlias)~='function'then return false end
 if c.firstaid_error_alias then killAlias(c.firstaid_error_alias);c.firstaid_error_alias=nil end
 local id=tempAlias('^faerrors(?: +(clear))?$',function()
  if matches and matches[2]=='clear'then M.clear_failures(c.current) end
  print(M.failure_report(c.current))
 end)
 if type(id)~='number'or id<=0 or id>=math.huge or id~=math.floor(id)then return false end
 c.firstaid_error_alias=id;return true
end
function M.text(s,text)
 if type(text)~='string' then return end
 local d=M.state(s);local a=s.player.afflictions
 -- These are explicitly OWN observations; never ingest reporter/NPC/Discern speech.
 local gained=text:match('^You are afflicted with ([%a_ ]+)%.$') or text:match('^You have discovered ([%a_ ]+)%.$')
 local cured=text:match('^You have cured ([%a_ ]+)%.$')
 if gained then local k=M.key(gained);a[k]=true;if k=='prone' or k=='fallen' then s.player.prone=true end end
 if cured then
  local k=M.key(cured);a[k]=nil;d.requested[k]=nil
  if k=='prone' or k=='fallen' then s.player.prone=(a.prone or a.fallen) and true or false end
 end
 local old,new=text:match('^Your ([%a_ ]+) has transformed into ([%a_ ]+)%.$')
 if old then a[M.key(old)]=nil;a[M.key(new)]=true end
 local channel,aff=text:match('^%[FirstAid%]: unable to (%a+): ([%a_ ]+)$')
 if channel then
  aff=aff:match('^%s*(.-)%s*$')
  if #aff>0 and #aff<=80 and #text<=256 then
   local k=M.key(aff);d.blocked[channel]={time=now(),aff=k};failure(s,channel,k,text)
  end
 end
 if text=='[FirstAid]: tree locked' then d.blocked.tree={time=now(),aff='locked'};failure(s,'tree',nil,text) end
 -- A rejected cure attempt identifies a blocked channel, NOT its cause or a cure.
end
function M.plan(s)
 local d=M.state(s);local p=s.player;local a=p.afflictions;local cfg=s.config or {}
 local hp=(tonumber(p.maxhp) or 0)>0 and 100*p.hp/p.maxhp or 100
 local pause=cfg.defense_health_pause or 45;local resume=cfg.defense_health_resume or 65
 if hp<pause then d.low_health=true elseif hp>=resume then d.low_health=false end
 local health_hold=d.low_health and s.mode~='BASH'
 local lock=a.anorexia and a.asthma and a.slickness
 local hinder=a.paralysis or a.asleep or a.unconsciousness or a.stun or a.stunned
 local reason=lock and (a.paralysis and 'cure-lock + paralysis' or 'cure-lock: eat/apply/smoke blocked') or
  health_hold and ('survival pause; recover to '..resume..'% HP') or
  (p.prone or a.prone or a.fallen) and 'recover posture; native FIRSTAID' or
  hinder and 'recover hinder; native FIRSTAID' or (s.mode=='BASH' and d.low_health and 'BASH low HP: attacking while FIRSTAID cures') or 'monitoring'
 local hold=(lock or health_hold or p.prone or a.prone or a.fallen or hinder) and true or false
 if cfg.defense_enabled==false then reason='disabled';hold=false end
 if d.fault and cfg.defense_enabled~=false then hold=true;reason=d.fault end
 if M.numb_hold and M.numb_hold(s)then hold=true;local _,status=M.numb_hold(s);reason=status or 'emergency transaction unresolved'end
 d.hold=hold;d.phase=reason;d.proposals={}
 for _,k in ipairs(blockers)do
  if not a[k] then d.requested[k]=nil
  elseif cfg.defense_enabled~=false and not d.requested[k] then d.proposals[#d.proposals+1]={aff=k,command='firstaid elevate '..k} end
 end
 return d
end
function M.hold(s)return M.plan(s).hold,M.state(s).phase end
function M.service(s,sender)
 local d=M.plan(s)
 if M.numb_service then if M.numb_service(s,sender)then return M.plan(s)end;d=M.plan(s)end
 if s.training_battle_ended or (s.mode~='FULL_AUTO' and s.mode~='BASH') or not connected(s) or d.fault then return d end
 -- At most one elevation per affliction episode. Server elevations expire on cure.
 for _,a in ipairs(d.proposals)do
  if not d.requested[a.aff] then
  d.requested[a.aff]=true
  local ok,err=pcall(sender or send,a.command)
  if not ok then d.fault='Defense send failed: '..tostring(err);break end
  s.history[#s.history+1]={time=now(),kind='defense_send',target='self',detail=a.command,reason=d.phase}
  while #s.history>100 do table.remove(s.history,1)end
  s.stats.sent=(s.stats.sent or 0)+1
  end
 end
 return d
end
function M.mana_safe(s,cost)
 local p=s.player;local maximum=tonumber(p.maxmana) or 0
 if maximum<=0 then return true end
 return (tonumber(p.mana) or 0)-cost>=maximum*((s.config or {}).defense_mana_reserve or 35)/100
end
function M.reset(s)local d=M.state(s);d.fault=nil;d.requested={} end
function M.audit(s,sender)
 if not connected(s) then return false,'Disconnected: live defense audit unavailable' end
 local commands={'firstaid','firstaid priority list','firstaid elevations','defences'}
 local class=tostring(s.player.class or ''):lower()
 if class=='monk' then
  for _,cmd in ipairs({'ab kaido heal','ab kaido transmute','ab kaido vitality','ab kaido numbness','ab kaido immunity','ab tekura kipup'})do commands[#commands+1]=cmd end
 elseif class=='archivist' then
  -- Read-only group discovery, not an Archivist emergency controller.
  for _,group in ipairs({'geometrics','numerology','bioessence'})do commands[#commands+1]='ab '..group end
 end
 for _,cmd in ipairs(commands)do local ok,err=pcall(sender or send,cmd);if not ok or err==false then return false,'Audit request failed: '..tostring(err) end end
 return true,'Read-only defense audit requested; inspect server replies'
end
function M.setup(s,sender)
 if not connected(s) then return false,'Disconnected: FIRSTAID setup was not sent' end
 -- Explicit operator action only. Preserve existing priorities and curesets.
 local commands={'firstaid on','firstaid curing on','firstaid heal health on','firstaid heal mana on',
  'firstaid use anabiotic on','firstaid auto stand on','firstaid auto wake on','firstaid use focus on',
  'firstaid use tree on','firstaid vitals priority health','firstaid forcehealth 50','firstaid forcemana 20','firstaid slickness pill on'}
 commands[#commands+1]='firstaid'
 for _,cmd in ipairs(commands)do local ok,err=pcall(sender or send,cmd);if not ok then M.state(s).setup='partial request; server readback required';return false,'Setup request failed: '..tostring(err) end end
 -- FIRSTAID at the end requests configuration readback -- Request exact configuration readback, not assumed success.
 M.state(s).setup='requested; server readback required'
 return true,'FIRSTAID survival baseline requested; inspect FIRSTAID readback'
end
-- Emergency NUMB transaction. Embedded in defense.lua; NOT a parallel sender.
-- Native DEF identity/fade metadata sourced 2026-11-24. Generic gain protocol
-- follows the existing own-gain handler; neither gain nor GMCP Add was live-tested.
local numb_owners=setmetatable({},{__mode='k'})
local numb_roots_clear,numb_arbiter,numb_invalidate
local function numfinite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function numkey(v)return tostring(v or ''):lower():gsub('[ %-]+','_')end
local function numb_flag(v)return v==true or v==1 or v=='1'end
local function numb_state(s)local c=numb_owners[s];return c and c.emergency_numb,c end
local function numb_connected(s)local ok,result=pcall(connected,s);return ok and result==true end
local function numb_observer_proof(c,n)
 local fn=n.observer_check or c.emergency_observer_check
 local ok,value=false,false
 if n.observers_ready and type(fn)=='function'then ok,value=pcall(fn,c,n)end
 local proved=ok and value==true
 if n.observer_verified and not proved then numb_invalidate(n,'native observer identity/continuity lost')end
 n.observer_verified=proved
 return proved
end
numb_invalidate=function(n,why)
 n.epoch=(n.epoch or 0)+1;n.session={};n.optin=false;n.shift_optin=false;n.shift_protocol=nil;n.shift_known=nil;n.racial_known=nil;n.race=nil;n.mana=nil;n.mana_at=nil;n.known=nil;n.group_signature=nil;n.class=nil;n.hp=nil;n.maxhp=nil;n.hp_at=nil
 n.balances={};n.balance_versions={};n.affs_known=false;n.affs_list_at=nil;n.known_at=nil;n.defs_at=nil;n.active=nil;n.absent_since=nil;n.cooldown_until=nil;n.ab=nil;n.racial_frame=nil;n.def_metadata=nil;n.text_def_list=nil
 if n.pending then n.fault=why..'; committed emergency action unresolved';n.pending.invalidated=true end
 n.status=why
end
function M.numb_bind(c)
 if type(c)~='table'or type(c.current)~='table'or not c.runner or c.runner.state~=c.current then return false,'canonical owner required'end
 if numb_owners[c.current]then return false,'NUMB owner already attached'end
 if c.emergency_numb and(c.emergency_numb.pending or c.emergency_numb.fault)then return false,'emergency commitment retained; reload/rebind refused'end
 -- Binding is disarmed and does not consume cached GMCP or preference flags.
 local n={owner=c,runner=c.runner,session={},epoch=1,version=0,prompt=0,optin=false,live=false,balances={},status='disarmed; awaiting genuine native evidence'}
 c.emergency_numb=n;numb_owners[c.current]=c;return true
end
function M.numb_optin(c,on)
 local n=numb_state(c.current);if not n then return false,'NUMB owner not attached'end
 n.optin=false
 if on~=true then n.status='NUMB disarmed';return true end
 if not n.live or not numb_connected(c.current)or n.class~='monk'or n.known~=true or n.known_session~=n.session or n.fault then return false,'fresh current-session learned Monk ownership required'end
 n.optin=true;n.status='NUMB explicitly armed for this session';return true
end
-- Observational diagnostics only. Never calls continuity validation, planners,
-- candidate selection or settlement; polling cannot mint absence/cooldown proof.
function M.numb_status(c)
 local n=c and c.current and numb_state(c.current)
 if not n or n.owner~=c then return false,'NUMB owner not attached'end
 local t=now()
 local function age(at)if not numfinite(t)or not numfinite(at)or t<at then return 'unknown'end;return tostring(t-at)end
 local ownership=n.live==true and n.class=='monk'and n.known==true and n.known_session==n.session
 local cooldown='unknown'
 if n.active==true then cooldown='active'
 elseif n.active==false and numfinite(n.absent_since)and numfinite(n.cooldown_until)and numfinite(t)and t>=n.absent_since then
  cooldown='observed-absence '..tostring(math.max(0,n.cooldown_until-t))..'s remaining (continuity enforced at service)'
 end
 return true,'NUMB wanted='..tostring(n.optin==true)..' fresh_ownership='..tostring(ownership)
  ..' class='..tostring(n.class)..' live='..tostring(n.live)..' learned_age='..age(n.known_at)
  ..' observers_registered='..tostring(n.observers_ready==true)..' observers_last_verified='..tostring(n.observer_verified==true)
  ..' binding='..tostring(c.survival_status)..' pending='..tostring(n.pending~=nil)..' fault='..tostring(n.fault)
  ..' cooldown='..cooldown..' defs_age='..age(n.defs_at)..' affs_known='..tostring(n.affs_known==true)
  ..' hp_age='..age(n.hp_at)..' balance='..tostring(n.balances.balance)..' equilibrium='..tostring(n.balances.equilibrium)
  ..' left_arm='..tostring(n.balances.left_arm_balance)..' right_arm='..tostring(n.balances.right_arm_balance)
  ..' status='..tostring(n.status)..' SHIFT=closed-unobserved'
end
function M.numb_observers(c,on)
 local n=numb_state(c.current);if not n then return false end
 n.observers_ready=on==true
 if n.observers_ready and not n.buff_guard then
  if not c.buffs or type(c.buffs.service)~='function'then n.observers_ready=false;return false end
  local old=c.buffs.service
  n.buff_guard=function(...)
   if M.numb_hold(c.current)then return {busy=true,status='Emergency defense physical commitment unresolved'}end
   return old(...)
  end
  n.buff_service_old=old;c.buffs.service=n.buff_guard
 end
 if not n.observers_ready then numb_invalidate(n,'native observers unavailable')end
 return true
end
function M.shift_optin(c,on)
 local n=numb_state(c.current);if not n then return false,'emergency owner not attached'end
 n.shift_optin=false
 if on~=true then return true end
 if not n.live or n.race~='azudim'or n.shift_known~=true or n.racial_known~=true or n.shift_known_session~=n.session or n.fault then return false,'current learned Azudim SHIFT ownership required'end
 n.shift_optin=true;return true,'SHIFT opted in; native activation/cooldown protocol still blocks transport'
end
function M.shift_bind_protocol(c,protocol)
 -- No built-in SHIFT activation/rejection/cooldown pattern exists. This adapter
 -- may be supplied only after genuine native observations; tests use a clearly
 -- synthetic normalized adapter, never invented server narratives.
 local n=numb_state(c.current)
 if not n or type(protocol)~='table'or protocol.schema~='shift-observed-v1'or protocol.owner~=c or protocol.session~=n.session or protocol.source~='native SHIFT activation/rejection/cooldown observations'then return false,'observed SHIFT protocol/session proof required'end
 for _,k in ipairs({'ready','observe','committed','settled'})do if type(protocol[k])~='function'then return false,'complete SHIFT protocol adapter required'end end
 n.shift_protocol=protocol;return true
end
function M.shift_candidate(c,own)
 local n=numb_state(c.current);local p=c.current.player;local t=now()
 if not numfinite(t)then return nil,'SHIFT clock unavailable'end
 if not n or not n.observers_ready or not n.shift_optin or not n.live or n.race~='azudim'or n.shift_known~=true or n.racial_known~=true or n.shift_known_session~=n.session then return nil,'SHIFT session/ownership unavailable'end
 if c.runner~=n.runner or c.runner.state~=c.current or c.runner.mode~='BASH'then return nil,'SHIFT canonical BASH runner required'end
 if not numb_observer_proof(c,n)then return nil,'SHIFT native observer continuity unproved'end
 if c.mode~='BASH'or c.current.mode~='BASH'or c.current.training_battle_ended or (c.current.config or{}).defense_enabled==false or p.dead or not numb_connected(c.current)or n.pending and n.pending~=own or n.fault then return nil,'SHIFT mode/life/ownership hold'end
 if not numfinite(n.hp)or not numfinite(n.maxhp)or n.hp<=0 or n.maxhp<=0 or n.hp>n.maxhp or n.hp/n.maxhp>.25 then return nil,'SHIFT requires HP <=25%'end
 if not numfinite(n.hp_at)or t<n.hp_at or t-n.hp_at>2 or not numfinite(n.mana_at)or t<n.mana_at or t-n.mana_at>2 or not numfinite(n.mana)or n.mana<=n.hp or p.hp~=n.hp or p.mana~=n.mana or p.maxhp~=n.maxhp then return nil,'fresh raw mana must exceed raw HP'end
 if not n.affs_known then return nil,'complete afflictions unknown'end
 for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if n.balances[k]~=true or not numb_flag(p[k])then return nil,'SHIFT balance unavailable'end end
 if p.prone then return nil,'SHIFT posture unavailable'end
 local aff=p.afflictions or{}
 for _,k in ipairs({'prone','fallen','paralysis','paresis','asleep','unconsciousness','unconscious','stun','stunned','frozen','webbed','bound','transfixed','impaled','impalement','entangled','roped'})do if aff[k]then return nil,'SHIFT hindered'end end
 local clear,why=numb_roots_clear(c);if not clear then return nil,why end
 local arb=numb_arbiter(c);if not arb then return nil,'SHIFT shared arbiter unavailable'end
 local ok,free=pcall(arb.clear,c,'shift',own and own.lease);if not ok or free~=true then return nil,'SHIFT shared ownership held'end
 local picked,choice=pcall(arb.choose,c,'shift',n.hp/n.maxhp,own and own.lease);if not picked or choice~='shift'then return nil,'SHIFT/NUMB/escape arbitration'end
 local protocol=n.shift_protocol;local executable=false
 if protocol and protocol.session==n.session then local valid,ready=pcall(protocol.ready,c,own);executable=valid and ready==true end
 return {name='emergency_shift',command='SHIFT',owner='defense',executable=executable,protocol=protocol,
  unrounded_health_benefit=math.min(n.maxhp-n.hp,n.mana/2),health_capacity=n.maxhp-n.hp,rounding_known=false,
  reason='native SHIFT activation/rejection/cooldown not yet observed; no transport or resource debit authorized'}
end
function M.numb_hold(s)
 local n=numb_state(s)
 return (s.earth_defense_pending~=nil or n and(n.pending~=nil or n.fault~=nil))and true or false,n and n.status
end
local function numb_defence(n,active)
 n.defs_at=now()
 if active then
  n.active=true;n.absent_since=nil;n.cooldown_until=nil
  if n.pending and n.pending.kind=='numb'and n.pending.started and not n.pending.invalidated then n.pending.ack=true;n.pending.ack_version=n.version end
 else
  if not numb_observer_proof(n.owner,n)then n.active=nil;n.absent_since=nil;n.cooldown_until=nil;return end
  if n.active~=false or not n.absent_since then n.absent_since=now();n.cooldown_until=n.absent_since+20 end
  n.active=false
 end
end
local function numb_name(v)
 if type(v)=='table'then v=v.name or v.id end
 return type(v)=='string'and numkey(v)=='numbness'
end
function M.numb_observe(c,event,data)
 local n=numb_state(c.current);if not n then return false end
 numb_observer_proof(c,n)
 local t=now()
 if not numfinite(t)or n.last_at and t<n.last_at then numb_invalidate(n,'native clock discontinuity');n.last_at=t;return false end
 n.last_at=t
 n.version=n.version+1
 local pending=n.pending
 if pending and pending.started and pending.protocol and not pending.invalidated then
  local observed,result=pcall(pending.protocol.observe,c,event,data,pending)
  if not observed or result=='reject'then n.fault='SHIFT protocol rejection/observer error; committed action held';n.status=n.fault
  elseif result=='ack'then pending.ack=true;pending.ack_version=n.version end
 end
 if event=='disconnect'then numb_invalidate(n,'disconnected');n.live=false;return true end
 if event=='status'then
  if type(data)~='table'or type(data.class)~='string'then numb_invalidate(n,'unknown class');return false end
  local class=numkey(data.class)
  if n.class and class~=n.class then numb_invalidate(n,'class changed')end
  local race=type(data.race)=='string'and numkey(data.race)or nil
  if n.race and race and n.race~=race then numb_invalidate(n,'race changed')end
  n.class=class;n.class_at=now();n.class_version=n.version;n.race=race or n.race
  if race then n.race_at=now();n.race_version=n.version end
  if class~='monk'then n.optin=false;n.known=nil end;return true
 end
 if event=='vitals'then
  if type(data)~='table'then return false end
  local hp,mx=tonumber(data.hp),tonumber(data.maxhp)
  if data.hp~=nil then
   if not numfinite(hp)or hp<=0 then
    if n.live then numb_invalidate(n,'dead or invalid HP')end;n.live=false;n.optin=false;return true
   end
   n.live=true;n.hp=hp;n.hp_at=now();n.hp_version=n.version
  end
  if data.maxhp~=nil then n.maxhp=numfinite(mx)and mx>0 and mx or nil end
  if data.mp~=nil then local mp=tonumber(data.mp);n.mana=numfinite(mp)and mp>=0 and mp or nil;n.mana_at=now()end
  for wire,key in pairs({balance='balance',equilibrium='equilibrium',left_arm='left_arm_balance',right_arm='right_arm_balance'})do
   if data[wire]~=nil then
    local value=numb_flag(data[wire]);n.balances[key]=value;n.balance_versions=n.balance_versions or{};n.balance_versions[key]=n.version
    local p=n.pending
    if p and p.started and n.version>p.version then
     if value==false then p.lost[key]=true elseif p.lost[key]then p.recovered[key]=true end
    end
   end
  end
  return true
 end
 if event=='afflictions'then
  if type(data)=='table'then n.affs_known=true;n.affs_version=n.version;n.affs_list_at=now();n.affs_session=n.session else n.affs_known=false end;return true
 end
 if event=='afflictions_delta'then n.affs_version=n.version;return true end
 if event=='groups'then
  local signature={}
  if type(data)=='table'then for _,g in pairs(data)do if type(g)=='table'and numkey(g.name)=='kaido'then signature[#signature+1]='kaido:'..tostring(g.rank or '')end end end
  table.sort(signature);signature=table.concat(signature,'|')
  if signature~=n.group_signature then n.known=nil;n.known_version=nil end
  n.group_signature=signature;return true
 end
 if event=='skills'then
  if n.live and n.class=='monk'and type(data)=='table'and numkey(data.group)=='kaido'then
   if type(data.list)~='table'then n.known=nil;return false end
   local known=false
   for _,row in pairs(data.list)do
    local permitted=true;local name=row
    if type(row)=='table'then
     name=row.name or row.id
     if row.known~=nil and row.known~=true and row.known~=1 then permitted=false end
    end
    if type(name)~='string'then n.known=nil;return false end
    if numkey(name)=='numbness'and permitted then known=true end
   end
   n.known=known;n.known_version=n.version;n.known_session=n.session;n.known_at=now()
  end
  return true
 end
 if event=='defences_list'then
  if n.live and n.class=='monk'and type(data)=='table'then
   local active=false
   for _,v in pairs(data)do
    local name=type(v)=='table'and(v.name or v.id)or v
    if type(name)~='string'then n.active=nil;n.absent_since=nil;n.cooldown_until=nil;return false end
    if numb_name(v)then active=true end
   end
   numb_defence(n,active);n.defs_version=n.version;n.defs_session=n.session;n.defs_at=now()
  else n.active=nil;n.absent_since=nil;n.cooldown_until=nil end
  return true
 end
 if event=='defences_add'or event=='defences_remove'then
  if n.live and n.class=='monk'and numb_name(data)then numb_defence(n,event=='defences_add');n.defs_version=n.version;n.defs_session=n.session end
  return true
 end
 if event=='text'and type(data)=='string'then
  -- DEFENCE help prints the exact Fade Message as documentation. It is NOT
  -- a real expiry. Fence this frame until its genuine prompt; conservatively
  -- require a later authoritative defence snapshot after text ambiguity.
  if data:match('^Defence:%s+[%a_ %-]+$')then n.def_metadata=true;n.active=nil;n.absent_since=nil;n.cooldown_until=nil;return true end
  if n.def_metadata then return true end
  if data=='You have the following active defences:'then n.text_def_list=true end
  if data:match('^You are protected by %d+ defences%.$')then n.text_def_list=nil end
  if n.text_def_list and data=='You are temporarily numbed to damage.'and n.live and n.class=='monk'then
   -- Sourced DEF row is positive status only, never an activation ACK.
   n.active=true;n.absent_since=nil;n.cooldown_until=nil;n.defs_version=n.version;n.defs_session=n.session;n.defs_at=now()
  end
  -- Current learned ownership, not accessible AB help or guild/rank inference.
  -- Accept either exact complete heading, or known line within its bounded AB frame.
  if data=='Numbness (Kaido)'then n.ab={session=n.session,at=now()};return true end
  if data:match('^Shift %(Racial%)%s+Known:%s+Yes%s*$')then n.shift_known=n.live and n.race=='azudim'or false;n.shift_known_session=n.session;n.shift_known_version=n.version;n.shift_known_at=now()
  elseif data:match('^Shift %(Racial%)%s+Known:%s+No')then n.shift_known=false;n.shift_optin=false end
  if data=='You possess the following abilities from your race:'then n.racial_frame={session=n.session,shift=false}end
  if n.racial_frame then
   if data=='You possess the following racial abilities through other means:'then n.racial_frame.other=true end
   if data=='Shift'and not n.racial_frame.other then n.racial_frame.shift=true end
   if data=='Type RACIAL HELP <skill> to learn more about a specific skill.'then n.racial_known=n.racial_frame.session==n.session and n.racial_frame.shift;n.racial_version=n.version;n.racial_session=n.session;n.racial_at=now();n.racial_frame=nil end
  end
  if n.ab and data:match('^.+ %([%a ]+%)')and not data:match('^Numbness %(Kaido%)')then n.ab=nil end
  local known=data:match('^Numbness %(Kaido%)%s+Known:%s+(Yes) %(%d+ lessons%)$')or data:match('^Numbness %(Kaido%)%s+Known:%s+(No).*$')
  if not known and n.ab and n.ab.session==n.session and now()-n.ab.at<=8 then
   known=data:match('^Known: (Yes) %(%d+ lessons%)$')or data:match('^Known: (No).*$')
  end
  if known and n.live and n.class=='monk'then n.known=known=='Yes';n.known_session=n.session;n.known_version=n.version;n.known_at=now();n.ab=nil end
  if n.live and n.class=='monk'then
   local gain=data:match('^You have gained the ([%a_ %-]+) defence%.$')
   local loss=data:match('^You have lost the ([%a_ %-]+) defence%.$')
   if gain and numkey(gain)=='numbness'then numb_defence(n,true);n.defs_version=n.version;n.defs_session=n.session end
   if loss and numkey(loss)=='numbness'or data=='The numbness slowly fades away, leaving you as you were.'then
    numb_defence(n,false);n.defs_version=n.version;n.defs_session=n.session
   end
  end
  -- Description "You are temporarily numbed to damage." is NOT an activation ACK.
  return true
 end
 if event=='prompt'then
  n.prompt=n.prompt+1;n.ab=nil;n.def_metadata=nil;n.text_def_list=nil
  local p=n.pending
  if p and p.started and p.ack and not p.invalidated then p.prompt_after_ack=true end
  return true
 end
 return false
end
local numb_barriers={'pending','fault','waiting','transport_unknown','transport_barriers','transportBarriers','physical_dispatch','physical_commit','dispatching','arrival_hold','eq_pending','txn','follow_pending','follow_fault','recall_due','query','listing','ability_listing','native_listing','native_pending','transport_pending','movement_pending','ink_pending','reserving'}
local function numb_present(v,k)
 if v==nil or v==false then return false end
 if type(v)=='table'and(k=='transport_barriers'or k=='transportBarriers'or k=='native_pending')then return next(v)~=nil end
 return true
end
numb_roots_clear=function(c)
 -- Shared authority alone owns strict passive-diagnostic admission and the full
 -- retained IO/root census. Never recurse through the mutating defense planner.
 local a=numb_arbiter(c);if not a then return false,'shared full-owner census unavailable'end
 local n=numb_state(c.current);local p=n and n.pending
 local ok,clear,why=pcall(a.clear,c,p and p.kind or 'numb',p and p.lease)
 return ok and clear==true,why or 'shared full-owner census held'
end
local numb_hinders={'sensitivity','prone','fallen','paralysis','paresis','asleep','unconscious','unconsciousness','stun','stunned','frozen','webbed','bound','transfixed','impaled','impalement','entangled','roped','left_arm_crippled','right_arm_crippled','left_arm_broken','right_arm_broken','left_arm_mangled','right_arm_mangled'}
numb_arbiter=function(c)
 local a=c.survival_arbiter
 if type(a)~='table'or a.schema~='survival-v1'or a.owner~=c then return nil end
 for _,k in ipairs({'clear','choose','reserve','owns','release'})do if type(a[k])~='function'then return nil end end
 return a
end
local function numb_call(fn,...)
 local ok,result=pcall(fn,...);return ok and result==true
end
local function numb_ready(c,own)
 local s=c.current;local p=s.player;local n=numb_state(s)
 if not n or not n.observers_ready or not n.optin or not n.live or n.class~='monk'or n.known~=true or n.known_session~=n.session then return false,'NUMB unarmed or ownership unknown'end
 if c.runner~=n.runner or c.runner.state~=s or c.runner.mode~='BASH'then return false,'canonical BASH runner required'end
 if not numb_observer_proof(c,n)then return false,'native observer continuity unproved'end
 if n.fault or n.pending and n.pending~=own then return false,n.fault or 'NUMB pending'end
 if s.mode~='BASH'or c.mode~='BASH'or s.training_battle_ended or (s.config or{}).defense_enabled==false then return false,'BASH emergency inactive'end
 if s.connected~=true or p.dead or not numb_connected(s)or numkey(p.class)~='monk'then return false,'disconnected/dead/foreign class'end
 local t=now()
 if not numfinite(t)or not numfinite(n.hp_at)or t<n.hp_at or t-n.hp_at>2 or not numfinite(n.hp)or not numfinite(n.maxhp)or n.hp<=0 or n.maxhp<=0 or n.hp>n.maxhp or p.hp~=n.hp or p.maxhp~=n.maxhp then return false,'fresh actual HP required'end
 local ratio=n.hp/n.maxhp;if not numfinite(ratio)or ratio>=.30 then return false,'NUMB requires strictly below30%'end
 if not n.affs_known or type(p.afflictions)~='table'then return false,'complete afflictions unknown'end
 if p.prone then return false,'posture'end
 for _,k in ipairs(numb_hinders)do if p.afflictions[k]then return false,k end end
 for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if n.balances[k]~=true or not numb_flag(p[k])then return false,'actual balance '..k end end
 if n.active~=false or n.defs_session~=n.session or not numfinite(n.cooldown_until)or t<n.cooldown_until then return false,'NUMB inactive/cooldown proof unavailable'end
 local clear,why=numb_roots_clear(c);if not clear then return false,why end
 local a=numb_arbiter(c);if not a then return false,'verified shared survival arbiter unavailable'end
 if not numb_call(a.clear,c,'numb',own and own.lease)then return false,'shared ownership unavailable'end
 local picked,choice=pcall(a.choose,c,'numb',ratio,own and own.lease)
 if not picked or choice~='numb'then return false,ratio<.20 and 'below20% escape owner arbitration'or 'shared emergency action arbitration'end
 return true,a
end
function M.numb_service(s,sender)
 local n,c=numb_state(s);if not n then return false end
 numb_observer_proof(c,n)
 -- Existing service/arbiter/owned sender only. FIRSTAID retains ordinary cures.
 local arb=numb_arbiter(c)
 if arb and type(arb.reinforce)=='function'then
  local busy,status=arb.reinforce(c)
  if busy then n.status=status;return true end
 end
 local p=n.pending
 if p then
  if p.settling then return true end
  if now()-p.at>8 and not n.fault then n.fault='Emergency acknowledgement/recovery timeout; review required';n.status=n.fault end
  local recovered=false;for k in pairs(p.lost)do if p.recovered[k]then recovered=true end end
  if not n.fault and not p.dispatching and p.transport_ok and p.ack and p.prompt_after_ack and recovered and not p.invalidated then
   local a=numb_arbiter(c)
   p.settling=true
   if p.protocol and not numb_call(p.protocol.settled,c,p)then n.fault='SHIFT protocol settlement unavailable';n.status=n.fault;return true end
   if a and numb_call(a.owns,c,p.lease)and numb_call(a.release,c,p.lease)then n.pending=nil;n.status=p.kind:upper()..' recovery settled';return false end
   n.fault='Emergency ownership settlement unavailable';n.status=n.fault
  end
  return true
 end
 local shift=M.shift_candidate(c)
 local kind,protocol='numb',nil
 local ok,a
 if shift and shift.executable then kind='shift';protocol=shift.protocol;ok=true;a=numb_arbiter(c)else ok,a=numb_ready(c)end
 if not ok then n.status=a..(shift and not shift.executable and '; SHIFT native protocol unavailable'or'');return false end
 p={at=now(),version=n.version,session=n.session,lost={},recovered={},dispatching=true,kind=kind,protocol=protocol}
 n.pending=p -- Before reserve or sender: callbacks may reenter either.
 local reserved,lease=pcall(a.reserve,c,kind,{hp_ratio=n.hp/n.maxhp,session=n.session})
 if reserved and lease==false then n.pending=nil;n.status='Emergency reservation declined without commitment';return false end
 if not reserved or type(lease)~='table'then
  -- A throwing reserve may already have acquired ownership: never pretend unsent.
  n.fault='Emergency reservation unavailable/unknown; review required';n.status=n.fault;p.dispatching=false;return true
 end
 p.lease=lease
 if not numb_call(a.owns,c,lease)then n.fault='Emergency lease ownership unknown';n.status=n.fault;p.dispatching=false;return true end
 local safe,why
 if kind=='shift'then local action;action,why=M.shift_candidate(c,p);safe=action and action.executable and action.protocol==protocol
 else safe,why=numb_ready(c,p)end
 if not safe then n.fault='Emergency pretransport invalidation: '..tostring(why);n.status=n.fault;p.dispatching=false;return true end
 if protocol then
  if not numb_call(protocol.committed,c,p)then n.fault='SHIFT protocol commit unavailable/unknown';n.status=n.fault;p.dispatching=false;return true end
  local again=M.shift_candidate(c,p)
  if not again or not again.executable or again.protocol~=protocol or p.session~=n.session or n.pending~=p then n.fault='SHIFT invalidated during protocol commit';n.status=n.fault;p.dispatching=false;return true end
 end
 p.started=true
 local command=kind:upper()
 local sent,result
 if type(a.transport)=='function'then sent,result=pcall(a.transport,c,p.lease,kind,sender or send,command)
 else sent,result=false,'shared owned transport capability unavailable'end
 p.dispatching=false;p.transport_ok=sent and result~=false
 if not p.transport_ok then n.fault='Emergency send failed/unknown; review required';n.status=n.fault
 else n.status=n.fault or(command..' sent; awaiting native acknowledgement and genuine channel recovery/prompt')end
 if s.history then s.history[#s.history+1]={time=now(),kind='defense_send',target='self',detail=command,reason='BASH emergency: NUMB<30%, SHIFT<=25% beneficial rawMP'};while #s.history>100 do table.remove(s.history,1)end end
 if s.stats then s.stats.sent=(s.stats.sent or 0)+1 end
 return true
end

return M
