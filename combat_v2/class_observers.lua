-- Passive bridge called ONLY by the existing ingress owners. No registration/IO.
local M={version='six-class-ingress-v4-earthcaller-review'}
local function now()return getEpoch and getEpoch()or os.time()end
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function scope(o)return {session=o.session,life=o.life,epoch=o.epoch}end
local function names(p)
 local t={};for _,v in ipairs(type(p)=='table'and p or {})do local n=type(v)=='table'and v.name or v;if type(n)=='string'then t[n:lower():gsub('%s+','_')]=true end end;return t
end
function M.attach(s,modules)
 local o=s.class_observations or {sequence=0,session='cv2-session-1',session_serial=1,life=1,epoch=1,cache={},contracts={},unknown={}}
 s.class_observations=o;o.modules=modules
 -- Reload revokes evidence, not issued work; it is not a new native life/session.
 M.revoke(s,'cold/reload')
 return o
end
function M.revoke(s,why)
 local o=s.class_observations;if not o then return end
 o.survival_frame=nil -- Incomplete AB framing is not durable learned knowledge.
 o.class=nil;o.defenses=nil;o.cache={};o.contracts={};o.learned={};o.archivist_learned=nil;o.archivist_groups=nil;o.unknown={reason=why};o.version=(o.version or 0)+1
 s.class_scope=scope(o);s.session_id=o.session;s.life_generation=o.life;s.class_generation=o.epoch
 local m=o.modules or {}
 if m.Earthcaller then m.Earthcaller.invalidate(s,why)end
 if m.Wayfarer then m.Wayfarer.invalidate(s,{session=o.session,life=o.life,epoch=o.epoch,class=s.player.class})end
 if m.Infiltrator then m.Infiltrator.invalidate(s,why)end
 if m.Shapeshifter then m.Shapeshifter.invalidate(s,why)end
 if m.Archivist then s.archivist=s.archivist or m.Archivist.new(scope(o));m.Archivist.invalidate(s.archivist,scope(o),why)end
 for _,key in ipairs({'wayfarer','earthcaller','infiltrator','archivist','shapeshifter'})do if s[key]then s[key].wanted={} end end
end
-- Character-wide Survival receipts: only this existing native ingress writes them.
-- Original records survive class changes; readiness/consent never comes from AB.
local survival_names={swimming=true,treading=true,fluidswim=true}
local function survival_ingress(s,o,record)
 local source,raw=record.source,record.raw
 if source=='Char.Status'and type(raw)=='table'and type(raw.name)=='string'and raw.name~=''then
  if o.character and o.character~=raw.name then o.survival=nil;o.survival_frame=nil end
  o.character=raw.name
 end
 local character=o.character
 if not character then return end
 local t=o.survival
 if not t or t.session~=o.session or t.character~=character then
  t={session=o.session,character=character,skills={}};o.survival=t
 end
 if source=='Char.Skills.List'and type(raw)=='table'and type(raw.group)=='string'and raw.group:lower()=='survival'and type(raw.list)=='table'then
  -- A real replacement list revokes omitted/unknown entries; strings do not prove Known.
  t.skills={}
  for _,v in ipairs(raw.list)do
   if type(v)=='table'and type(v.name)=='string'and survival_names[v.name:lower()]
    and(v.known==true or v.known==1 or v.known=='Yes')and v.inactive~=true then
    t.skills[v.name:lower()]={known=true,record=record}
   end
  end
 elseif source=='native.text'and type(raw)=='string'then
  local name,known=raw:match('^([%a]+) %(Survival%)%s+Known:%s+(%a+)%s+%(%d+ lessons?%)%s*$')
  if not name then name,known=raw:match('^([%a]+) %(Survival%)%s+Known:%s+(%a+)%s*$')end
  name=name or raw:match('^([%a]+) %(Survival%)%s*$')
  if name then
   o.survival_frame=survival_names[name:lower()]and {name=name:lower(),header=record}or nil
  elseif raw:match('^.+ %([%a ]+%)')then o.survival_frame=nil end
  local f=o.survival_frame
  if f and record.at-f.header.at<=8 and record.seq-f.header.seq<=80 then
   known=known or raw:match('^Known:%s+(%a+)%s+%(%d+ lessons?%)%s*$')or raw:match('^Known:%s+(%a+)%s*$')
   if known then
    t.skills[f.name]=known=='Yes'and {known=true,record=record,header=f.header}or nil
   end
   if f.name=='swimming'and raw:match('^Syntax:%s+SWIM%s+<direction>%s*$')then t.syntax=record end
  else o.survival_frame=nil end
 elseif source=='native.prompt'then o.survival_frame=nil end
