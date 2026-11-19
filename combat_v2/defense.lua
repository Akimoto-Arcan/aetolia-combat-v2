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
return M
