-- Class-scoped Monk/shared preparations and read-only Archivist defence tracking.
-- No IO/global sender, generic cures, emergency abilities or ENEMY changes.
-- Intent is revocable; an already dispatched action is a physical barrier until
-- confirmed AND followed by a real ready prompt. Exact BAL/EQ non-execution
-- replies for ordinary skills may retire after fresh native channel readiness.
local M={}
local class_groups={monk={'kaido','telepathy','survival','vision','avoidance'},archivist={'geometrics','numerology','bioessence','survival','vision','avoidance'}}
local function class_name(x) return tostring(x or ''):lower() end
function M.supported_class(name) return class_groups[class_name(name)]~=nil end
function M.audit_groups(name)
 local result={};for _,g in ipairs(class_groups[class_name(name)] or {}) do result[#result+1]=g end;return result
end
local function allowed_group(class,group)
 for _,g in ipairs(M.audit_groups(class)) do if g==group then return true end end
 return false
end
local function in_class(b,e)
 return M.supported_class(b.class) and e and (e.tracking_only and e.metadata_classes and e.metadata_classes[b.class] or e.class_routes and e.class_routes[b.class] or e.tattoo or e.class=='shared' or e.class==b.class or allowed_group(b.class,e.group) or e.also_group and allowed_group(b.class,e.also_group))
end
M.catalog={
 {key='vitality',label='Vitality',command='vitality',default=true,requires_full=true,cooldown_loss=180},
 {key='weathering',label='Weathering',command='weathering',default=true},
 {key='toughness',label='Toughness',command='toughness',default=true},
 {key='resistance',label='Resistance',command='resistance',default=true},
 {key='consciousness',label='Consciousness',command='consciousness',default=true},
 {key='constitution',label='Constitution',command='constitution',default=true},
 {key='nightsight',label='Nightsight',command='nightsight',default=true,ids={'night sight'}},
 {key='courage',label='Courage',command='courage',default=true},
 {key='sturdiness',label='Sturdiness',command='stand firm',default=false},
 {key='regeneration',label='Regeneration',command='regeneration on',off='regeneration off',default=false,drain=true},
 {key='projectiles',label='Projectiles',command='projectiles on',off='projectiles off',default=false,drain=true},
 {key='trance',label='Trance',command='kai trance',off='break trance',default=false,drain=true,ids={'kai_trance'}},
 {key='splitting',label='Splitting',command='split mind',off='join mind',default=false,ids={'split_mind','mind_split'}},
 {key='boosting',label='Boosting (legacy confirmation)',command='boost regeneration',default=false,drain=true,depends='regeneration',ids={'boosted_regen','boosted_regeneration'}}
}
-- Only curated, source-verified abilities may be inferred from a learned group.
for _,e in ipairs(M.catalog) do e.group=e.key=='nightsight' and 'vision' or 'kaido' end
local additions={
 {key='immunity',group='kaido',command='immunity',default=true,cooldown_activation=120,ids={'kaido_immunity','kai_immunity'}},
 {key='insight',group='telepathy',command='mind insight on',off='mind insight off'},
 {key='mindcloak',group='telepathy',ability='cloak',command='mind cloak on',off='mind cloak off'},
 {key='telesense',group='telepathy',also_group='vision',command='telesense on',off='telesense off',drain=true},
 {key='metawake',group='survival',command='metawake on',off='metawake off',drain=true},
 {key='clarity',group='survival',command='clarity',antipsychotic_block=true},
 {key='selfishness',group='survival',command='selfishness',off='generosity'},
 {key='vigilance',group='vision',command='vigilance on',off='vigilance off',drain=true},
 {key='deathsight',group='vision',command='deathsight',off='deathsight off'},
 {key='skywatch',group='vision',command='skywatch on',off='skywatch off',drain=true},
 {key='alertness',group='vision',command='alertness on',off='alertness off'},
 {key='hypersight',group='vision',command='hypersight on',off='hypersight off',drain=true},
 {key='thirdeye',group='vision',command='thirdeye'},
 {key='eagleeye',group='vision',command='eagleeye on',off='eagleeye off',drain=true},
 {key='dodgemelee',label='Dodging (all)',group='avoidance',ability='dodging',command='dodge all',ids={'dodge'}},
 {key='divertmelee',label='Diversion (all)',group='avoidance',ability='diversion',command='divert all',ids={'diverting','diversion'}},
 {key='bolstered',label='Bolstering',group='avoidance',ability='bolstering',command='bolster',cooldown_activation=600},
 {key='book',label='Book (BASH only)',group='tattoos',tattoo=true,bash_only=true,command='touch book',ids={'book_tattoo'}},
 {key='voice_recognition',label='Voice Recognition (passive)',ability='recognition',group='vision',passive=true},
 -- Current AB: these five autoactivate on login, but fresh ink needs TOUCH.
 -- A reported ACTIVE tattoo is never an activation budget. Only an explicit
 -- positive Uses left row can authorize the conditional producer below.
 {key='boar',group='tattoos',tattoo=true,login_auto=true,command='touch boar'},
 {key='moon',group='tattoos',tattoo=true,login_auto=true,command='touch moon'},
 {key='moss',group='tattoos',tattoo=true,login_auto=true,command='touch moss'},
 {key='owl',group='tattoos',tattoo=true,login_auto=true,command='touch owl'},
 {key='mountain',group='tattoos',tattoo=true,login_auto=true,command='touch mountain'},
 {key='firefly',group='tattoos',tattoo=true,command='touch firefly'},
 {key='flame',group='tattoos',tattoo=true,command='touch flame'},
 {key='starburst',label='Starburst (consumed death protection)',group='tattoos',tattoo=true,command='touch starburst',cooldown_loss=120},
 {key='cloak',group='tattoos',tattoo=true,command='touch cloak'},
 {key='mindseye',label='Mindseye (one-time sensory protection)',group='tattoos',tattoo=true,default=true,command='touch mindseye',ids={'allsight'}}
}
for _,e in ipairs(additions) do
 e.label=e.label or e.key:sub(1,1):upper()..e.key:sub(2)
 e.default=e.default==true;M.catalog[#M.catalog+1]=e
end
-- Current native DEF LIST CLASS ARCHIVIST: fourteen class rows plus shared speed.
-- Deliberately no commands: AB syntax alone cannot verify energy/number protocol.
M.archivist_catalog={
 {key='adaptation',group='bioessence',ability='adaptation',reason='Class-specific manual: requires a player corpse'},
 {key='ameliorate',group='bioessence',ability='ameliorate',drain=true},
 {key='anchored',group='numerology',ability='fix',reason='Class-specific manual PvP only: Fix prevents movement'},
 {key='catabolism',group='bioessence',ability='catabolism',drain=true,reason='Class-specific manual: lowers maximum health and mana by 10%'},
 {key='conjoin',group='geometrics',ability='conjoin',reason='Class-specific manual PvP: includes offensive psychic damage'},
 {key='dilation',group='numerology',ability='dilation',reason='Class-specific manual: doubles negative as well as positive star effects'},
 {key='ethereal',group='bioessence',ability='ethereal',reason='Missing verified Archivist energy/number state; tracking only; rapidly diminishing temporary protection, not permanent upkeep'},
 {key='linked',group='numerology',ability='link',reason='Missing verified Archivist energy/number state; tracking only; redirects health damage into mana with an explicit percentage policy'},
 {key='nexus',group='bioessence',ability='nexus',drain=true,reason='Class-specific manual: offensive mutagen contact/room policy and endurance/willpower drains'},
 {key='oneness',group='numerology',ability='oneness',drain=true},
 {key='recognition',group='bioessence',ability='malignant',drain=true,reason='Class-specific manual: native Malignant producer metadata is ambiguous; no verified activation; mana/willpower drain'},
 {key='spheres',group='numerology',ability='spheres',drain=true,reason='Class-specific manual: committed channel penalizes interruption and drains willpower'},
 {key='sublimation',group='numerology',ability='sublimation'},
 {key='veiled',group='numerology',ability='veil'}
}
for _,e in ipairs(M.catalog) do
 e.class=(e.group=='kaido' or e.group=='telepathy') and 'monk' or 'shared'
 if e.key=='telesense' then e.class='shared' end
end
for _,e in ipairs(M.archivist_catalog) do
 e.class='archivist';e.tracking_only=true;e.default=false
 e.label=e.key:sub(1,1):upper()..e.key:sub(2)
 e.reason=e.reason or 'Missing verified Archivist energy/number state; tracking only'
 M.catalog[#M.catalog+1]=e
end
-- Retained only for raw sensory observations and committed-action settlement.
-- Blindness/deafness are curable afflictions, never selectable defense goals.
local sensory={blindness='amaurosis',deafness='ototoxin'}
local passive_tattoos={boar=true,moon=true,moss=true,owl=true,mountain=true}
local function now() return getEpoch and getEpoch() or os.clock() end
local function norm(x) return tostring(x or ''):lower():gsub('[%s_%-]','') end
local index,aliases={},{}
function M.bind_classes(router,modules,catalogs,s)
 M.class_router=router;router.defense_routes={};router.catalog_counts={};for cl,rows in pairs(catalogs)do router.catalog_counts[cl]=#rows end
 class_groups.wayfarer={'wayfaring','tenacity','fury','survival','vision','avoidance'}
 class_groups.earthcaller={'subjugation','apocalyptia','tectonics','survival','vision','avoidance'}
 class_groups.infiltrator={'assassination','subterfuge','hypnosis','survival','vision','avoidance'}
 class_groups.shapeshifter={'survival','vision','avoidance'}
 local function add(cl,row)
  local k=row.key;local e=index[k]
  if not e then e={key=k,label=k,class='metadata',default=false,tracking_only=true,reason='Canonical metadata only; no bounded producer'};M.catalog[#M.catalog+1]=e;index[k]=e;aliases[norm(k)]=k end
  if row.id then assert(not e.canonical_id or e.canonical_id==row.id,'Canonical defense ID conflict: '..k);e.canonical_id=row.id end
  e.metadata_classes=e.metadata_classes or {};e.metadata_classes[cl:lower()]=true
  if row.command then
   e.class_routes=e.class_routes or {};e.class_routes[cl:lower()]=true
   router.defense_routes[k]=router.defense_routes[k]or {};router.defense_routes[k][cl]=row
   e.routed_classes=e.routed_classes or {};e.routed_classes[cl:lower()]=true
   if not e.command then e.command=row.command end
   if e.class=='metadata'or e.class==cl:lower()then e.tracking_only=false end
  end
 end
 for cl,rows in pairs(catalogs)do for _,row in ipairs(rows)do add(cl,row)end end
 for _,row in pairs(modules.Earthcaller.defense_routes)do add('Earthcaller',row)end
 for _,cl in ipairs({'Wayfarer','Infiltrator'})do for _,row in ipairs(modules[cl].defense_catalog)do if row.command and not row.tracking_only then add(cl,row)end end end
 for k,row in pairs(modules.Archivist.defenses)do if row.command then local x={};for a,v in pairs(row)do x[a]=v end;x.key=k;add('Archivist',x)end end
 for k,row in pairs(modules.Shapeshifter.catalog())do if row.kind=='defense'then add('Shapeshifter',{key=k,command=row.command})end end
 if s then local b=M.state(s);for _,e in ipairs(M.catalog)do if e.routed_classes and not(e.class=='monk'and s.player.class=='Monk')then b.wanted[e.key]=false;b.cancel[e.key]=nil end end end
end
local function routed(s,e)return M.class_router and e and e.routed_classes and e.routed_classes[class_name(s.player.class)]end
local function class_proposal(s,e,pending)
 if pending and s.buffs and s.buffs.pending==pending then
  local view={};for k,v in pairs(s)do view[k]=v end
  view.buffs={};for k,v in pairs(s.buffs)do if k~='pending'then view.buffs[k]=v end end
  return M.class_router.defense(view,e.key)
 end
 return M.class_router.defense(s,e.key)
end

for _,e in ipairs(M.catalog) do
 index[e.key]=e;aliases[norm(e.key)]=e.key;aliases[norm(e.label)]=e.key
 for _,id in ipairs(e.ids or {}) do aliases[norm(id)]=e.key end
end
-- Native FIRSTAID owns these IDs even when disabled. No commands in this catalog.
M.native_catalog={}
local native_order={'courage','density','fangbarrier','insomnia','levitation','rebounding','waterbreathing','instawake','arcane','harmony','speed','vigor'}
local general_order={'insulation','temperance','venom_resistance','antivenin','daydream','cloak','clarity','deathsight','divertmelee','dodgemelee','divine_speed','hypersight','irongrip','metawake','thirdeye','shielded','vigilance','skywatch','tremorsense','recognition','selfishness','alertness','telesense','bolstered','safeguard','flame','firefly','mindseye','starburst','boar','moon','moss','owl'}
local metadata={}
for _,k in ipairs(native_order) do
 local e={key=k,label=k:sub(1,1):upper()..k:sub(2)}
 M.native_catalog[k]=e;metadata[k]=e;aliases[norm(k)]=k
end
for _,k in ipairs(general_order) do
 metadata[k]=metadata[k] or {key=k,label=k:gsub('_',' '):gsub('^%l',string.upper)};aliases[norm(k)]=k
end
metadata.mountain={key='mountain',label='Mountain'}
general_order[#general_order+1]='mountain'
for _,k in ipairs({'fitness','kai_recursion','numbness','hold_breath','guarding'}) do
 metadata[k]={key=k,label=k:gsub('_',' '),reason=k=='hold_breath' and 'Excluded: blocks all actions and drains health' or k=='numbness' and 'Excluded: deferred damage hazard' or k=='guarding' and 'Manual PvP limb policy; not automated' or 'Current ownership unverified; not automated'}
 general_order[#general_order+1]=k
end
metadata.daydream.reason='CURATIVE MANUAL: optional cosmetic waking dream; effect under-specified; no activation loop'
metadata.daydream.owner='CURATIVE MANUAL'
metadata.insulation.reason='UNAVAILABLE: current producers Illumination Warmth / Tectonics Insulation; no verified usable command'
metadata.temperance.reason='UNAVAILABLE: not a current verified DEF ID'
metadata.venom_resistance.reason='UNAVAILABLE: not a current verified DEF ID; antivenin is tracked separately'
metadata.antivenin.reason='UNAVAILABLE: current DEF ID verified but no supplied producer; no guessed consumption'
-- Promote the existing tracked row: one identity in metadata, index and catalog.
local racial_safeguard=metadata.safeguard
racial_safeguard.class='shared';racial_safeguard.owner='SKILL';racial_safeguard.racial=true
racial_safeguard.group='racial';racial_safeguard.command='MIASMA';racial_safeguard.default=false
racial_safeguard.minimum_mana=300 -- observed own MIASMA loss; no guessed drain/duration
M.catalog[#M.catalog+1]=racial_safeguard;index.safeguard=racial_safeguard
-- Current user-selected racial skill: no race-name guess, resource cost or timer.
local racial_irongrip=metadata.irongrip
racial_irongrip.class='shared';racial_irongrip.owner='SKILL';racial_irongrip.racial=true
racial_irongrip.group='racial';racial_irongrip.command='IRONGRIP';racial_irongrip.default=true
M.catalog[#M.catalog+1]=racial_irongrip;index.irongrip=racial_irongrip
M.curative_catalog={}
local curatives={
 {'courage','Herbalism','pluck','consumed'}, {'daydream','Herbalism','somnium','consumed'},
 {'deathsight','Herbalism','thanatonin','consumed'}, {'fangbarrier','Herbalism','paste','applied'},
 {'insomnia','Herbalism','kawhe','consumed'}, {'instawake','Herbalism','stimulant','consumed'},
 {'rebounding','Herbalism','reishi','smoked'}, {'thirdeye','Herbalism','acuity','consumed'},
 {'waterbreathing','Herbalism','waterbreathing','consumed'}, {'arcane','Apothecary','arcane','elixir'},
 {'density','Apothecary','mass','apply torso'}, {'harmony','Apothecary','harmony','elixir'},
 {'levitation','Apothecary','levitation','elixir'}, {'speed','Apothecary','speed','elixir'}, {'vigor','Apothecary','vigor','elixir'}
}
for _,c in ipairs(curatives) do
 M.curative_catalog[#M.curative_catalog+1]={key=c[1],kind='official_defence',source=c[2],producer=c[3],delivery=c[4],class='shared',owner=M.native_catalog[c[1]] and 'FIRSTAID' or c[1]=='daydream' and 'CURATIVE MANUAL' or 'SKILL'}
end
aliases.blind='blindness';aliases.deaf='deafness'
aliases.blindness='blindness';aliases.deafness='deafness'
local function key(x)
 if type(x)=='table' then x=x.name or x.id or x.key end
 return aliases[norm(x)]
end
local function observed_key(x)
 if type(x)=='table' then x=x.name or x.id or x.key end
 if type(x)~='string' then return nil end
 return key(x) or (x:match('^[%a][%w_ %-]*$') and x:lower():gsub('[ %-]+','_'))
end
local function yes(x) return x==true or tonumber(x)==1 end
local function ready(s)
 local p=s.player or {};local a=p.afflictions or {}
 if not (yes(p.balance) and yes(p.equilibrium)) then return false end
 if (class_name(p.class)=='monk' or not M.supported_class(p.class)) and not(yes(p.left_arm_balance)and yes(p.right_arm_balance))then return false end
 if yes(p.prone) then return false end
 for _,k in ipairs({'prone','fallen','paralysis','paresis','asleep','unconsciousness','unconscious','stun','stunned','frozen','webbed','bound','transfixed','impaled','impalement','entangled','roped','left_arm_crippled','right_arm_crippled','left_arm_broken','right_arm_broken','left_arm_mangled','right_arm_mangled'}) do
  if yes(a[k]) then return false end
 end
 return true
end
local function connected(s)
 local p=s.player or {}
 if not yes(s.connected) or yes(p.dead) or (tonumber(p.hp) or 0)<=0 then return false end
 if getConnectionInfo then local ok,_,_,tcp=pcall(getConnectionInfo);return ok and tcp==true end
 return true
end
function M.state(s)
 if not s.buffs then
  local wanted={};for _,e in ipairs(M.catalog) do wanted[e.key]=e.default end
  s.buffs={master=false,sequence=false,wanted=wanted,have={},known={},known_ready=false,
   defs_known=false,cancel={},cooldown={},retry={},prompt=0,status='disarmed'}
 end
 local b=s.buffs
 -- Revoke obsolete saved intent without clearing a committed pending barrier.
 for k in pairs(sensory) do if not index[k] then
  b.wanted[k]=false
  if b.sensory_optin then b.sensory_optin[k]=nil end
  if b.todo then b.todo[k]=nil end
  if b.cancel then b.cancel[k]=nil end
 end end
 if b.class_schema~='monk-archivist-v1' then
  b.class_schema='monk-archivist-v1';b.wanted.recognition=false;b.wanted.voice_recognition=false
  for _,e in ipairs(M.archivist_catalog) do b.wanted[e.key]=false end
 end
 b.observed=b.observed or {};b.native_priorities=b.native_priorities or {};b.native_last_active=b.native_last_active or {}
 b.groups=b.groups or {};b.tattoos=b.tattoos or {};b.vitals_flags=b.vitals_flags or {};b.flag_sources=b.flag_sources or {}
 -- Canonicalize old status-only aliases in place; never mint ink or capability.
 if b.have.book_tattoo~=nil then
  if b.have.book==nil then b.have.book=b.have.book_tattoo end
  b.have.book_tattoo=nil
 end
 if b.observed.book_tattoo~=nil then
  if b.observed.book==nil then b.observed.book=b.observed.book_tattoo end
  b.observed.book_tattoo=nil
 end
 for _,e in ipairs(M.catalog) do if b.wanted[e.key]==nil then b.wanted[e.key]=e.default end end
 -- Corrected native ownership needs a new complete readback, never old ACKs.
 if b.native_schema~='verified12' then
  b.native_schema='verified12';b.native_priorities={};b.native_listing=nil;b.native_full_required=true
  b.native_version=(b.native_version or 0)+1
 end
 return b
end
function M.native_priority(s,k)
 if not M.native_catalog[k] then return nil end
 local b=M.state(s)
 if b.native_full_required or b.native_pending and b.native_pending[k] then return nil end
 return b.native_priorities[k]
end
-- Requested values are not proof. Fence any listing begun before this write.
function M.native_request(s,k,pri)
 if not M.native_catalog[k] or type(pri)~='number' or pri%1~=0 or pri<1 or pri>26 or M.native_priority(s,k)==nil then return false end
 local b=M.state(s);b.native_version=(b.native_version or 0)+1
 b.native_pending=b.native_pending or {};b.native_pending[k]=pri
 return true
end
function M.native_enable_priority(s,k)
 if not M.native_catalog[k] then return nil end
 return M.state(s).native_last_active[k] or 8
end
function M.rows(s)
 local b=M.state(s);local rows,seen,positive={},{},{}
 for id,v in pairs((s.player or {}).defences or {}) do
  local k=observed_key(id);if k and yes(v) then positive[k]=true end
 end
 local function add(k,e)
  if sensory[k] and not index[k] then return end
  if seen[k] then return end;seen[k]=true
  local active
  if b.have[k] or b.observed[k] or positive[k] then active=true elseif b.defs_known or (passive_tattoos[k] and b.observed[k]==false) or b.vitals_flags[k]==false then active=false end
  local native=M.native_catalog[k];local class=index[k] and not native
  local available,reason=M.availability(s,k)
  local tattoo=b.tattoos[k]
  if tattoo and tattoo.active then active=true end
  if e and e.passive and in_class(b,e) and b.known[k] then active=true end
  local pri=M.native_priority(s,k);local wanted
  if native then if pri then wanted=pri<26 end elseif class then wanted=b.wanted[k] end
  local routed_class=e and e.routed_classes and e.routed_classes[b.class]and b.class
  rows[#rows+1]={key=k,label=e and e.label or k,active=active,wanted=wanted,canonical_id=e and e.canonical_id,producer=routed_class,
   owner=e and e.curative and 'CURATIVE' or native and 'FIRSTAID' or e and e.tattoo and 'TATTOO' or routed_class and 'BUFFS' or e and e.owner or class and (e.class=='archivist' and 'ARCHIVIST' or e.class=='monk' and 'MONK' or 'SKILL') or tattoo and 'TATTOO' or 'UNAVAILABLE',
   control=native and 'native' or class and not e.passive and not e.tracking_only and 'class' or 'observed',priority=pri,drain=e and e.drain==true or false,
   available=available,availability=reason,group=e and e.group,passive=e and e.passive or e and e.login_auto and tattoo and tattoo.active,
   required=k=='mindseye',class=e and e.class or 'shared',relevant=not class or in_class(b,e),tracking_only=e and e.tracking_only or k=='daydream',
   off=e and e.off,requires_full=e and e.requires_full,cooldown_loss=e and e.cooldown_loss,cooldown_activation=e and e.cooldown_activation}
 end
 for _,e in ipairs(M.catalog) do add(e.key,e) end
 for _,k in ipairs(native_order) do add(k,metadata[k]) end
 for _,k in ipairs(general_order) do add(k,metadata[k]) end
 local extra={}
 for k in pairs(positive) do extra[k]=true end
 for k in pairs(b.observed) do extra[k]=true end
 local sorted={};for k in pairs(extra) do sorted[#sorted+1]=k end;table.sort(sorted)
 for _,k in ipairs(sorted) do add(k,metadata[k]) end
 return rows
end
function M.stop(s,reason)
 local b=M.state(s);b.master=false;b.sequence=false;b.todo=nil;b.cancel={};b.query=nil
 if b.racial_stream and b.racial_stream.kind=='irongrip' then b.racial_stream.revoked=true end
 b.status=reason or 'disarmed' -- Never erase committed pending, fault, or runner recovery.
 return true,b.status
end
local function fault(b,why)
 b.fault=why;b.master=false;b.sequence=false;b.todo=nil;b.status=why
end
function M.reset(s)
 local b=M.state(s);M.stop(s,'reviewed reset; disarmed');b.pending=nil;b.fault=nil;b.query=nil
 b.retry={};b.listing=nil;b.ability_listing=nil
 return true,b.status
end
function M.set_class(s,name)
 local b=M.state(s);local class=norm(name)
 if class~=b.class then
  M.stop(s,'class changed; disarmed');b.class=class;b.have={};b.defs_known=false;b.defs_at=nil
  if M.class_router and class~='monk'then for _,e in ipairs(M.catalog)do if e.routed_classes and e.routed_classes[class]then b.wanted[e.key]=false;b.cancel[e.key]=nil end end end
  M.invalidate(s);b.listing=nil;b.ability_listing=nil
  if b.pending then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false end
 end
 if not M.supported_class(class) then M.stop(s,'Supported class required (Monk/Archivist)') end
 return M.supported_class(class)
end
local function each_name(payload,fn)
 if type(payload)=='string' then fn(payload);return end
 if type(payload)~='table' then return end
 if payload.name or payload.id or payload.key then fn(payload);return end
 local list=payload.list or payload.skills or payload.defences or payload
 if list~=payload then each_name(list,fn);return end
 for k,v in pairs(list) do
  if type(k)=='string' and (v==true or v==1) then fn(k)
  elseif type(v)=='table' or type(v)=='string' then fn(v) end
 end
end
-- Bind permission to the genuine observer identity, character and scope. A
-- shallow action-state view is fine; a replacement observer/session is not.
local function irongrip_binding(s)
 local o=s.class_observations;local p=s.player or {}
 local name=o and o.character or p.name
 local session=o and o.session or s.session_id
 local life=o and o.life or s.life_generation
 local epoch=o and o.epoch or s.class_generation
 if type(name)~='string' or name=='' or session==nil or life==nil or epoch==nil then return nil end
 return {owner=o or s,character=name,session=session,life=life,epoch=epoch,version=o and o.version}
end
local function same_irongrip(a,b)
 return a and b and a.owner==b.owner and a.character==b.character and a.session==b.session and a.life==b.life and a.epoch==b.epoch and a.version==b.version
end
local function same_irongrip_transport(a,b)
 return a and b and a.owner==b.owner and a.character==b.character and a.session==b.session and a.life==b.life
end
function M.race_status(s,race)
 local b=M.state(s);race=type(race)=='string' and race:lower() or ''
 local prior=b.racial_status
 if not prior or prior.race~=race then
  b.racial_epoch=(b.racial_epoch or 0)+1;b.racial_proof=nil;b.racial_listing=nil
  if b.racial_stream then b.racial_stream.revoked=true end
  if b.pending and b.pending.key=='safeguard' then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false end
 end
 b.racial_status={race=race,epoch=b.racial_epoch or 0,irongrip_binding=irongrip_binding(s)}
 return race=='azudim'
end
function M.racial_text(s,line)
 local b=M.state(s);local q=b.racial_stream
 if not q then return false end
 if q.kind=='irongrip' then
  local value=line:match('^Irongrip %(Racial%)%s+Known:%s+(%a+)%s*$')
  if value then
   if q.header or (value~='Yes' and value~='No') then q.invalid=true end
   q.header=true;q.known=value=='Yes';return true
  end
  local text=line:match('^%s*(.-)%s*$')
  if q.header then
   if text:match('^%-+$') then q.separator=true end
   if text=='Syntax: IRONGRIP' then q.syntax=true end
   if text=='RELAX IRONGRIP' then q.relax=true end
   if text=='Syntax: IRONGRIP and RELAX IRONGRIP' then q.syntax=true;q.relax=true end
   if text=='By gripping your weapons tightly, you can prevent others from disarming you of your precious weapons.' then q.description=true end
   if text=='By gripping your weapons tightly, you can prevent others from disarming you of your precious' then q.description_prefix=true
   elseif q.description_prefix and text=='weapons.' then q.description=true;q.description_prefix=nil
   elseif q.description_prefix and text~='' then q.description_prefix=nil end
  end
  -- Entire solicited help frame is source text, never a live defense receipt.
  return true
 end
 if line=='You possess the following abilities from your race:' then
  if b.racial_listing then b.racial_listing.invalid=true;return true end
  b.racial_listing={query=q,own=true,safeguard=false};return true
 end
 local frame=b.racial_listing
 if line=='You possess the following racial abilities through other means:' then
  if frame then frame.own=false;frame.other_seen=true end;return true
 end
 if line=='Type RACIAL HELP <skill> to learn more about a specific skill.' then
  local status=b.racial_status
  if not q.revoked and status and status.race=='azudim' and status.epoch==q.epoch then
   if frame and frame.query==q and frame.other_seen and not frame.invalid then
    b.racial_proof={race='azudim',epoch=q.epoch,known=frame.safeguard==true}
   else fault(b,'Buff racial snapshot malformed; review/reset required') end
  end
  if b.query==q then b.query=nil end
  b.racial_listing=nil;b.racial_stream=nil;return true
 end
 if frame and frame.own and line:match('^%s*Safeguard%s*$') then frame.safeguard=true;return true end
 return false
end
function M.set_group_known(s,group,names,inferred)
 local b=M.state(s);group=norm(group)
 if not allowed_group(b.class,group) then return false end
 local prior=b.groups[group]
 -- Precise Lists remain authoritative over later rank inference.
 if inferred==true and prior and prior.list then return false end
 local known,supplied={},{}
 each_name(names,function(v)
  local name=type(v)=='table' and (v.name or v.id or v.key) or v
  supplied[norm(name)]=true
 end)
 for _,e in ipairs(M.catalog) do
  if not e.racial and in_class(b,e) and (e.group==group or e.also_group==group) and not e.tattoo and (supplied[norm(e.ability or e.key)] or supplied[norm(e.key)]) then known[e.key]=true end
 end
 local precise=not inferred
 if inferred=='revoke' then precise=prior and prior.list or false end
 b.groups[group]={known=known,list=precise};b.known={}
 for group,g in pairs(b.groups) do if allowed_group(b.class,group) then for k in pairs(g.known) do if in_class(b,index[k]) then b.known[k]=true end end end end
 for k,t in pairs(b.tattoos) do if index[k] and (t.charges or 0)>0 then b.known[k]=true end end
 b.known_ready=true
 if b.query and b.query.kind=='skills' then
  if b.query.groups then
   b.query.groups[group]=nil
   if not next(b.query.groups) then b.query=nil end
  elseif b.query.group==group then b.query=nil end
 end
 return true
end
function M.set_known(s,names) return M.set_group_known(s,'kaido',names) end
function M.set_groups(s,groups)
 local seen={}
 for _,g in pairs(type(groups)=='table' and groups or {}) do
  if type(g)=='table' then
   local name=norm(g.name);seen[name]=true;local names={}
   if tostring(g.rank):lower():match('^transcendent') then
    for _,e in ipairs(M.catalog) do if (e.group==name or e.also_group==name) and not e.tattoo then names[#names+1]=e.key end end
   end
   M.set_group_known(s,name,names,tostring(g.rank):lower():match('^transcendent') and true or 'revoke')
  end
 end
 local missing={};for g in pairs(M.state(s).groups) do if not seen[g] then missing[#missing+1]=g end end
 for _,g in ipairs(missing) do M.set_group_known(s,g,{},'revoke') end
end
function M.invalidate(s)
 local prior=M.state(s);prior.racial_epoch=(prior.racial_epoch or 0)+1;prior.racial_status=nil;prior.racial_proof=nil;prior.racial_listing=nil;prior.irongrip_proof=nil
 if prior.defence_text_enrolled then prior.defence_text_ready=false end
 if prior.racial_stream then prior.racial_stream.revoked=true end
 local b=M.state(s);b.known={};b.groups={};b.tattoos={};b.tattoos_ready=false;b.tattoo_listing=nil;b.vitals_flags={};b.flag_sources={};b.known_ready=false
 b.sensory_context=nil;b.herb=nil;b.sensory_optin={};b.sensory_epoch=(b.sensory_epoch or 0)+1
 b.starburst_optin=nil;b.starburst_clock_known=nil
 b.observed={};b.have={};b.defs_known=false;b.ability_listing=nil;b.immunity_clock_known=false;b.bolstered_clock_known=false
 b.native_priorities={};b.native_full_required=true;b.native_listing=nil;b.native_version=(b.native_version or 0)+1
 if b.pending then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false
  if b.pending.channel_retry then b.pending.channel_retry.ready=nil end
  if b.pending.key=='irongrip' then
   b.pending.irongrip_own=nil;b.pending.irongrip_gain=nil;b.pending.irongrip_measured=nil;b.pending.irongrip_lost=nil;b.pending.irongrip_recovered=nil
  end
  if b.pending.curative then b.pending.herb_lost=false;b.pending.herb_recovered=false end
 end
end
-- Caller owns evidence acquisition, not this module. The five-second action
-- context is herb/vitals freshness, NOT a renewed observation of old stock.
-- Optional tracked_ic_v1 metadata is scalar-copied and strictly validated;
-- integration must revalidate the live owner/source/fact before OUTC and EAT.
function M.set_sensory_context(s,c)
 local b=M.state(s);b.sensory_context=nil
 if type(c)~='table' or not M.supported_class(b.class) or c.class~=b.class or c.epoch~=(b.sensory_epoch or 0) then return false end
 local t=now()
 if type(c.observed_at)~='number' or c.observed_at~=c.observed_at or c.observed_at>t or t-c.observed_at>5 then return false end
 if type(c.priorities)~='table' or type(c.stocks)~='table' then return false end
 if c.eating_allowed~=true or c.curing_clear~=true or c.barriers_clear~=true then return false end
 if not (c.herb==true or c.herb==1 or c.herb=='1') or b.herb~=true then return false end
 local copy={class=b.class,epoch=c.epoch,observed_at=c.observed_at,priorities={},stocks={}}
 if c.stock_evidence~=nil then
  if type(c.stock_evidence)~='table' then return false end
  copy.stock_evidence={}
 end
 for k,pill in pairs(sensory) do
  local pri,n=c.priorities[k],c.stocks[pill]
  if pri~=nil and (type(pri)~='number' or pri%1~=0 or pri<1 or pri>26) then return false end
  if n~=nil and (type(n)~='number' or n~=n or n==math.huge or n<0 or n%1~=0) then return false end
  if copy.stock_evidence then
   local e=c.stock_evidence[pill]
   if type(e)~='table' or e.mode~='tracked_ic_v1' or e.tracked~=true or e.count~=n or not n or n<0 then return false end
   if type(e.observed_at)~='number' or e.observed_at~=e.observed_at or e.observed_at>t or e.observed_at==-math.huge then return false end
   if type(e.version)~='number' or e.version<1 or e.version%1~=0 or e.version==math.huge then return false end
   if type(e.session)~='number' or e.session<1 or e.session%1~=0 or e.session==math.huge or type(e.owner_id)~='string' or e.owner_id=='' then return false end
   if e.source~='ic' and e.source~='gmcp.IRE.Rift.Change' and e.source~='native IC withdrawal' and e.source~='native IC deposit' then return false end
   copy.stock_evidence[pill]={mode=e.mode,tracked=true,count=n,source=e.source,observed_at=e.observed_at,version=e.version,owner_id=e.owner_id,session=e.session}
  end
  copy.priorities[k]=pri;copy.stocks[pill]=n
 end
 if copy.stock_evidence then
  local a,o=copy.stock_evidence.amaurosis,copy.stock_evidence.ototoxin
  if a.owner_id~=o.owner_id or a.session~=o.session then return false end
 end
 b.sensory_context=copy;return true
end
function M.sensory_ready(s,k)
 local b=M.state(s);local c=b.sensory_context
 if sensory[k] and not index[k] then return false,'CURABLE AFFLICTION: self-affliction retired' end
 if not sensory[k] or not c or c.class~=b.class or c.epoch~=(b.sensory_epoch or 0) or now()<c.observed_at or now()-c.observed_at>5 then return false,'UNKNOWN: fresh sensory policy/resource proof required' end
 if c.priorities[k]~=26 then return false,'UNKNOWN/ACTIVE: native affliction cure must be ignored at priority 26' end
 if b.vitals_flags[k]==nil and not b.have[k] then return false,'UNKNOWN: current sensory flag required' end
 if (c.stocks[sensory[k]] or 0)<1 or b.herb~=true then return false,'Herb balance or cache stock unavailable' end
 -- Leave all actual cures to FIRSTAID; even an unrelated confirmed affliction
 -- takes precedence over optional intentional self-affliction.
 for aff,v in pairs((s.player or {}).afflictions or {}) do if yes(v) and not sensory[key(aff)] then return false,'Native curing takes precedence' end end
 if not ready(s) or s.training_battle_ended or (s.walker and s.walker.pending) or (s.mental and (s.mental.eq_pending or s.mental.fault)) then return false,'Unresolved action/readiness barrier' end
 return true,'AVAILABLE: intentional affliction; native cure ignored'
end
function M.select_sensory(s,k,on)
 local b=M.state(s)
 if not sensory[k] or type(on)~='boolean' then return false,'Expected sensory goal and boolean' end
 if on and not index[k] then return false,'CURABLE AFFLICTION: self-affliction retired' end
 if on and (not in_class(b,index[k]) or not M.sensory_ready(s,k)) then return false,'Fresh sensory cure-ignore/resource proof required' end
 b.sensory_optin=b.sensory_optin or {};b.sensory_optin[k]=on;b.wanted[k]=on
 if not on and b.todo then b.todo[k]=nil end
 return true,on and 'Sensory goal selected; master unchanged' or 'Sensory upkeep off; no cure or policy write'
end
function M.availability(s,k)
 local b=M.state(s);local e=index[k]
 if sensory[k] and not e then return false,'CURABLE AFFLICTION: self-affliction retired' end
 if M.native_catalog[k] then return true,'NATIVE' end
 if e and not in_class(b,e) then return false,'CLASS-SPECIFIC: '..tostring(e.class)..' only' end
 if e and e.curative then return M.sensory_ready(s,k) end
 if k=='irongrip' then
  local status,proof=b.racial_status,b.irongrip_proof
  if not status or status.race=='' or not same_irongrip(status.irongrip_binding,irongrip_binding(s)) then return false,'UNKNOWN: fresh character-bound Status race required' end
  if not proof or proof.epoch~=status.epoch or proof.race~=status.race or not same_irongrip(proof.binding,status.irongrip_binding) then return false,'UNKNOWN: solicited RACIAL HELP IRONGRIP Known required' end
  return proof.known==true,proof.known and 'AVAILABLE: current selected racial Irongrip' or 'NOT LEARNED: racial Irongrip Known: No'
 end
 if e and e.racial then
  local status,proof=b.racial_status,b.racial_proof
  if not status then return false,'UNKNOWN: fresh native Status race required' end
  if status.race~='azudim' then return false,'RACE-SPECIFIC: Azudim MIASMA only' end
  if proof and proof.race=='azudim' and proof.epoch==status.epoch and proof.known~=true then return false,'NOT LEARNED: own-race Safeguard absent' end
  local ok=proof and proof.race=='azudim' and proof.epoch==status.epoch and proof.known==true
  return ok==true,ok and 'AVAILABLE: verified Azudim Safeguard' or 'UNKNOWN: fresh own-race RACIAL SKILLS required'
 end
 if routed(s,e)then local a=class_proposal(s,e);return a.command~='',a.reason end
 if e and e.tracking_only then return false,e.reason end
 if e and e.passive then return false,b.known[k] and 'PASSIVE' or 'NOT LEARNED' end
 if e and e.bash_only and s.mode~='BASH' then return false,'BASH ONLY: activation and discovery disabled in this mode' end
 if k=='bolstered' then
  if not b.defs_known then return false,'UNKNOWN: complete defence List required to exclude Nimbleness' end
  for _,map in ipairs({b.have,b.observed,(s.player or {}).defences or {}}) do
   for id,on in pairs(map) do if norm(id)=='nimbleness' and yes(on) then return false,'CONFLICT: Nimbleness active; no automatic cancellation' end end
  end
 end
 if e and e.tattoo then
  local t=b.tattoos[k]
  if k=='book' then
   for _,map in ipairs({b.have,b.observed,(s.player or {}).defences or {}}) do
    for id,on in pairs(map) do if key(id)=='book' and yes(on) then return false,'ACTIVE: Book already activated' end end
   end
  end
  if t and t.active and not e.login_auto then return false,'ACTIVE: tattoo already activated' end
  if e.login_auto then
   if t and t.active then return false,'PASSIVE' end
   if not (b.tattoos_ready and t and t.touchable==true and t.active==false and (t.charges or 0)>0) then
    return false,'UNKNOWN: fresh inactive ink with explicit Uses left required; ACTIVE/login/removal grants no TOUCH'
   end
  end
  if k=='starburst' then
   if not b.defs_known or not b.starburst_clock_known then return false,'UNKNOWN: current death protection/cooldown required' end
   -- Legacy AC2 conflated these protections with Starburst. Do not port its
   -- auto-touch triggers or infer absence from a partial text DEF report.
   local conflicts={starburst=true,soulcage=true,rebirth=true,substitute=true,soul_substitute=true,soulstore=true,soul_store=true,soulstored=true,soul_storage=true,death_protection=true,resurrection=true,reincarnation=true}
   for _,map in ipairs({b.have,b.observed,(s.player or {}).defences or {}}) do
    for id,on in pairs(map) do if yes(on) and conflicts[tostring(id):lower():gsub('[ %-]','_')] then return false,'ACTIVE: death protection already present' end end
   end
   if (b.cooldown.starburst or 0)>now() then return false,'UNKNOWN/COOLDOWN: wait two minutes before Starburst' end
  end
  return t~=nil and (t.charges or 0)>0,b.tattoos_ready and (t and (t.charges or 0)>0 and 'AVAILABLE' or 'UNAVAILABLE: no charged tattoo') or 'UNKNOWN: fresh TATTOOS required'
 end
 if e then
  local proof=false;local complete=false
  for _,group in ipairs({e.group,e.also_group}) do
   local g=b.groups[group];if allowed_group(b.class,group) and g then complete=true;if g.known[k] then proof=true end end
  end
  return proof,proof and 'AVAILABLE' or complete and 'NOT LEARNED' or 'UNKNOWN: fresh class-appropriate abilities required'
 end
 local t=b.tattoos[k]
 if t and t.active then return false,'PASSIVE' end
 if k=='shielded' then return false,'MANUAL ONLY: shield breaks on offense' end
 return false,metadata[k] and metadata[k].reason or 'UNAVAILABLE: ownership/command unverified'
end
function M.has_work(s)
 local b=M.state(s)
 return b.master==true or b.sequence==true or b.pending~=nil or next(b.cancel)~=nil
end
local function canonical_have(s,k)
 for id,value in pairs((s.player or {}).defences or {}) do
  if key(id)==k and yes(value) then return true end
 end
 return false
end
local function observe(s,k,on)
 local b=M.state(s);local was_on=b.have[k]==true
 local tattoo=b.tattoos[k];local e=index[k]
 if tattoo or passive_tattoos[k] or e and e.tattoo then
  -- A snapshot crossing any tattoo event cannot prove current ink/status.
  b.tattoo_version=(b.tattoo_version or 0)+1
  if tattoo then
   if k=='book' then tattoo.active=on end
   if not on then
    tattoo.active=false
    -- A missing/faded autoactivated tattoo is not freshly inked ownership.
    if passive_tattoos[k] then tattoo.charges=nil;tattoo.touchable=nil;b.known[k]=nil end
   elseif e and e.tattoo and not (b.pending and b.pending.key==k and b.pending.tattoo_debited) then
    -- External activation has no correlated debit. Revoke, never guess stock;
    -- repeated own gain lines are harmless and cannot restore authorization.
    tattoo.charges=nil;tattoo.touchable=nil;b.known[k]=nil
   end
   if on and passive_tattoos[k] then tattoo.active=true;tattoo.touchable=nil end
  end
 end
 if index[k] then b.have[k]=on or nil else b.observed[k]=on or false end
 if passive_tattoos[k] then b.observed[k]=on or false end
 local p=s.player or {};p.defences=p.defences or {};s.player=p
 -- Keep legacy identifiers consumed by mental.lua coherent, without replacing
 -- generic GMCP defences (which include many unrelated abilities).
 p.defences[k]=on or nil
 if not on then
  for id in pairs(p.defences) do if observed_key(id)==k then p.defences[id]=nil end end
 end
 if k=='trance' then p.defences.kai_trance=on or nil end
 if k=='boosting' then p.defences.boosted_regen=on or nil end
 if k=='blindness' or k=='deafness' then b.vitals_flags[k]=nil;b.flag_sources[k]=nil end
 if on and (k=='immunity' or k=='bolstered') and not was_on then
  b[k..'_clock_known']=true
  local at=b.pending and b.pending.key==k and b.pending.at or now()
  b.cooldown[k]=math.max(b.cooldown[k] or 0,at+index[k].cooldown_activation)
 end
 if not on and index[k] and index[k].cooldown_loss then b.cooldown[k]=now()+index[k].cooldown_loss end
 local pending=b.pending
 if pending and pending.curative and pending.key==k and not on then pending.confirmed=false;pending.prompt_ready=false end
 if pending and pending.key=='irongrip' and k=='irongrip' then
  pending.irongrip_gain=on==true;pending.confirmed=false;pending.prompt=nil;pending.prompt_ready=false
  if on then pending.irongrip_witness_prompt=b.prompt end
 end
 if pending and pending.key==k and pending.off==not on and (not pending.curative or pending.eat_started) then
  pending.confirmed=pending.key~='irongrip' or pending.irongrip_own==true;pending.confirmed_prompt=b.prompt
  if pending.curative then pending.prompt=nil;pending.prompt_ready=false end
 end
end
local function snapshot(s,have)
 local b=M.state(s)
 if not b.starburst_clock_known then
  b.cooldown.starburst=math.max(b.cooldown.starburst or 0,now()+120);b.starburst_clock_known=true
 end
 if not b.immunity_clock_known then
  b.cooldown.immunity=math.max(b.cooldown.immunity or 0,now()+120);b.immunity_clock_known=true
 end
 if not b.bolstered_clock_known then
  b.cooldown.bolstered=math.max(b.cooldown.bolstered or 0,now()+600);b.bolstered_clock_known=true
 end
 for _,e in ipairs(M.catalog) do
  -- Missing vitality in a first snapshot is NOT evidence it was triggered.
  if e.curative then have[e.key]=b.have[e.key] or nil
  elseif e.login_auto and b.tattoos[e.key] and b.tattoos[e.key].active then have[e.key]=have[e.key] or b.have[e.key] or nil
  elseif have[e.key] or b.have[e.key] or canonical_have(s,e.key) then observe(s,e.key,have[e.key]==true) end
 end
 b.have=have;b.defs_known=true;b.defs_at=now()
 local p=b.pending
 if p and not p.curative then p.confirmed=(have[p.key]==true)~=p.off and (p.key~='irongrip' or p.irongrip_own==true) end
 if b.query and b.query.kind=='defs' then b.query=nil end
end
function M.sync(s,kind,payload)
 local b=M.state(s);kind=norm(kind):match('([^%.]+)$')
 if kind=='list' then
  local have,general={},{}
  each_name(payload,function(v)local k=observed_key(v);if k then if index[k] then have[k]=true else general[k]=true end end end)
  local flags,sources={},{};for k,v in pairs(b.vitals_flags) do flags[k]=v;sources[k]=b.flag_sources[k];if v then general[k]=true end end
  for k in pairs(b.observed) do
   -- DEF absence is not evidence that a passive tattoo stopped being active.
   if general[k] or not (b.tattoos[k] and b.tattoos[k].active) then observe(s,k,general[k]==true) end
  end
  for k in pairs(general) do observe(s,k,true) end
  snapshot(s,have)
  b.vitals_flags=flags;b.flag_sources=sources
 elseif kind=='add' or kind=='remove' then
  each_name(payload,function(v)local k=observed_key(v);if k then observe(s,k,kind=='add') end end)
 end
 return b
end
local confirmations={
 ['You are immune to normal weather.']='weathering',
 ['Your skin is toughened.']='toughness',
 ['You have already toughened your skin.']='toughness',
 ['Flexing your muscles, you concentrate on forcing unnatural toughness over the surface of your skin.']='toughness',
 ['You are resisting magical damage.']='resistance',
 ['You call aloud and feel an aura of resistance shroud itself silently about you.']='resistance',
 ['You are maintaining consciousness at all times.']='consciousness',
 ['You are using your superior constitution to prevent nausea.']='constitution',
 ['Your vision is heightened to see in the dark.']='nightsight',
 ['Your vision sharpens with light as you gain night sight.']='nightsight',
 ['You are brimming with courage.']='courage',
 ['You will call upon your fortitude in need.']='vitality',
 ['You are regenerating lost health through the power of Kaido.']='regeneration',
 ['You are regenerating lost health through will.']='regeneration',
 ['You begin to concentrate on regeneration of your wounds.']='regeneration',
 ['Your regeneration is boosted.']='boosting',
 ['You call upon your Kai power to boost your health regeneration.']='boosting'
}
local up={
 instawake={'You are feeling extremely energetic.','An instant feeling of excitement and edginess overcomes you.'},
 rebounding={'You are protected from hand-held weapons with an aura of rebounding.','You feel an aura of rebounding surround you.'},
 levitation={'You walk on a small cushion of air.','You are already levitating.'},
 density={'You are extremely heavy and difficult to move.'},
 speed={'Your sense of time is heightened, and your reactions are speeded.','Your sense of time is already heightened.'},
 waterbreathing={'You are surrounded by a pocket of air.','You are already surrounded by a pocket of air.'},
 fangbarrier={'The paste solidifies into a thick, hardened shell.','You are protected from the fangs of serpents.'},
 insomnia={'You have insomnia, and cannot easily go to sleep.'},
 arcane={'You are tempered against elemental magic.','You are already tempered against elemental magic.'},
 harmony={'Your thoughts are harmonized.'},vigor={'You have been invigorated with strength.'},
 blindness={'You are blind.'},deafness={'You are deaf.','The world around fades to silence as you lose your hearing.'},
 insulation={'You are insulated against the harsh cold.','You are coated in an insulating caloric salve.'},
 temperance={'You are tempered against fire damage.'},antivenin={'Your resistance to damage by poison has been increased.'},
 cloak={'You are surrounded by a cloak of protection.'},clarity={'Your mind is filled with clarity.'},
 deathsight={'Your mind has been touched by the essence of the Underking.'},divertmelee={'You are diverting melee attacks.'},
 dodgemelee={'You are dodging melee attacks.'},divine_speed={'You have been granted the speed of the Divine.'},
 hypersight={'You are utilising hypersight.'},irongrip={'Your hands are gripping your wielded items tightly.'},
 metawake={'You are concentrating on maintaining distance from the dreamworld.'},thirdeye={'You possess the sight of the third eye.'},
 shielded={'You are surrounded by a nearly invisible magical shield.'},vigilance={'You are vigilant to attempts to hypnotise you.'},
 skywatch={'You are aware of movement in the skies.'},tremorsense={'You are listening for underground movement.'},
 recognition={'You are recognizing masking afflictions.'},selfishness={'You are feeling quite selfish.'},
 alertness={'Your senses are attuned to nearby movement.'},telesense={'You are using your telesense.','You are attuned to local telepathic interference.'},
 bolstered={'You have prepared yourself for incoming attacks.'},safeguard={'You have the safeguard of an Idreth.','You are surrounded by a safeguard charm.','You begin to exude a foul miasma, granting protection upon you and your allies.'},
 flame={'Your flame tattoo is glowing faintly.'},firefly={'Your firefly tattoo glows softly.'},
 mindseye={'Your senses are magically heightened.'},starburst={'You walk with the grace of the stars.'}
}
for k,lines in pairs(up) do for _,line in ipairs(lines) do confirmations[line]=k end end
local losses={
 ['The aura about you fades, leaving you somewhat more vulnerable again.']='safeguard',
 ['You call a halt to the regenerative process.']='regeneration',
 ['You feel yourself calm down as the stimulant wears off.']='instawake',
 ['Your aura of weapons rebounding disappears.']='rebounding',
 ['You gently lower yourself to the ground.']='levitation',
 ['You cease your levitation as the pit attempts to pull you towards it.']='levitation',
 ['You feel your density return to normal.']='density',
 -- Legacy source typo retained; not claimed as a current verified server line.
 ['Your speed defence defence erodes away.']='speed',
 ['Your waterbreathing defence has been washed away.']='waterbreathing',
 ['Your protective coating rots away under the noxious attack.']='fangbarrier',
 ['You feel your defense against venoms weaken and fade.']='antivenin',
 ['You cease to concentrate on hypersight.']='hypersight',
 ['Your magical shield is sheared straight through.']='shielded',
 ['You allow your muscles to relax once more as you cease to bolster them.']='bolstered'
}
-- Exact own lines only: sourced Fallout gain/loss triggers, not echoed speech.
local extra_up={
 immunity={'You close your eyes and grit your teeth, feeling the heat of the blood pumping through your veins.','Your blood is steeled against poisons.'},
 insight={'You have insight into the thoughts of others.'},
 mindcloak={'You will now begin to concentrate on cloaking your telepathy.','You are already cloaking your attempts at mindlocking.','You are cloaking your attempts at establishing a mindlock.'},
 telesense={'You attune your mind to tampering from telepathy.'},
 clarity={'You listen intently for an instant of silence. Finding it, you focus on it and its clarity, protecting your mind against corruption.','You have already filled your mind with clarity.'},
 selfishness={'You rub your hands together greedily.'},
 skywatch={'You are watching the skies for danger.'},alertness={'You prick up your ears.'},
 deathsight={'You shut your eyes and concentrate on the wise Underking. A moment later, you feel inextricably linked with the underworld and its passengers.','A miasma of darkness passes over your eyes and you feel a link to the Underking form in your mind.'},
 thirdeye={'You now possess the gift of the third eye.','You already possess the gift of the third eye.'},
 eagleeye={'You are already keep watching for projectiles.','Your vision is trained for incoming projectiles.'},
 dodgemelee={'You begin to focus your efforts on dodging all attacks.','You are dodging all attacks.','You are already dodging all attacks.','You begin to focus your efforts on dodging melee attacks.'},
 divertmelee={'You begin to focus your efforts on diverting damage from all attacks.','You are diverting all attacks.','You are already diverting all attacks.'},
 cloak={'You caress the tattoo and immediately you feel a cloak of protection surround you.'},
 boar={'Your boar tattoo has been activated.'},moon={'Your moon tattoo has been activated.'},
 moss={'Your moss tattoo has been activated.'},owl={'Your owl tattoo has been activated.'},
 firefly={'You touch the firefly tattoo and suddenly your surroundings are alight.','You use Tattoos Firefly.'},
 flame={'You use Tattoos Flame.'},
 mindseye={'Touching the mindseye tattoo, your senses are suddenly heightened.','You use Tattoos Mindseye.','You are already using the mindseye defense.'},
 blindness={'Your eyes dim as you lose your sight.','It has no effect. You are already blind.'},
 deafness={'It has no effect. You are already deaf.'},
 insulation={'A feeling of comfortable warmth spreads over you.','You already have the insulation defense!'},
 temperance={'A chill runs over your icy skin.','You are already tempered against fire damage.'},
 venom_resistance={'You feel a momentary dizziness as your resistance to damage by poison increases.','You are already benefitting from increased venom resistance.'}
}
for k,lines in pairs(extra_up) do for _,line in ipairs(lines) do confirmations[line]=k end end
losses['You are no longer blind.']='blindness';losses['You have cured blindness.']='blindness'
losses['You are no longer deaf.']='deafness';losses['You have cured deafness.']='deafness'
local extra_down={
 immunity={'Your blood boils as it throws off the effects of the venom rushing through your veins.'},
 mindcloak={'You allow the mindcloak to drop.'},
 telesense={'You cease to concentrate your mind on mindlock attempts.'},
 clarity={'Your clarity of mind has been corrupted.','The clarity that filled your mind suddenly dissipates.'},
 selfishness={'A feeling of generosity spreads throughout you.'},
 alertness={'You cease your watchful alertness.'},
 cloak={'You suddenly feel that it would be a fine idea to relax your cloak defence.'},
 mindseye={'You are blind and can see nothing but darkness.'}
}
for k,lines in pairs(extra_down) do for _,line in ipairs(lines) do losses[line]=k end end
-- Public native DEF details: own status/fade/end only, not activation proof.
confirmations['You embrace your core oneness.']='oneness'
confirmations['You are recognizing masking afflictions.']='recognition'
confirmations['You are anchored to the ground.']='anchored'
confirmations['Your mind is dampened against psychic attack.']='sublimation'
confirmations['Your physical form is partly ethereal.']='ethereal'
confirmations['Your internal core is in a state of hyper production.']='catabolism'
confirmations['You have heightened your ability to repair tissue and organs.']='ameliorate'
confirmations['The states of your body and mind are joined.']='linked'
confirmations['You are attuned to the music of the spheres.']='spheres'
confirmations['You have recognised the potential of the geometric shapes.']='conjoin'
confirmations['You are veiled.']='veiled'
confirmations['You have adapted new racial qualities.']='adaptation'
confirmations['The effects of the stars are magnified upon you.']='dilation'
confirmations['You are wreathed in an aura of toxicity.']='nexus'
confirmations['Your sense of time is heightened, and your reactions are speeded.']='speed'
confirmations['Your resistance to damage by poison has been increased.']='antivenin'
confirmations['You are extremely heavy and difficult to move.']='density'
confirmations['You are protected from the fangs of serpents.']='fangbarrier'
confirmations['You have insomnia, and cannot easily go to sleep.']='insomnia'
confirmations['You are feeling extremely energetic.']='instawake'
confirmations['You possess the sight of the third eye.']='thirdeye'
confirmations['Your mind is filled with distant thoughts.']='daydream'
confirmations['Your mind has been touched by the essence of the Underking.']='deathsight'
confirmations['Your thoughts are harmonized.']='harmony'
confirmations['You are protected from hand-held weapons with an aura of rebounding.']='rebounding'
confirmations['You are surrounded by a pocket of air.']='waterbreathing'
losses['You lose your inner focus upon yourself as fatigue wins over.']='oneness'
losses['Your body loses its ethereal form as the essence wears off.']='ethereal'
losses['The music of the spheres fades, leaving you weak and unsteady.']='spheres'
losses['The recognition you had of the world geometries finally escapes you.']='conjoin'
losses['You feel the effect of the stars weaken upon you.']='dilation'
losses['You feel your density return to normal.']='density'
losses['Your mind focuses back on the tasks at hand.']='daydream'
losses['The harmony you felt settles out into stillness.']='harmony'
losses['The bubble of air around you dissipates as water floods in.']='waterbreathing'
losses['Your racing mind slows.']='book'
local function priority_set(b,k,pri)
 b.native_priorities[k]=pri
 if b.native_pending then b.native_pending[k]=nil end
 if pri<26 then b.native_last_active[k]=pri end
end
local function priority_text(b,line)
 -- An own acknowledgement is independent of a listing and newer than its rows.
 local name,n=line:match("^You have set the '(.-)' defence to the (%d+) priority%.$")
 local pri=tonumber(n)
 if name and M.native_catalog[name] and pri and pri>=1 and pri<=26 then
  b.native_version=(b.native_version or 0)+1
  -- A delayed ACK for another value cannot acknowledge the unresolved write.
  -- Still fence older listing rows, but retain uncertainty and restoration memory.
  if not b.native_pending or not b.native_pending[name] or b.native_pending[name]==pri then priority_set(b,name,pri) end
  return true
 end
 if line=='Your defense priorities:' then
  b.native_listing={values={},seen={},priorities={},valid=true,rows=0,version=b.native_version or 0};return true
 end
 local tx=b.native_listing
 if tx then
  if line=='Defs with priority 26 are ignored.' then
   b.native_listing=nil
   if tx.valid and tx.rows==25 and tx.version==(b.native_version or 0) then
    b.native_full_required=false
    for _,k in ipairs(native_order) do
     local value=tx.values[k] or 26
     -- A pre-write response delivered late must not confirm a conflicting value.
     if not b.native_pending or not b.native_pending[k] or b.native_pending[k]==value then priority_set(b,k,value) end
    end
   end
   return true
  end
  if line:match('^%s*$') then return true end
  local n,names=line:match('^%s*(%d+):%s*(.-)%s*$');local pri=tonumber(n)
  if not pri or pri<1 or pri>25 or tx.priorities[pri] or not names or names:match(',%s*$') then tx.valid=false;return false end
  tx.priorities[pri]=true
  tx.rows=tx.rows+1
  if names==''then return true end -- Native readback includes empty 5: ... 25: rows.
  for name in (names..','):gmatch('(.-),') do
   name=name:match('^%s*(.-)%s*$')
   if not name:match('^[%a][%a_ %-]*$') or tx.seen[name] then tx.valid=false end
   tx.seen[name]=true
   if M.native_catalog[name] then tx.values[name]=pri end
  end
  return true
 end

 local state=line:match('^Status:%s+(%u+)$');if state=='ON'or state=='OFF'then b.native_status=state=='ON';return true end
 state=line:match('^Defences:%s+(%u+)$');if state=='ON'or state=='OFF'then b.native_defences=state=='ON';return true end
 return false
end
function M.text(s,line)
 if type(line)~='string' then return end
 local b=M.state(s)
 -- DEFENCE help prints status/fade templates, not live effect observations.
 if line:match('^Defence:%s+') then
  b.defence_help_frame=true
  if b.racial_stream then b.racial_stream.revoked=true;b.racial_listing=nil end
  return
 end
 -- A revoked read-only stream may drain, but never grant capability.
 if b.racial_stream and b.racial_stream.revoked and line=='Type RACIAL HELP <skill> to learn more about a specific skill.' then M.racial_text(s,line);return end
 if b.defence_help_frame or b.defence_text_enrolled and b.defence_text_ready~=true then return end
 if M.racial_text(s,line) then return end
 if priority_text(b,line) then return end
 local ip=b.pending
 if ip and ip.key=='irongrip' then
  if line=='You use Racial Irongrip.' then
   ip.irongrip_own=true;ip.prompt=nil;ip.prompt_ready=false;ip.irongrip_witness_prompt=b.prompt
   ip.confirmed=ip.irongrip_gain==true
  elseif line:match('^Balance Used: %d+%.?%d* seconds?%.?$') then
   ip.irongrip_measured=true;ip.prompt=nil;ip.prompt_ready=false;ip.irongrip_witness_prompt=b.prompt
  end
 end
 if line=='You have the following tattoos:' then
  b.tattoo_listing={};b.tattoo_listing_version=b.tattoo_version or 0
  -- Even a post-dispatch header may describe the pre-consumption budget.
  b.tattoo_listing_uncertain=b.pending and b.pending.tattoo_debited or false;return
 end
 if b.tattoo_listing then
  local name,count=line:match('^[%a ]+:%s+(%a+)%s+Uses left:%s+(%d+)%s*$')
  local active=line:match('^[%a ]+:%s+(%a+)%s+Active%s*$')
  local k=name and norm(name) or active and norm(active)
  if k then
   local t=b.tattoo_listing[k] or {charges=0,active=false};b.tattoo_listing[k]=t
   local n=tonumber(count)
   if n and (n==math.huge or n<0 or n%1~=0) then b.tattoo_listing_uncertain=true;return end
   t.charges=t.charges+(n or 0);t.active=t.active or active~=nil
   t.touchable=not t.active and n~=nil and t.charges>0
   return
  end
 end
 local group=line:match('^You possess the following abilities in ([%a]+):$')
 if group then b.ability_listing={};b.ability_group=norm(group);return end
 if b.ability_listing then
  if line:match('^Type AB '..b.ability_group:upper()..' <ability>') then
   M.set_group_known(s,b.ability_group,b.ability_listing);b.ability_listing=nil;return
  end
  local name=line:match('^%s*([%a][%a ]-)%s%s+%S')
  if name then b.ability_listing[#b.ability_listing+1]=name end
 end
 if line=='You have the following active defences:' then b.listing={};return end
 if line:match('^You are protected by %d+ defences%.$') and b.listing then
  -- Our text recognizer is partial. Unrecognized rows are not absent defenses.
  -- Only a full GMCP List may clear existing positives or establish known absence.
  b.listing=nil;return -- Each row was observed immediately; never replay stale evidence.
 end
 -- Native DEF template has a variable duration; never match speech or blank time.
 local k=confirmations[line] or (line:match('^Your mind is racing from the effects of the Book tattoo for another %S.-%.$') and 'book')
 if k then if b.listing then b.listing[k]=true end;observe(s,k,true);return end
 k=losses[line];if k then observe(s,k,false);return end
 local name=line:match('^You have gained the ([%a_ %-]+) defence%.$')
 if name then k=observed_key(name);if k then observe(s,k,true);if b.listing then b.listing[k]=true end end;return end
 name=line:match('^You have lost the ([%a_ %-]+) defence%.$') or
  line:match('^Your ([%a_ %-]+) defence has been stripped%.$') or
  line:match('^Your ([%a_ %-]+) defence is degraded away%.$')
 if name then k=observed_key(name);if k then observe(s,k,false) end;return end
 if b.pending and (line=='You must regain balance first.' or line=='You must regain equilibrium first.' or
  b.pending.key=='firefly' and line=='You cannot activate your firefly tattoo again just yet.' or
  b.pending.key=='flame' and line=='You have no flame.' or
  line=='You do not possess that ability.' or line=='You have not learned that ability.' or line=='You do not know that ability.' or
  line=='You know of no such ability.' or line=='You cannot perform that ability.' or line=='You have not yet learned that ability.') then
  if b.pending.key=='immunity' or b.pending.key=='bolstered' then
   -- These replies contain no action identity. Another controller may have
   -- triggered them, before OR after our own UP. Retain the committed barrier
   -- and activation clock; only ACK + fresh ready prompt (or reset) settles it.
   b.status='Unattributed rejection; '..b.pending.key..' confirmation/recovery still required'
  else
   local p=b.pending;local e=index[p.key]
   local channel=line=='You must regain balance first.' and 'balance' or line=='You must regain equilibrium first.' and 'equilibrium'
   -- Only ordinary skill non-execution is retryable. Resource debits, racial
   -- proofs, routed ledgers, ambiguous sends and confirmed actions stay fenced.
   if channel and e and not e.tattoo and not e.racial and not p.curative and not routed(s,e) and not p.shape_reservation and not p.earth_reservation and not p.send_failed and not p.confirmed and not b.fault then
    p.rejected=true;p.channel_retry={channel=channel};p.prompt=nil;p.prompt_ready=false
    if b.sequence and b.todo and b.wanted[p.key] and not p.off then b.todo[p.key]=true end
    if p.off then b.cancel[p.key]=true end
    b.status='Buff not executed; awaiting fresh native '..channel..' readiness'
   else
    p.rejected=true;b.retry[p.key]=now()+5;fault(b,'Buff rejected: '..line..' Review/reset required')
   end
  end
 end
end
-- Called only from a genuine fresh Vitals event, never a cached tick.
function M.vitals(s,v)
 local b=M.state(s)
 local ip=b.pending
 if ip and ip.channel_retry then
  local r=ip.channel_retry;local value=v[r.channel]
  if value~=nil then
   r.ready=(value==true or value==1 or value=='1')
   r.witness_prompt=b.prompt;ip.prompt=nil;ip.prompt_ready=false
  end
 end
 if ip and ip.key=='irongrip' and v.balance~=nil then
  local value=v.balance
  if value==false or value==0 or value=='0' then
   ip.irongrip_lost=true;ip.irongrip_recovered=nil;ip.prompt=nil;ip.prompt_ready=false;ip.irongrip_witness_prompt=b.prompt
  elseif (value==true or value==1 or value=='1') and ip.irongrip_lost then
   ip.irongrip_recovered=true;ip.prompt=nil;ip.prompt_ready=false;ip.irongrip_witness_prompt=b.prompt
  end
 end
 if v.herb~=nil then
  local h=v.herb
  if h==true or h==1 or h=='1' then b.herb=true
  elseif h==false or h==0 or h=='0' then b.herb=false else b.herb=nil end
  local p=b.pending
  if p and p.curative and p.eat_started then
   if b.herb~=true then p.herb_recovered=nil;p.prompt_ready=false;p.prompt=nil end
   if b.herb==false then p.herb_lost=true end
   if b.herb==true and p.herb_lost then p.herb_recovered=true end
  end
 end
 for field,k in pairs({blind='blindness',deaf='deafness'}) do
  if v[field]~=nil then
   local x=v[field]
   if x==true or x==false or x==1 or x==0 or x=='1' or x=='0' then
    local on=yes(x);observe(s,k,on);b.vitals_flags[k]=on;b.flag_sources[k]='vitals'
   else b.sensory_context=nil;b.vitals_flags[k]=nil;b.flag_sources[k]=nil end
  end
 end
end
function M.affliction_flags(s,kind,payload)
 -- Sensory positives may be delivered as afflictions rather than Defences.
 local b=M.state(s);local found={}
 if kind=='List' or kind=='Add' or kind=='Remove' then each_name(payload,function(v)
  local k=key(v);if k=='blindness' or k=='deafness' then
   found[k]=true;local on=kind~='Remove';observe(s,k,on)
   b.vitals_flags[k]=on;b.flag_sources[k]='afflictions'
  end
 end) end
 if kind=='List' then
  for _,k in ipairs({'blindness','deafness'})do
   if b.flag_sources[k]=='afflictions' and not found[k] then
    observe(s,k,false);b.vitals_flags[k]=false;b.flag_sources[k]='afflictions'
   end
  end
 end
end
function M.start(s)
 local b=M.state(s)
 if not M.supported_class(b.class) then return false,'Supported class required (Monk/Archivist)' end
 if b.fault then return false,b.fault end
 if b.pending then return false,'Buff action unresolved; await confirmation/recovery or reviewed reset' end
 b.sequence=true;b.todo={};for _,e in ipairs(M.catalog) do if b.wanted[e.key] then b.todo[e.key]=true end end
 b.status='defup requested';return true,b.status
end
function M.master(s,on)
 local b=M.state(s)
 if on~=true then
  b.master=false;b.status='maintenance paused; active defences retained'
  if not b.sequence and b.racial_stream and b.racial_stream.kind=='irongrip' then b.racial_stream.revoked=true end
  return true,b.status -- Explicit off queue and one-shot intent are independent.
 end
 if not M.supported_class(b.class) then return false,'Supported class required (Monk/Archivist)' end
 if b.fault then return false,b.fault end
 b.master=true;b.status='maintenance armed';return true,b.status
end
function M.toggle(s,name,on)
 local b=M.state(s);local k=key(name);local e=k and index[k]
 if sensory[k] then return M.select_sensory(s,k,on) end
 if k=='irongrip' and type(on)=='boolean' then
  -- Selection is not permission to arm every other selected defense.
  b.wanted[k]=on;b.cancel[k]=nil
  if not on and b.todo then b.todo[k]=nil end
  if not on and b.racial_stream and b.racial_stream.kind=='irongrip' then b.racial_stream.revoked=true end
  return true,on and 'Irongrip selected; master unchanged; capability still required' or 'Irongrip upkeep off; active defense retained'
 end
 if not e then return false,k and metadata[k] and metadata[k].reason or 'Unknown defence' end
 if M.native_catalog[k] then return false,'Native FIRSTAID owns this defence' end
 if on==false and e.class_routes then b.wanted[k]=false;b.cancel[k]=nil;if b.todo then b.todo[k]=nil end;return true,'local wanted OFF; no foreign cancellation' end
 if on==true and routed(s,e)then
  b.wanted[k]=true;b.master=true
  local cl=s.player.class;local a=M.class_router.modules[cl];local ctx=s[cl:lower()]
  if ctx then ctx.wanted=ctx.wanted or {};ctx.wanted[k]=true;if cl=='Wayfarer'then ctx.owners=ctx.owners or {};ctx.owners[k]='wayfarer';ctx.armed=true elseif cl=='Shapeshifter'then ctx.defense_armed=true elseif cl=='Infiltrator'then ctx.defense_owner=ctx.defense_owner or {};ctx.defense_owner[k]='buffs'end end
  return true,'wanted ON; execution remains capability-gated'
 end
 if not in_class(b,e) or e.tracking_only then return false,select(2,M.availability(s,k)) end
 if e.passive then return false,'Passive ability; no command' end
 if type(on)~='boolean' then return false,'Expected boolean' end
 -- Selecting future BASH upkeep for an already ACTIVE Book spends nothing.
 local active_book=k=='book' and s.mode=='BASH' and
  (b.have.book or b.observed.book or canonical_have(s,'book') or b.tattoos.book and b.tattoos.book.active)
 if on and not active_book and not M.availability(s,k) then return false,select(2,M.availability(s,k)) end
 if on then
  local ok,why=M.master(s,true);if not ok then return false,why end
  if k=='starburst' then b.starburst_optin=true end
  b.wanted[k]=true;b.cancel[k]=nil;return true,why
 end
 b.wanted[k]=false
 if k=='starburst' then b.starburst_optin=nil end
 if b.todo then b.todo[k]=nil end
 -- Queue even if currently absent: a preceding in-flight ON can still succeed.
 if e.off then b.cancel[k]=true;return true,e.label..' off queued (confirmation required)' end
 return true,e.label..' upkeep off; no verified cancellation, active defence retained'
end
function M.on_prompt(s)
 local b=M.state(s);b.prompt=b.prompt+1
 local q=b.racial_stream
 if q and q.kind=='irongrip' then
  local status=b.racial_status
  if not q.revoked and not q.invalid and q.header and q.separator and q.syntax and q.relax and q.description and status and status.epoch==q.epoch and status.race==q.race and same_irongrip(q.binding,irongrip_binding(s)) and same_irongrip(q.binding,status.irongrip_binding) then
   b.irongrip_proof={known=q.known==true,epoch=q.epoch,race=q.race,binding=q.binding}
  end
  if b.query==q then b.query=nil end
  b.racial_stream=nil
 end
 b.defence_help_frame=nil
 if b.defence_text_enrolled then b.defence_text_ready=true end
 if b.tattoo_listing then
  if b.tattoo_listing_version==(b.tattoo_version or 0) and not b.tattoo_listing_uncertain and
   not (b.pending and b.pending.tattoo_debited) then
   b.tattoos=b.tattoo_listing;b.tattoos_ready=true
   -- Fresh report status replaces earlier autoactivated positives. An ACTIVE
   -- row still has zero/unknown uses; never manufacture a charge for it.
   for k in pairs(passive_tattoos) do
    local t=b.tattoos[k]
    if not (t and t.active) then
     b.have[k]=nil;b.observed[k]=false
     for id in pairs((s.player or {}).defences or {}) do if observed_key(id)==k then s.player.defences[id]=nil end end
    end
   end
  end
  b.tattoo_listing=nil
  for _,e in ipairs(M.catalog) do if e.tattoo then
   local t=b.tattoos[e.key];b.known[e.key]=t and (t.charges or 0)>0 or nil
  end end
 end
 if b.pending then
  local p=b.pending;p.prompt=b.prompt
  p.prompt_ready=ready(s) and (not p.curative or p.confirmed and p.herb_recovered and b.herb==true and b.prompt>(p.confirmed_prompt or b.prompt))
 end
end
local function percent(v,max)
 v,max=tonumber(v),tonumber(max);if not v or not max or max<=0 then return nil end
 return 100*v/max
end
local function eligible(s,b,e)
 if routed(s,e)then local a=class_proposal(s,e);if a.command==''then return false,a.reason end end
 if e.bash_only and s.mode~='BASH' then return false,'BASH only' end
 -- Public catalog tables are metadata, not authority to reintroduce a producer.
 if sensory[e.key] and index[e.key]~=e then return false,'Retired self-affliction producer' end
 if e.curative and not (b.sensory_optin and b.sensory_optin[e.key]) then return false,'Explicit sensory opt-in required' end
 if e.key=='starburst' and b.starburst_optin~=true then return false,'Explicit current-session Starburst opt-in required' end
 local p=s.player;local hp=percent(p.hp,p.maxhp);local mp=percent(p.mana,p.maxmana)
 if not hp or not mp or hp<65 or mp<50 then return false,'resources' end
 if e.racial and (hp~=hp or mp~=mp or hp==math.huge or mp==math.huge or hp==-math.huge or mp==-math.huge) then return false,'finite resources required' end
 if e.minimum_mana then
  local mana,maxmana=tonumber(p.mana),tonumber(p.maxmana)
  if not mana or mana~=mana or mana==math.huge or not maxmana or maxmana~=maxmana or maxmana==math.huge or mana<e.minimum_mana then return false,'verified mana cost unavailable' end
 end
 if e.requires_full and (hp<100 or mp<100) then return false,'full HP and mana required' end
 if not e.command or e.passive or not M.availability(s,e.key) then return false,'unavailable' end
 if e.antipsychotic_block then
  -- Conservative until the complete current antipsychotic tree is enumerated.
  for _,v in pairs(p.afflictions or {}) do if yes(v) then return false,'clarity requires affliction-free snapshot' end end
 end
 if e.drain then
  local wp=percent(p.willpower,p.maxwillpower)
  if not wp or wp<25 then return false,'willpower reserve unknown/low' end
 end
 if e.depends and not (b.have[e.depends] or canonical_have(s,e.depends)) then return false,'dependency '..e.depends end
 if (b.cooldown[e.key] or 0)>now() or (b.retry[e.key] or 0)>now() then return false,'cooldown' end
 return true
end
local function send_checked(b,sender,command)
 if type(sender)~='function' then fault(b,'Buff sender unavailable; review/reset required');return false end
 local ok,result=pcall(sender,command)
 if not ok or result==false then fault(b,'Buff send failed: '..tostring(result)..'; review/reset required');return false end
 return true
end
local function service(s,runner,sender,hold,policy)
 if M.class_router then local blocked,why=M.class_router.barrier(s,true);if blocked then return {busy=true,status=why}end end
 local b=M.state(s);local t=now()
 if not M.supported_class(b.class) or not connected(s) or s.training_battle_ended then
  M.stop(s,'disconnected/dead/class/training stop');M.invalidate(s)
  b.listing=nil;b.ability_listing=nil
  if b.pending then b.pending.prompt=nil;b.pending.prompt_ready=false end
  return {busy=b.pending~=nil,status=b.status}
 end
 -- Recovery is processed even while intent is disarmed or survival holds.
 local p=b.pending
 if p and p.channel_retry then
  local r=p.channel_retry
  if not p.send_failed and not p.confirmed and not b.fault and r.ready and p.prompt and p.prompt>(r.witness_prompt or p.prompt) and p.prompt_ready and ready(s) then
   -- Retire a proven non-execution, not a successful action. Normal selection
   -- below remains the sole sender and rechecks current intent and every gate.
   b.pending=nil;b.status='Native channel ready after rejected '..p.key;p=nil
  else
   return {busy=true,status=b.fault or 'awaiting fresh native channel readiness after buff rejection'}
  end
 end
 if p then
  if not p.send_failed and not p.rejected and (not(p.shape_reservation or p.earth_reservation)or M.class_router and M.class_router.defense_settled(s,p)) and (not(s.class_observations and s.class_observations.defense_issued and s.class_observations.defense_issued.pending==p)or s.class_observations.defense_issued.native_ready_seq) and (p.key~='irongrip' or same_irongrip_transport(p.irongrip_binding,irongrip_binding(s)) and p.irongrip_own and p.irongrip_gain and p.irongrip_measured and p.irongrip_lost and p.irongrip_recovered and p.prompt and p.prompt>(p.irongrip_witness_prompt or p.prompt)) and p.confirmed and p.prompt and p.prompt>p.dispatched_prompt and (not (index[p.key] and index[p.key].racial) or p.confirmed_prompt and p.prompt>p.confirmed_prompt) and p.prompt_ready and ready(s) and (not p.curative or p.herb_recovered and b.herb==true) then
   if p.earth_reservation and not M.class_router.earth_retire(s,p)then return {busy=true,status='Earthcaller ledger settlement held'}end
   b.pending=nil
   if b.fault==p.timeout_fault then b.fault=nil end
   if s.class_observations and s.class_observations.defense_issued and s.class_observations.defense_issued.pending==p then s.class_observations.defense_issued=nil;if M.class_router then M.class_router.sync_transport(s)end end
   b.retry[p.key]=t+2;b.status='confirmed: '..p.key
   -- Curative resource evidence has a separate lifetime; leave its historical
   -- settlement cadence untouched. Routine skill/tattoo DEFUP can advance.
   if p.curative then return {busy=false,status=b.status} end
   -- Continue through every current policy/readiness gate; one new action
   -- may use this genuinely ready prompt without a settlement-only idle tick.
  else
   if t-p.at>=12 and not b.fault then
    p.timeout_fault='Buff acknowledgement timed out; review/reset required';fault(b,p.timeout_fault)
   end
   -- One reconciliation only, after a real prompt, never activation retry.
   if not p.curative and not b.fault and not p.confirmed and p.prompt and p.prompt>p.dispatched_prompt and not p.queried then
    p.queried=true
    if not send_checked(b,sender,'defences') then p.send_failed=true end
   end
   return {busy=true,status=b.fault or 'awaiting buff confirmation and ready prompt'}
  end
 end
 -- Suppression survives state/reentrant settlement: no discovery, OFF or TOUCH.
 if policy then return {busy=false,status='convenience action unresolved'} end
 if b.fault then return {busy=false,status=b.fault} end
 if b.defence_help_frame or b.defence_text_enrolled and b.defence_text_ready~=true then return {busy=false,status='awaiting native DEFENCE text boundary prompt'} end
 if not b.master and not b.sequence and not next(b.cancel) then return {busy=false,status=b.status} end
 -- Mode constrains new discovery, never settlement of an issued TOUCH above.
 local permitted,mode_blocked=false,false
 for _,e in ipairs(M.catalog) do
  local selected=b.cancel[e.key] or b.sequence and b.todo[e.key] or b.master and b.wanted[e.key]
  if selected then
   if not e.bash_only or s.mode=='BASH' then permitted=true else mode_blocked=true end
  end
 end
 if mode_blocked and not permitted then return {busy=false,status='No selected defence permitted in this mode'} end
 local can_cancel=false
 for _,e in ipairs(M.catalog) do
  if b.cancel[e.key] and e.off and M.availability(s,e.key) then can_cancel=true;break end
 end
 if (hold and not can_cancel) or (s.walker and s.walker.pending) or (runner and (runner.waiting or runner.fault)) or
  (s.mental and (s.mental.eq_pending or s.mental.fault)) or not ready(s) then return {busy=false,status='waiting for safe readiness'} end
 local sensory_only,sensory_available,sensory_selected=true,false,false
 for _,e in ipairs(M.catalog) do
  local selected=b.cancel[e.key] or b.sequence and b.todo[e.key] or b.master and b.wanted[e.key]
  if selected and (not e.bash_only or s.mode=='BASH') and not M.native_catalog[e.key] and in_class(b,e) and not e.passive and not e.tracking_only then
   if not e.curative then sensory_only=false
   else sensory_selected=true;if b.sensory_optin and b.sensory_optin[e.key] and M.sensory_ready(s,e.key) then sensory_available=true end end
  end
 end
 sensory_only=sensory_only and sensory_selected
 if sensory_only and not sensory_available then return {busy=false,status='Sensory goals awaiting explicit opt-in and fresh evidence'} end
 -- An issued racial read stream survives cancellation/scope invalidation until
 -- its footer drains. Never retag an old response as a new race/session query.
 if b.racial_stream then
  local q=b.racial_stream
  if t-q.at>=12 then q.revoked=true;if not b.fault then fault(b,'Buff racial snapshot timed out; review/reset required') end end
  return {busy=false,status=b.fault or 'awaiting scoped racial skills snapshot'}
 end
 -- Unknown authoritative snapshots are solicited once, with a bounded wait.
 if b.query then
  if t-b.query.at>=12 then fault(b,'Buff '..b.query.kind..' snapshot timed out; review/reset required') end
  return {busy=false,status=b.fault or 'awaiting '..b.query.kind..' snapshot'}
 end
 local racial_selected=b.wanted.safeguard and (b.master or b.sequence and b.todo.safeguard)
 local racial_status,racial_proof=b.racial_status,b.racial_proof
 local racial_complete=racial_status and racial_proof and racial_proof.race==racial_status.race and racial_proof.epoch==racial_status.epoch
 local racial_query=racial_selected and racial_status and racial_status.race=='azudim' and not racial_complete
 local irongrip_selected=b.wanted.irongrip and (b.master or b.sequence and b.todo.irongrip) and not b.have.irongrip and not canonical_have(s,'irongrip')
 local irongrip_status=racial_status and racial_status.race~='' and same_irongrip(racial_status.irongrip_binding,irongrip_binding(s))
 local irongrip_complete=b.irongrip_proof and irongrip_status and b.irongrip_proof.epoch==racial_status.epoch and b.irongrip_proof.race==racial_status.race and same_irongrip(b.irongrip_proof.binding,racial_status.irongrip_binding)
 local irongrip_query=irongrip_selected and irongrip_status and not irongrip_complete
 local irongrip_wait=irongrip_selected and not irongrip_status
 local racial_wait=racial_selected and not racial_status and not b.have.safeguard and not canonical_have(s,'safeguard')
 -- Batch only missing selected skill routes, once each. This is read-only;
 -- activation still waits for every requested snapshot and the defence List.
 local groups,ordered={},{}
 for _,e in ipairs(M.catalog) do
  local selected=b.cancel[e.key] or b.sequence and b.todo[e.key] or b.master and b.wanted[e.key]
  if selected and (not e.bash_only or s.mode=='BASH') and in_class(b,e) and not e.racial and not e.curative and not e.tattoo and not e.passive and not e.tracking_only and not M.native_catalog[e.key] and not routed(s,e) and not b.known[e.key] then
   for _,group in ipairs({e.group,e.also_group}) do
    if allowed_group(b.class,group) and not b.groups[group] and not groups[group] then
     groups[group]=true;ordered[#ordered+1]=group
    end
   end
  end
 end
 if #ordered>0 then
  local query={kind='skills',group=ordered[1],groups=groups,at=t};b.query=query
  for _,group in ipairs(ordered) do
   -- A synchronous death/class/intent change may revoke the unsent remainder.
   if b.query~=query or b.fault or not connected(s) then break end
   if not send_checked(b,sender,'ab '..group) then break end
  end
  return {busy=false,status=b.fault or 'requested selected ability snapshots'}
 end
 if not b.defs_known and not sensory_only then
  b.query={kind='defs',at=t};send_checked(b,sender,'defences')
  return {busy=false,status=b.fault or 'requested defence snapshot'}
 end
 local chosen,off
 for _,e in ipairs(M.catalog) do
  if b.cancel[e.key] then
   if e.off and M.availability(s,e.key) then chosen=e;off=true;break end
   b.cancel[e.key]=nil -- Never send unlearned syntax.
  end
 end
 if not chosen and hold then return {busy=false,status='waiting for safe readiness'} end
 if not chosen then
  for _,e in ipairs(M.catalog) do
   local selected=b.sequence and b.todo[e.key] or b.master and b.wanted[e.key]
   if selected and b.wanted[e.key] and not M.native_catalog[e.key] then
    -- An unproven racial goal stays wanted, but must not delay learned core DEFUP.
    if b.todo and not(e.racial and(racial_query or racial_wait or e.key=='irongrip' and(irongrip_query or irongrip_wait)))then b.todo[e.key]=nil end
    local ok=eligible(s,b,e)
    if not b.have[e.key] and not canonical_have(s,e.key) and (routed(s,e) or e.racial or e.curative or b.known[e.key]) and ok then chosen=e;break end
   end
  end
 end
 if not chosen then
  if irongrip_query then
   local q={kind='irongrip',epoch=racial_status.epoch,race=racial_status.race,binding=irongrip_binding(s),at=t};b.query=q;b.racial_stream=q
   if not send_checked(b,sender,'racial help irongrip')then q.revoked=true end
   return {busy=false,status=b.fault or 'requested current racial Irongrip help'}
  end
  if irongrip_wait then return {busy=false,status='awaiting fresh character-bound Status race evidence'}end
  if racial_query then
   local q={kind='racial',epoch=racial_status.epoch,at=t};b.query=q;b.racial_stream=q
   if not send_checked(b,sender,'racial skills')then q.revoked=true end
   return {busy=false,status=b.fault or 'requested own-race racial skills'}
  end
  if racial_wait then return {busy=false,status='awaiting fresh native Status race evidence'}end
  b.sequence=false;b.todo=nil;b.status=b.master and 'maintenance monitoring' or 'defup complete'
  return {busy=false,status=b.status}
 end
 if off then b.cancel[chosen.key]=nil end
 local command=off and chosen.off or chosen.command
 if routed(s,chosen)then
  if off then return {busy=false,status='No foreign class cancellation'}end
  local a=class_proposal(s,chosen);if a.command==''then return {busy=false,status=a.reason}end
  command=a.command
 end
 p={key=chosen.key,off=off==true,at=t,dispatched_prompt=b.prompt,confirmed=false,previous_cooldown=b.cooldown[chosen.key]}
 b.pending=p -- Before calling the sender: synchronous fake callbacks cannot double-send.
 if chosen.key=='irongrip' then p.irongrip_binding=irongrip_binding(s);b.irongrip_proof=nil end -- one activation per current selected Known proof
 if chosen.curative then
  p.curative=true
  -- Static pair only; never a separator, cache alias, or caller-supplied command.
  local pill=sensory[chosen.key]
  if chosen.prepare~='outc '..pill or command~='eat '..pill then p.send_failed=true;fault(b,'Invalid curative recipe');return {busy=true,status=b.fault} end
  if not send_checked(b,sender,chosen.prepare) then p.send_failed=true;return {busy=true,status=b.fault} end
  -- Reentrant ingestion may revoke intent, resource or session proof.
  if b.pending~=p or b.have[chosen.key] or canonical_have(s,chosen.key) or not connected(s) or not b.sensory_optin or not b.sensory_optin[chosen.key] or not b.wanted[chosen.key] or not (b.master or b.sequence) or not eligible(s,b,chosen) or hold or runner and (runner.waiting or runner.fault) then
   p.send_failed=true;fault(b,'Curative interrupted after withdrawal; review/reset required');return {busy=true,status=b.fault}
  end
  b.sensory_context=nil;b.sensory_epoch=(b.sensory_epoch or 0)+1
  p.eat_started=true
 end
 if not off and chosen.tattoo then
  local tattoo=b.tattoos[chosen.key];tattoo.charges=tattoo.charges-1
  p.tattoo_debited=true;b.tattoo_version=(b.tattoo_version or 0)+1
 end
 if not off and chosen.cooldown_activation then b.cooldown[chosen.key]=t+chosen.cooldown_activation end
 if routed(s,chosen)then
  -- Existing Buffs pending is the sole defense lifecycle owner. No adapter commit.
  local a=class_proposal(s,chosen,p)
  local o=s.class_observations
  if a.command~=command or not M.class_router.reserve_defense then b.pending=nil;return {busy=false,status='Class shared-ledger reservation unavailable'}end
  local mirrored,mirror_reason=M.class_router.sync_transport(s)
  if not mirrored then b.pending=nil;return {busy=false,status=mirror_reason}end
  local reserved=M.class_router.reserve_defense(s,chosen.key,a,p)
  if reserved~=true then b.pending=nil;return {busy=false,status='Class shared-ledger reservation denied'}end
  o.defense_issued={class=s.player.class,key=chosen.key,pending=p,scope=o.class and o.class.scope,seq=o.sequence,at=t}
  M.class_router.sync_transport(s)
 end
 local ok=send_checked(b,sender,command)
 if not ok then p.send_failed=true end
 b.status=b.fault or 'sent: '..command
 return {busy=true,status=b.status}
end
function M.service(s,runner,sender,hold,policy)
 local b=M.state(s)
 if b.servicing then return {busy=b.pending~=nil,status='buff service reentrant; deferred'} end
 b.servicing=true
 local ok,result=pcall(service,s,runner,sender,hold,policy)
 b.servicing=false
 if not ok then fault(b,'Buff service error: '..tostring(result)..'; review/reset required');return {busy=b.pending~=nil,status=b.fault} end
 return result
end
return M