end
-- `source` is the exact event at its actual owner, never a cache refresh call.
function M.ingress(s,source,raw)
 local o=s.class_observations;if not o then return false end
 local at=now();o.sequence=o.sequence+1;s.native_event_sequence=o.sequence;s.clock=at
 -- Earthcaller durable equipment is valid only under this exact enrolled
 -- observer/adapter/scope. A gap revokes proof, never an issued transport.
 local earth=s.earthcaller;local em=o.modules and o.modules.Earthcaller
 if earth and earth.observer then
  local c=earth.observer
  if source=='observer.gap' or c.version~=o.version or c.observer~=M.version or not em or c.adapter~=em.version or c.session~=o.session or c.life~=o.life or c.epoch~=o.epoch then
   em=em or {};if em.invalidate then em.invalidate(s,'Earthcaller observer continuity gap')end
  end
 end
 o.observer_version=M.version
 if s.shapeshifter then s.shapeshifter.now=at end
 if source=='sysDisconnectionEvent'then
  o.survival=nil;o.survival_frame=nil;o.character=nil
  o.session_serial=o.session_serial+1;o.session='cv2-session-'..o.session_serial;M.revoke(s,'disconnect');o.last_alive=nil;return true
 end
 -- Continuous tracking is revoked on known observer gaps/version/scope mismatch.
 -- No elapsed-time poll or cache-restamping substitutes for genuine ingress.
 local shape=s.shapeshifter
 if o.class and o.class.value=='Shapeshifter' and shape then
  local module=o.modules and o.modules.Shapeshifter
  local gap=source=='observer.gap' or shape.observer_valid~=true or shape.observer_version~=M.version or shape.observer_generation~=o.version or not module or shape.adapter_version~=module.version or shape.session~=o.session or shape.life~=o.life or shape.epoch~=o.epoch
  local spec=source=='Char.Status' and type(raw)=='table' and raw.spec
  local contradiction=type(spec)=='string' and spec~='' and ((shape.specialization and shape.specialization.value~=spec) or (shape.form and shape.form.value~=spec))
  if gap or contradiction then o.epoch=o.epoch+1;M.revoke(s,gap and 'observer continuity gap' or 'genuine specialization contradiction') end
 end
 if source=='observer.gap' then return true end
 -- Character identity is independent of a partial packet's class field. Revoke
 -- before the existing identity owner accepts the new name, including name-only
 -- Status; a same-name partial packet is not a new class observation.
 if source=='Char.Status' and type(raw)=='table' and type(raw.name)=='string' and raw.name~='' and o.character and o.character~=raw.name
  and (o.last_class=='Earthcaller' or s.player.class=='Earthcaller' or raw.class=='Earthcaller') then
  o.epoch=o.epoch+1;M.revoke(s,'genuine Earthcaller character change')
 end
 if source=='Char.Status'and type(raw)=='table'and type(raw.class)=='string'and raw.class~=''then
  if o.last_class and o.last_class~=raw.class then o.epoch=o.epoch+1;M.revoke(s,'genuine class change')end
  o.last_class=raw.class;s.player.class=raw.class
 elseif source=='Char.Vitals'and type(raw)=='table'and tonumber(raw.hp)then
  local alive=tonumber(raw.hp)>0
  if o.last_alive~=nil and o.last_alive~=alive then o.life=o.life+1;M.revoke(s,'genuine life transition')end
  o.last_alive=alive
 end
 local record={source=source,at=at,seq=o.sequence,scope=scope(o),raw=copy(raw),version=o.version,observer=M.version}
 survival_ingress(s,o,record)
 o.cache[source]=record
 -- Retain one bounded diagnostic history; original time/sequence/raw never restamped.
 o.history=o.history or {};o.history[#o.history+1]=record;if #o.history>128 then table.remove(o.history,1)end
 local cl=s.player.class;local m=o.modules
 if source=='Char.Status'and type(raw)=='table'and type(raw.class)=='string'and raw.class~=''then
  o.class={value=raw.class,at=at,seq=o.sequence,scope=scope(o),observer=M.version}
  if m.Earthcaller then m.Earthcaller.status(s,raw.class,o.session)end
  if cl=='Earthcaller' and m.Earthcaller then
   s.earthcaller.observer={version=o.version,observer=M.version,adapter=m.Earthcaller.version,session=o.session,life=o.life,epoch=o.epoch}
  end
  if cl=='Wayfarer'then
   local w=s.wayfarer;w.class=cl;w.identity={class=cl,session=o.session,life=o.life,epoch=o.epoch,native=true,source=source,at=at,seq=o.sequence}
  elseif cl=='Archivist'then
   m.Archivist.observe(s.archivist,'class',{native=true,source=source,seq=o.sequence,at=at,scope=scope(o),raw_ref=source..':'..o.sequence,value=raw.class},at)
  elseif cl=='Shapeshifter'then
   local c=s.shapeshifter or {capabilities={},resources={},channels={},cooldowns={},defenses={},wanted={}};s.shapeshifter=c
   c.session=o.session;c.life=o.life;c.epoch=o.epoch;c.now=at
   c.observer_valid=true;c.observer_version=M.version;c.observer_generation=o.version;c.adapter_version=m.Shapeshifter.version
   if not c.class then c.class={value=cl,observed=true,native=true,source=source,session=o.session,life=o.life,epoch=o.epoch,at=at,tracked=true,seq=o.sequence,observer=M.version,observer_generation=o.version,adapter_version=m.Shapeshifter.version} end
   -- Specialization alone is not mutation; passive adapter normalizes exact DEF/AB frames below.
  elseif cl=='Infiltrator'then
   s.infiltrator=s.infiltrator or {groups={},skills={},gear={},cooldowns={},wanted={}}
   s.infiltrator.status={class=cl,source=source,live=true,session=o.session,life=o.life,epoch=o.epoch,at=at,expires=at+30}
  end
 elseif source=='Char.Skills.List'and o.class and o.class.value==cl and type(raw)=='table'and type(raw.group)=='string'and type(raw.list)=='table'then
  local accepted={};local learned={}
  for _,v in ipairs(raw.list)do
   -- No rank/help/accessibility inference. Unknown/strings remain diagnostic.
   if type(v)=='table'and type(v.name)=='string'and(v.known==true or v.known==1 or v.known=='Yes')and v.inactive~=true then
    accepted[#accepted+1]={name=v.name,known=true};learned[raw.group:lower()..'.'..v.name:lower()]={known=true,active=true}
   end
  end
  o.learned[raw.group]=record
  if cl=='Earthcaller'then
   -- Genuine IRE lists contain strings, not fabricated Known flags. Membership
   -- alone never grants a skill: require its separate exact native Known header.
   o.earth_string_lists=o.earth_string_lists or {}
   local members={};local valid=true;local n,max=0,0
   for k,v in pairs(raw.list)do
    if type(k)~='number'or k<1 or k%1~=0 then valid=false else n=n+1;max=math.max(max,k)end
    if type(v)=='string'then local key=v:lower();if not key:match('^[%a][%a_%-]*$')or members[key]then valid=false else members[key]=true end else valid=false end
   end
   o.earth_string_lists[raw.group:lower()]=valid and n==max and {record=record,epoch=s.earthcaller.epoch,members=members,proofs={},structured=accepted}or nil
   m.Earthcaller.skills(s,raw.group,accepted,{source='native-skill-list',epoch=s.earthcaller.epoch,session=o.session,at=at})
  elseif cl=='Wayfarer'then
   local w=s.wayfarer
   for key,recipe in pairs(m.Wayfarer.source_index)do if recipe.group:lower()==raw.group:lower()then
    w.learned[recipe.group..'.'..recipe.ability]=nil
    for _,v in ipairs(raw.list)do if type(v)=='table'and type(v.name)=='string'and v.name:lower()==recipe.ability:lower()and(v.known==true or v.known==1 or v.known=='Yes')and(v.active==true or v.inactive==false)then
     w.learned[recipe.group..'.'..recipe.ability]={class=cl,session=o.session,life=o.life,epoch=o.epoch,native=true,learned=true,active=true,source=source,at=at,seq=o.sequence,observer=M.version}
    end end
   end end
  elseif cl=='Infiltrator'then
   local c=s.infiltrator
   local prefix=raw.group:lower()..'.';for k in pairs(c.skills)do if k:sub(1,#prefix)==prefix then c.skills[k]=nil end end
   for _,v in ipairs(raw.list)do if type(v)=='table'and type(v.name)=='string'and(v.known==true or v.known==1 or v.known=='Yes')and(v.active==true or v.inactive==false)then
    c.skills[raw.group:lower()..'.'..v.name:lower()]={class=cl,session=o.session,life=o.life,epoch=o.epoch,live=true,known=true,learned=true,active=true,source=source,at=at,expires=at+30,seq=o.sequence,observer=M.version}
   end end
  elseif cl=='Archivist'then
   -- The single-module envelope uses the OLDEST contributing original time.
   -- A new group packet must never renew a cached group's learning timestamp.
   o.archivist_groups=o.archivist_groups or {};o.archivist_groups[raw.group]={at=at,value=learned}
   local combined={};local oldest=at
   for _,group in pairs(o.archivist_groups)do oldest=math.min(oldest,group.at);for k,v in pairs(group.value)do combined[k]=v end end
   m.Archivist.observe(s.archivist,'learned',{native=true,source=source,seq=o.sequence,at=oldest,scope=scope(o),raw_ref=source..':'..o.sequence,value=combined},at)
  end
 elseif source=='Char.Skills.Groups'and cl=='Infiltrator'and o.class and type(raw)=='table'then
  s.infiltrator.groups={}
  for _,v in ipairs(raw)do if type(v)=='table'and type(v.name)=='string'and v.active==true then
   s.infiltrator.groups[v.name:lower()]={session=o.session,life=o.life,epoch=o.epoch,source=source,live=true,active=true,at=at,expires=at+30,seq=o.sequence,observer=M.version}
  end end
 elseif source=='Char.Defences.List'and o.class and type(raw)=='table'then
  o.defenses={active=names(raw),complete=true,at=at,seq=o.sequence,scope=scope(o),observer=M.version}
 elseif(source=='Char.Defences.Add'or source=='Char.Defences.Remove')and o.defenses then
  local n=type(raw)=='table'and raw.name or raw
  if type(n)=='string'then o.defenses.active[n:lower():gsub('%s+','_')]=source=='Char.Defences.Add'or nil;o.defenses.last_delta=record end
 elseif cl=='Earthcaller' and source:match('^Char%.Items%.') then
  -- Payloads do not establish binding/calcification. Conservatively revoke on
  -- inventory/equipment deltas; room movement/item frames do not expire gear.
  if type(raw)~='table' or raw.location~='room' then
   local e=m.Earthcaller.state(s);e.equipment=nil;e.effects.lavacoat=nil
  end
 elseif source=='native.text'and cl=='Earthcaller'and o.class then
  -- Join an actual string-list receipt with explicit Known: Yes/No from a
  -- separately received native AB header. Never synthesize a GMCP event/raw flag.
  local line=type(raw)=='string'and raw:gsub(string.char(27)..'%[[%d;]*m',''):match('^%s*(.-)%s*$')or ''
  local ability,group,known=line:match('^([%a]+) %(([%a]+)%)%s+Known:%s+(%a+)%s+%(%d+ lessons?%)%s*$')
  if not ability then ability,group,known=line:match('^([%a]+) %(([%a]+)%)%s+Known:%s+(%a+)%s*$')end
  local slot=group and o.earth_string_lists and o.earth_string_lists[group:lower()]
  if slot and slot.epoch==s.earthcaller.epoch and o.learned[group:lower()]==slot.record
   and slot.record.version==o.version and slot.record.scope.session==o.session and slot.record.scope.life==o.life and slot.record.scope.epoch==o.epoch
   and slot.members[ability:lower()]then
   if known=='Yes'then
    if at>=slot.record.at and at-slot.record.at<=5 then slot.proofs[ability:lower()]=record end
   else slot.proofs[ability:lower()]=nil end
   -- A newer explicit negative revokes even if the positive-acquisition window
   -- has expired; freshness is never permission to ignore contradictory facts.
   if known~='Yes'then
    local skill=s.earthcaller.skills[group:lower()]
    if skill then skill.known[ability:lower()]=nil end
    for i=#slot.structured,1,-1 do if slot.structured[i].name:lower()==ability:lower()then table.remove(slot.structured,i)end end
   end
   local accepted={};for _,v in ipairs(slot.structured)do accepted[#accepted+1]=v end
   for key in pairs(slot.proofs)do accepted[#accepted+1]={name=key,known=true}end
   m.Earthcaller.skills(s,group,accepted,{source='native-skill-list',epoch=s.earthcaller.epoch,session=o.session,at=math.min(at,slot.record.at)})
  end
  -- Exact source-backed swarm response only; no generic resource/equipment guesses.
  m.Earthcaller.text(s,raw,true,{source='native-text',session=o.session,epoch=s.earthcaller.epoch,at=at})
 end
 if cl=='Earthcaller' and o.class and m.Earthcaller and m.Earthcaller.observe then m.Earthcaller.observe(s,source,raw,record) end
 if cl=='Shapeshifter' and o.class and m.Shapeshifter then m.Shapeshifter.observe(s,source,raw,record) end
 if m.Shapeshifter and m.Shapeshifter.observe_defense_settlement then m.Shapeshifter.observe_defense_settlement(s,source,raw,record) end
 local issued=o.defense_issued
 if issued and issued.scope and issued.scope.session==o.session and issued.scope.life==o.life and issued.scope.epoch==o.epoch and o.sequence>issued.seq then
  if (source=='Char.Defences.List'or source=='Char.Defences.Add')and o.defenses and o.defenses.active[issued.key]then issued.native_confirm_seq=o.sequence end
  if source=='native.prompt'and issued.native_confirm_seq and o.sequence>issued.native_confirm_seq and s.player.balance==true and s.player.equilibrium==true then issued.native_ready_seq=o.sequence end
 end
 o.unknown.protocol='No certified class-native syntax/cost/channel/ACK protocol observations'
 o.unknown.equipment='Items payload retained raw; bound/calcified/wield/venom/form meaning unknown'
 o.unknown.resources='Unknown class resource keys are raw only; no zero/default conversion'
 o.unknown.target='No absent flags converted to explicit false or positive NPC certification'
 if cl=='Earthcaller' then
  o.unknown.protocol='Quash own ACK/consumed-channel/recovery chronology not captured; issued attacks remain unknown'
  o.unknown.equipment=s.earthcaller.equipment and 'Native unique inventory + Vitals wield + self-bound Magic WEAPONPROBE continuously tracked with original receipts' or 'Require genuine unique inventory, explicit Vitals wield IDs, character identity and complete self-bound Magic WEAPONPROBE'
  o.unknown.resources='Raw charstats fervour (native AB capacity 65000) and impurity (capacity UNKNOWN); framed COUNT generation; shared reserve/commit/debit API, no percentage-cost conversion'
  o.unknown.target='Existing Runner binds canonical Core/preset current FULL + attack policy; eligibility recomputed without restamping FULL'
 end
 if cl=='Shapeshifter' then
  o.unknown.protocol='Four reviewed Werewolf defense schemas require new current-class/framed DEF/own AB/raw Vitals and existing Buffs reservation/Add/debit/recovery/prompt; Bracing/Berserk/offense remain held'
  o.unknown.resources='Raw lowercase Char.Vitals.madness stays scoped; defense budgets are single-context observed debits, mismatches hold issued work; offense costs/recovery remain unknown/unapproved'
 end
 return true
end
function M.text_lifecycle(s)
 local o=s.class_observations
 if o and o.last_alive==true and s.player.dead==true then
  o.life=o.life+1;o.last_alive=false;M.revoke(s,'existing native text owner confirmed death')
 end
end
return M
