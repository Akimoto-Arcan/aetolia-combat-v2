-- Exact-six dispatcher. No IO, handlers or timers. Current adapter is authority.
local M={classes={'Monk','Wayfarer','Earthcaller','Infiltrator','Archivist','Shapeshifter'}}
local function wait(why)return {name='wait',command='',reason=why,requires={}}end
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
function M.new(modules)
 local r={modules=modules}
 local owns_earth_resource
 function r.supported(class)return modules[class]~=nil end
 function r.sync_transport(s)
  if s.transport_barriers~=nil and type(s.transport_barriers)~='table'then return false,'Existing shared transport barrier map malformed/occupied'end
  s.transport_barriers=s.transport_barriers or {}
  local o=s.class_observations;s.transport_barriers.cv2_class_adapters=o and(o.issued or o.defense_issued)or nil
  return true
 end
 function r.barrier(s,defense_owner)
  if s.transport_barriers~=nil and type(s.transport_barriers)~='table'then return true,'Shared transport barrier map unknown/malformed'end
  for key,value in pairs(s.transport_barriers or {})do
   local own=key=='cv2_earthcaller_resources'and defense_owner and s.buffs and s.buffs.pending and owns_earth_resource and owns_earth_resource(s,s.buffs.pending,value)
   if key~='cv2_class_adapters'and not own and value~=nil and value~=false and(type(value)~='table'or next(value)~=nil)then return true,'Shared transport unresolved: '..tostring(key)end
  end
  local o=s.class_observations
  if o and o.defense_issued and not(defense_owner and s.buffs and s.buffs.pending==o.defense_issued.pending)then return true,'Class defense transport unresolved: '..o.defense_issued.class end
  if o and o.issued then return true,'Class transport unresolved: '..o.issued.class end
  for _,k in ipairs({'wayfarer','infiltrator','shapeshifter','archivist'})do
   local c=s[k];if c and(c.pending or c.issued or c.outstanding)then return true,k..' issued work unresolved'end
  end
  return false
 end
 function r.choose(s)
  local cl=s.player and s.player.class;local a=modules[cl]
  if not a then return wait('Unknown/unsupported exact current class')end
  local observed=s.class_observations
  if observed and observed.class and observed.class.value~=cl then return wait('Current player class contradicts latest genuine Status scope')end
  local held,why=r.barrier(s);if held then return wait(why)end
  if cl~='Monk'then
   local o=s.class_observations
   if not o or not o.class or o.class.value~=cl then return wait('Genuine current-class Status observation required')end
  end
  return a.choose(s)
 end
 function r.validate(s,a)
  if type(a)~='table'then return false,'missing action'end
  local b=r.choose(s)
  if b.command==''or b.command~=a.command or b.name~=a.name then return false,b.reason or 'foreign/stale class action'end
  if a.generation and a.generation~=s.target_generation then return false,'stale target'end
  local cl=s.player.class;local module=modules[cl]
  if cl~='Monk'then local ok,why=module.validate(s,a);if not ok then return false,why end end
  -- Never trust caller-supplied requirements/costs, even for direct approval.
  local allowed={balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true}
  for key,value in pairs(b.requires or {})do if not allowed[key]or type(value)~='boolean'then return false,'Unobserved physical requirement: '..tostring(key)end end
  b.generation=s.target_generation;return true,b
 end
 function r.commit(s,a)
  local ok,b=r.validate(s,a);if not ok then return false,b end
  local cl=s.player.class;if cl=='Monk'then return true,b end
  local o=s.class_observations;if not o or not o.sequence or o.sequence<1 then return false,'native ingress sequence missing'end
  local mirrored,mirror_reason=r.sync_transport(s);if not mirrored then return false,mirror_reason end
  o.transport_serial=(o.transport_serial or 0)+1
  local id=tostring(o.session)..':'..o.life..':'..o.epoch..':'..o.transport_serial
  local module=modules[cl];local success,why=true
  if cl=='Wayfarer'then success,why=module.mark_issued(s,b,id)
  elseif cl=='Infiltrator'then success,why=module.commit(s,b,o.sequence,s.clock)
  elseif cl=='Shapeshifter'then success,why=module.commit(s,b,id)
  elseif cl=='Archivist'then success,why=module.issued(s,b,id)
  elseif cl=='Earthcaller'then module.issued(s,b)end
  if success==false then return false,why end
  o.issued={id=id,class=cl,scope={session=o.session,life=o.life,epoch=o.epoch},seq=o.sequence,at=s.clock,action=copy(b),state='issued/unknown'}
  r.sync_transport(s)
  -- No generic prompt, timeout, stop or reset clears this correlation barrier.
  return true,b
 end
 function r.settle(s,event)
  local o=s.class_observations;local issued=o and o.issued
  if not issued or type(event)~='table'or event.native~=true or event.id~=issued.id or type(event.scope)~='table'or event.scope.session~=issued.scope.session or event.scope.life~=issued.scope.life or event.scope.epoch~=issued.scope.epoch or type(event.seq)~='number'or event.seq<=issued.seq then return false,'Original transport identity/scope and newer genuine event required'end
  local module=modules[issued.class];local ok,why
  if issued.class=='Archivist'then ok,why=module.settle(s.archivist,event,s.clock)
  elseif issued.class=='Wayfarer'then ok,why=module.settle(s,event)
  elseif issued.class=='Shapeshifter'then ok,why=module.settle(s,event)
  else return false,'No certified generic attack ACK protocol; physical settlement is not HIT success'end
  local c=s[issued.class:lower()]
  if ok and not(c.pending or c.issued or c.outstanding)then o.issued=nil;r.sync_transport(s)end
  return ok,why
 end
 -- Reviewed Earthcaller defense schemas. Native AB/activation archives define
 -- syntax/debits; only NEW exact ingress records grant current capability.
 -- No sender/timer, no percent-to-raw conversion, no invented impurity maximum.
 local earth=setmetatable({},{__mode='k'})
 local schemas={
  battlehymn={ability='Battlehymn',group='Apocalyptia',command='DIRGE BATTLEHYMN',resource='fervour',cost=750,eq='2.50'},
  constitution={ability='Constitution',group='Apocalyptia',command='DIRGE CONSTITUTION',resource='fervour',cost=100,eq='2.00'},
  truth={ability='Revelation',group='Apocalyptia',command='DIRGE REVELATION',resource='fervour',cost=100,eq='3.00'},
  heatshield={ability='Heatshield',group='Tectonics',command='TECTONIC HEATSHIELD',resource='impurity',cost=300},
  smothering={ability='Smothering',group='Tectonics',command='TECTONIC SMOTHERING',resource='impurity',cost=30},
  insulation={ability='Insulation',group='Tectonics',command='TECTONIC INSULATION',resource='impurity',cost=20},
  ribcage={ability='Ribcage',group='Subjugation',command='OSSO RIBCAGE',resource='fragments',cost=100,eq='4.00'}
 }
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function integer(v)return finite(v)and v>=0 and v%1==0 end
 local function flag(v)return v==true or v==1 or v=='1'end
 local function scope_id(s)
  local o=s.class_observations
  if not o or not o.class or o.class.value~='Earthcaller'or s.player.class~='Earthcaller'or s.connected~=true or s.player.dead then return nil end
  local a=s.earthcaller;local c=a and a.observer;local api=modules.Earthcaller
  if not c or not api or c.observer~=o.observer_version or c.adapter~=api.version or c.version~=o.version or c.session~=o.session or c.life~=o.life or c.epoch~=o.epoch then return nil end
  return tostring(o.session)..':'..tostring(o.life)..':'..tostring(o.epoch)..':'..tostring(o.version)..':'..tostring(a.epoch)..':'..tostring(c.observer)..':'..tostring(c.adapter)
 end
 local function context(s)
  -- Semantic observer identity survives same-name Status refreshes; actual
  -- observer/adapter discontinuities revoke capability, never issued barriers.
  local id=scope_id(s);local identity=s.class_observations or s;local e=earth[identity]
  if not e or e.scope~=id or e.observations~=s.class_observations or e.adapter~=modules.Earthcaller or e.state~=s.earthcaller then
   if e and e.pending then e.pending.invalidated=true end
   e={scope=id,ab={},learned={},last=0,observations=s.class_observations,adapter=modules.Earthcaller,state=s.earthcaller};earth[identity]=e
  end
  return e
 end
 local function recent(s,record,seconds)
  local o=s.class_observations;local t=type(getEpoch)=='function'and getEpoch()or s.clock
  return record and o and record.scope and record.scope.session==o.session and record.scope.life==o.life and record.scope.epoch==o.epoch
   and record.version==o.version and finite(t)and finite(record.at)and t>=record.at and t-record.at<=(seconds or 5)
 end
 local function current_resource(s,e,key)
  local api=modules.Earthcaller
  if not api or type(api.resource_receipt)~='function'then return nil end
  local x=api.resource_receipt(s,key)
  return x and x.units=='raw'and not x.unavailable and recent(s,x.record)and integer(x.value)and x or nil
 end
 local function dynamic(s,e)
  local v=e.vitals
  if not v or not recent(s,v)or type(v.raw)~='table'then return false end
  for _,k in ipairs({'balance','equilibrium','left_arm','right_arm'})do if not flag(v.raw[k])then return false end end
  for _,k in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do if not flag(s.player[k])then return false end end
  if flag(v.raw.channeling)or flag(v.raw.writhing)or flag(v.raw.prone)or flag(v.raw.fallen)or s.player.prone then return false end
  for _,k in ipairs({'blackout','recklessness','paralysis','paresis','asleep','unconscious','unconsciousness','stun','stunned','webbed','bound','transfixed','impaled','left_arm_broken','right_arm_broken','left_arm_mangled','right_arm_mangled'})do if flag((s.player.afflictions or {})[k])then return false end end
  return finite(tonumber(s.player.hp))and tonumber(s.player.hp)>0
   and tonumber(v.raw.hp)==tonumber(s.player.hp)and tonumber(v.raw.maxhp)==tonumber(s.player.maxhp)
 end
 local function learned(s,key)
  local e=context(s);local z=schemas[key];local a=z and e.ab[key]
  if not e.scope or not a or not a.syntax or not a.cost then return false end
  local o=s.class_observations;local rec=o.learned and o.learned[z.group:lower()]
  if not rec or e.learned[z.group:lower()]~=rec or not rec.scope or rec.scope.session~=o.session or rec.scope.life~=o.life or rec.scope.epoch~=o.epoch or rec.version~=o.version or rec.observer~=o.observer_version then return false end
  for _,x in ipairs(rec.raw.list or {})do if type(x)=='table'and tostring(x.name):lower()==z.ability:lower()and(x.known==true or x.known==1 or x.known=='Yes')and x.inactive~=true then return true end end
  local slot=o.earth_string_lists and o.earth_string_lists[z.group:lower()]
  local proof=slot and slot.proofs[z.ability:lower()]
  if slot and slot.record==rec and slot.epoch==s.earthcaller.epoch and slot.members[z.ability:lower()]and proof and proof.source=='native.text'
   and proof.version==o.version and proof.observer==o.observer_version and proof.scope.session==o.session and proof.scope.life==o.life and proof.scope.epoch==o.epoch then return true end
  return false
 end
 local function contract(s,key)
  local e=context(s);local z=schemas[key]
  if not z or not learned(s,key)then return nil,'current own AB and learned-list proof required'end
  if z.resource=='impurity'then return nil,'raw impurity maximum/headroom unobserved; percentage is not capacity'end
  if not dynamic(s,e)then return nil,'fresh exact readiness required'end
  local q=current_resource(s,e,z.resource)
  if not q or not integer(q.maximum)or q.maximum<=0 or q.value>q.maximum or q.value<z.cost then return nil,'fresh raw resource/max or unspent budget required'end
  if z.resource=='fervour'and e.fervour_max~=65000 then return nil,'current native Fervour maximum AB required'end
  return {schema='earth-defense-native-v1',syntax=z.command,costs_verified=true,channels_verified=true,ledger_verified=true,cost=z.cost,resource=z.resource,before=q.value,maximum=q.maximum,record=q.record,generation=q.generation,scope=e.scope},nil
 end
 local function reserve(s,key,a,p)
  local e=context(s);local x,why=contract(s,key);local z=schemas[key]
  if not x or e.pending or a.command~=z.command or type(p)~='table'then return false,why end
  local o=s.class_observations
  local api=modules.Earthcaller
  local token=api.resource_reserve(s,x.resource,x.cost,key=='ribcage'and 'survival.ribcage'or 'buffs.'..key,x.generation)
  if not token then return false,'shared resource reservation denied'end
  if not api.resource_commit(s,token)then api.resource_release(s,token);return false,'shared resource commit denied'end
  p.earth_reservation={key=key,scope=e.scope,before=x.before,maximum=x.maximum,resource=x.resource,cost=x.cost,seq=o.sequence,at=s.clock,command=z.command,channel='equilibrium',token=token}
  e.pending=p.earth_reservation
  return true
 end
 owns_earth_resource=function(s,p,map)
  local e=context(s);local x=p and p.earth_reservation
  if not x or e.pending~=x or e.scope~=x.scope or x.invalidated or type(map)~='table'then return false end
  local found=false
  for _,token in pairs(map)do if token~=x.token then return false end;found=true end
  return found
 end
 function r.owns_resource_barrier(s,p,map)return owns_earth_resource(s,p,map)end
 function r.earth_contract(s,key)return contract(s,key)end
 local function prompt_after_witnesses(x,prompt)
  if not prompt then return false end
  for _,key in ipairs({'own','add','debit','channel_used','loss','recovery'})do
   if not x[key]or prompt<=x[key]then return false end
  end
  return true
 end
 function r.earth_settled(s,p)
  local x=p and p.earth_reservation
  if not x then return true end
  local e=context(s)
  return e.scope==x.scope and e.pending==x and not x.invalidated and not x.fault and prompt_after_witnesses(x,x.prompt)and dynamic(s,e)
 end
 function r.earth_retire(s,p)
  if not r.earth_settled(s,p)then return false end
  local e=context(s);local x=p.earth_reservation
  if x then
   local barriers=s.transport_barriers;local map=barriers and barriers.cv2_earthcaller_resources
   if not modules.Earthcaller.resource_settle(s,x.token)then return false end
   if type(map)=='table'and next(map)==nil and barriers.cv2_earthcaller_resources==map then barriers.cv2_earthcaller_resources=nil end
   e.pending=nil
  end
  return true
 end
 -- Called ONLY immediately after existing class ingress; the exact cached event
 -- object/sequence is consumed once. AB frames cannot satisfy activation ACKs.
 function r.observe_defense(s,source)
  local e=context(s);local o=s.class_observations;local rec=o and o.cache and o.cache[source]
  if not e.scope or not rec or rec.source~=source or rec.seq~=o.sequence or rec.seq<=e.last or not recent(s,rec)then return false end
  e.last=rec.seq;local raw=rec.raw;local x=e.pending
  if source=='native.text'and type(raw)=='string'then
   local name,group,known=raw:match('^(%a+) %((%a+)%)%s+Known:%s+(%a+)')
   if name then
    e.frame=nil
    if group=='Apocalyptia'and name=='Fervour'then e.fervour_max=nil;if known=='Yes'then e.frame={maximum=true,at=rec.at}end
    else for key,z in pairs(schemas)do if name==z.ability and group==z.group then e.ab[key]=nil;if known=='Yes'then e.frame={key=key,at=rec.at,record=rec};e.ab[key]={record=rec}end end end end
   elseif raw:match('^.+ %([%a ]+%)')then e.frame=nil end
   local f=e.frame
   if f and rec.at-f.at<=8 then
    if f.maximum and raw=='Maximum amount of fervour: 65,000' then e.fervour_max=65000 end
    local z=schemas[f.key];local ab=e.ab[f.key]
    if z and ab then
     if raw=='Syntax: '..z.command or f.key=='ribcage'and raw=='Syntax: OSSO RIBCAGE [target]'then ab.syntax=true end
     local label=z.resource=='fervour'and 'Fervour cost: 'or z.resource=='impurity'and 'Impurity gained: 'or 'Fragment cost: '
     if raw==label..z.cost then ab.cost=true end
    end
   end
   if x and not f and rec.seq>x.seq then
    local z=schemas[x.key]
    if raw=='You use '..z.group..' '..z.ability..'.'then x.own=rec.seq end
    if x.own and z.eq and raw=='Equilibrium Used: '..z.eq..' seconds'then x.channel_used=rec.seq end
    if raw=='You have recovered equilibrium.'and x.loss then x.recovery=rec.seq end
   end
  elseif source=='Char.Skills.List'and type(raw)=='table'and type(raw.group)=='string'then
   e.learned[raw.group:lower()]=rec
  elseif source=='Char.Vitals'and type(raw)=='table'then
   e.vitals=rec
   if x and rec.seq>x.seq then
    if raw.equilibrium=='0'or raw.equilibrium==0 then x.loss=rec.seq;x.recovery=nil
    elseif flag(raw.equilibrium)and x.loss then x.recovery=rec.seq end
   end
  elseif source=='Char.Defences.Add'or source=='Char.Defences.List'then
   if x and rec.seq>x.seq and not e.frame then
    local rows=source=='Char.Defences.Add'and {raw}or raw
    for _,v in ipairs(type(rows)=='table'and rows or {})do local name=type(v)=='table'and v.name or v;if name== (x.key=='ribcage'and 'shielded'or x.key)then x.add=rec.seq end end
   end
  elseif source=='native.prompt'then
   e.frame=nil
   if x and prompt_after_witnesses(x,rec.seq)then x.prompt=rec.seq end
  end
  if x then
   local receipt=modules.Earthcaller.resource_receipt and modules.Earthcaller.resource_receipt(s,x.resource)
   if receipt and not receipt.unavailable and receipt.record and receipt.record.seq>x.seq then
    if receipt.value==x.before-x.cost and receipt.maximum==x.maximum then x.debit=receipt.record.seq
    elseif receipt.value~=x.before then x.fault='unexpected shared raw resource debit'end
   end
   -- Late or replacement witnesses cannot settle against a retained old prompt.
   if x.prompt and not prompt_after_witnesses(x,x.prompt)then x.prompt=nil end
  end
  return true
 end
 function r.ribcage_ready(s)
  local e=context(s);local defs=s.class_observations and s.class_observations.defenses
  if not defs or not defs.complete or defs.active.shielded or(s.player.defences or {}).shielded then return false,'shield already active or complete List missing'end
  -- Native self-Ribcage: 5000 -> 4900 / 5000, EQ 4.00, canonical shielded.
  -- Other collection maxima remain unqualified; no DRAW/RESORPTION here.
  local receipt=current_resource(s,e,'fragments')
  if not receipt or receipt.maximum~=5000 then return false,'qualified 5000 maximum collection required'end
  local x,why=contract(s,'ribcage');return x~=nil,why
 end
 function r.ribcage_ack(s,p)
  local e=context(s);local x=p and p.earth_reservation
  return x and e.pending==x and e.scope==x.scope and not x.invalidated and not x.fault and x.own and x.add
 end
 function r.reserve_ribcage(s,p)
  if not r.ribcage_ready(s)then return false end
  return reserve(s,'ribcage',{command='OSSO RIBCAGE'},p)
 end
 function r.defense(s,key,selecting)
  local cl=s.player.class;local module=modules[cl];if not module then return wait('unsupported current class')end
  local routes=r.defense_routes and r.defense_routes[key];local row=routes and routes[cl]
  if not row then return wait('No current-class producer for canonical '..key)end
  local o=s.class_observations;local defs=o and o.defenses
  if not o or not o.class or o.class.value~=cl or not defs or not defs.complete then return wait('Fresh current-life class and complete Defences.List required')end
  if defs.active[key]then return wait('Defense already active')end
  if cl=='Shapeshifter' then return module.defense(s,key) end
  -- This contract table is deliberately EMPTY in native ingress. AB/catalog is not
  -- runtime protocol/cost/ledger authority. Only separately reviewed observers may
  -- eventually supply it, never the fixture or status display.
  local contract=o.contracts and o.contracts[cl..'.'..key]
  if cl=='Earthcaller'then
   local observed,why=r.earth_contract(s,key)
   if not observed then return wait(why)end
   contract=observed
  end
  if not contract or contract.syntax~=row.command or contract.costs_verified~=true or contract.channels_verified~=true or contract.ledger_verified~=true then
   return wait('Held '..cl..'.'..key..': runtime syntax/cost/channel/shared-ledger contract unobserved')
  end
  local b
  if cl=='Earthcaller'then
   -- Native contract above proves this exact learned ability and raw budget;
   -- never feed percent resources or an invented maximum into the offense adapter.
   b={command=row.command,name='earth_defense_'..key,requires={balance=true,equilibrium=true},class='earthcaller'}
  elseif cl=='Infiltrator'then b=module.defense_plan(s,key,s.clock)
  else b=module.defense(s,key)end
  return b
 end
 function r.reserve_defense(s,key,a,p)
  local cl=s.player.class;local module=modules[cl]
  if cl=='Shapeshifter' then return module.reserve_defense(s,key,a,p) end
  if cl=='Earthcaller'then return reserve(s,key,a,p)end
  local o=s.class_observations;local contract=o and o.contracts and o.contracts[cl..'.'..key]
  if not contract or type(contract.reserve)~='function' then return false end
  return contract.reserve(s,a,p)
 end
 function r.defense_settled(s,p)
  if p.earth_reservation then return r.earth_settled(s,p)end
  if not p.shape_reservation then return true end
  return modules.Shapeshifter.defense_settled(s,p)
 end
 function r.status(s)
  local out={};local o=s.class_observations
  for _,cl in ipairs(M.classes)do
   local a=cl==s.player.class and r.choose(s)or wait('Inactive class; current native class is '..tostring(s.player.class))
   local producers=0;for _,routes in pairs(r.defense_routes or {})do if routes[cl]then producers=producers+1 end end
   local missing={Earthcaller='fervour/impurity mapping; equipped bound/calcified weapon; strict NPC facts; action settlement',Wayfarer='throwing axe/wield/flight/venom state; actual costs/channels; runtime protocol; attributed settlement',Infiltrator='owned active groups/skills; clean wielded whip/dirk; channel and cooldown observations; ordinary Garrote/DSTAB ACK absent',Archivist='number capacity and actual numbers; exact energy budget; codex/channels; Crux/Sublimation/Veil runtime protocol',Shapeshifter='offense/madness recovery unchanged and uncertified; Bracing/Berserk held; four defense schemas require new current native class/framed DEF/own AB/raw dynamics and Buffs-owned settlement; Weathering metadata discrepancy retained'}
   out[#out+1]=cl..': '..(a.command~=''and 'proposal '..a.command or 'HELD '..tostring(a.reason))..'; boundedDefenseProducers='..producers..'; canonicalMetadata='..tostring(r.catalog_counts and r.catalog_counts[cl]or 'existing Monk/shared')
   if missing[cl]then out[#out+1]='  Uncertified: '..missing[cl]end
  end
  out[#out+1]='Collected sequence='..tostring(o and o.sequence or 0)..'; metadata is not learned/active/protocol authority'
  return table.concat(out,'\n')
 end
 return r
end
return M
