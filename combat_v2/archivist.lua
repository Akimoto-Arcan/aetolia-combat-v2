-- Archivist bounded planner, Lua 5.1+. No IO, sender, timers, curing or global hooks.
-- Evidence ingestion is a TRUSTED ADAPTER boundary, not a native protocol parser.
-- Source IDs resolve in provenance.json. Historical help/legacy patterns are metadata,
-- never current learned ownership, resource readiness, or native activation ACKs.
local M={version='archivist-offline-v1',class='archivist'}
local function copy(x)
 if type(x)~='table' then return x end
 local t={};for k,v in pairs(x) do t[k]=copy(v) end;return t
end
local function finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function lower(x) return type(x)=='string' and x:lower() or '' end
local function held(why) return {name='wait',command='',reason=why,confidence=0,requires={}} end
local function scoped(a)
 return type(a)=='table' and type(a.session)=='string' and a.session~='' and integer(a.life) and a.life>0 and integer(a.epoch) and a.epoch>0
end
local function same(a,b) return scoped(a) and scoped(b) and a.session==b.session and a.life==b.life and a.epoch==b.epoch end
local numbers={yuef=true,["ef'tig"]=true,rafic=true,jherza=true,yi=true,jhako=true,lgakt=true}
M.resource_schema={
 energy={source='native-prerequisites',baseline_capacity=3,consumed_return_seconds_per=20,
  note='metadata only: no timed regeneration; consumed returns only on fresh native observation; expended remains reserved until observed effect expiry'},
 numbers={source='native-prerequisites',names={'yuef',"ef'tig",'rafic','jherza','yi','jhako','lgakt'},
  capacity={primality=1,duality=2,triunity=3},note='Spheres is hazardous tracking-only; never auto-contemplate, empower or forget'},
 link={source='native-batch2',min_percent=0,max_percent=50},
 protocol={note='Costs, required channels, equipment and cooldown readiness must be current native observations; nil is unknown, not zero'}
}
-- Fourteen class identities; speed belongs to FIRSTAID, not a fifteenth producer.
M.defenses={
 adaptation={group='bioessence',ability='adaptation',source='native-initial',energy=1,energy_kind='expended',tracking_only=true,reason='adventurer corpse/racial adaptation policy'},
 ameliorate={group='bioessence',ability='ameliorate',source='native-batch3',energy=1,energy_kind='expended',tracking_only=true,reason='nearby allies, upkeep and unobserved energy protocol'},
 anchored={group='numerology',ability='fix',source='native-initial',numbers={'rafic'},tracking_only=true,reason='prevents escape; toggle requires explicit manual policy'},
 catabolism={group='bioessence',ability='catabolism',source='native-batch3',tracking_only=true,reason='lowers max health and mana 10%; never an automatic energy producer'},
 conjoin={group='geometrics',ability='conjoin',source='native-identity1',cooldown=20,tracking_only=true,reason='offensive side effect; no untargeted room action'},
 dilation={group='numerology',ability='dilation',source='native-batch2',numbers={'jhako','lgakt'},tracking_only=true,reason='doubles negative as well as positive star effects'},
 ethereal={group='bioessence',ability='ethereal',source='native-batch3',energy=2,energy_kind='consumed',tracking_only=true,reason='short diminishing protection; unobserved energy protocol'},
 linked={group='numerology',ability='link',source='native-batch2',numbers={'yi','jherza','jhako'},tracking_only=true,reason='mana redirection needs explicit percent and survival policy'},
 nexus={group='bioessence',ability='nexus',source='native-batch3',energy=1,energy_kind='expended-on-advance',tracking_only=true,reason='contact/room mutagen hazard and endurance/willpower upkeep'},
 oneness={group='numerology',ability='oneness',source='native-identity1',numbers={'yuef'},tracking_only=true,reason='continuous mana/willpower upkeep not authorized'},
 recognition={group='bioessence',ability='malignant',source='native-identity2',tracking_only=true,reason='DEF masking recognition producer ambiguous; NOT Vision voice recognition'},
 spheres={group='numerology',ability='spheres',source='native-initial',tracking_only=true,reason='committed channel with interruption penalty; willpower drain'},
 sublimation={group='numerology',ability='sublimation',source='native-batch1',numbers={'yuef','rafic','yi'},command='elicit sublimation',effect='psychic resistance'},
 veiled={group='numerology',ability='veil',source='native-batch1',numbers={'rafic','yuef'},command='elicit veil',effect='location concealment lost on movement'}
}
M.offense={crux={group='geometrics',ability='crux',source='ac2:4704',
 command='incite crux',syntax='INCITE CRUX <target>',effect='damage; magnitude/bonus not assumed',
 note='Legacy candidate only; current native AB target modes and full protocol required'}}
