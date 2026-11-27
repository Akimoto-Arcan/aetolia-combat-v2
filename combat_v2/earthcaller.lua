-- Earthcaller bounded class adapter. Proposals + enrolled physical receipts;
-- transport remains exclusively in the existing Runner (no sender/queue here).
-- Native AB/DETAILS and solo Quash/Splinter captures are the schema provenance.
-- See HANDOFF.md and evidence SHA256: paired live acceptance is still pending.
local M={version='earthcaller-v6-owned-rewield'}
local function now() return getEpoch and getEpoch() or os.clock() end
local function lower(x)return tostring(x or ''):lower()end
local function finite(x)return type(x)=='number' and x==x and x~=math.huge and x~=-math.huge end
local function copy(t)local r={};for k,v in pairs(t or {})do r[k]=v end;return r end
local function deep(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=deep(x)end;return r end
local reservation_specs=setmetatable({},{__mode='k'})
local reservation_evidence=setmetatable({},{__mode='k'})
local function yes(x)return x==true or x==1 or x=='1'end
local groups={subjugation=true,apocalyptia=true,tectonics=true}
local abilities={splinter='subjugation',quash='subjugation',raze='subjugation',subdue='subjugation',beset='subjugation',deface='subjugation',fragmentation='subjugation',lavacoat='tectonics',heatshield='tectonics',smothering='tectonics',insulation='tectonics',battlehymn='apocalyptia',constitution='apocalyptia',revelation='apocalyptia',nightsight='tectonics'}
function M.state(s)
 if not s.earthcaller then s.earthcaller={epoch=0,skills={},resources={},effects={}}end
 return s.earthcaller
end
function M.invalidate(s,reason)
 -- Scope loss is sticky for issued work; a later matching number in another
 -- observation scope cannot reconstruct an uninterrupted debit witness.
 for _,token in pairs(M.state(s).reservations or {})do
  local evidence=reservation_evidence[token]
  if evidence and not evidence.ambiguity then evidence.ambiguity={reason=reason or 'scope lost',seq=s.native_event_sequence}end
 end
 local e=M.state(s);if e.physical then e.physical.unknown=reason or 'scope revoked' end;e.epoch=e.epoch+1;e.skills={};e.resources={};e.effects={};e.equipment=nil;e.mana=nil;e.status=nil;e.observer=nil;e.native=nil;e.reason=reason
 -- An issued or unknown action belongs to runner/buffs. Never clear it here.
end
-- Invoke ONLY for a genuinely received Char.Status server event (not cached replay).
function M.status(s,class,session)
 local e=M.state(s);class=lower(class)
 if not e.status or e.status.class~=class or e.status.session~=session then M.invalidate(s,'class/session changed');e=M.state(s)end
 e.status={class=class,session=session,epoch=e.epoch}
 return class=='earthcaller'
end
function M.active(s)
 local e=M.state(s);local p=s.player or {};local z=e.status
 return z~=nil and z.class=='earthcaller' and lower(p.class)=='earthcaller' and z.epoch==e.epoch and s.connected==true and not p.dead and (tonumber(p.hp)or 0)>0
end
-- Event witnesses are acquisition contracts, not cryptographic evidence. Parent
-- must mint them at real observers, NEVER from saved/cached status, accessible
-- AB detail, rank inference, fixtures or calls that pretend to receive events.
local function witness(s,w,source)
 local e=M.state(s)
 return M.active(s) and type(w)=='table' and w.source==source and w.epoch==e.epoch and w.session==e.status.session and finite(w.at) and w.at<=now() and now()-w.at<=5
end
function M.skills(s,group,names,w)
 group=lower(group);if not groups[group] or not witness(s,w,'native-skill-list') or type(names)~='table' then return false end
 local found={};for _,v in ipairs(names)do
  local n=type(v)=='table' and v.name or v
  local learned=type(v)~='table' or (v.known==nil or v.known==true or v.known==1 or v.known=='Yes') and v.inactive~=true
  if learned and type(n)=='string' then found[lower(n)]=true end
 end
 M.state(s).skills[group]={known=found,epoch=M.state(s).epoch};return true
end
function M.known(s,ability)
 if not M.active(s) then return false end
 local e=M.state(s);local g=e.skills[abilities[ability]]
 return g~=nil and g.epoch==e.epoch and g.known[ability]==true
end
function M.equipment(s,data,w)
 if not witness(s,w,'native-equipment') or type(data)~='table' then return false end
 -- No CALCIFY/purchases. Only continuously evidenced former loadout is recoverable.
 if not tostring(data.weapon_id or ''):match('^%d+$') or not ({crozier=true,warpick=true})[data.weapon_type] or data.calcified~=true or data.wielded~=true or data.bound_to_self~=true then M.state(s).equipment=nil;return false end
 local e=M.state(s);local d=copy(data);d.epoch=e.epoch;d.at=w.at
 -- Only the enrolled observer can certify continuous coverage. Original time
 -- stays intact; exported-only callers retain the conservative legacy TTL.
 d.observer=e.observer and copy(e.observer) or nil
 e.equipment=d;return true
end
local function equipment(s,shield)
 local e=M.state(s);local d=e.equipment
 local o=s.class_observations;local c=d and d.observer
 local contract=o and o.contracts and o.contracts['Earthcaller.equipment']
 local tracked=c and e.observer and o and contract and contract.continuity_verified==true and contract.semantics_verified==true and contract.observer==c.observer and contract.version==c.version and contract.adapter==M.version and c.version==o.version and c.observer==o.observer_version and c.adapter==M.version and c.session==o.session and c.life==o.life and c.epoch==o.epoch
 return d and d.epoch==e.epoch and finite(d.at) and now()>=d.at and (tracked or now()-d.at<=30) and d.wielded==true and d.calcified==true and d.bound_to_self==true and (not shield or d.shield_wielded==true)
end
function M.resource(s,key,value,maximum,w)
 if not ({fervour=true,impurity=true,fragments=true})[key] or not witness(s,w,'native-resource') or not finite(value) or value<0 or not finite(maximum) or maximum<=0 then return false end
 -- Fragmentation can overflow maximum; do not truncate genuine fragment facts.
 if key~='fragments' and value>maximum then return false end
 M.state(s).resources[key]={value=value,maximum=maximum,at=w.at,epoch=M.state(s).epoch};return true
end
function M.budget(s,key,cost)
 if not M.active(s) then return false end
 local e=M.state(s);local r=e.resources[key]
 if not r or r.epoch~=e.epoch or not finite(r.at) or now()<r.at or now()-r.at>5 then return false end
 if key=='impurity' then
  local limit=(s.config or {}).earthcaller_impurity_limit
  return finite(limit) and limit>=0 and limit<=r.maximum and r.value+cost<=limit
 end
 return r.value>=cost
end
-- Genuine line callback only, outside AB/DEFENCE help/list/documentation frames.
-- Lavacoat is an equipment effect, NOT an invented canonical defense ID.
function M.text(s,line,live,w)
 if live~=true or not witness(s,w,'native-text') or type(line)~='string' then return false end
 local n,max=line:match('^Your swarm contains (%d+) fragments of a maximum (%d+)%.$')
 if n then return M.resource(s,'fragments',tonumber(n),tonumber(max),{source='native-resource',at=w.at,session=w.session,epoch=w.epoch})end
 local d=M.state(s).equipment
 if d and type(d.weapon_label)=='string' and line=='You use Tectonics Lavacoat on '..d.weapon_label..'.' then
  M.state(s).effects.lavacoat={weapon_id=tostring(d.weapon_id),epoch=M.state(s).epoch};return true
 end
 return false
end
local function coated(s)
 local e=M.state(s);local f=e.effects.lavacoat;return f and e.equipment and f.epoch==e.epoch and f.weapon_id==tostring(e.equipment.weapon_id)
end
local function wait(reason)return {name='wait',command='',reason=reason,confidence=0,requires={}}end
local function action(s,name,command,reason,ability,requires,cost)
 return {name='earth_'..name,command=command,reason=reason,confidence=.9,class='earthcaller',earth_epoch=M.state(s).epoch,generation=s.target_generation,ability=ability,requires=requires or {balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true},earth_cost=cost}
end
-- Typed targeting must be certified by existing room/player policy; absence of
-- loyal/protected flags is NOT proof of eligibility. No name-only fallback.
local function target(s)
 local t=s.target or {};local proof=t.earth_evidence
 local continuous=proof and proof.source=='canonical-full-policy' and type(proof.check)=='function' and proof.check(s,proof)==true
 if proof and proof.source=='canonical-full-policy' and not continuous then return nil end
 if t.dead or not proof or proof.generation~=s.target_generation or proof.room~=s.room.id or not finite(proof.at) or now()<proof.at or (not continuous and now()-proof.at>5) then return nil end
 if proof.protected~=false or proof.loyal~=false or proof.eligible~=true then return nil end
 if s.mode=='BASH' then
  if proof.kind~='npc' or proof.player~=false or not tostring(t.name or ''):match('^%d+$') or not s.room.items[tostring(t.name)] then return nil end
 else
  if proof.kind~='player' or proof.player~=true or not tostring(t.name or ''):match('^[A-Za-z]+$') then return nil end
 end
 return tostring(t.name),proof
end
local function fact(s,k)
 local f=(s.target.earth_facts or {})[k]
 if f and f.generation==s.target_generation and finite(f.at) and now()>=f.at and now()-f.at<=5 and finite(f.confidence) and f.confidence>=.9 then return f.value end
 return nil
end
-- A remembered loadout is intent only. Every admission still needs continuous
-- inventory/probe authority, explicit slots and both genuinely functional arms.
local function rewield(s)
 local e=M.state(s);local n=e.native;local o=s.class_observations
 local intent=n and n.loadout
 local aff=s.player.afflictions or {}
 for _,side in ipairs({'left_arm','right_arm'})do
  if aff[side..'_crippled'] or aff[side..'_broken'] or aff[side..'_mangled'] then return nil end
 end
 if s.mode~='BASH' or not intent or not n.inventory or not e.observer or not o
  or not n.arms or not yes(n.arms.left) or not yes(n.arms.right) then return nil end
 local c=e.observer
 if c.version~=o.version or c.observer~=o.observer_version or c.adapter~=M.version
  or c.session~=o.session or c.life~=o.life or c.epoch~=o.epoch then return nil end
 local probe=n.probes[intent.weapon_id];local item=n.items[intent.weapon_id];local shield=n.items[intent.shield_id]
 if not probe or not item or not shield or probe.label~=item.name or probe.bound~=o.character or probe.type~='Magic'
  or item.name~=intent.weapon_label or shield.name~=intent.shield_label then return nil end
 local counts={};for _,it in pairs(n.items)do counts[it.name]=(counts[it.name]or 0)+1 end
 if counts[item.name]~=1 or counts[shield.name]~=1 then return nil end
 for _,side in ipairs({'left','right'})do
  local slot=n.wield[side];local expected=intent[side]
  if not slot or not expected or (slot.token~='empty' and slot.token~=expected.token) then return nil end
 end
 -- Always restore the weapon first; never submit two balance-consuming WIELDs.
 for _,side in ipairs({intent.weapon_side,intent.shield_side})do
  if n.wield[side].token=='empty' then
   local expected=intent[side]
   local a=action(s,'rewield','WIELD '..expected.id..' '..side:upper(),'restore exact previously verified loadout',nil)
   a.wield_side=side;a.wield_token=expected.token;a.wield_label=n.items[expected.id].name
   return a
  end
 end
end
function M.choose(s)
 if not M.active(s) then return wait('fresh current Earthcaller class required')end
 if M.target_check then M.certify_target(s,M.target_check)end
 if s.mode~='BASH' and s.mode~='ASSIST' and s.mode~='FULL_AUTO' and s.mode~='SHADOW' then return wait('offense mode not permitted')end
 local p=s.player;local aff=p.afflictions or {}
 if p.prone or yes(p.mounted) or aff.paralysis or aff.paralysed or aff.entangled or aff.fallen or aff.asleep or aff.disfigured or aff.disfigurement or aff.left_arm_broken or aff.right_arm_broken then return wait('physical readiness unresolved')end
 local name=target(s);if not name then return wait('fresh typed eligible target required')end
 if not equipment(s,true) then return rewield(s) or wait('fresh wielded bound calcified weapon and shield required')end
 -- Observed protection is never ignored; unknown is closed for PvP.
 local shield,rebound=fact(s,'shield'),fact(s,'rebounding')
 if s.target.shield==true then shield=true end;if s.target.rebounding==true then rebound=true end
 if shield==true or rebound==true then
  if M.known(s,'raze') then return action(s,'raze','SHIELD RAZE '..name,'observed protection; native Raze','raze')end
  return wait('protection observed; Raze unlearned')
 end
 if s.mode=='BASH' then
  if not M.known(s,'quash') then return wait('fresh learned Quash required')end
  -- Lavacoat enhances Quash; it is not an activation prerequisite. No automatic
  -- equipment modification or impurity spend in the bounded hunting baseline.
  return action(s,'quash','QUASH '..name,'bounded denizen baseline; no assumed mana/afflictions','quash')
 end
 if shield~=false or rebound~=false then return wait('fresh PvP protection absence required')end
 if fact(s,'mana_percent') and finite(fact(s,'mana_percent')) and fact(s,'mana_percent')>=0 and fact(s,'mana_percent')<45 and M.known(s,'fragmentation') and M.budget(s,'fragments',500) then
  return action(s,'fragment','OSSO FRAGMENT '..name,'observed target mana strictly below 45 percent','fragmentation',nil,{fragments=500})
 end
 if fact(s,'prone')==true and M.known(s,'deface') then return action(s,'deface','SHIELD DEFACE '..name,'observed prone; no invented affliction damage bonus','deface')end
 -- AC2 lock/subdue recipe; explicit observed absence only, never unknown=false.
 local order={'anorexia','hypochondria','lethargy','stupidity','agony','self loathing','justice','recklessness','dementia','paranoia'}
 if M.known(s,'subdue') then
  for _,affliction in ipairs(order)do
   local legal=affliction~='anorexia' or fact(s,'asthma')==true and fact(s,'slickness')==true
   if legal and fact(s,affliction)==false then return action(s,'subdue','SUBDUE '..name..' '..affliction,'AC2 lock recipe; fresh absent '..affliction,'subdue',{equilibrium=true,left_arm_balance=true,right_arm_balance=true})end
  end
 end
 if M.known(s,'beset') and fact(s,'asthma')==false then return action(s,'beset','BESET '..name,'observed asthma absence; no assumption that delivery succeeds','beset')end
 return wait('no evidenced bounded PvP route')
end
-- Call immediately before existing runner IO. Recompute, compare, never send.
function M.validate(s,a)
 if not a or a.class~='earthcaller' or not M.active(s) or a.earth_epoch~=M.state(s).epoch then return false,'Earthcaller scope revoked'end
 local fresh=M.choose(s)
 if fresh.command=='' or fresh.command~=a.command or fresh.name~=a.name or a.generation~=s.target_generation then return false,'Earthcaller proposal changed or stale' end
 for k,v in pairs(fresh.requires or {})do if not a.requires or a.requires[k]~=v then return false,'Earthcaller readiness requirements changed' end end
 for k,v in pairs(a.requires or {})do if (fresh.requires or {})[k]~=v then return false,'Earthcaller readiness requirements changed' end end
 for k,v in pairs(fresh.earth_cost or {})do if not a.earth_cost or a.earth_cost[k]~=v then return false,'Earthcaller resource requirements changed' end end
 for k,v in pairs(a.earth_cost or {})do if (fresh.earth_cost or {})[k]~=v then return false,'Earthcaller resource requirements changed' end end
 return true,'Earthcaller proposal validated'
end
-- Call after runner commits its waiting barrier, immediately BEFORE transport.
function M.issued(s,a)
 if a and a.class=='earthcaller' then for resource in pairs(a.earth_cost or {})do M.state(s).resources[resource]=nil end end
 if not a or (a.name~='earth_quash' and a.name~='earth_rewield') then return end
 local o=s.class_observations;local item=s.room.items[tostring(s.target.name)]
 M.state(s).physical={action=deep(a),seq=o.sequence,epoch=M.state(s).epoch,
  session=o.session,life=o.life,scope_epoch=o.epoch,character=o.character,
  generation=s.target_generation,target=tostring(s.target.name),room=s.room.id,
  label=item and item.name,dispatching=true}
 local t=M.state(s).physical
 if a.name=='earth_rewield' then
  t.rewield={seq=o.sequence,at=now(),channel='balance'}
  local n=M.state(s).native;t.other_side=a.wield_side=='left' and 'right' or 'left'
  t.other_token=n.wield[t.other_side].token
 else t.quash={seq=o.sequence,at=now(),channel='balance'} end
end
-- One existing Runner owns both transports. Resource reservations are independent.
function M.transport_begin(s)
 local t=M.state(s).physical;local o=s.class_observations;local issued=o and o.issued
 if not t or not issued or issued.class~='Earthcaller' or issued.seq~=t.seq or issued.action.command~=t.action.command then return false end
 t.id=issued.id;t.issued=issued;return true
end
function M.transport_result(s,which,ok,result)
 local t=M.state(s).physical;local leg=t and t[which]
 if not leg then return false end
 leg.transport=ok and result==true
 if not leg.transport then t.unknown='transport result not explicitly true' end
 return leg.transport
end
local function physical_scope(s,t)
 local o=s.class_observations
 return M.active(s) and o and t.epoch==M.state(s).epoch and t.session==o.session
  and t.life==o.life and t.scope_epoch==o.epoch and t.character==o.character
  and t.room==s.room.id and t.generation==s.target_generation and t.target==tostring(s.target.name)
end
function M.pair_ready(s)
 -- Optional unissued Splinter intent only; absent/default retains immediate pairing.
 -- Never consult this switch when observing or settling an already-issued leg.
 if (s.config or {}).earthcaller_optional_splinter==false then return false end
 local t=M.state(s).physical;local o=s.class_observations
 -- Additive refill must not mask a fragment transaction or another owner.
 if next(M.state(s).reservations or {}) or o and o.defense_issued then return false end
 if s.transport_barriers~=nil and type(s.transport_barriers)~='table' then return false end
 for key,value in pairs(s.transport_barriers or {})do
  if key~='cv2_class_adapters' and value~=nil and value~=false and (type(value)~='table' or next(value)) then return false end
 end
 for _,key in ipairs({'wayfarer','infiltrator','archivist','shapeshifter'})do
  local other=s[key];if other and(other.pending or other.issued or other.outstanding)then return false end
 end
 local v=M.state(s).mana
 local mana=v and v.value;local maximum=v and v.maximum
 local aff=s.player.afflictions or {}
 return t and not t.unknown and not t.splinter and physical_scope(s,t)
  and s.mode=='BASH' and M.known(s,'splinter') and target(s)~=nil
  and not aff.disfigured and not aff.disfigurement
  and equipment(s,true) and yes(s.player.equilibrium) and mana and finite(mana)
  -- Native DETAILS: 5% maximum mana. Conservative ceiling avoids inventing
  -- the server rounding rule (observed 159 at max3196); no fixed159 at other maxima.
  and finite(maximum) and maximum>0 and now()>=v.at and now()-v.at<=5
  and mana>=math.ceil(maximum*.05) and (tonumber(s.player.mana)or 0)>=math.ceil(maximum*.05)
end
function M.pair_commit(s)
 local t=M.state(s).physical
 if not M.pair_ready(s) then return false end
 t.splinter={seq=s.class_observations.sequence,at=now(),channel='equilibrium'}
 return true
end
function M.physical_stop(s)
 local t=M.state(s).physical;if t then t.unknown='STOP/OFF revokes continuation; issued work retained' end
end
-- Enrolled by observe(), not an exported-only settlement API. Each leg needs its
-- own exact ACK, real postdispatch raw loss->recovery and a strictly later prompt.
local function physical_observe(s,source,raw,record)
 local t=M.state(s).physical;if not t then return end
 local o=s.class_observations;local issued=o and o.issued
 local runtime=M.runtime
 if runtime and runtime.current==s and (runtime.mode~='BASH' or runtime.runner.mode~='BASH' or s.mode~='BASH') then t.unknown='OFF/mode changed';return end
 if not issued or issued~=t.issued or issued.id~=t.id or issued.class~='Earthcaller' or issued.seq~=t.seq
  or issued.action.class~='earthcaller' or issued.action.generation~=t.generation
  or issued.action.command~=t.action.command or issued.action.name~=t.action.name
  or (t.rewield and (issued.action.wield_side~=t.action.wield_side
   or issued.action.wield_label~=t.action.wield_label or issued.action.wield_token~=t.action.wield_token))
  or issued.scope.session~=t.session or issued.scope.life~=t.life or issued.scope.epoch~=t.scope_epoch
  or not physical_scope(s,t) then t.unknown='issued identity/scope/target changed';return end
 t.id=t.id or issued.id;if t.id~=issued.id then t.unknown='issued identity changed';return end
 if record.seq<=t.seq or t.unknown then return end
 if t.rewield then
  local leg=t.rewield;local a=t.action
  if source=='native.text' and type(raw)=='string' then
   local line=raw:gsub(string.char(27)..'%[[%d;]*m',''):match('^%s*(.-)%s*$')
   if line:match('^You start to wield ') then
    if line~='You start to wield '..a.wield_label..' in your '..a.wield_side..' hand.' or leg.ack or record.at-leg.at>8 then t.unknown='foreign/duplicate/late WIELD ACK';return end
    leg.ack=record.seq
   elseif line:match('^You use ') or line:match('^Syntax:') or line:match('^Message:') or line:match('^[%a][%a ]* %([%a ]+%)') then t.unknown='foreign action/documentation during WIELD';return end
  elseif source=='Char.Vitals' and type(raw)=='table' then
   local other=raw['wield_'..t.other_side]
   if other~=nil and other~=t.other_token then t.unknown='foreign opposite WIELD slot';return end
   local slot=raw['wield_'..a.wield_side]
   if slot~=nil then
    if slot==a.wield_token then leg.equipped=record.seq
    elseif slot~='empty' or leg.equipped then t.unknown='conflicting WIELD slot';return end
   end
   local value=raw.balance
   if value==0 or value=='0' or value==false then
    if leg.recovered then t.unknown='foreign second WIELD balance loss';return end
    leg.loss=leg.loss or record.seq
   elseif yes(value) then if leg.loss then leg.recovered=leg.recovered or record.seq end
   elseif value~=nil then t.unknown='malformed WIELD balance';return end
  end
  if source~='native.prompt' then return end
  local slot=M.state(s).native and M.state(s).native.wield[a.wield_side]
  if not leg.equipped or not slot or slot.token~=a.wield_token or record.seq<=leg.equipped then return end
 end
 if source=='native.text' and type(raw)=='string' then
  local line=raw:gsub(string.char(27)..'%[[%d;]*m',''):match('^%s*(.-)%s*$')
  if line:match('^[%a][%a ]* %([%a ]+%)%s+Known:') or line:match('^Syntax:') or line:match('^Message:') then t.unknown='documentation during issue';return end
  if line=='A swarm of bone fragments is at maximum capacity.'then
   local leg=t.splinter
   if not leg or leg.ack or leg.loss or leg.rejected or record.seq<=leg.seq or record.at-leg.at>8 then t.unknown='unowned/late/conflicting capacity rejection';return end
   leg.rejected=record.seq
  end
  if line:match('^You use ') then
   local leg
   if line=='You use Subjugation Quash on '..tostring(t.label)..'.' then leg=t.quash
   elseif line=='You use Subjugation Splinter.' then leg=t.splinter end
   if not leg or leg.ack or leg.rejected or record.seq<=leg.seq or record.at-leg.at>8 then t.unknown='foreign/duplicate/late own action';return end
   leg.ack=record.seq
  end
 elseif source=='Char.Vitals' and type(raw)=='table' then
  for _,key in ipairs(t.rewield and {'rewield'} or {'quash','splinter'})do
   local leg=t[key];local value=leg and raw[leg.channel]
   if leg and record.seq>leg.seq and value~=nil then
    if value==0 or value=='0' or value==false then
     if leg.rejected then t.unknown='channel consumed after explicit no-op';return end
     if leg.recovered then t.unknown='foreign second channel consumption';return end
     leg.loss=leg.loss or record.seq
    elseif yes(value) then
     if leg.loss then leg.recovered=leg.recovered or record.seq end
    else t.unknown='malformed physical channel';return end
   end
  end
 elseif source=='native.prompt' and not t.dispatching then
  if t.unknown then return end
  local complete=true
  for _,key in ipairs(t.rewield and {'rewield'} or {'quash','splinter'})do
   local leg=t[key]
   if leg then
    if key=='splinter'and leg.transport and leg.rejected and not leg.ack and not leg.loss and record.seq>leg.rejected and yes(s.player[leg.channel])then
     leg.state='native-rejected-no-consumption';leg.settled_seq=leg.settled_seq or record.seq
    elseif leg.transport and leg.ack and leg.loss and leg.recovered
     and record.seq>leg.ack and record.seq>leg.recovered and yes(s.player[leg.channel]) then
     leg.state='physical-settled';leg.settled_seq=leg.settled_seq or record.seq
    else complete=false end
   end
  end
  if not complete then return end
  o.issued=nil;M.state(s).physical=nil
  local c=M.runtime
  if c and c.current==s then
   c.class_router.sync_transport(s);c.runner.waiting=false;c.runner.saw_unready=false
   if s.target.dead or t.death_seen or not s.room.items[t.target] then
    -- Physical settlement grants neither a target nor hunting/travel consent.
    -- Events deferred the kill while this issue owned the channels. Return it
    -- to Core's existing killed -> bounded IH -> fresh FULL selector, BEFORE
    -- its held-class gate (a dead target cannot propose an attack). Core and
    -- the enrolled survival/walker wrappers retain all continuation policy.
    if c.mode=='BASH' and c.runner.mode=='BASH' and s.mode=='BASH'
     and s.hunting.active and not s.stop_reason then
     s.stop_reason=(s.target.dead or t.death_seen) and 'target slain'
      or 'target left room; confirmation required'
     -- Retain the deferred event when policy is paused; a later ordinary Core
     -- tick may process it, but settlement cannot bypass current admission.
     if c.policy.allowed(s) then combat_v2_tick() end
    end
    return
   end
   -- Never select a next target. Restore only the SAME generation via the
   -- canonical selector; FULL freshness, pick and live policy still govern.
   if c.mode=='BASH' and c.runner.mode=='BASH' and not s.target.dead and not s.stop_reason
    and c.policy.allowed(s) and not c.class_router.barrier(s) then
    if c.areas.fresh(s) and not s.hunting.area_recovery
     and c.areas.pick(s,s.room.items,t.target)==t.target then
     -- Core-only same-generation verification does not cross the manual
     -- target API, which intentionally revokes WALK. It never restamps FULL.
     if combat_v2_reverify_current_target(t.target)then combat_v2_tick()
     else combat_v2_start_ih('Quash same-target canonical reinspection',true,true)end
    elseif not c.areas.fresh(s) and not s.hunting.area_recovery then
     combat_v2_start_ih('Quash same-target continuation requires fresh FULL',true,true)
    end
   end
  end
 end
end
-- Emergency/continuous hostile powers deliberately absent. No Ashcloud,
-- Endoskeleton, RESORPTION, Seismicity, Spur loops, automatic ENEMY or UNALLY.
M.held={ashfall='requires measured channel/recovery protocol',ashcloud='movement restrictions, willpower exhaustion can kill; no bounded protocol',endoskeleton='entire swarm inert and drawing blocked ten minutes',spur='native cooldown observation required',anointing='one mutually exclusive rune plus verified inks required'}
M.defense_routes={
 battlehymn={key='battlehymn',class='earthcaller',group='apocalyptia',command='DIRGE BATTLEHYMN',cost={fervour=750}},
 constitution={key='constitution',class='earthcaller',group='apocalyptia',command='DIRGE CONSTITUTION',cost={fervour=100}},
 truth={key='truth',class='earthcaller',group='apocalyptia',ability='revelation',command='DIRGE REVELATION',cost={fervour=100}},
 heatshield={key='heatshield',class='earthcaller',group='tectonics',command='TECTONIC HEATSHIELD',cost={impurity=300}},
 smothering={key='smothering',class='earthcaller',group='tectonics',command='TECTONIC SMOTHERING',cost={impurity=30}},
 insulation={key='insulation',class='earthcaller',group='tectonics',command='TECTONIC INSULATION',cost={impurity=20}}
}
function M.defense_ready(s,e)
 if not M.active(s) or not e or e.class~='earthcaller' or not M.known(s,e.ability or e.key) then return false end
 for k,v in pairs(e.cost or {})do if not M.budget(s,k,v)then return false end end
 return true
end
function M.defense_issued(s,e)
 for k in pairs(e.cost or {})do M.state(s).resources[k]=nil end
end
-- Called only by the enrolled existing ingress. No queries, hooks or senders.
-- Item attributes alone never certify wielding or calcification. The receipt is
-- the conjunction of genuine inventory identity, explicit Vitals wield slots,
-- and one contiguous native WEAPONPROBE frame bearing the SAME unique label.
local function native(s)
 local e=M.state(s);e.native=e.native or {items={},probes={},wield={}}
 return e.native
end
local function wield(v)
 if type(v)~='string' then return nil end
 local kind,id=v:match('^(%a+)(%d+)$')
 return id and {kind=kind,id=id,token=v} or {token=v}
end
local function resource_observation(s,key,receipt,record,reason)
 for _,token in pairs(M.state(s).reservations or {})do
  local spec=reservation_specs[token];local evidence=reservation_evidence[token]
  if spec and evidence and spec.state=='issued/unknown' and spec.key==key and record.seq>spec.issued_seq and not evidence.ambiguity then
   if not receipt or receipt.unavailable or not finite(receipt.value) then
    evidence.ambiguity={reason=reason or 'resource evidence lost',record=deep(record)}
   elseif receipt.value==spec.before-spec.cost then
    -- Identical later refreshes do not renew the original debit witness.
    evidence.debit=evidence.debit or deep(receipt)
   elseif receipt.value~=spec.before or evidence.debit then
    evidence.ambiguity={reason='unexpected intervening resource value',record=deep(record)}
   end -- Untouched same-value refresh before any debit is not evidence loss.
  end
 end
end
local function lose_resource(s,key,record,reason)
 local n=native(s);n.raw_resources=n.raw_resources or {};n.raw_resources[key]=nil
 n.resource_serial=(n.resource_serial or 0)+1
 if key=='fragments' then M.state(s).resources.fragments=nil end
 resource_observation(s,key,nil,record,reason)
end
local function raw_resource(s,key,value,maximum,record,unavailable)
 if not unavailable and (not finite(value) or value<0 or value%1~=0 or
  key~='impurity' and (not finite(maximum) or maximum<=0 or maximum%1~=0) or
  key=='fervour' and (maximum~=65000 or value>65000)) then
  lose_resource(s,key,record,'invalid raw value/capacity');return false
 end
 local n=native(s);n.raw_resources=n.raw_resources or {};n.resource_serial=(n.resource_serial or 0)+1
 n.raw_resources[key]={value=value,maximum=maximum,record=record,units='raw',generation=n.resource_serial,epoch=M.state(s).epoch,unavailable=unavailable}
 resource_observation(s,key,n.raw_resources[key],record)
 return true
end
local function inventory_gap(s,record)
 local n=native(s);local e=M.state(s)
 n.items={};n.inventory=nil;n.wield={};n.probes={};n.probe_frame=nil;n.gear_gap=record;n.loadout=nil;n.arms=nil
 if e.physical then e.physical.unknown='inventory coverage lost' end
 e.equipment=nil;e.effects.lavacoat=nil
 local o=s.class_observations;if o and o.contracts then o.contracts['Earthcaller.equipment']=nil end
end
local function refresh_gear(s)
 local e=M.state(s);local n=native(s);local o=s.class_observations
 e.equipment=nil
 if not M.active(s) or not n.inventory or not o or not e.observer then return false end
 local left,right=n.wield.left,n.wield.right
 local weapon,shield
 for _,pair in ipairs({{left,right},{right,left}})do
  local a,b=pair[1],pair[2]
  if a and b and (a.kind=='crozier' or a.kind=='warpick') and b.kind=='shield' then weapon,shield=a,b end
 end
 if not weapon or not shield then return false end
 local item,off=n.items[weapon.id],n.items[shield.id];local probe=n.probes[weapon.id]
 if not item or not off or not probe or probe.label~=item.name or probe.bound~=o.character or probe.type~='Magic' then return false end
 local count=0;for _,it in pairs(n.items)do if it.name==item.name then count=count+1 end end
 if count~=1 or not tostring(off.name):lower():match('shield') then return false end
 local acquired=math.min(probe.record.at,n.inventory.at,weapon.record.at,shield.record.at)
 -- Internal reviewed observer contract: minted only after all actual receipts.
 o.contracts['Earthcaller.equipment']={continuity_verified=true,semantics_verified=true,observer=e.observer.observer,version=e.observer.version,adapter=M.version}
 local d={weapon_id=weapon.id,weapon_type=weapon.kind,weapon_label=item.name,calcified=true,bound_to_self=true,wielded=true,shield_wielded=true,shield_id=shield.id,at=acquired,epoch=e.epoch,observer=copy(e.observer),provenance={probe=probe.record,inventory=n.inventory,left=left.record,right=right.record}}
 e.equipment=d
 n.loadout={weapon_id=weapon.id,shield_id=shield.id,weapon_label=item.name,shield_label=off.name,
  weapon_side=weapon==left and 'left' or 'right',shield_side=shield==left and 'left' or 'right',
  left=copy(left),right=copy(right)}
 if probe.enflamed then e.effects.lavacoat={weapon_id=weapon.id,epoch=e.epoch,record=probe.record} end
 return true
end
function M.observe(s,source,raw,record)
 if record then physical_observe(s,source,raw,record) end
 if not M.active(s) or not record or record.source~=source then return false end
 local n=native(s);local e=M.state(s);local o=s.class_observations
 if source:match('^Char%.Items%.') and (type(raw)~='table' or raw.location~='inv' and raw.location~='room') then
  inventory_gap(s,record);return false
 elseif source=='Char.Vitals' and type(raw)=='table' then
  if raw.mp~=nil then
   local value=tonumber(raw.mp)
   local maximum=e.mana and e.mana.maximum
   if raw.maxmp~=nil then maximum=tonumber(raw.maxmp) end
   e.mana=finite(value) and value>=0 and {value=value,maximum=maximum,at=record.at,seq=record.seq} or nil
  end
  n.arms=n.arms or {}
  for side,key in pairs({left='left_arm',right='right_arm'})do if raw[key]~=nil then n.arms[side]=raw[key] end end
  for side,key in pairs({left='wield_left',right='wield_right'})do
   if raw[key]~=nil then
    local v=wield(raw[key]);if v then v.record=record end;n.wield[side]=v
    local intent=n.loadout
    if intent and (not v or v.token~='empty' and v.token~=intent[side].token) then
     n.loadout=nil;if e.physical and e.physical.rewield then e.physical.unknown='loadout slot intent revoked' end
    end
   end
  end
  if raw.charstats~=nil then
   -- A supplied charstats vector is replacement evidence. Validate before any
   -- write; malformed/duplicate fields must not become last-row-wins grants.
   local frame_ok=type(raw.charstats)=='table';local parsed,seen,bad={},{},{}
   local rows,max,classes=0,0,0
   if frame_ok then
    for k,line in pairs(raw.charstats)do
     if type(k)~='number' or k<1 or k%1~=0 or type(line)~='string' then frame_ok=false
     else rows=rows+1;max=math.max(max,k) end
    end
    if rows~=max then frame_ok=false end
    if frame_ok then
     for _,line in ipairs(raw.charstats)do
      if line:match('^Class:') then classes=classes+1;if line~='Class: Earthcaller' then frame_ok=false end end
      for label,key in pairs({Fervour='fervour',Impurity='impurity'})do
       if line:match('^'..label..':') then
        if seen[key] then bad[key]=true end;seen[key]=true
        local value=line:match('^'..label..': (%d+)$')
        if not value then bad[key]=true else parsed[key]=tonumber(value) end
       end
      end
     end
    end
   end
   if classes~=1 then frame_ok=false end
   for _,key in ipairs({'fervour','impurity'})do
    if frame_ok and not bad[key] and parsed[key]~=nil then raw_resource(s,key,parsed[key],key=='fervour' and 65000 or nil,record)
    else lose_resource(s,key,record,'omitted/malformed/duplicate raw resource replacement')end
   end
  end
  -- raw.fervour/raw.impurity are PERCENTAGES, never AB-cost units.
  refresh_gear(s)
 elseif source:match('^Char%.Items%.') and type(raw)=='table' and raw.location=='inv' then
  if source=='Char.Items.List' then
   n.items={};n.inventory=nil
   if type(raw.items)~='table' then inventory_gap(s,record);return false end
   local size,max=0,0
   for k,it in pairs(raw.items)do
    if type(k)~='number' or k<1 or k%1~=0 or type(it)~='table' then inventory_gap(s,record);return false end
    size=size+1;max=math.max(max,k)
   end
   if size~=max then inventory_gap(s,record);return false end
   local seen={};for _,it in ipairs(raw.items)do
    local id=tostring(it.id or '')
    if not id:match('^%d+$') or seen[id] or type(it.name)~='string' then inventory_gap(s,record);return false end
    seen[id]=true;n.items[id]={id=id,name=it.name,attrib=it.attrib,icon=it.icon}
   end
   n.inventory=record
   for id,p in pairs(n.probes)do if not n.items[id] or n.items[id].name~=p.label then n.probes[id]=nil end end
  else
   local it=raw.item or raw.id;local id=type(it)=='table' and tostring(it.id or '') or tostring(it or '')
   if not id:match('^%d+$') then inventory_gap(s,record);return false end
   if source=='Char.Items.Remove' then n.items[id]=nil;n.probes[id]=nil
   elseif type(it)=='table' and id:match('^%d+$') and type(it.name)=='string' then n.items[id]={id=id,name=it.name,attrib=it.attrib,icon=it.icon};n.probes[id]=nil
   else inventory_gap(s,record);return false end
   -- Do not pretend a delta is a complete baseline or renew baseline time.
  end
  local intent=n.loadout
  if intent then
   local valid=n.items[intent.weapon_id] and n.items[intent.shield_id] and n.probes[intent.weapon_id]
   local counts={};for _,it in pairs(n.items)do counts[it.name]=(counts[it.name]or 0)+1 end
   if not valid or counts[intent.weapon_label]~=1 or counts[intent.shield_label]~=1 then
    n.loadout=nil;if e.physical and e.physical.rewield then e.physical.unknown='loadout inventory/probe continuity lost' end
   end
  end
  n.probe_frame=nil;refresh_gear(s)
 elseif source=='native.text' and type(raw)=='string' then
  local line=raw:gsub(string.char(27)..'%[[%d;]*m',''):match('^%s*(.-)%s*$')
  if line:match('^[%a]+ %([%a ]+%)') or line:match('^Syntax:') or line:match('^Message:') then
   if n.count_frame then lose_resource(s,'fragments',record,'COUNT interrupted by documentation')end
   n.count_frame=nil;n.documentation=true;n.probe_frame=nil;return false
  end
  if n.documentation then return false end
  if line=='There is no bone swarm of your own to answer your call.' then
   raw_resource(s,'fragments',nil,nil,record,true);e.resources.fragments=nil;n.count_frame=nil
  elseif line=='You draw your gaze upon a swarm of bone fragments, noting its status.' then n.count_frame=record
  else
   local value,maximum=line:match('^Your swarm contains (%d+) fragments of a maximum (%d+)%.$')
   if n.count_frame then
    if value and record.seq==n.count_frame.seq+1 and record.at-n.count_frame.at<=5 then raw_resource(s,'fragments',tonumber(value),tonumber(maximum),record)
    else lose_resource(s,'fragments',record,'malformed/incomplete COUNT response')end
   end
   n.count_frame=nil
  end
  if line=='It is a one-handed weapon and can be used to parry.' then n.probe_frame={stage=1,record=record};return true end
  local f=n.probe_frame
  if f and record.seq-f.record.seq<=16 and record.at-f.record.at<=8 then
   if f.stage==1 and line=='You are proficient with this weapon.' then f.stage=2
   elseif f.stage==2 and line=='Class: Small bludgeon  Type: Magic' then f.stage=3;f.type='Magic'
   elseif f.stage==3 and line:match('^Damage: %d+  Penetration: %d+  Speed: %d+$') then f.stage=4
   elseif f.stage==4 and line:match('^(.+) has the following effects upon on it:$') then f.label=line:match('^(.+) has the following effects upon on it:$');f.label_record=record;f.stage=5
   elseif f.stage==5 and line:match('^Bound to ([%a]+)$') then f.bound=line:match('^Bound to ([%a]+)$');f.bound_record=record;f.stage=6
   elseif f.stage==6 and line=='Enflamed' then f.enflamed=true
   elseif f.stage==6 and (line:match('^H:%s*%d') or line:match('^%[HP:') or line:match('^%[B:')) then -- prompt rendering is not another probe row
   else n.probe_frame=nil end
  elseif f then n.probe_frame=nil end
 elseif source=='native.prompt' then
  n.documentation=nil
  if n.count_frame then lose_resource(s,'fragments',record,'COUNT ended without complete response')end
  n.count_frame=nil
  local f=n.probe_frame;n.probe_frame=nil
  if f and f.stage==6 and record.at-f.record.at<=8 and f.bound==o.character then
   local id,count=nil,0
   for k,it in pairs(n.items)do
    if it.name:lower()==f.label:lower() then id=k;count=count+1;f.label=it.name end
   end
   local held=false;for _,v in pairs(n.wield)do if v and v.id==id and (v.kind=='crozier' or v.kind=='warpick')then held=true end end
   if count==1 and held then n.probes[id]=f;refresh_gear(s);return true end
  end
 end
 return false
end
-- Eligibility is derived from the existing Core policy/current FULL on EVERY
-- admission, not from a timer or from absence of arbitrary loyal/player flags.
function M.certify_target(s,check)
 if type(check)~='function' or not M.active(s) or s.mode~='BASH' then return false end
 local q=s.hunting and s.hunting.area_snapshot
 local t=s.target;local id=t and tostring(t.name or '')
 if not q or not check(s) then if t then t.earth_evidence=nil end;return false end
 t.earth_evidence={source='canonical-full-policy',generation=s.target_generation,room=s.room.id,at=q.at,kind='npc',player=false,loyal=false,protected=false,eligible=true,check=check}
 return true
end
-- The existing Runner binding supplies the canonical runtime. No new hooks/IO.
function M.bind_runtime(c,policy)
 if type(c)~='table' or not c.class_router or c.class_router.modules.Earthcaller~=M or type(policy)~='function' or not c.policy or c.policy.attack_allowed~=policy or not c.areas or not c.mobs then return false end
 M.runtime=c
 M.target_check=function(s)
  if combat_v2~=c or c.current~=s or c.class_router.modules.Earthcaller~=M or c.policy.attack_allowed~=policy or s.player.class~='Earthcaller' or s.mode~='BASH' then return false end
  local t,h,q=s.target,s.hunting,s.hunting and s.hunting.area_snapshot
  local id=t and tostring(t.name or '');local item=s.room.items[id]
  if not h or not q or not c.areas.fresh(s) or h.area_recovery or h.verified_generation~=s.target_generation or not item or t.dead or (h.killed_ids or {})[id] or not id:match('^%d+$') then return false end
  if item.attrib~='m' and not(item.attrib=='' and item.icon=='monster') then return false end
  if item.icon and item.icon~='monster' and item.icon~='face-angry-horns' then return false end
  local label=tostring(item.name or ''):lower()
  if label:find('guard',1,true) or label:find('loyal',1,true) or (label:find('%f[%a]mounts?%f[%A]') or label:find('%f[%a]mounted%f[%A]')) or label:find('horse',1,true) or label:find('steed',1,true) or label:find('%f[%a]rocs?%f[%A]') then return false end
  if h.preset or h.defensive_selected then
   if c.areas.pick(s,s.room.items,id)~=id then return false end
  elseif not c.mobs[label] then return false end
  return policy(s)==true
 end
 return true
end
-- Shared API: observed receipts and reservations, never activation permission.
-- Issued reservations survive all scope invalidation and STOP/OFF.
function M.resource_receipt(s,key)
 if not M.active(s) then return nil,'current Earthcaller scope missing'end
 local r=native(s).raw_resources;local v=r and r[key]
 if not v or v.epoch~=M.state(s).epoch then return nil,'no genuine current raw receipt'end
 return deep(v)
end
function M.resource_reserve(s,key,cost,owner,generation)
 local r,why=M.resource_receipt(s,key);if not r then return nil,why end
 if key=='impurity' or r.unavailable or not finite(r.value) or r.value<0 or not finite(r.maximum) or r.maximum<=0 or key=='fervour' and (r.maximum~=65000 or r.value>65000) or not finite(cost) or cost<=0 or type(owner)~='string' or owner=='' or generation~=r.generation then return nil,'resource units/capacity/generation unavailable'end
 if key=='fragments' and (now()<r.record.at or now()-r.record.at>5) then return nil,'fragment count is diagnostic only; dynamic drain coverage unverified'end
 local e=M.state(s);e.reservations=e.reservations or {};local available=r.value
 for _,pending in pairs(e.reservations)do
  local spec=reservation_specs[pending]
  if not spec then return nil,'old/unknown resource reservation retained'end
  if spec.key==key then available=available-spec.cost end
 end
 if available<cost then return nil,'resource already reserved or insufficient'end
 e.reservation_serial=(e.reservation_serial or 0)+1
 local token={id=e.reservation_serial,key=key,cost=cost,owner=owner,generation=generation,epoch=e.epoch,before=r.value,seq=r.record.seq,state='reserved'}
 e.reservations[token.id]=token;reservation_specs[token]=copy(token);return token
end
local function reservation(s,token,state)
 local e=M.state(s);local spec=type(token)=='table' and reservation_specs[token]
 if not spec or spec.state~=state or not e.reservations or e.reservations[spec.id]~=token then return nil end
 for k,v in pairs(spec)do if token[k]~=v then return nil end end
 return spec
end
function M.resource_commit(s,token)
 local e=M.state(s);local spec=reservation(s,token,'reserved');local r=spec and M.resource_receipt(s,spec.key)
 if not spec or not r or r.generation~=spec.generation or spec.epoch~=e.epoch then return false,'reservation stale or altered'end
 if token.key=='fragments' and (now()<r.record.at or now()-r.record.at>5) then return false,'fragment budget expired before transport'end
 for _,pending in pairs(e.reservation_barriers or {})do if pending~=token then return false,'another resource issue remains unknown'end end
 if s.transport_barriers~=nil and type(s.transport_barriers)~='table' then return false,'shared barrier map malformed'end
 s.transport_barriers=s.transport_barriers or {};e.reservation_barriers=e.reservation_barriers or {}
 token.state='issued/unknown';token.issued_seq=(s.class_observations or {}).sequence
 spec.state=token.state;spec.issued_seq=token.issued_seq
 reservation_evidence[token]={}
 e.reservation_barriers[token.id]=token;s.transport_barriers.cv2_earthcaller_resources=e.reservation_barriers;return true
end
function M.resource_release(s,token)
 local e=M.state(s);local spec=reservation(s,token,'reserved')
 if not spec then return false,'issued/unknown or altered reservations cannot be cancelled'end
 e.reservations[token.id]=nil;token.state='cancelled-before-issue';reservation_specs[token]=nil;return true
end
function M.resource_settle(s,token)
 local e=M.state(s);local spec=reservation(s,token,'issued/unknown');local r=spec and M.resource_receipt(s,spec.key)
 local evidence=spec and reservation_evidence[token]
 if evidence and evidence.ambiguity then return false,'issued resource ambiguity/evidence loss retained'end
 if not spec or not evidence or not evidence.debit or not r or r.epoch~=spec.epoch or not finite(r.value) or evidence.debit.record.seq<=spec.issued_seq or r.value~=spec.before-spec.cost then return false,'genuine uninterrupted exact later debit not observed'end
 e.reservations[token.id]=nil;if e.reservation_barriers then e.reservation_barriers[token.id]=nil end
 token.state='debit-observed';token.debit=deep(evidence.debit.record);reservation_specs[token]=nil;reservation_evidence[token]=nil;return true
end
return M
