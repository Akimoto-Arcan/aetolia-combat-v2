-- Original bounded Combat V2 proposal adapter. No sender, hooks, timers or native queries.
-- Offense remains held without its own protocol. Four reviewed Werewolf defenses
-- use historical schemas plus NEW live witnesses through the sole Buffs owner.
local M = {version='shapeshifter-v4-native-defense-owner'}
local recipes = {
 slash={command='slash',kind='offense',skill='Slashing',group='Ferality',syntax='SLASH <target> [limb]',source='native AB Ferality Slashing'}, 
 pounce={command='pounce',kind='offense',skill='Pounce',source='AC22:4987'},
 rend={command='rend',kind='offense',skill='Rend',source='AC22:4992'},
 hardening={command='harden bones',kind='defense',skill='Hardening',group='Shapeshifting',syntax='HARDEN BONES',source='native AB Shapeshifting Hardening'},
 thickhide={command='thickhide',kind='defense',skill='Thickhide',group='Shapeshifting',syntax='THICKHIDE',source='native AB Shapeshifting Thickhide'},
 bracing={command='brace',kind='defense',skill='Bracing',group='Shapeshifting',syntax='BRACE',source='native AB Shapeshifting Bracing'},
 bodyheat={command='bodyheat',kind='defense',skill='Bodyheat',group='Shapeshifting',syntax='BODYHEAT',proc_cooldown=20,source='native AB Shapeshifting Bodyheat'},
 berserk={command='berserk',kind='defense',skill='Berserk',group='Shapeshifting',syntax='BERSERK',exhaustion_cooldown=30,source='native AB Shapeshifting Berserk'},
 weathering={command='weathering',kind='defense',skill='Weathering',group='Shapeshifting',syntax='WEATHERING',metadata_discrepancy='DEFENCE lists Kaido only; own AB positive',source='native AB Shapeshifting Weathering'}
}
local function copy(v)
 if type(v)~='table' then return v end
 local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function num(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function held(why) return {name='wait',command='',reason='Shapeshifter held: '..why,confidence=0,requires={}} end
local function yes(x) return x==true or x==1 or x=='1' end
local function context(s)
 return type(s)=='table' and s.shapeshifter or nil
end
-- Facts are installed by the existing trusted event owner, never by this module.
-- Native: genuine server-received source. Event-tracked caches retain original at/expires.
local function fresh(c,f)
 return type(f)=='table' and f.observed==true and f.native==true and
 type(f.source)=='string' and f.source~='' and f.session==c.session and
 f.life==c.life and f.epoch==c.epoch and num(f.at) and num(f.expires) and
 num(c.now) and f.at<=c.now and c.now<=f.expires and f.expires>=f.at
end
-- Knowledge/form identity persists through continuous observed scope, not a poll TTL.
-- This path is intentionally NOT used for madness/readiness/channels/resources.
local function observed(c,f)
 if type(f)~='table' or f.tracked~=true then return fresh(c,f) end
 return f.observed==true and f.native==true and type(f.source)=='string' and f.source~='' and
 f.session==c.session and f.life==c.life and f.epoch==c.epoch and num(f.at) and num(c.now) and f.at<=c.now and
 c.observer_valid==true and f.observer==c.observer_version and f.observer_generation==c.observer_generation and
 f.adapter_version==M.version and c.adapter_version==M.version
end
local function fact(c,f,v) return fresh(c,f) and f.value==v end
local function continuous(s,c)
 if c.observer_valid==nil then return true end -- legacy bounded synthetic contracts retain TTL
 if c.observer_valid~=true or not c.class or c.class.tracked~=true then return false end
 local o=s.class_observations;local module=o and o.modules and o.modules.Shapeshifter
 return o and o.class and o.class.value=='Shapeshifter' and s.player.class=='Shapeshifter' and
 o.session==c.session and o.life==c.life and o.epoch==c.epoch and o.version==c.observer_generation and
 o.class.observer==c.observer_version and module and module.version==M.version
end
local function base(s)
 local c=context(s);if not c then return nil,'missing observation context' end
 if not continuous(s,c) then return nil,'observer continuity unavailable/revoked' end
 if c.pending then return nil,'issued physical/resource commitment unresolved' end
 if type(c.session)~='string' or c.session=='' or not num(c.life) or not num(c.epoch) then return nil,'invalid session/life/epoch' end
 if s.connected~=true or not s.player or s.player.dead or not num(s.player.hp) or s.player.hp<=0 then return nil,'disconnected/dead/no vitals' end
 if not observed(c,c.class) or c.class.value~='Shapeshifter' then return nil,'current class missing/wrong/expired' end
 if not observed(c,c.form) or type(c.form.value)~='string' or c.form.value=='' or c.form.value=='human' then return nil,'actual transformed form unknown/expired' end
 if not fact(c,c.body,true) then return nil,'actual body unknown/unusable' end
 if not fact(c,c.safe,true) then return nil,'shared safety/location/curing hold' end
 if c.room==nil or not s.room or c.room~=s.room.id then return nil,'current room evidence mismatch' end
 if not fact(c,c.readiness,true) then return nil,'readiness observations missing/expired' end
 return c
end
local function build(s,key,limb)
 local r=recipes[key];if not r then return held('unknown finite recipe') end
 local c,why=base(s);if not c then return held(why) end
 local cap=(c.capabilities or {})[key]
 if not observed(c,cap) or cap.learned~=true or cap.class~='Shapeshifter' or cap.skill~=r.skill or cap.native_contract~=true then return held('learned native capability/contract missing: '..key) end
 if key=='weathering' then
  local own=(c.learned or {}).weathering
  if not observed(c,own) or own.learned~=true or own.group~='Shapeshifting' or own.skill~='Weathering' or own.syntax~='WEATHERING' or own.form~=c.form.value then return held('own current-form Shapeshifting Weathering AB proof missing; metadata discrepancy retained') end
 end
 if type(cap.forms)~='table' or cap.forms[c.form.value]~=true or (r.form and r.form~=c.form.value) then return held('ability unavailable in observed form') end
 -- Costs, physical requirements and channels must come from current native AB/observations.
 -- An explicitly verified empty costs table means no resource cost, not unknown cost.
 if cap.costs_verified~=true or type(cap.costs)~='table' then return held('unknown resource costs') end
 if cap.requirements_verified~=true or type(cap.requires)~='table' or cap.requires.balance~=true or cap.requires.equilibrium~=true then return held('physical requirements unknown') end
 if type(cap.channels)~='table' or not next(cap.channels) then return held('actual ability channels unknown') end
 if not fact(c,c.equipment,true) or cap.equipment_verified~=true then return held('actual equipment prerequisites unknown') end
 local p=s.player
 if p.prone~=false or p.mounted~=false or type(p.afflictions)~='table' then return held('posture/mount/afflictions unknown or hindered') end
 for _,k in ipairs({'paralysis','asleep','stun','webbed','transfixed'}) do if yes(p.afflictions[k]) then return held('hindered: '..k) end end
 for k,v in pairs(cap.requires) do
  if v~=true and v~=false then return held('malformed physical requirement') end
  if v and not yes(p[k]) then return held('physical channel unavailable: '..k) end
 end
 for k,v in pairs(cap.channels) do if v~=true or not fact(c,(c.channels or {})[k],true) then return held('actual channel unavailable: '..k) end end
 if not fact(c,(c.cooldowns or {})[key],true) then return held('cooldown unknown/not ready: '..key) end
 for k,cost in pairs(cap.costs) do
  local f=(c.resources or {})[k]
  if not num(cost) or cost<0 or not fresh(c,f) or not num(f.value) or f.value<cost then return held('resource missing/insufficient: '..k) end
 end
 local command=r.command;local t=s.target
 if r.kind=='offense' then
  if not t or type(t.name)~='string' or #t.name==0 or #t.name>100 or not t.name:match("^[%w%s'%-]+$") or t.name:find('[;\r\n]') or t.name:find('##',1,true) then return held('invalid target') end
  local f=c.target
  if not fresh(c,f) or f.name~=t.name or f.generation~=s.target_generation or f.room~=c.room or f.present~=true or f.alive~=true or t.dead then return held('target evidence missing/stale') end
  -- Absence of protection proof is not permission to attack.
  for _,k in ipairs({'protected','loyal','player_npc','friendly'}) do if f[k]~=false then return held('protected/loyal/player-NPC/friendly or unknown: '..k) end end
  if f.shield~=true and f.shield~=false or f.rebounding~=false then return held('target defense state unknown/rebounding') end
  if s.mode=='BASH' then
   if f.kind~='npc' or f.hunt_allowed~=true then return held('not a confirmed allowed hunt NPC') end
   if key=='rend' then return held('PvP limb action prohibited in BASH') end
   local madness=c.madness;local policy=c.madness_policy
   if not fresh(c,madness) or not num(madness.value) or madness.value<0 or madness.value>100 then return held('current raw madness unknown') end
   if type(policy)~='table' or policy.approved~=true or policy.session~=c.session or policy.life~=c.life or policy.epoch~=c.epoch or policy.form~=c.form.value or not num(policy.limit) or policy.limit<=0 or policy.limit>=70 or policy.recovery_permission~=true or type(policy.recovery_plan)~='string' or policy.recovery_plan=='' then return held('explicit conservative madness limit/recovery permission required') end
   if madness.value>=policy.limit then return held('madness limit reached; stop and await approved recovery, no automatic REVERT/corpse consumption') end
  elseif s.mode=='ASSIST' or s.mode=='FULL_AUTO' or s.mode=='SHADOW' then
   if f.kind~='player' or f.explicit_player~=true or not fact(c,c.pvp_consent,true) then return held('explicit player-only PvP consent required') end
   if key=='slash' then return held('slash reserved for PvE') end
  else return held('mode does not authorize proposal') end
  if key=='pounce' and f.shield~=true then return held('pounce requires observed shield') end
  if key~='pounce' and f.shield~=false then return held('observed shield requires verified pounce') end
  command=command..' '..t.name
  if key=='rend' then
   if limb~='left_arm' and limb~='right_arm' then return held('unknown/legal limb required') end
   local l=f.limbs and f.limbs[limb]
   if not fresh(c,l) or l.broken~=false or l.mangled~=false or l.parried~=false or l.restoring~=false then return held('limb confirmed state missing/guarded/injured') end
   command=command..(limb=='left_arm' and ' left' or ' right')
  end
 else
  if c.defense_armed~=true then return held('defense maintenance disarmed') end
  local d=(c.defenses or {})[key]
  if not fresh(c,d) or type(d.active)~='boolean' then return held('canonical defense state unknown') end
  if d.active then return held('canonical defense already active') end
  if d.owner~='SHAPESHIFTER' then return held('canonical defense owned elsewhere') end
  if not c.wanted or c.wanted[key]~=true then return held('defense not wanted') end
 end
 return {name='shapeshifter_'..key,recipe=key,kind=r.kind,command=command,reason='bounded '..key..'; native prerequisites observed',confidence=1,
 requires=copy(cap.requires),generation=s.target_generation,session=c.session,life=c.life,epoch=c.epoch,form=c.form.value,
 limb=limb,planned={limb=limb,damage='unknown',afflictions={}},costs=copy(cap.costs),source=r.source}
end
function M.choose(s)
 local c=context(s);local key='slash';local limb
 if c and c.target and c.target.shield==true then key='pounce'
 elseif s.mode~='BASH' then key='rend';limb=c and c.route_limb end
 return build(s,key,limb)
end
-- Reviewed historical activation schemas, NOT native receipts or consent. Costs are
-- single-context measured debits; a discrepant live debit retains the issued hold.
local defense_protocols={
 thickhide={costs={hp=0,mp=0,ep=25,wp=0},channel='balance',capture='01-thickhide-extracted-observation.json'},
 hardening={costs={hp=0,mp=0,ep=50,wp=50},channel='equilibrium',capture='03-hardening-observed.json'},
 bodyheat={costs={hp=0,mp=0,ep=50,wp=50},channel='equilibrium',capture='04-bodyheat-observed.json'},
 weathering={costs={hp=0,mp=0,ep=0,wp=10},capture='05-weathering-observed.json'}
}
-- Two independently measured WHOLE tuples only; never their Cartesian product.
-- Schemas are historical qualification, not current facts, consent or replay.
local reviewed_defense_contexts={
 {maxhp=5170,maxmp=3196,maxep=29400,maxwp=15900},
 {maxhp=5995,maxmp=4360,maxep=29400,maxwp=18900}
}
local recaptures={thickhide='06-thickhide-observed.json',hardening='07-hardening-observed.json',bodyheat='08-bodyheat-observed.json',weathering='09-weathering-observed.json'}
local function scoped_record(c,r)
 return type(r)=='table' and type(r.scope)=='table' and r.scope.session==c.session and r.scope.life==c.life and r.scope.epoch==c.epoch and r.version==c.observer_generation and r.observer==c.observer_version
end
local function dynamic_record(c,r)
 local t=getEpoch and getEpoch() or os.time()
 return scoped_record(c,r) and num(r.at) and t>=r.at and t-r.at<=5
end
local function raw_number(x)
 if type(x)~='string' and type(x)~='number' then return nil end
 local n=tonumber(x);if num(n) and n>=0 then return n end
end
local function native_defense(s,key)
 local schema=defense_protocols[key];local c=context(s)
 if not schema then return held('no reviewed Werewolf activation protocol: '..tostring(key)..'; Bracing remains held') end
 if not c or not continuous(s,c) or c.observer_valid~=true or not observed(c,c.class) or c.class.value~='Shapeshifter' then return held('genuine continuous current Shapeshifter class required') end
 if not observed(c,c.form) or c.form.value~='Werewolf' then return held('complete current framed DEF Werewolf mutation required') end
 local r=recipes[key];local own=(c.learned or {})[key]
 if not observed(c,own) or own.learned~=true or own.group~=r.group or own.skill~=r.skill or own.syntax~=r.syntax or own.form~='Werewolf' then return held('own current-form AB syntax/learning required: '..key) end
 local o=s.class_observations;local v=o.cache and o.cache['Char.Vitals'];local raw=v and v.raw
 if not dynamic_record(c,v) or type(raw)~='table' then return held('fresh complete actual body/readiness/resource Vitals required') end
 local qualified_context
 for index,tuple in ipairs(reviewed_defense_contexts) do
  local matches=true;for field,value in pairs(tuple)do if raw_number(raw[field])~=value then matches=false end end
  if matches then qualified_context=index end
 end
 if not qualified_context then return held('reviewed activation-budget context differs/unknown; only two whole measured tuples qualified; new controlled cost evidence required') end
 if s.connected~=true or s.player.dead or not raw_number(raw.hp) or raw_number(raw.hp)<=0 or s.player.hp<=0 then return held('disconnected/dead/no actual vitals') end
 if not s.room or not s.room.id or s.player.prone~=false or s.player.mounted~=false then return held('room/posture unknown') end
 if raw.wield_left~='empty' or raw.wield_right~='empty' then return held('only observed empty-handed equipment context reviewed') end
 for _,field in ipairs({'balance','equilibrium','ability_bal','left_arm','right_arm'}) do if not yes(raw[field]) then return held('actual channel unavailable: '..field) end end
 for _,field in ipairs({'prone','mounted','fallen','writhing','channeling'}) do if raw[field]~=0 and raw[field]~='0' then return held('actual body state unknown/hindered: '..field) end end
 if type(s.player.afflictions)~='table' then return held('afflictions unknown') end
 for _,field in ipairs({'paralysis','paresis','asleep','stun','webbed','transfixed','impaled','entangled'}) do if yes(s.player.afflictions[field]) then return held('hindered: '..field) end end
 local defs=o.defenses
 if not defs or not defs.complete or not scoped_record(c,{scope=defs.scope,version=c.observer_generation,observer=defs.observer}) then return held('current scoped complete native defense List required') end
 if defs.active[key] then return held('canonical defense already active') end
 if c.pending or o.issued or o.defense_issued then return held('issued commitment unresolved') end
 if c.defense_armed~=true or not c.wanted or c.wanted[key]~=true or not s.buffs or not s.buffs.wanted[key] or not(s.buffs.master or s.buffs.sequence) then return held('existing Buffs consent/maintenance disarmed') end
 for field,cost in pairs(schema.costs) do local n=raw_number(raw[field]);if not n or n<cost then return held('actual resource unknown/insufficient: '..field) end end
 return {name='shapeshifter_'..key,recipe=key,kind='defense',command=r.command,requires={balance=true,equilibrium=true},costs=copy(schema.costs),
  session=c.session,life=c.life,epoch=c.epoch,form='Werewolf',room=s.room.id,vitals_seq=v.seq,learning_seq=own.seq,form_seq=c.form.seq,
  reason='reviewed whole-context Werewolf activation schema; existing Buffs owner only',source=qualified_context==2 and recaptures[key] or schema.capture}
end
function M.defense(s,key)
 return native_defense(s,key)
end
-- Reservation belongs to the existing Buffs pending + shared transport barrier.
-- No second ledger/sender/timer and no debit of mutable cached resource facts.
function M.reserve_defense(s,key,a,p)
 local b=native_defense(s,key)
 if b.command=='' or type(a)~='table' then return false end
 for _,field in ipairs({'command','recipe','session','life','epoch','form','room','vitals_seq','learning_seq','form_seq'}) do if a[field]~=b[field] then return false end end
 local o=s.class_observations;local v=o.cache['Char.Vitals']
 p.shape_reservation={key=key,costs=copy(defense_protocols[key].costs),before=copy(v.raw),vitals_seq=v.seq,scope={session=o.session,life=o.life,epoch=o.epoch},room=s.room.id}
 return true
end
-- Called only by the existing genuine ingress owner; historical schemas never
-- fabricate Add, channel loss, resource debit or a ready native prompt.
function M.observe_defense_settlement(s,source,raw,w)
 local o=s.class_observations;local issued=o and o.defense_issued;local p=issued and issued.pending;local ledger=p and p.shape_reservation
 if not ledger then return false end
 p.shape_ledger_ready=nil
 if ledger.revoked or w.seq<=issued.seq or not w.scope or w.scope.session~=ledger.scope.session or w.scope.life~=ledger.scope.life or w.scope.epoch~=ledger.scope.epoch then return false end
 if s.player.class~='Shapeshifter' or not s.shapeshifter or not observed(s.shapeshifter,s.shapeshifter.form) or s.shapeshifter.form.value~='Werewolf' or s.room.id~=ledger.room then ledger.revoked=true;return false end
 if source=='Char.Defences.Add' and (type(raw)=='table' and raw.name or raw)==ledger.key then ledger.add_seq=w.seq end
 if source=='Char.Defences.Remove' and (type(raw)=='table' and raw.name or raw)==ledger.key then ledger.add_seq=nil end
 if source=='Char.Vitals' and type(raw)=='table' then
  for _,field in ipairs({'maxhp','maxmp','maxep','maxwp'})do
   if raw[field]~=nil and raw_number(raw[field])~=raw_number(ledger.before[field])then ledger.revoked=true;return false end
  end
  local schema=defense_protocols[ledger.key];local channel=schema.channel
  if channel and (raw[channel]=='0' or raw[channel]==0) then ledger.loss_seq=w.seq end
  local matches=true
  for field,cost in pairs(ledger.costs) do local n=raw_number(raw[field]);local before=raw_number(ledger.before[field]);if not n or not before or before-n~=cost then matches=false end end
  if matches then ledger.debit_seq=w.seq end
  ledger.ready_seq=nil
  if yes(raw.balance) and yes(raw.equilibrium) and yes(raw.ability_bal) and (not channel or ledger.loss_seq and w.seq>ledger.loss_seq) then ledger.ready_seq=w.seq;ledger.ready_at=w.at end
 end
 if source=='native.prompt' and ledger.add_seq and ledger.debit_seq and ledger.ready_seq and w.seq>ledger.add_seq and w.seq>ledger.debit_seq and w.seq>ledger.ready_seq and w.at>=ledger.ready_at and w.at-ledger.ready_at<=5 then p.shape_ledger_ready=true end
 return p.shape_ledger_ready==true
end
function M.defense_settled(s,p)
 local l=p and p.shape_reservation;local c=context(s);local o=s.class_observations
 return l and not l.revoked and p.shape_ledger_ready==true and c and continuous(s,c) and observed(c,c.form) and c.form.value=='Werewolf' and s.room.id==l.room and o and o.session==l.scope.session and o.life==l.scope.life and o.epoch==l.scope.epoch
end
function M.status(s)
 local c=context(s);return {version=M.version,class=c and copy(c.class),form=c and copy(c.form),specialization=c and copy(c.specialization),learned=c and copy(c.learned),madness=c and copy(c.madness),madness_policy=c and copy(c.madness_policy),madness_guard='HOLD ONLY; no recovery controller or BASH safe-ready certification',weathering_metadata_discrepancy=recipes.weathering.metadata_discrepancy,pending=c and copy(c.pending),proposal=M.choose(s)}
end
-- Execution fence: existing runner MUST call this immediately before transport,
-- including direct execute and ASSIST approval. Proposal identity is never authority.
function M.validate(s,a)
 if type(a)~='table' or not recipes[a.recipe] then return false,'unknown action' end
 if recipes[a.recipe].kind=='defense' then return false,'Native class defenses use the sole existing Buffs owner, not offense execution' end
 local b=build(s,a.recipe,a.limb)
 if b.command=='' then return false,b.reason end
 for _,k in ipairs({'command','recipe','kind','generation','session','life','epoch','form'}) do if a[k]~=b[k] then return false,'stale/tampered proposal: '..k end end
 -- Never pass caller-supplied requires/costs to the runner: use returned canonical action.
 return true,b
end
-- Call before the single existing sender; sender errors remain uncertain, not unsent.
function M.commit(s,a,id)
 local ok,b=M.validate(s,a);if not ok then return false,b end
 if type(id)~='string' or id=='' then return false,'transport id required' end
 local c=context(s);c.pending={id=id,action=copy(b),at=c.now,session=c.session,life=c.life,epoch=c.epoch,uncertain=true}
 return true,b
end
function M.invalidate(s,reason)
 local c=context(s);if not c then return end
 local issued=s.class_observations and s.class_observations.defense_issued
 if issued and issued.pending and issued.pending.shape_reservation then issued.pending.shape_reservation.revoked=true;issued.pending.shape_ledger_ready=nil end
 c.epoch=(c.epoch or 0)+1;c.revoked=reason;c.defense_armed=false
 -- Preserve physical/resource commitments and never mutate observed target state.
 c.class=nil;c.form=nil;c.body=nil;c.capabilities={};c.readiness=nil;c.safe=nil;c.pvp_consent=nil
 c.learned={};c.madness=nil;c.madness_policy=nil;c.native_frame=nil;c.ab_frame=nil;c.defenses={}
 c.specialization=nil;c.observer_valid=false
end
-- Settlement is supplied by the existing ACK + recovery/resource owner, NOT timeouts.
-- Old-session commitment requires explicitly reconciled current-session proof.
function M.settle(s,w)
 local c=context(s);local p=c and c.pending
 if not p or not fresh(c,w) or w.id~=p.id or w.issued_session~=p.session or
 w.issued_life~=p.life or w.issued_epoch~=p.epoch or w.acknowledged~=true or
 w.physical_reconciled~=true or w.resources_reconciled~=true then return false,'commitment unresolved' end
 c.pending=nil;return true
end
-- Called by the existing genuine ingress owner only. Archives/tests never call this
-- inside connected Mudlet. Partial AB receipts are NOT executable protocol contracts.
function M.observe(s,source,raw,w)
 local c=context(s)
 if not c or not continuous(s,c) or not observed(c,c.class) or c.class.value~='Shapeshifter' or not w or w.scope.session~=c.session or w.scope.life~=c.life or w.scope.epoch~=c.epoch then return false end
 local function receipt(value,origin,tracked)
  return {value=value,observed=true,native=true,source=origin or source,session=c.session,life=c.life,epoch=c.epoch,at=w.at,expires=not tracked and w.at+30 or nil,tracked=tracked,seq=w.seq,observer=w.observer,observer_generation=w.version,adapter_version=M.version}
 end
 c.learned=c.learned or {};c.capabilities=c.capabilities or {};c.defenses=c.defenses or {}
 local function learned(key,syntax)
  local r=recipes[key];local f=receipt(true,nil,true);f.learned=true;f.class='Shapeshifter';f.skill=r.skill;f.group=r.group;f.syntax=syntax
  f.form=observed(c,c.form) and c.form.value or nil
  c.learned[key]=f
  local cap=copy(f);cap.forms={};if f.form=='Werewolf' then cap.forms.Werewolf=true end
  cap.native_contract=false -- costs/channels/physical prerequisites/ACK remain unknown
  c.capabilities[key]=cap
 end
 if source=='Char.Status' then
  -- spec is specialization, never proof that MUTATE is currently active.
  if type(raw.spec)=='string' and raw.spec~='' and not c.specialization then c.specialization=receipt(raw.spec,nil,true) end
 elseif source=='Char.Skills.List' and type(raw)=='table' and type(raw.group)=='string' and type(raw.list)=='table' then
  for _,v in ipairs(raw.list) do if type(v)=='table' and type(v.name)=='string' then
   for key,r in pairs(recipes) do if r.group and r.group:lower()==raw.group:lower() and r.skill:lower()==v.name:lower() then
    if v.inactive==true or v.known==false or v.known==0 or v.known=='No' then c.learned[key]=nil;c.capabilities[key]=nil
    elseif v.known==true or v.known==1 or v.known=='Yes' then
     local f=receipt(true,nil,true);f.learned=true;f.group=r.group;f.skill=r.skill;f.class='Shapeshifter';c.learned[key]=f
     -- List knowledge is not syntax, form allowance or protocol authority.
     c.capabilities[key]=nil
    end
   end end
  end end
 elseif source=='Char.Vitals' and type(raw)=='table' and raw.madness~=nil then
  local n=tonumber(raw.madness)
  c.madness=num(n) and n>=0 and n<=100 and receipt(n) or nil
 elseif source=='Char.Defences.List' and type(raw)=='table' then
  local active={};for _,v in ipairs(raw) do local n=type(v)=='table' and v.name or v;if type(n)=='string' then active[n:lower()]=true end end
  for key,r in pairs(recipes) do if r.kind=='defense' then local f=receipt(nil);f.active=active[key]==true;f.owner='SHAPESHIFTER';c.defenses[key]=f end end
  -- GMCP omits the mutated-form row. Its absence cannot clear or mint form.
 elseif source=='Char.Defences.Add' or source=='Char.Defences.Remove' then
  local key=type(raw)=='table' and raw.name or raw
  if type(key)=='string' and recipes[key] and recipes[key].kind=='defense' then local f=receipt(nil);f.active=source=='Char.Defences.Add';f.owner='SHAPESHIFTER';c.defenses[key]=f end
 elseif source=='native.prompt' then
  c.native_frame=nil;c.ab_frame=nil
 elseif source=='native.text' and type(raw)=='string' then
  if raw=='You have the following active defences:' then c.native_frame={rows={},seen={},at=w.at};c.ab_frame=nil;return true end
  local frame=c.native_frame
  if frame then
   local count=raw:match('^You are protected by (%d+) defences%.$')
   if count then
    c.native_frame=nil
    if tonumber(count)==#frame.rows and w.at-frame.at<=30 then
     local form=false
     local messages={thickhide='Your hide is thickened.',hardening='Your bones have been hardened greatly.',bracing='You are braced against physical attacks.',bodyheat='Your body is well heated internally.',berserk='You are blind with primal rage.',weathering='You are immune to normal weather.'}
     for _,line in ipairs(frame.rows) do if line=='You have mutated into the form of a Werewolf.' then form=true end end
     if form and (not c.specialization or c.specialization.value=='Werewolf') then if not observed(c,c.form) or c.form.value~='Werewolf' then c.form=receipt('Werewolf','native.text:complete DEF',true) end else c.form=nil;c.body=nil;c.learned={};c.capabilities={};c.madness=nil;c.madness_policy=nil;if s.class_observations then s.class_observations.contracts={} end end
     for key,message in pairs(messages) do local f=receipt(nil,'native.text:complete DEF');f.active=frame.seen[message]==true;f.owner='SHAPESHIFTER';c.defenses[key]=f end
    end
    return true
   elseif raw:match('^You ') or raw:match('^Your ') or raw:match('^The eggnog effect is boosting your willpower regeneration %(%d+ minutes%)%.$') then
    if frame.seen[raw] or #frame.rows>=100 then c.native_frame=nil else frame.rows[#frame.rows+1]=raw;frame.seen[raw]=true end
   elseif raw~='' then c.native_frame=nil end
   return true
  end
  local ability,group,known=raw:match('^(%a+) %((%a+)%)%s+Known: (%a+)')
  if ability then
   c.ab_frame=nil
   for key,r in pairs(recipes) do if r.skill==ability and r.group==group then
    -- A direct negative AB revokes the old capability, even if another list omits it.
    c.learned[key]=nil;c.capabilities[key]=nil
    if known=='Yes' then c.ab_frame={key=key,at=w.at} end
   end end
   return true
  end
  local ab=c.ab_frame
  if ab then
   if w.at-ab.at>30 then c.ab_frame=nil;return true end
   local syntax=raw:match('^Syntax: (.+)$')
   if syntax then ab.syntax=syntax;return true end
   if ab.syntax and raw:match('^%-%-%-%-') then
    c.ab_frame=nil
    if recipes[ab.key].syntax==ab.syntax then learned(ab.key,ab.syntax) end
   end
  end
 end
 return true
end
function M.catalog() return copy(recipes) end
return M