M.excluded={speed='FIRSTAID; BIO JOLT never duplicates Speed',voice_recognition='Vision passive owner',
 stimulant='unobserved energy protocol; never recursively accelerate',steroid='unobserved energy protocol',
 infection='mutagen/energy protocol unobserved',unravel='number/kill conditions unobserved',pattern='self-stun hazard',
 knitting='unobserved energy protocol',osmosis='health/mana swap hazard'}
M.event_schema={
 class='Char.Status or native.score; exact current class, scope and native sequence',
 learned='Char.Skills.List; group.ability -> {known=true,active=true}; class scoped',
 protocol='native.class.protocol; finite recipe ID -> syntax, target modes, costs, requirements, equipment requirements, cooldown semantics, activation/reject parser source references',
 resources='native.archivist.resources; explicit numbers/capacity, energy.available/consumed/expended/capacity; no GMCP bio assumption',
 equipment='native.equipment; flags observed from inventory/wielded/probe',
 channels='native.channels; idle boolean; unresolved/unknown channel holds all actions',
 defenses='Char.Defences.List; complete=true, have map; absence only from complete list',
 target='native.target; exact name,generation,room and booleans npc/player/protected/loyal/dead/present/shield/rebounding',
 action='native.action; only action-specific observed parser with dispatch ID, newer seq and scope; metadata is not ACK',
 recovery='native.prompt; genuinely later ready prompt after action observation; shared owner retains pending until then'
}
function M.new(scope)
 return {scope=copy(scope),class=nil,facts={},wanted={},outstanding=nil,last_seq=0}
end
local sources={class={['Char.Status']=true,['native.score']=true},learned={['Char.Skills.List']=true},
 protocol={['native.class.protocol']=true},resources={['native.archivist.resources']=true},equipment={['native.equipment']=true},
 channels={['native.channels']=true},defenses={['Char.Defences.List']=true},target={['native.target']=true}}
local function envelope(b,e,now)
 return type(e)=='table' and same(e.scope,b.scope) and finite(now) and finite(e.at) and e.at<=now
  and now-e.at<=30 and integer(e.seq) and e.seq>0 and e.native==true and type(e.raw_ref)=='string' and #e.raw_ref>0
end
-- Explicit mutation entry points only. No function reads cached guild as authority.
function M.observe(b,kind,e,now)
 if not sources[kind] or not envelope(b,e,now) or not sources[kind][e.source] then return false,'invalid native envelope/source' end
 if e.seq<=(b.floor_seq or 0) then return false,'pre-dispatch evidence cannot re-grant authority' end
 local prior=b.facts[kind]
 if prior and e.seq<=prior.seq then return false,'out-of-order evidence' end
 if kind=='class' then
  local cl=lower(e.value)
  if b.class and b.class~=cl then
   b.scope.epoch=b.scope.epoch+1;b.facts={};b.wanted={};b.class=nil
   return false,'class changed: scope invalidated; re-observe in new epoch'
  end
  b.class=cl
 end
 b.facts[kind]=copy(e);b.last_seq=math.max(b.last_seq,e.seq);return true
end
function M.invalidate(b,scope,reason)
 -- A class/session/death boundary revokes all future authority, NOT physical work.
 b.scope=copy(scope);b.class=nil;b.facts={};b.wanted={};b.last_seq=0;b.floor_seq=0;b.invalidated=reason or 'scope changed'
end
M.classSwitch=M.invalidate
local function fact(b,kind,now)
 local e=b.facts[kind]
 if not envelope(b,e,now) or not sources[kind][e.source] then return nil end
 return e.value
end
local function root(s)
 local b=s.archivist;local now=s.clock
 if not b or not finite(now) then return nil,'Archivist evidence/clock unknown' end
 if not same(b.scope,s.class_scope) then return nil,'scope invalidated' end
 if lower(fact(b,'class',now))~='archivist' or b.class~='archivist' then return nil,'current native class is not Archivist' end
 for _,cl in ipairs({s.player and s.player.class or 'archivist',s.buffs and s.buffs.class or 'archivist'}) do
  if lower(cl)~='archivist' then return nil,'contradictory current class facts' end
 end
 local p=s.player or {};local a=p.afflictions or {}
 if s.connected~=true or p.dead~=false or not finite(p.hp) or p.hp<=0 then return nil,'not connected/alive with current vitals' end
 if p.prone~=false or p.mounted~=false then return nil,'posture/equipment channel unknown or hindered' end
 for _,k in ipairs({'paralysis','paresis','asleep','stun','stunned','webbed','bound','impaled','transfixed','unconsciousness'}) do
  if a[k] then return nil,'hindered: '..k end
 end
 if b.outstanding or s.transport_unknown or s.dispatching or s.transport_barrier or s.runner_waiting or s.buffs and s.buffs.pending then return nil,'issued/unknown work outstanding' end
 if s.mode~='BASH' and s.mode~='FULL_AUTO' and s.mode~='ASSIST' then return nil,'mode not armed' end
 local channel=fact(b,'channels',now)
 if not channel or channel.idle~=true then return nil,'channel unknown/active' end
 return b
