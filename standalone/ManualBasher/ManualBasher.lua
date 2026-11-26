-- ManualBasher: pure factory, no global installation or sends on load.
local M = {}
local function lower(v) return tostring(v or ''):lower() end
local function yes(v) return v == true or v == 1 or v == '1' end
local function bal(v) if v.balance~=nil then return v.balance end; return v.bal end
local function eq(v) if v.equilibrium~=nil then return v.equilibrium end; return v.eq end
local function no(v) return v == false or v == 0 or v == '0' end
local function id(v) local s=tostring(v or ''); if s:match('^%d+$') and tonumber(s)>0 then return s end end
local function protected(n)
 n=lower(n)
 if ({['clive, a sly-looking bandit']=true,['khabarak, the jeweler']=true,['belok, the mining chief']=true,['thelvoro stonefist']=true})[n] then return true end
 for w in n:gmatch('%a+') do
  if ({guard=true,guards=true,loyal=true,horse=true,horses=true,steed=true,steeds=true,roc=true,rocs=true,mount=true,mounts=true,mounted=true,corpse=true})[w] then return true end
 end
 return false
end
function M.new(api, db)
 local s={enabled=false, reason='default OFF', class='Earthcaller', command='quash {target}', room=nil, generation=0, items={}, target=nil, pending=nil, request=nil, readySeq=0, seq=0, prompt=0, lastSend=-100, area=nil, vitals=nil, status=nil, inventory={}, affs=nil, destroyed=false}
 s.irongrip=true; s.ironActive=nil; s.ironKnown=nil
 local self={state=s}
 local function say(t) api.notice('[ManualBasher] '..t) end
 local function off(reason) s.enabled=false; s.reason=reason or 'manual OFF'; say('OFF: '..s.reason) end
 self.off=off
 local function scope()
  if s.area then return db[s.area] end
  local found
  for _,a in pairs(db) do if a.areas and a.areas[s.nativeArea] then if found and found~=a then return nil end; found=a end end
  return found
 end
 local function classOK()
  if not s.status or lower(s.status.class)~=lower(s.class) then return false end
  local stats=(s.vitals or {}).charstats
  if stats~=nil and type(stats)~='table' then return false end
  for _,v in pairs(stats or {}) do
   local c=tostring(v):match('^[Cc]lass:%s*(.-)%s*$')
   if c and lower(c)~=lower(s.class) then return false end
  end
  return true
 end
 local function eligible(it)
  if type(it)~='table' or not id(it.id) or not it.name or protected(it.name) then return false end
  local a=lower(it.attrib or it.attributes)
  -- Aetolia positive mobile flag plus deliberately narrow known flags.
  if a~='m' then return false end
  if it.icon~=nil and not ({['']=true,m=true,mob=true,monster=true,['face-angry-horns']=true})[lower(it.icon)] then return false end
  if it.player or it.loyal or it.vendor or it.corpse or it.mount or it.dead or it.protected then return false end
  local area=scope(); return area and area.mobs and (area.mobs[it.name] == true or area.mobs[lower(it.name)] == true)
 end
 local function request()
  if s.request or not s.room then return end
  s.request={generation=s.generation, at=api.now()}; api.gmcp('Char.Items.Room')
 end
 function self.room(info)
  if not info or not info.num then return end
  local r=tostring(info.num)
  if r~=s.room then
   s.room=r; s.nativeArea=info.area; s.generation=s.generation+1; s.items={}; s.target=nil; s.snapshot=nil
   -- Keep an in-flight request as a drain barrier; never label its reply fresh after moving.
   request()
  else s.nativeArea=info.area end
 end
 function self.list(msg)
  if not msg or msg.location~='room' or not s.request then return end
  local req=s.request; s.request=nil
  if req.generation~=s.generation then request(); return end
  s.items={}
  for _,it in pairs(msg.items or {}) do local n=id(it.id); if n then s.items[n]=it end end
  s.snapshot=s.generation
  if s.target and not eligible(s.items[s.target]) then s.target=nil end
 end
 function self.item(kind,msg)
  if not msg or msg.location~='room' or s.snapshot~=s.generation then return end
  local it=msg.item or msg; local n=id(it.id or msg.id); if not n then return end
  if kind=='remove' then s.items[n]=nil
  elseif kind=='update' then
   if not s.items[n] then return end
   for k,v in pairs(it) do s.items[n][k]=v end
  else s.items[n]=it end
  if s.target==n and not eligible(s.items[n]) then s.target=nil end
 end
 function self.status(v)
  if s.status and v and s.status.name and v.name~=s.status.name then self.disconnect() end
  s.status=v
  if s.enabled and not classOK() then off('class unavailable or changed') end
 end
 function self.afflictions(v) s.affs=v end
 function self.inv(msg)
  if not msg or msg.location~='inv' then return end
  s.inventory={}; for _,it in pairs(msg.items or {}) do s.inventory[tostring(it.id)]=it end
  s.invAt=api.now()
 end
 function self.invItem(kind,msg)
  if not msg or msg.location~='inv' then return end
  local it=msg.item or msg; local n=id(it.id or msg.id); if not n then return end
  if kind=='remove' then s.inventory[n]=nil else
   local old=s.inventory[n] or {}; for k,v in pairs(it) do old[k]=v end; s.inventory[n]=old
  end
  s.invAt=api.now()
 end
 local function wielded()
  local v=s.vitals or {}
  for _,key in ipairs({'wield_left','wield_right'}) do
   if type(v[key])=='string' and (v[key]:match('^crozier%d+$') or v[key]:match('^flail%d+$')) then return true end
  end
  return false
 end
 function self.ironKnown(known) s.ironKnown=known; s.ironQuery=nil; if not known and s.enabled and s.irongrip then off('Irongrip not Known: Yes; select racial skill manually, or mb irongrip off') end end
 function self.iron(active)
  s.ironActive=active
  if active and s.pending and s.pending.kind=='irongrip' then s.pending.ack=true end
 end
 function self.defences(kind,msg)
  if kind=='list' then
   local active=false
   for _,v in pairs(msg or {}) do if lower(type(v)=='table' and v.name or v)=='irongrip' then active=true end end
   self.iron(active)
  elseif lower(type(msg)=='table' and msg.name or msg)=='irongrip' then self.iron(kind=='add') end
 end
 function self.vitals(v)
  s.seq=s.seq+1; s.vitals=v; s.vitalsAt=api.now()
  local hp,max=tonumber(v.hp),tonumber(v.maxhp)
  if s.enabled and hp and max and max>0 and hp/max<0.20 then off('!!! HEALTH BELOW 20% -- STOP; MANUAL ACTION REQUIRED !!!') end
  if s.enabled and not classOK() then off('class mismatch/unavailable') end
  local p=s.pending
  if p and s.seq>p.seq then
   if no(bal(v)) then p.lost=true end
   if p.lost and yes(bal(v)) and yes(eq(v)) and (p.kind~='irongrip' or p.ack) then s.pending=nil; s.readySeq=s.seq; s.recoveryPrompt=s.prompt end
  end
 end
 local function safe()
  local v=s.vitals or {}; local hp,m=tonumber(v.hp),tonumber(v.maxhp)
  if not classOK() then return false,'class mismatch/unavailable' end
  if not hp or not m or m<=0 or hp/m<0.20 then return false,'health missing/low' end
  if not s.vitalsAt or api.now()-s.vitalsAt>3 then return false,'stale vitals' end
  if not yes(bal(v)) or not yes(eq(v)) then return false,'balance/equilibrium' end
  -- Require explicit native posture and arm status, never assume absent=false.
  if not no(v.prone) then return false,'prone unknown/active' end
  if not yes(v.left_arm) or not yes(v.right_arm) then return false,'arm balance unknown/blocked' end
  if not s.affs then return false,'waiting for native affliction list' end
  for _,name in ipairs({'left_arm_broken','right_arm_broken','left_arm_crippled','right_arm_crippled','crippled_left_arm','crippled_right_arm','broken_left_arm','broken_right_arm','mangled_left_arm','mangled_right_arm','paralysis','paresis','prone','fallen','asleep','stun','stunned'}) do
   if s.affs[name] then return false,'native impairment: '..name end
  end
  if lower(s.class)=='earthcaller' and not wielded() then return false,'no native wield evidence' end
  return true
 end
 function self.prompt()
  s.prompt=s.prompt+1
  if not s.enabled or s.destroyed then return end
  if api.conflict() then off('competing offense present; use a separate profile'); return end
  if s.pending then return end
  if s.recoveryPrompt and s.prompt<=s.recoveryPrompt then return end
  local ok,reason=safe(); if not ok then if s.reason~=reason then say('HOLD: '..reason..'; manual action required') end; s.reason=reason; return end
  if s.seq<=s.lastIssueSeq or api.now()-s.lastSend<0.30 then return end
  if s.irongrip then
   if s.ironKnown~=true then s.reason='waiting for native Racial Irongrip Known: Yes'; return end
   if s.ironActive~=true then
    s.pending={seq=s.seq,at=api.now(),lost=false,kind='irongrip',ack=false}; s.lastIssueSeq=s.seq; s.lastSend=api.now(); s.reason='Irongrip: waiting for own defence acknowledgement and BAL cycle'; api.send('irongrip'); return
   end
  end
  if s.snapshot~=s.generation or not scope() then s.reason='waiting for fresh room list / known area'; return end
  if not eligible(s.items[s.target]) then
   s.target=nil; local keys={}; for n,it in pairs(s.items) do if eligible(it) then keys[#keys+1]=n end end
   table.sort(keys,function(a,b) return tonumber(a)<tonumber(b) end); s.target=keys[1]
  end
  if not s.target then s.reason='no eligible listed NPC'; return end
  s.pending={seq=s.seq, at=api.now(), lost=false}; s.lastIssueSeq=s.seq; s.lastSend=api.now()
  s.reason='waiting for raw BAL loss/recovery'; api.send((s.command:gsub('{target}',s.target)))
 end
 s.lastIssueSeq=-1
 function self.timeout()
  if s.ironQuery and api.now()-s.ironQuery>10 then off('Irongrip help query timed out; OFF/ON after checking native help') end
  if s.pending and api.now()-s.pending.at>10 then off('attack acknowledgement/BAL recovery timed out; reconnect or wait for actual recovery') end
  if s.request and api.now()-s.request.at>10 then off('room refresh timed out; use mb refresh after reconnect') end
 end
 function self.on()
  if s.destroyed then return false end
  if api.conflict() then off('CombatV2/known offense present: use separate profile'); return false end
  if not classOK() then off('class unavailable/mismatch'); return false end
  if not scope() then off('unknown/ambiguous area: mb area <preset> while OFF'); return false end
  s.enabled=true; s.reason='armed; waiting for fresh native prompt'; say('ON -- MANUAL WALK ONLY. Stay at keyboard.'); if s.snapshot~=s.generation then request() end
  if s.irongrip and s.ironKnown==nil and not s.ironQuery then s.ironQuery=api.now(); api.send('racial help irongrip') end
  return true
 end
 function self.configure(k,v)
  if s.enabled then say('Configure only while OFF'); return false end
  if type(v)~='string' or v:find('[%c;|]') then say('Rejected control/separator characters'); return false end
  if k=='irongrip' then if v=='on' then v=true elseif v=='off' then v=false else return false end
  elseif k=='command' then
   local _,n=v:gsub('{target}',''); if n~=1 or v:gsub('{target}',''):find('[{}]') or not v:match('^[%a][%w%s{}_-]+$') then say('Use exactly one {target}; simple single command only'); return false end
  elseif k=='class' then if not v:match('^[%a][%a -]*$') then return false end
  elseif k=='area' then if v=='auto' then v=nil elseif not db[v] then say('Unknown preset. See README/catalog'); return false end
  else return false end
  s[k]=v; if k=='area' then s.items={}; s.snapshot=nil; s.target=nil end; return true
 end
 function self.refresh()
  s.items={}; s.target=nil; s.snapshot=nil
  if s.request then s.request.generation=-1 end
  api.send('look'); request()
 end
 function self.disconnect() off('disconnect/reconnect'); s.vitals=nil; s.status=nil; s.affs=nil; s.items={}; s.inventory={}; s.invAt=nil; s.room=nil; s.snapshot=nil; s.request=nil; s.ironKnown=nil; s.ironActive=nil; s.ironQuery=nil; s.ironHeader=nil; s.generation=s.generation+1 end
 function self.cleanup() off('reload/uninstall'); s.destroyed=true; if api.cleanup then api.cleanup() end end
 function self.command(line)
  local cmd,arg=tostring(line):match('^(%S+)%s*(.-)%s*$')
  if cmd=='on' then self.on() elseif cmd=='off' then off('manual OFF')
  elseif cmd=='status' then say((s.enabled and 'ON' or 'OFF')..' | '..s.reason..' | class '..s.class..' | area '..tostring(s.area or s.nativeArea)..' | target '..tostring(s.target))
  elseif cmd=='class' or cmd=='command' or cmd=='area' or cmd=='irongrip' then if self.configure(cmd,arg) then say(cmd..' set; use mb refresh') end
  elseif cmd=='refresh' then self.refresh()
  else say('mb on | off | status | command <verb {target}> | class <class> | area <preset/auto> | irongrip on/off | refresh | help. OFF to configure. Irongrip wanted ON by default; never selects racial slots or relaxes it. No walking/cures/resources. Default Earthcaller quash. Stay present.') end
 end
 return self
end
return M