end
local function learned(b,group,ability,now)
 local l=fact(b,'learned',now);local e=l and l[group..'.'..ability]
 return type(e)=='table' and e.known==true and e.active==true
end
-- Pure, bounded resource validation. No recursion, resource generation or timer refill.
function M.check_resources(b,need,now)
 local r=fact(b,'resources',now)
 if not r then return false,'number/energy state unknown' end
 local cap=r.number_capacity;local ns=r.numbers
 if not integer(cap) or cap<1 or cap>3 or type(ns)~='table' then return false,'number capacity unknown/out of bounds (Spheres unsupported)' end
 local ability=cap==3 and 'triunity' or cap==2 and 'duality' or 'primality'
 if not learned(b,'numerology',ability,now) then return false,'number capacity lacks current learned prerequisite' end
 local count=0
 for n,v in pairs(ns) do
  if not numbers[n] or type(v)~='boolean' then return false,'invalid number state' end
  if v then count=count+1 end
 end
 if count>cap then return false,'contradictory number capacity' end
 for _,n in ipairs(need.numbers or {}) do if ns[n]~=true then return false,'required number not contemplated: '..n end end
 local e=r.energy
 if type(e)~='table' then return false,'energy unknown' end
 for _,k in ipairs({'available','consumed','expended','capacity'}) do if not integer(e[k]) then return false,'invalid/unknown energy '..k end end
 if e.capacity<1 or e.capacity>4 or e.available+e.consumed+e.expended~=e.capacity then return false,'contradictory energy bounds' end
 if e.capacity~=3 then return false,'nonbaseline energy capacity: Catabolism protocol tracking-only' end
 if not integer(need.energy or 0) or e.available<(need.energy or 0) then return false,'insufficient energy' end
 return true
end
local function target_safe(s,b,protocol)
 local t=s.target or {};local f=fact(b,'target',s.clock)
 if type(t.name)~='string' or #t.name>100 or not t.name:match('^[%w][%w\' %-]*$') or t.name:find('[;\r\n]') then return false,'invalid target token' end
 if not f or f.name~=t.name or f.generation~=s.target_generation or f.room~=s.room_id then return false,'target evidence stale/unknown' end
 if f.present~=true or t.present==false or f.dead~=false or t.dead==true or f.protected~=false or f.loyal~=false or t.protected==true or t.loyal==true then return false,'target absent/dead/protected/loyal/unknown' end
 if f.shield~=false or f.rebounding~=false or t.shield==true or t.rebounding==true then return false,'target shield/rebounding unknown/active' end
 if s.mode=='BASH' then
  if f.npc~=true or f.player~=false or t.player==true or t.npc==false or t.protected==true or t.loyal==true then return false,'PvE strict NPC/player veto' end
  if protocol.pve~=true then return false,'native PvE targeting unobserved' end
 else
  if f.player~=true or f.npc~=false or t.player==false or t.npc==true then return false,'PvP explicit player evidence required' end
  if s.explicit_target~=t.name or protocol.pvp~=true then return false,'PvP explicit consent/native targeting unobserved' end
 end
 return true
end
local function build(s,id,defense)
 local b,why=root(s);if not b then return held(why) end
 local row=defense and M.defenses[id] or M.offense[id]
 if not row then return held('unsupported finite recipe') end
 if row.tracking_only then return held('tracking-only: '..row.reason) end
 if not learned(b,row.group,row.ability,s.clock) then return held('current learned/active ability unverified') end
 local protocols=fact(b,'protocol',s.clock);local q=protocols and protocols[id]
 if not q or q.observed_as_class~='archivist' or q.complete~=true then return held('native action protocol unknown: '..id) end
 local expected=defense and row.command:upper() or row.syntax
 if q.syntax~=expected or q.activation_observed~=true or type(q.activation_ref)~='string' or q.activation_ref=='' or type(q.reject_ref)~='string' or q.reject_ref=='' then return held('native syntax/activation/reject schema unknown') end
 if q.cooldown_known~=true or q.cooldown_ready~=true or not finite(q.cooldown_seconds) or q.cooldown_seconds<0 then return held('cooldown unknown/not ready') end
 if type(q.requires)~='table' or next(q.requires)==nil or type(q.costs)~='table' or type(q.equipment)~='table' then return held('native cost/channel/equipment schema unknown') end
 local p=s.player
 for k,v in pairs(q.requires) do
  if (k~='balance' and k~='equilibrium' and k~='left_arm_balance' and k~='right_arm_balance') or type(v)~='boolean' then return held('unsupported native channel schema') end
  if v and p[k]~=true then return held('required balance unavailable: '..k) end
 end
 for _,k in ipairs({'mana','endurance','willpower','energy'}) do
  local n=q.costs[k]
  if not finite(n) or n<0 or k=='energy' and not integer(n) then return held('native cost unknown/invalid: '..k) end
  if k~='energy' and (not finite(p[k]) or p[k]<n) then return held('insufficient/unknown '..k) end
 end
 -- This executable subset has NO energy producer or spender. A changed native
 -- contract must be reviewed, not silently promoted through a learned cache.
 if q.costs.energy~=0 then return held('energy-dependent route tracking-only') end
 local eq=fact(b,'equipment',s.clock)
 if not eq then return held('equipment unknown') end
 for k,v in pairs(q.equipment) do if v~=true or eq[k]~=true then return held('required equipment unobserved: '..tostring(k)) end end
 local ok,err=M.check_resources(b,{numbers=row.numbers,energy=q.costs.energy},s.clock)
 if not ok then return held(err) end
 if defense then
  local d=fact(b,'defenses',s.clock)
  if not d or d.complete~=true or type(d.have)~='table' then return held('complete current defenses unknown') end
  if d.have[id]==true or p.defences and p.defences[id]==true then return held('already active: '..id) end
  if b.wanted[id]~=true then return held('defense not explicitly wanted') end
 else
  ok,err=target_safe(s,b,q);if not ok then return held(err) end
 end
 return {name='archivist_'..id,recipe=id,command=row.command..(defense and '' or ' '..s.target.name),
  reason='bounded source-indexed '..(defense and 'self defense' or 'single-target damage'),confidence=1,
  requires=copy(q.requires),generation=s.target_generation,scope=copy(b.scope),proof_seq=b.last_seq,
  kind=defense and 'defense' or 'offense',activation_ref=q.activation_ref,reject_ref=q.reject_ref}
end
function M.choose(s) return build(s,'crux',false) end
M.propose=M.choose
function M.defense(s,id) return build(s,id,true) end
function M.validate(s,a)
 if type(a)~='table' then return false,'missing action' end
 local fresh=build(s,a.recipe,a.kind=='defense')
 if fresh.command=='' then return false,fresh.reason end
 local function eq(x,y)
  if type(x)~=type(y) then return false end
  if type(x)~='table' then return x==y end
  for k,v in pairs(x) do if not eq(v,y[k]) then return false end end
  for k in pairs(y) do if x[k]==nil then return false end end
  return true
 end
 if not eq(a,fresh) then return false,'stale/modified proposal' end
 return true
end
function M.issued(s,a,id)
 local ok,why=M.validate(s,a);if not ok then return false,why end
 if type(id)~='string' or id=='' then return false,'dispatch ID required' end
 local b=s.archivist;b.outstanding={id=id,action=copy(a),scope=copy(b.scope),seq=b.last_seq,at=s.clock,state='issued'}
 -- Commit invalidates pre-dispatch budgets/readiness without estimating a debit,
 -- cooldown or activation. Fresh real evidence is required even after recovery.
 b.floor_seq=b.last_seq
 for _,kind in ipairs({'protocol','resources','channels','defenses'}) do b.facts[kind]=nil end
 return true
end
-- These normalized events MUST originate from the shared action-specific parser.
-- No matching AB DEF "Message:" / legacy trigger can call this as a native ACK.
function M.settle(b,e,now)
 local o=b.outstanding
 if not o or type(e)~='table' or not same(e.scope,o.scope) or e.id~=o.id or e.native~=true
  or not integer(e.seq) or e.seq<=o.seq or not finite(now) or not finite(e.at) or e.at<o.at or e.at>now
  or type(e.raw_ref)~='string' or e.raw_ref=='' then return false,'unattributed/stale observation' end
 if e.source=='native.action' and (e.kind=='activation' or e.kind=='reject') then
  local ref=e.kind=='activation' and o.action.activation_ref or o.action.reject_ref
  if e.parser_ref~=ref then return false,'unobserved parser schema' end
  o.state=e.kind;o.observed_seq=e.seq;o.observed_at=e.at;return true
 end
 if e.source=='native.prompt' and e.kind=='recovery' and e.ready==true and o.observed_seq and e.seq>o.observed_seq and e.at>o.observed_at then
  b.outstanding=nil;return true
 end
 return false,'action observation and later ready prompt required'
end
function M.status(s)
 local b,why=root(s);local rows={}
 for k,r in pairs(M.defenses) do rows[k]={tracking_only=r.tracking_only==true,reason=r.reason or 'native number/action protocol required',source=r.source,wanted=b and b.wanted[k]==true or false} end
 return {class=b and 'archivist' or nil,held=why,outstanding=copy(s.archivist and s.archivist.outstanding),defenses=rows}
end
return M
