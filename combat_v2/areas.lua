-- Native, send-free area catalog and selector. No legacy Lua is loaded.
local M={catalog={}}
-- Private received facts: recovery evidence is deliberately NOT attack approval.
local incoming=setmetatable({},{__mode='k'});local incoming_serial=0
local incoming_generations=setmetatable({},{__mode='k'})
local hostile_loyals=setmetatable({},{__mode='k'}) -- endpoint veto only, never attack authority
local function now()return getEpoch and getEpoch()or os.clock()end
local function key(v)return tostring(v or ''):lower()end
local function same(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
function M.living(it)
 if type(it)~='table'then return false end
 local a=tostring(it.attrib or '')
 return not a:find('d',1,true)and not a:find('x',1,true)and not a:find('p',1,true)and (a:find('m',1,true)~=nil or it.icon=='monster')
end
function M.complete(payload)
 if type(payload)~='table'or payload.location~='room'or type(payload.items)~='table'then return false end
 local seen,n,max={},0,0
 for i,it in pairs(payload.items)do
  if type(i)~='number'or i<1 or i%1~=0 or type(it)~='table'or not tostring(it.id):match('^%d+$')or type(it.name)~='string'or it.name==''or it.attrib~=nil and type(it.attrib)~='string'or seen[tostring(it.id)]then return false end
  seen[tostring(it.id)]=true;n=n+1;max=math.max(max,i)
 end
 return max==n
end
function M.invalidate(s,keep_encounter)
 incoming[s]=nil
 incoming_generations[s]=nil
 if not s.connected or s.player and s.player.dead then hostile_loyals[s]=nil end
 s.hunting.area_snapshot=nil;s.hunting.area_dirty=true
 s.hunting.defensive=nil;s.hunting.defensive_fragment=nil
 local used=s.hunting.defensive_refresh
 if used and (used.room~=s.room.id or used.area~=s.room.area)then s.hunting.defensive_refresh=nil end
 if not keep_encounter then s.hunting.encounter=nil end
end
function M.scope(s)
 local p=s.hunting.preset
 return p and same(p.area,s.room.area)and p or nil
end
-- Explicit private configuration; room sets are mapper IDs supplied by the operator.
-- No graph/room/account data is shipped in this module.
function M.configure(s,id,area,rooms,encounter)
 local row=M.catalog[key(id)]
 if not row then return false,'unknown area preset'end
 if type(area)~='string'or area==''or area~=s.room.area then return false,'explicit current area name required'end
 local w=s.walker or {}
 if w.active or w.offer or w.pending or w.dispatching or w.arrival_hold or w.restock_checkpoint then return false,'stop walking and settle before configuring preset'end
 if row.requires_rooms and type(rooms)~='table'then return false,'preset requires reviewed private room allowlist'end
 local allowed
 if rooms then
  allowed={};local n=0
  for room,yes in pairs(rooms)do if yes~=true or not tostring(room):match('^%d+$')then return false,'invalid room allowlist'end;allowed[tostring(room)]=true;n=n+1 end
  if n==0 then return false,'empty room allowlist'end
 end
 local names={knight="a gargantuan, nightmarish knight"}
 for role,name in pairs(encounter or {})do
  if (role~='shard'and role~='nest'and role~='knight')or type(name)~='string'or name==''then return false,'invalid exact encounter name'end
  names[role]=key(name)
 end
 s.hunting.preset={id=key(id),area=area,rooms=allowed,encounter=names,cutter_limit=4}
 M.invalidate(s);s.hunting.verified_generation=nil
 return true,'Preset configured; stationary, fresh IH and walking YES still required'
end
function M.select(s,id)
 id=key(id);local row=M.catalog[id]
 if not row then return false,'unknown area preset'end
 if not row.areas[key(s.room.area)]then return false,'area name unverified; use explicit private configure with observed area/room scope'end
 return M.configure(s,id,s.room.area)
end
-- Session-only stationary discovery intent, enrolled by the existing BASH command.
-- Catalog aliases are exact source facts. No mapper labels or global mob union.
function M.auto_scope(s)
 local h=s.hunting;local w=s.walker or {}
 if not h.area_auto_intent or w.enabled or w.active or w.offer or w.pending or w.dispatching or w.arrival_hold or w.restock_checkpoint then h.area_auto=nil;return false end
 if h.area_auto_suspended then h.area_auto=true;h.area_auto_hold=h.area_auto_suspended;return true,h.area_auto_hold end
 local p=h.preset
 if p and not p.automatic then h.area_auto=nil;return false end -- retain explicit restricted configuration
 local chosen,reason
 for id,row in pairs(M.catalog)do
  if row.areas[key(s.room.area)]then
   if chosen then reason='ambiguous native area; explicit reviewed preset required' end
   chosen=chosen or id
  end
 end
 local row=chosen and M.catalog[chosen]
 reason=reason or (not row and 'unknown native area; no approved catalog')
  or (row and (row.requires_rooms or chosen=='tiyen')and 'restricted encounter/room preset; explicit review required')
 if not p or p.area~=s.room.area or p.id~=chosen or reason then
  h.preset=nil;h.verified_generation=nil;h.auto_certificate=nil;h.area_dirty=true
  h.query=nil;h.target_name=nil;h.manual_target=nil
  if not reason then h.preset={id=chosen,area=s.room.area,automatic=true,encounter={},cutter_limit=4}end
 end
 h.area_auto=true;h.area_auto_hold=reason
 return true,reason
end
function M.auto_certified(s)
 local q=s.hunting.auto_certificate
 return q and q.room==s.room.id and q.area==s.room.area and q.items==s.room.items and q.version==s.room.item_version and M.fresh(s)
end
function M.snapshot(s,payload)
 s.hunting.area_snapshot=nil;s.hunting.area_dirty=true
 if not M.complete(payload)then return false end
 s.hunting.area_snapshot={room=s.room.id,area=s.room.area,items=s.room.items,version=s.room.item_version,at=now()}
 return true
end
function M.fresh(s)
 local q=s.hunting.area_snapshot
 return s.connected and q and same(q.room,s.room.id)and same(q.area,s.room.area)and q.items==s.room.items and q.version==s.room.item_version
end
-- Received attack evidence is ephemeral, never a catalog write. Templates are
-- exact sourced server messages, not a universal English attack recognizer.
local attacks={
 -- Captured own attacks, death-console.txt 33-34,70-71,124 in the fatal Farsai archive.
 -- Recovery-only: actual mV/burst role semantics have NOT been reviewed for offense.
 {name='a horrendous abomination',line='A horrendous abomination charges at you, knocking you painfully to the ground as its shadowy form tramples your body.',wrapped=true,recovery_only=true,source='2026-11-25_16-09-46_monk-farsai-finite-test/death-console.txt:33-34'},
 {name='a horrendous abomination',line='A horrendous abomination charges at you, plunging its sword-like tusks deep into your body before pulling them out with a spray of blood.',wrapped=true,recovery_only=true,source='2026-11-25_16-09-46_monk-farsai-finite-test/death-console.txt:70-71'},
 {name='a horrendous abomination',line='A horrendous abomination rams its bony skull into yours.',recovery_only=true,source='2026-11-25_16-09-46_monk-farsai-finite-test/death-console.txt:124'},
 -- Captured own-directed aggression/damage: death-incident-buffer.json, 2026-11-24.
 -- Name is sourced; no native FULL ID/flags have been recovered. Metadata remains mandatory.
 {name="a lean Shil'tok scout",line="A lean Shil'tok scout snarls angrily at you and moves in for the kill.",wrapped=true,required_class='monk',source="Native own aggression/damage, Ia'shal Barrow room 8761; 2026-11-24_14-42-10_buffed-bash70-80/death-incident-buffer.json"},
 {name="a lean Shil'tok scout",line="A lean Shil'tok scout rakes its black-tinged claws across your face, spattering blood across the room in a visceral arc.",wrapped=true,required_class='monk',source="Native own aggression/damage, Ia'shal Barrow room 8761; 2026-11-24_14-42-10_buffed-bash70-80/death-incident-buffer.json"},
 {name="a lean Shil'tok scout",line="A lean Shil'tok scout lurches forward, face splitting open with a sickly squelch as it bites down upon you with its fanged maw.",wrapped=true,required_class='monk',source="Native own aggression/damage, Ia'shal Barrow room 8761; 2026-11-24_14-42-10_buffed-bash70-80/death-incident-buffer.json"},
 {name='a warbling hobgobbler',line='Its head swinging about erratically, a warbling hobgobbler pecks at your eyes wildly!',source='Observed native self attack, Three Rock Outpost, 2026-11-23'},
 {name='a wolf',line='With a guttural growl, a wolf leaps forward and sinks his teeth into you.',source='AC2.2 Sentinel classattacks - passive; legacy exact template (not a newly observed wild wolf)'},
 {name='a grumpy badger',line='You wince in pain as a grumpy badger rakes her claws across your flesh.',source='AC2.2 Sentinel classattacks - passive; legacy exact template'},
}
local protected={['clive, a sly-looking bandit']=true,['khabarak, the jeweler']=true,['belok, the mining chief']=true,['thelvoro stonefist']=true}
local function defendable(s,it)
 if not M.living(it)then return false end
 local n=key(it.name)
 -- Unknown flags/icons are not proof of a free, hostile NPC. In particular
 -- reject player, corpse, loyal, vendor and mount metadata, not just names.
 if it.attrib~='m'and not(it.attrib==''and it.icon=='monster')then return false end
 if it.icon~=nil and it.icon~='monster'and it.icon~='face-angry-horns'then return false end
 if protected[n]or n:find('guard',1,true)or n:find('loyal',1,true)or n:match('%f[%a]mounts?%f[%A]')or n:match('%f[%a]mounted%f[%A]')or n:find('horse',1,true)or n:find('steed',1,true)or n:match('%f[%a]rocs?%f[%A]')then return false end
 if s.policy and s.policy.players and s.policy.players[n]then return false end
 return true
end
-- Recovery may leave a genuinely attacking excluded NPC; it may not attack it.
local function pressure_identity(s,it)
 if not M.living(it)or type(it.attrib)~='string'then return false end
 if it.attrib~='m'and it.attrib~='mV'and not(it.attrib==''and it.icon=='monster')then return false end
 if it.icon~=nil and it.icon~='monster'and it.icon~='face-angry-horns'and it.icon~='burst'then return false end
 local n=key(it.name)
 return not(n:find('loyal',1,true)or n:find('mount',1,true)or n:find('horse',1,true)or n:find('steed',1,true)or n:find('roc',1,true))and not(s.policy and s.policy.players and s.policy.players[n])
end
function M.endpoint_loyal_dependency_hostile(s,id)
 local r=(hostile_loyals[s]or {})[tostring(id)]
 -- A negative dependency veto is not retired by departure or silence.
 return r~=nil and s.connected==true and r.class==s.player.class and now()>=r.at or false
end
function M.endpoint_loyal_hostile(s,id)
 local r=(hostile_loyals[s]or {})[tostring(id)];local it=(s.room.items or {})[tostring(id)]
 -- Negative safety evidence survives identical FULL/polling. Silence is not a
 -- hostility cure; only current entity/scope membership can make it irrelevant.
 return r~=nil and s.connected==true and r.class==s.player.class
  and now()>=r.at and it~=nil and it.name==r.name and it.attrib==r.attrib and it.icon==r.icon or false
end
function M.incoming_pressure(s)
 local r=incoming[s];local q=s.hunting.area_snapshot;local it=r and s.room.items[r.id]
 if not r or s.mode~='BASH'or not M.fresh(s)or s.hunting.area_recovery or not q.at or now()<q.at or now()-q.at>30
  or now()<r.at or now()-r.at>8 or r.room~=s.room.id or r.area~=s.room.area or r.class~=s.player.class
  or r.items~=s.room.items or r.version~=s.room.item_version or r.item~=it or not pressure_identity(s,it)
  or r.name~=it.name or r.attrib~=it.attrib or r.icon~=it.icon then return nil end
 local n=0;for _,v in pairs(s.room.items)do if v.name==r.name then n=n+1 end end
 if n~=1 then return nil end
 -- Copy facts; public diagnostic mutations cannot mint or renew a receipt.
 return {seq=r.seq,at=r.at,generation=r.generation,room=r.room,area=r.area,class=r.class,id=r.id,name=r.name,attrib=r.attrib,icon=r.icon,source=r.source}
end
function M.defensive_eligible(s,id)
 id=tostring(id);local d=s.hunting.defensive;local r=d and d[id];local it=s.room.items[id];local q=s.hunting.area_snapshot
 if r and r.required_class and tostring(s.player.class or ''):lower()~=r.required_class then return false end
 if s.mode~='BASH'or not r or not M.fresh(s)or s.hunting.area_recovery or not q.at or now()<q.at or now()-q.at>30 then return false end
 if now()<r.at or now()-r.at>15 or r.room~=s.room.id or r.area~=s.room.area or r.items~=s.room.items or r.version~=s.room.item_version or r.item~=it then return false end
 if not it or r.name~=it.name or r.attrib~=it.attrib or r.icon~=it.icon or not defendable(s,it)or(s.hunting.killed_ids or {})[id]then return false end
 local n=0;for _,v in pairs(s.room.items)do if v.name==r.name then n=n+1 end end
 return n==1
end
-- Assemble only a contiguous exact prefix of a sourced wrapped template.
-- No arbitrary narrative concatenation, cached-event replay or substring authority.
local function attack_frame(s,text)
 local old=s.hunting.defensive_fragment;s.hunting.defensive_fragment=nil
 if not s.connected or s.mode~='BASH'or type(text)~='string'then return text end
 local q=s.hunting.area_snapshot
 local function prefix(value)
  for _,t in ipairs(attacks)do
   if t.wrapped and #value<#t.line and t.line:sub(1,#value)==value and t.line:sub(#value+1,#value+1)==' 'then return true end
  end
  return false
 end
 local raw=text:gsub('%s+$','') -- native wrap frames contain trailing spaces
 local joined
 if old and old.room==s.room.id and old.area==s.room.area and old.snapshot==q
  and old.items==s.room.items and old.version==s.room.item_version
  and now()>=old.at and now()-old.at<=2 then
  joined=old.text..' '..raw
  for _,t in ipairs(attacks)do if t.wrapped and joined==t.line then return joined end end
 end
 local value=joined and prefix(joined)and joined or raw
 -- A fresh complete FULL is still required downstream; a prefix is never authority.
 if q and prefix(value)then
  s.hunting.defensive_fragment={text=value,at=old and joined==value and old.at or now(),room=s.room.id,area=s.room.area,snapshot=q,items=s.room.items,version=s.room.item_version}
 end
 return text
end
function M.received_attack(s,text)
 text=attack_frame(s,text)
 if not s.connected or type(text)~='string'or text:find('"',1,true)or text:find(' says',1,true)then return false end
 local template
 for _,t in ipairs(attacks)do if text==t.line then template=t;break end end
 local matched,id,item,n=nil,nil,nil,0
 for k,it in pairs(s.room.items or {})do
  if template and it.name==template.name then id=tostring(k);item=it;n=n+1
  elseif not template and type(it.name)=='string'and key(text):find(key(it.name),1,true)and(text:find('you',1,true)or text:find('your',1,true))then matched=it.name end
 end
 if not template and not matched then return false end
 local refresh=false
 local reason='unsupported narrative; diagnostic only'
 if template then
  reason=n~=1 and 'attacker absent or ambiguous'or not defendable(s,item)and 'protected or uncertain NPC metadata'or 'stale FULL or BASH not active'
  local q=s.hunting.area_snapshot
  if n==1 and item.attrib=='mx'and s.mode=='BASH'and M.fresh(s)and not s.hunting.area_recovery and q.at and now()>=q.at and now()-q.at<=30
   and(not template.required_class or key(s.player.class)==template.required_class)then
   local h=hostile_loyals[s]or {};hostile_loyals[s]=h
   h[id]={room=s.room.id,area=s.room.area,class=s.player.class,name=item.name,attrib=item.attrib,icon=item.icon,at=now(),source=template.source}
  end
  refresh=n==1 and s.mode=='BASH'and (defendable(s,item)or template.recovery_only and pressure_identity(s,item))and M.fresh(s)and not s.hunting.area_recovery and q.at and now()>q.at+30 or false
  if n==1 and s.mode=='BASH'and pressure_identity(s,item)and M.fresh(s)and not s.hunting.area_recovery and q.at and now()>=q.at and now()-q.at<=30
   and(not template.required_class or key(s.player.class)==template.required_class)then
   incoming_serial=incoming_serial+1
   local g=incoming_generations[s]
   if not g or g.snapshot~=q or g.items~=s.room.items or g.version~=s.room.item_version or g.item~=item then
    g={snapshot=q,items=s.room.items,version=s.room.item_version,item=item,token={}};incoming_generations[s]=g
   end
   incoming[s]={seq=incoming_serial,at=now(),generation=g.token,room=s.room.id,area=s.room.area,class=s.player.class,id=id,items=s.room.items,version=s.room.item_version,item=item,name=item.name,attrib=item.attrib,icon=item.icon,source=template.source}
   if template.recovery_only then reason='confirmed own NPC pressure; recovery only, no attack permission'end
  end
  if not template.recovery_only and n==1 and s.mode=='BASH'and defendable(s,item)and M.fresh(s)and not s.hunting.area_recovery and q.at and now()>=q.at and now()-q.at<=30 then
   local d=s.hunting.defensive or {};s.hunting.defensive=d
   d[id]={at=now(),room=s.room.id,area=s.room.area,items=s.room.items,version=s.room.item_version,item=item,name=item.name,attrib=item.attrib,icon=item.icon,source=template.source,required_class=template.required_class}
   s.hunting.area_dirty=true;reason='confirmed own NPC attack'
  end
 end
 local history=s.hunting.potential_attackers or {};s.hunting.potential_attackers=history
 history[#history+1]={at=now(),room=s.room.id,area=s.room.area,name=template and template.name or matched,line=text,reason=reason}
 if #history>20 then table.remove(history,1)end
 return reason=='confirmed own NPC attack',refresh
end
-- Retire exception-only identities, not ordinary targets or physical ownership.
function M.prune_defensive(s)
 local d=s.hunting.defensive
 for id in pairs(d or {})do if not M.defensive_eligible(s,id)then d[id]=nil end end
 if d and not next(d)then s.hunting.defensive=nil end
end
-- Selection labels the exceptional authority, so expiry is rechecked at the
-- existing executor even without another room-list callback.
function M.certify_defensive(s,id)
 local p=M.scope(s);local row=p and M.catalog[p.id]
 s.hunting.defensive_selected=id and not(row and row.mobs[key(s.room.items[id].name)])and M.defensive_eligible(s,id)and tostring(id)or nil
 if s.hunting.defensive_selected then s.hunting.watch=nil end -- fresh verified own attacker supersedes quiet watch
end
-- Navigation-only protected role, not an attack or general metadata policy.
-- This is the observed area name, independent of a user-selected preset label.
function M.navigation_exempt(s,it)
 if type(s)~='table'or type(it)~='table'or not s.connected or type(s.player)~='table'
  or s.player.dead or type(s.player.class)~='string'or s.player.class==''
  or type(s.room)~='table'or type(s.room.items)~='table'
  or type(s.room.item_version)~='number'or s.room.item_version<=0 or s.room.item_version>=math.huge or s.room.item_version%1~=0
  or type(s.hunting)~='table'or type(s.hunting.area_snapshot)~='table'or s.hunting.area_recovery then return false end
 local p=s.hunting.preset
 if type(p)~='table'or p.area~=s.room.area
  or p.rooms~=nil and type(p.rooms)~='table'
  or p.rooms and not p.rooms[tostring(s.room.id)]or s.hunting.encounter
  or not M.fresh(s)then return false end
 local clive=s.room.area=='the Three Rock Outpost'and p.id=='threerock'
  and it.name=='Clive, a sly-looking bandit'and it.attrib=='mV'and it.icon=='burst'
 local khabarak=s.room.area=='the Khauskin Mines'and p.id=='khauskin'
  and it.name=='Khabarak, the jeweler'and it.attrib=='m'and it.icon==nil
 local belok=s.room.area=='the Khauskin Mines'and p.id=='khauskin'
  and it.name=='Belok, the mining chief'and it.attrib=='m'and it.icon==nil
 local thelvoro=s.room.area=='the Khauskin Mines'and p.id=='khauskin'
  and it.name=='Thelvoro Stonefist'and it.attrib=='m'and it.icon==nil
 if not clive and not khabarak and not belok and not thelvoro then return false end
 for _,actual in pairs(s.room.items)do if actual==it then return true end end
 return false
end
-- One navigation-pressure classifier for area, readiness and restock guards.
-- Exact protected names still HOLD if their reviewed metadata has drifted.
function M.navigation_blocked(s,it)
 if type(it)~='table'or it.attrib~=nil and type(it.attrib)~='string'then return true end
 if not M.living(it)then return false end
 -- Only approved current-area targets and verified own attackers are pressure.
 -- Fresh FULL/membership remains mandatory; ignoring a bystander is not attack authority.
 if type(s)~='table'or not M.fresh(s)then return true end
 local actual_id
 for id,actual in pairs(s.room.items or {})do if actual==it then actual_id=tostring(id);break end end
 if not actual_id then return true end
 if (s.hunting.killed_ids or {})[actual_id]then return false end
 local p=M.scope(s);local row=p and M.catalog[p.id]
 if row and row.mobs[key(it.name)]then return true end
 local pressure=M.incoming_pressure(s)
 return M.defensive_eligible(s,actual_id)==true or pressure~=nil and pressure.id==actual_id
end
function M.blocked(s)
 local p=s.hunting.preset
 if p and (not M.scope(s)or p.rooms and not p.rooms[tostring(s.room.id)])then return true,'preset room/area boundary'end
 if p and s.hunting.encounter then return true,'encounter not settled'end
 for _,it in pairs(s.room.items or {})do if M.navigation_blocked(s,it)then return true,'living room NPC; fresh empty room required'end end
 return false
end
-- wanted is an explicit request; otherwise retain a certified room-local choice.
function M.pick(s,items,wanted)
 local p=M.scope(s)
 if not p and s.hunting.preset then return nil,'preset area mismatch'end
 local row=p and M.catalog[p.id]
 if p and not row then return nil,'unknown area preset'end
 row=row or{mobs={}}
 -- Mandatory hunting restrictions survive stationary mode. Ordinary private
 -- room sets bound navigation/tests only; they never broaden area/NPC approval.
 if p and (row.requires_rooms or (s.walker or {}).active)and (not p.rooms and row.requires_rooms or p.rooms and not p.rooms[tostring(s.room.id)])then return nil,'preset room boundary'end
 if not M.fresh(s)or items~=s.room.items then return nil,'awaiting complete fresh room list'end
 local candidates={};local cutters=0
 local e=s.hunting.encounter
 if e and (not same(e.room,s.room.id)or e.area~=s.room.area)then return nil,"encounter scope unresolved"end
 for id,it in pairs(items)do
  if M.living(it)and not (s.hunting.killed_ids or {})[tostring(id)]then
   local name=key(it.name);local r=row.mobs[name]
   if name=='a crazed nazetu cutter'then cutters=cutters+1 end
   local priority=r and r.priority
   if M.defensive_eligible(s,id)then priority=1000 end
   if e then
    local desired=p and p.encounter[e.role]
    if not desired then return nil,'encounter exact NPC name requires private configuration'end
    priority=name==desired and 300 or nil
   end
   if p and p.automatic and not defendable(s,it)then priority=nil end
   if priority then candidates[#candidates+1]={id=tostring(id),priority=priority}end
  end
 end
 if p and p.id=='tiyen'and cutters>=(p.cutter_limit or 4)then return nil,'HOLD: cutter pressure limit'end
 table.sort(candidates,function(a,b)
  if a.priority~=b.priority then return a.priority>b.priority end
  local current=tostring(s.target.name)
  if a.id==current or b.id==current then return a.id==current end
  local x,y=tonumber(a.id),tonumber(b.id);if x~=y then return x<y end;return a.id<b.id
 end)
 if wanted~=nil then
  local token=key(wanted):match('^%s*(.-)%s*$');local found,kind
  for _,candidate in ipairs(candidates)do
   local name=key(items[candidate.id].name);local a,z=name:find(token,1,true)
   local word=token~=''and not token:match('^%d+$')and a and (a==1 or not name:sub(a-1,a-1):match('%w'))and (z==#name or not name:sub(z+1,z+1):match('%w'))
   if candidate.id==token or name==token or word then
    if kind and kind~=name then return nil,'ambiguous approved NPC keyword; use current room ID'end
    found=found or candidate.id;kind=name
   end
  end
  return found,found and 'manual approved NPC'or 'no eligible manual NPC in fresh room list'
 end
 local manual=s.hunting.manual_target
 if manual then
  if same(manual.room,s.room.id)and same(manual.area,s.room.area)then
   for _,candidate in ipairs(candidates)do if candidate.id==manual.id then return candidate.id,'manual approved NPC'end end
  end
  -- Removed/dead/changed scope is not a kill and must not stick to an old ID.
  s.hunting.manual_target=nil;s.hunting.query=nil
 end
 return candidates[1]and candidates[1].id or nil,'no eligible preset NPC'
end
function M.killed(s)
 local e=s.hunting.encounter;local p=M.scope(s)
 if e and p and (e.role=='nest'or e.role=='knight')and p.encounter[e.role]==key(s.target.display_name)then s.hunting.encounter=nil end
 s.hunting.area_dirty=true
end
local shield='A gargantuan, nightmarish knight lets out a deafening howl, protectivecrimson shards forming upon his armor.'
local broken='A gargantuan, nightmarish knight lets loose a guttural howl as the shards protecting him are destroyed.'
function M.text(s,text)
 local p=M.scope(s)
 if not s.connected or not p or s.mode~='BASH'then return false end
 -- Exact server narrative only; other-player combat lines and substring matches cannot arm.
 if text==shield then s.hunting.encounter={role='shard',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true end
 if text==broken then
  local e=s.hunting.encounter
  if e and e.role=='shard'and same(e.room,s.room.id)and p.encounter.shard and key(s.target.display_name)==p.encounter.shard then
   s.hunting.encounter={role='knight',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true
  end
 elseif type(text)=='string'and text:match('^A slime nest grows in the %a+ section of the cavern!$')then
  s.hunting.encounter={role='nest',room=s.room.id,area=s.room.area};s.hunting.area_dirty=true;return true
 end
 return false
end
-- Catalog rows below are static quotations, not executable reference code.
M.catalog["alaqsii"]={label="Alaqsii Inlet",areas={["alaqsii inlet"]=true},requires_rooms=false,mobs={
 ["an arctic wolf"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Alaqsii Inlet",evidence="--aggro"},
}}
M.catalog["bloodwood"]={label="Bloodwood",areas={["bloodwood"]=true},requires_rooms=false,mobs={
 ["a distressed spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
 ["a lingering spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
 ["a wailing spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Bloodwood",evidence=""},
}}
M.catalog["drakuum"]={label="Drakuum",areas={["drakuum"]=true},requires_rooms=false,mobs={
 ["a blackened darkwalker"]={priority=50,aggressive=false,potential_aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence="-- some aggro"},
 ["a gnarled spirit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a hideous lich"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a misty apparition"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence=""},
 ["a savage shade"]={priority=50,aggressive=false,potential_aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Drakuum",evidence="-- some aggro"},
}}
M.catalog["fengard"]={label="Fengard Keep",areas={["fengard keep"]=true},requires_rooms=true,mobs={
 ["a brawny glaive knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a fiery phenkyre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a horrid basilwyrm"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a massive argobole"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a pious invoker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a pungent lichosphere"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a radiant lumore"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a shrieking grimshrill"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a tall chempala"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["a vicious horned garwhol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["an ethereal construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["an ogre berserker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["cosmina, the confessor"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["derban, the ice mage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["derryk, the guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["gladius, the red knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["gloom, the construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["grothgar, the ogre warlord"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["hecuba, the grim witch"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["sylvos, squire of gladius"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tara, the priestess"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["taskmaster grollum"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["the salacious sisters"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tiber, a young telepath"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
 ["tiber. a young telepath"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fengard Keep",evidence=""},
}}
M.catalog["kalydian"]={label="Kalydian Forest",areas={["kalydian forest"]=true},requires_rooms=false,mobs={
 ["a gaunt elk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
 ["a rabid rabbit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
 ["a ravenous squirrel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Kalydian Forest",evidence=""},
}}
M.catalog["khauskin"]={label="Khauskin Mines",areas={["khauskin mines"]=true},requires_rooms=false,mobs={
 ["a burly dwarven miner"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a dwarven boy"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a dwarven girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a grotesque fangtooth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a powerful dwarven warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a soft-shelled klikkin"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a statuesque dwarven guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a stocky dwarven woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
 ["a stout dwarven man"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khauskin Mines",evidence=""},
}}
M.catalog["lich"]={label="Lich Gardens",areas={["lich gardens"]=true},requires_rooms=false,mobs={
 ["a commanding lich scientist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Lich Gardens",evidence=""},
}}
M.catalog["mamashi"]={label="Mamashi Tunnels",areas={["mamashi tunnels"]=true},requires_rooms=false,mobs={
 ["a githani grappler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a githani inscriber"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a githani master"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a greater nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mature nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk axeman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk bladesman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a mit'olk illusionist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["a young nalas"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["garthun, the maw"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
 ["timol, the head inscriber"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mamashi Tunnels",evidence=""},
}}
M.catalog["mor"]={label="Caverns of Mor",areas={["caverns of mor"]=true},requires_rooms=false,mobs={
 ["a ravenous, shadowy ghast"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a robed, skeletal lich"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a skeletal warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a stench-ridden ghoul"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["a vampiric warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
 ["aclyr, the vampiric general"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Caverns of Mor",evidence=""},
}}
M.catalog["ollin"]={label="Isle of Ollin",areas={["isle of ollin"]=true},requires_rooms=false,mobs={
 ["a ferocious alpha syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a fiendish, tainted syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a giant, rabid syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a massive, verdant-furred syll"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a nazetu comfort woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a rotting nazetu ghoul"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
 ["a young syll cub"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Isle of Ollin",evidence=""},
}}
M.catalog["salma"]={label="Salma Settlement",areas={["salma settlement"]=true},requires_rooms=false,mobs={
 ["a bemused artist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a busy mage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a common man"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a dark-furred bear"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a dark-haired woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a hooded scholar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a robust blacksmith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a salmati guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a salmati warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a wealthy merchant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["a wild-eyed scientist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an energetic child"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an engrossed scholar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an ordinary woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["an unclean miner"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["dima, captain of the salmati guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["kyros, the salmati leader"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
 ["linette, the salmati architect"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement",evidence=""},
}}
M.catalog["ayhesa"]={label="Ayhesa Cliffs",areas={["ayhesa cliffs"]=true},requires_rooms=false,mobs={
 ["a spellshaper adept"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
 ["a spellshaper archon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
 ["a spellshaper master"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ayhesa Cliffs",evidence=""},
}}
M.catalog["tiyen"]={label="Tiyen Esityi",areas={["tiyen esityi"]=true},requires_rooms=false,mobs={
 ["a ball of chitinous legs"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["a bound shade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a cancerous stallion"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a crazed nazetu cutter"]={priority=200,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi; Fallout / Bashing / Tiyen / Cutter + Cutter here room message",evidence="AC aggro comment; Fallout cutter-only counter <4; native HOLD replaces movement fallback"},
 ["a deformed nazetu priest"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a massive, sacred serpent"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a mutated nazetu intercessor"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["a nazetu captain"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu cook"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu corrupter"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu crossbowman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu halberdier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a nazetu necromancer"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro and standard"},
 ["a nazetu provost"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a supply officer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a tangible malevolence"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["a victimised intruder"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["commander marakhi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["insubstantial whispers"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["lieutenant chiakhi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["lieutenant gharvoi"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence=""},
 ["quartermaster kuius"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["the creature beneath tiyen esityi"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
 ["tirahl the necromancer"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tiyen Esityi",evidence="-- aggro"},
}}
M.catalog["xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},requires_rooms=false,mobs={
 ["a bejeweled xorani harem girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a cautious xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a churning tidal spectre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a firewrought behemoth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a helpless xorani nestling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a merciless xorani warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a stoic bedrock colossus"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a suspicious xorani patrol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a willowy nest guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a wiry xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arcane anomaly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arrogant xorani master at arms"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an electrified sparkwraith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["caelakan, an arrogant prince"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["kithan, a young xorani girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
}}
M.catalog["top-xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},requires_rooms=true,mobs={
 ["a bejeweled xorani harem girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a cautious xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a churning tidal spectre"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a firewrought behemoth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a helpless xorani nestling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a merciless xorani warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a stoic bedrock colossus"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a suspicious xorani patrol"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a willowy nest guardian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["a wiry xorani guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arcane anomaly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an arrogant xorani master at arms"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["an electrified sparkwraith"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["caelakan, an arrogant prince"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
 ["kithan, a young xorani girl"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Xaanhal",evidence=""},
}}
M.catalog["tcanna"]={label="Tcanna Island",areas={["tcanna island"]=true},requires_rooms=false,mobs={
 ["a bald eagle"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a black and white badger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a black bear"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a blue crab"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a box jellyfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a brown and tan python"]={priority=200,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island; Fallout / Bashing / Tcanna Bashing / Python Target trigger + Python here + guarded animal triggers",evidence=""},
 ["a brown-furred bat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a dark green alligator"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a diseased raccoon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a gray wolf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a great white stag"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a howler monkey"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a large capybara"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a lithe cougar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a long-billed toucan"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a nazetu officer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a ragged coyote"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a scarlet macaw"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a silverback gorilla"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a small ocelot"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a spotted jaguar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a spotted leopard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a striped tiger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a thick boa constrictor"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a troll cook"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a troll guard"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a venomous bushmaster"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a vicious copperhead snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a water buffalo"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a white goose"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["a white-tailed deer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an ebon crow"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an enormous elephant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
 ["an oversized tortoise"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tcanna Island",evidence=""},
}}
M.catalog["threerock"]={label="Threerock Outpost",areas={["threerock outpost"]=true},requires_rooms=false,mobs={
 ["a warbling hobgobbler"]={priority=100,aggressive=true,provenance="Observed native Three Rock Outpost self attack 2026-11-23",evidence="Its head swinging about erratically, a warbling hobgobbler pecks at your eyes wildly!"},
 ["a banded scrubland racer"]={priority=1,aggressive=false,provenance="Reviewed native Three Rock Outpost wildlife LOOK",evidence="Banded wild snake; A banded scrubland racer looks relatively helpless."},
 ["a beautiful wild horse"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a huge, scarred wildcat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a long-haired buffalo"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a mountain wildcat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a shifty bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["a wildcat kitten"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["an enormous troll bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["ennioch, a scruffy bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["the cave bear, white ghost"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["ugtar, a tall troll bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
 ["webb, a shifty bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Threerock Outpost",evidence=""},
}}
M.catalog["ylem"]={label="Ylem Mines",areas={["ylem mines"]=true},requires_rooms=true,mobs={
}}
M.catalog["snakepit"]={label="a snake pit",areas={["a snake pit"]=true},requires_rooms=false,mobs={
 ["a grassel snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a large sertag snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a muselon snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a tiny hatchling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["a venenigol snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["an andragil snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["namaqua, queen of serpents"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
 ["nandqua, mate of namaqua"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a snake pit",evidence=""},
}}
M.catalog["spiral"]={label="Spiral of corruption",areas={["spiral of corruption"]=true},requires_rooms=false,mobs={
 ["a five-tentacled octopus of jade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["a miasma-wreathed electric eel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["a rot-infested swordfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence="-- aggro"},
 ["a taint-infested shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence=""},
 ["an ethereal, scarred jellyfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption",evidence="-- aggro"},
}}
M.catalog["teshen"]={label="Teshen Caldera",areas={["teshen caldera"]=true},requires_rooms=false,mobs={
 ["a gargantuan teshen drone"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen reaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen scout"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
 ["a teshen worker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Teshen Caldera",evidence=""},
}}

-- Recovered statically from installed AC2.2 Moblistings; never execute legacy code.
M.catalog["augerweald"]={label="Augerweald",areas={["augerweald"]=true,["the augerweald"]=true},requires_rooms=false,mobs={
 ["an agitated direwolf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Augerweald",evidence=""},
 ["a gargantuan augerweald rabbit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Augerweald",evidence=""},
 ["a silvery pink salmon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Augerweald",evidence=""},
}}
M.catalog["festering"]={label="Festering Wastes",areas={["festering wastes"]=true,["the festering wastes"]=true},requires_rooms=false,mobs={
 ["a darkly patterned sand viper"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Festering Wastes",evidence="--aggro"},
}}
M.catalog["iashal"]={label="Ia'shal Barrow",areas={["ia'shal barrow"]=true,["the ia'shal barrow"]=true},requires_rooms=false,mobs={
 ["a bulbous cave spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ia'shal Barrow",evidence=""},
 ["an egg-laden spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ia'shal Barrow",evidence=""},
 ["a ravenous cave spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ia'shal Barrow",evidence=""},
 ["a foul spiderling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Ia'shal Barrow",evidence=""},
}}
M.catalog["iernian"]={label="Iernian Fracture",areas={["iernian fracture"]=true,["the iernian fracture"]=true},requires_rooms=false,mobs={
 ["a cacophonous cluster of eld"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Iernian Fracture",evidence=""},
}}
M.catalog["morass"]={label="Itzatl Morass",areas={["itzatl morass"]=true,["the itzatl morass"]=true},requires_rooms=false,mobs={
 ["an oversized fly"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence="-- aggro"},
 ["an oversized earthworm"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence="--aggro"},
 ["a poisonous water moccasin"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
 ["a capybara"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
 ["a vicious snapping turtle"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
 ["a green slime toad"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
 ["a silent reed cat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
 ["a long-toothed beaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Itzatl Morass",evidence=""},
}}
M.catalog["direant"]={label="a direant hill",areas={["a direant hill"]=true},requires_rooms=false,mobs={
 ["a direant rattler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
 ["a sand rattler hatchling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
 ["a direant soldier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
 ["a direant worker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
 ["a bulbous direant bomber"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
 ["a sand rattler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a direant hill",evidence=""},
}}
M.catalog["sparklight"]={label="Sparklight Rift",areas={["sparklight rift"]=true,["the sparklight rift"]=true},requires_rooms=false,mobs={
 ["a churning fire elemental"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sparklight Rift",evidence=""},
 ["an oversized efreeti"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sparklight Rift",evidence=""},
 ["a greater fire elemental"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sparklight Rift",evidence=""},
 ["a fire elemental minion"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sparklight Rift",evidence=""},
 ["a colossal elemental"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sparklight Rift",evidence=""},
}}
M.catalog["tarean-ice"]={label="Tarean Ice Caverns",areas={["tarean ice caverns"]=true,["the tarean ice caverns"]=true},requires_rooms=true,mobs={
 ["an ornery frost gremlin"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tarean Ice Caverns",evidence=""},
 ["a reanimated ice wolf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tarean Ice Caverns",evidence=""},
 ["a gigantic mother icewyrm"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tarean Ice Caverns",evidence=""},
 ["a ravenous ice fly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Tarean Ice Caverns",evidence=""},
}}
M.catalog["tarean-ice"].review_required="Mother icewyrm gates lower route; protected icy elemental guard excluded; requires reviewed private rooms"
M.catalog["hlugnic"]={label="Hlugnic Labyrinth",areas={["hlugnic labyrinth"]=true,["the hlugnic labyrinth"]=true},requires_rooms=true,mobs={
 ["an ancient multi-headed woderhund"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Hlugnic Labyrinth",evidence=""},
 ["a rune-covered lodestone golem"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Hlugnic Labyrinth",evidence=""},
 ["an enormous spinelash fish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Hlugnic Labyrinth",evidence=""},
 ["a warden of the hlugnic clans"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Hlugnic Labyrinth",evidence=""},
 ["a boisterous hlugna man"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Hlugnic Labyrinth",evidence=""},
}}
M.catalog["hlugnic"].review_required="Lethal native rating; encounter and aquatic branches unreviewed"
-- Static species-only subsets from supplied AC2.2 Moblistings. No legacy execution.
-- Omit guards, named quest roles and bystanders; retain every native attack veto.
local additions={
 azdun={label='Azdun Dungeon',area='the azdun dungeon',section='Azdun Dungeon',mobs={'a huge pulsating spider','a large pulsating spider','a medium pulsating spider'}},
 farsai={label='Ruins of Farsai',area='the ruins of farsai',section='Ruins of Farsai',mobs={'a darkling','an unctuous creepling','a shadowdrop','a shadow'}},
 gloaming={label='Cathedral of Gloaming',area='the cathedral of gloaming',section='Cathedral of Gloaming',mobs={'a vengeful spirit'}},
 redhands={label='Red Hands hideout',area='an abandoned hideout of the red hands',section='an abandoned hideout of the Red Hands',mobs={'a small red scorpion','a bronze-hued scorpion','a golden scorpion'}},
 dramedo={label='Dramedo Warrens',area='the dramedo warrens',section='Dramedo Warrens',mobs={'a vast ochre ooze','a winged fungal horror','a shambling fungal abomination','a gigantic fungal strider','a cloud of fungal spores'},aggressive={['a vast ochre ooze']=true,['a winged fungal horror']=true}}
}
for id,v in pairs(additions)do
 local row={label=v.label,areas={[v.area]=true},requires_rooms=false,mobs={}}
 for _,name in ipairs(v.mobs)do
  local aggro=v.aggressive and v.aggressive[name]or false
  row.mobs[name]={priority=aggro and 100 or 10,aggressive=aggro,provenance='AC2.2 / Msys / Bashing / Moblistings / '..v.section,evidence=aggro and 'AC2.2 exact aggro comment; static data only'or 'species-only reviewed subset; static data only'}
 end
 M.catalog[id]=row
end
-- Batch 2: every reviewed exact area-specific AC2.2 species subset.
-- Static data only. Rejected named/guard/civilian roles are documented in the
-- 73-row review artifact, never runtime exceptions. Existing selector/policy
-- metadata, occupancy, own-loyal/player and current class executor fences remain.
M.catalog["ac2-sunwash-ascent"]={label="Sunwash Ascent",areas={["sunwash ascent"]=true},requires_rooms=false,mobs={
 ["a gnarled, decrepit vrukh"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1095",evidence="area-specific curated species; membership is not aggression"},
 ["a bald fledgling vrukh"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1096",evidence="area-specific curated species; membership is not aggression"},
 ["a disgusting fledgling vrukh"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1097",evidence="area-specific curated species; membership is not aggression"},
 ["a vicious, maimed vrukh"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1098",evidence="area-specific curated species; membership is not aggression"},
 ["a grotesque, battle-torn vrukh"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1099",evidence="area-specific curated species; membership is not aggression"},
 ["a menacing vrukh lurker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1100",evidence="area-specific curated species; membership is not aggression"},
 ["a vrukh clutch-matron"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Sunwash Ascent; source line 1101",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-nal-jin-depths"]={label="the Nal'jin Depths",areas={["the nal'jin depths"]=true},requires_rooms=false,mobs={
 ["a sinewy nal'jin eel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 872",evidence="area-specific curated species; membership is not aggression"},
 ["an enormous spinelash fish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 873",evidence="area-specific curated species; membership is not aggression"},
 ["a shadow ray"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 874",evidence="area-specific curated species; membership is not aggression"},
 ["a serpentine jawsnapper"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 875",evidence="area-specific curated species; membership is not aggression"},
 ["a lurking shadow"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 876",evidence="area-specific curated species; membership is not aggression"},
 ["a voracious blind-fish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Nal'jin Depths; source line 877",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-shattered-vortex"]={label="the Shattered Vortex",areas={["the shattered vortex"]=true},requires_rooms=false,mobs={
 ["a warped turtle"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1024",evidence="area-specific curated species; membership is not aggression"},
 ["a petrified treant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1025",evidence="area-specific curated species; membership is not aggression"},
 ["a stalwart templar"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1026",evidence="area-specific curated species; membership is not aggression"},
 ["an ascendril mage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1027",evidence="area-specific curated species; membership is not aggression"},
 ["a fetish-decorated shaman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1028",evidence="area-specific curated species; membership is not aggression"},
 ["a nimble sentinel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1029",evidence="area-specific curated species; membership is not aggression"},
 ["an agile sentaari monk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1031",evidence="area-specific curated species; membership is not aggression"},
 ["a battle-worn ascendril"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1032",evidence="area-specific curated species; membership is not aggression"},
 ["a reinforcement warrior of the demonsbane"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1033",evidence="area-specific curated species; membership is not aggression"},
 ["a minion of chaos"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1034",evidence="area-specific curated species; membership is not aggression"},
 ["a dervish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1035",evidence="area-specific curated species; membership is not aggression"},
 ["a humbug"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1036",evidence="area-specific curated species; membership is not aggression"},
 ["a bloodleech"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1037",evidence="area-specific curated species; membership is not aggression"},
 ["an ethereal firelord"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1038",evidence="area-specific curated species; membership is not aggression"},
 ["a chimera"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1040",evidence="area-specific curated species; membership is not aggression"},
 ["a sharp-toothed gremlin"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1042",evidence="area-specific curated species; membership is not aggression"},
 ["a chaos storm"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1043",evidence="area-specific curated species; membership is not aggression"},
 ["a soulmaster"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1044",evidence="area-specific curated species; membership is not aggression"},
 ["a chaos hound"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1045",evidence="area-specific curated species; membership is not aggression"},
 ["a simpering sycophant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1046",evidence="area-specific curated species; membership is not aggression"},
 ["a bubonis"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1047",evidence="area-specific curated species; membership is not aggression"},
 ["a green slime"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1048",evidence="area-specific curated species; membership is not aggression"},
 ["a chaos orb"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1049",evidence="area-specific curated species; membership is not aggression"},
 ["a chaos worm"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shattered Vortex; source line 1050",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-squal"]={label="the Squal",areas={["the squal"]=true},requires_rooms=false,mobs={
 ["a sly keeper tamer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Squal; source line 1090",evidence="area-specific curated species; membership is not aggression"},
 ["a camouflaged keeper guerrilla"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Squal; source line 1091",evidence="area-specific curated species; membership is not aggression"},
 ["a thuggish keeper brute"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Squal; source line 1092",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-a-bandit-encampment-in-the-bonro-sands"]={label="a bandit encampment in the Bonro Sands",areas={["a bandit encampment in the bonro sands"]=true},requires_rooms=false,mobs={
 ["a sly caentoi vagabond"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1429",evidence="area-specific curated species; membership is not aggression"},
 ["a wiry caentoi bandit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1430",evidence="area-specific curated species; membership is not aggression"},
 ["a grizzled caentoi highwayman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1431",evidence="area-specific curated species; membership is not aggression"},
 ["a grinning caentoi cutthroat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1432",evidence="area-specific curated species; membership is not aggression"},
 ["a caentoi bushwhacker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1433",evidence="area-specific curated species; membership is not aggression"},
 ["a burly caentoi raider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1435",evidence="area-specific curated species; membership is not aggression"},
 ["a caentoi marauder"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1436",evidence="area-specific curated species; membership is not aggression"},
 ["a thieving caentoi outlaw"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1437",evidence="area-specific curated species; membership is not aggression"},
 ["a sun-scorched sandy haatun"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1438",evidence="area-specific curated species; membership is not aggression"},
 ["a scarlet kestrel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1439",evidence="area-specific curated species; membership is not aggression"},
 ["a lappet-faced vulture"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1440",evidence="area-specific curated species; membership is not aggression"},
 ["a sun-scorched aurulent haatun"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1441",evidence="area-specific curated species; membership is not aggression"},
 ["a sun-scorched crimson haatun"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a bandit encampment in the Bonro Sands; source line 1442",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-yohanan-village"]={label="Yohanan Village",areas={["yohanan village"]=true},requires_rooms=false,mobs={
 ["a cave bat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Yohanan village; source line 1417",evidence="area-specific curated species; membership is not aggression"},
 ["a mangy rat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Yohanan village; source line 1418",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-holy-impire-of-sehal"]={label="the Holy Impire of Sehal",areas={["the holy impire of sehal"]=true},requires_rooms=false,mobs={
 ["a soulless pixie"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Holy Impire of Sehal; source line 635",evidence="area-specific curated species; membership is not aggression"},
 ["a stern imp warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Holy Impire of Sehal; source line 636",evidence="area-specific curated species; membership is not aggression"},
 ["a fluffy white sheep"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Holy Impire of Sehal; source line 653",evidence="area-specific curated species; membership is not aggression"},
 ["a fuzzy grey rabbit"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Holy Impire of Sehal; source line 654",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-riparium"]={label="Riparium",areas={["riparium"]=true},requires_rooms=false,mobs={
 ["a large red crab"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 938",evidence="area-specific curated species; membership is not aggression"},
 ["a moray eel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 939",evidence="area-specific curated species; membership is not aggression"},
 ["a gelatinous polyp"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 942",evidence="area-specific curated species; membership is not aggression"},
 ["a plated ixthean"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 945",evidence="area-specific curated species; membership is not aggression"},
 ["a mantaglow fish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 946",evidence="area-specific curated species; membership is not aggression"},
 ["a powerful-looking swordfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 947",evidence="area-specific curated species; membership is not aggression"},
 ["a large blackfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 948",evidence="area-specific curated species; membership is not aggression"},
 ["a fearsome tiger shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 949",evidence="area-specific curated species; membership is not aggression"},
 ["a giant octopus"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 950",evidence="area-specific curated species; membership is not aggression"},
 ["a large, deepwater salmon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Riparium; source line 951",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-raim-vale"]={label="Raim Vale",areas={["raim vale"]=true},requires_rooms=false,mobs={
 ["a mutilated creature"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Raim Vale; source line 913",evidence="exact static aggro comment"},
 ["a rabid dog"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Raim Vale; source line 915",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-centipede-cave"]={label="the Centipede Cave",areas={["the centipede cave"]=true},requires_rooms=false,mobs={
 ["a large centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 363",evidence="area-specific curated species; membership is not aggression"},
 ["a chitinous centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 364",evidence="area-specific curated species; membership is not aggression"},
 ["a skittering centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 365",evidence="area-specific curated species; membership is not aggression"},
 ["a massive centipede queen"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 366",evidence="area-specific curated species; membership is not aggression"},
 ["a juvenile centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 367",evidence="area-specific curated species; membership is not aggression"},
 ["a venomous centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Centipede Cave; source line 368",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-maghuir-fissure"]={label="the Maghuir Fissure",areas={["the maghuir fissure"]=true},requires_rooms=false,mobs={
 ["an amorphous black umbra"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Maghuir Fissure; source line 797",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-scidve"]={label="Scidve",areas={["scidve"]=true},requires_rooms=false,mobs={
 ["a large gray and black dugger"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Scidve; source line 1012",evidence="exact static aggro comment"},
 ["a soul cultist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Scidve; source line 1013",evidence="area-specific curated species; membership is not aggression"},
 ["a blood cultist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Scidve; source line 1014",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-rebels-ridge"]={label="Rebels' Ridge",areas={["rebels' ridge"]=true},requires_rooms=false,mobs={
 ["a tenacious tough"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Rebels Ridge; source line 931",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-dun-fortress"]={label="Dun Fortress",areas={["dun fortress"]=true},requires_rooms=false,mobs={
 ["a demonic screamer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 480",evidence="area-specific curated species; membership is not aggression"},
 ["an ogre bowman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 481",evidence="area-specific curated species; membership is not aggression"},
 ["a slime-encrusted spitter"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 482",evidence="area-specific curated species; membership is not aggression"},
 ["an orc soldier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 483",evidence="area-specific curated species; membership is not aggression"},
 ["a large catfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 484",evidence="area-specific curated species; membership is not aggression"},
 ["a dangerous water snake"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 485",evidence="area-specific curated species; membership is not aggression"},
 ["an ogre knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 486",evidence="area-specific curated species; membership is not aggression"},
 ["an orc sergeant"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 488",evidence="area-specific curated species; membership is not aggression"},
 ["an orc archer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 489",evidence="area-specific curated species; membership is not aggression"},
 ["an ogre sentry"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 490",evidence="area-specific curated species; membership is not aggression"},
 ["an orc captain"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 492",evidence="area-specific curated species; membership is not aggression"},
 ["an ogre captain"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dun Fortress; source line 493",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-temple-of-sonn"]={label="the Temple of Sonn",areas={["the temple of sonn"]=true},requires_rooms=false,mobs={
 ["a choke creeper"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Temple of Sonn; source line 1211",evidence="exact static aggro comment"},
 ["a giant mosquito"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Temple of Sonn; source line 1212",evidence="exact static aggro comment"},
 ["a giant fly"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Temple of Sonn; source line 1213",evidence="area-specific curated species; membership is not aggression"},
 ["a giant moth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Temple of Sonn; source line 1214",evidence="area-specific curated species; membership is not aggression"},
 ["a glossy black silk-spinner"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Temple of Sonn; source line 1215",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-halls-of-tornos"]={label="Halls of Tornos",areas={["halls of tornos"]=true},requires_rooms=false,mobs={
 ["a malformed beast"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 612",evidence="exact static aggro comment"},
 ["a crazed blood-fiend"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 613",evidence="exact static aggro comment"},
 ["a snowy armadilleon"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 614",evidence="area-specific curated species; membership is not aggression"},
 ["a speckled tinyok"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 615",evidence="area-specific curated species; membership is not aggression"},
 ["a rabid blood-fiend"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 617",evidence="area-specific curated species; membership is not aggression"},
 ["a mutated blood-fiend"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 618",evidence="area-specific curated species; membership is not aggression"},
 ["a botched phase-hound"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Halls of Tornos; source line 623",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-siha-dylis"]={label="Siha Dylis",areas={["siha dylis"]=true},requires_rooms=false,mobs={
 ["a goblin batrider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Siha Dylis; source line 1053",evidence="area-specific curated species; membership is not aggression"},
 ["a small red squirrel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Siha Dylis; source line 1065",evidence="area-specific curated species; membership is not aggression"},
 ["a disoriented cave bat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Siha Dylis; source line 1069",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-torturers-caverns"]={label="the Torturers' Caverns",areas={["the torturers' caverns"]=true},requires_rooms=false,mobs={
 ["a rank ghoul"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Torturers' Caverns; source line 1316",evidence="exact static aggro comment"},
 ["a blood construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Torturers' Caverns; source line 1320",evidence="area-specific curated species; membership is not aggression"},
 ["a flesh golem sentry"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Torturers' Caverns; source line 1321",evidence="area-specific curated species; membership is not aggression"},
 ["a maggot-ridden skeleton"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Torturers' Caverns; source line 1322",evidence="area-specific curated species; membership is not aggression"},
 ["a voracious blind-fish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Torturers' Caverns; source line 1323",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-morgun-forest"]={label="the Morgun Forest",areas={["the morgun forest"]=true},requires_rooms=false,mobs={
 ["a poisonous hemlock bush"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Morgun Forest; source line 865",evidence="area-specific curated species; membership is not aggression"},
 ["a prickly raspberry bush"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Morgun Forest; source line 866",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-mount-humgurd"]={label="Mount Humgurd",areas={["mount humgurd"]=true},requires_rooms=false,mobs={
 ["a black-spotted cow"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mount Humgurd; source line 869",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-village-of-torston"]={label="the village of Torston",areas={["the village of torston"]=true},requires_rooms=false,mobs={
 ["an enormous blue-green crocodile"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Torston; source line 1301",evidence="exact static aggro comment"},
 ["a mottled brown frog"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Torston; source line 1310",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-barony-of-dun-valley"]={label="the Barony of Dun Valley",areas={["the barony of dun valley"]=true},requires_rooms=false,mobs={
 ["a muscular mountain lion"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Barony of Dun Valley; source line 296",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-ruins-of-salma"]={label="the ruins of Salma",areas={["the ruins of salma"]=true},requires_rooms=false,mobs={
 ["a salmati warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Salma Settlement; source line 967",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-offspring"]={label="the Offspring",areas={["the offspring"]=true},requires_rooms=false,mobs={
 ["a pudgy water badger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1252",evidence="area-specific curated species; membership is not aggression"},
 ["a flat-snouted scaled sheep"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1253",evidence="area-specific curated species; membership is not aggression"},
 ["a muscular freshwater hound"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1254",evidence="area-specific curated species; membership is not aggression"},
 ["a long-tailed bullfrog"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1255",evidence="area-specific curated species; membership is not aggression"},
 ["an amphibious, ebon-winged hawk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1256",evidence="area-specific curated species; membership is not aggression"},
 ["a predatory river canine"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Offspring; source line 1257",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-eresh-mines"]={label="the Eresh Mines",areas={["the eresh mines"]=true},requires_rooms=false,mobs={
 ["a blind wolf spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Eresh Mines; source line 525",evidence="area-specific curated species; membership is not aggression"},
 ["a swarm of black beetles"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Eresh Mines; source line 526",evidence="area-specific curated species; membership is not aggression"},
 ["an angry vampire bat"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Eresh Mines; source line 527",evidence="area-specific curated species; membership is not aggression"},
 ["a slimy brown salamander"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Eresh Mines; source line 528",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-fractal-bloom"]={label="the Fractal Bloom",areas={["the fractal bloom"]=true},requires_rooms=false,mobs={
 ["a towering crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 575",evidence="area-specific curated species; membership is not aggression"},
 ["a slender crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 576",evidence="area-specific curated species; membership is not aggression"},
 ["a radiant crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 577",evidence="area-specific curated species; membership is not aggression"},
 ["a squat crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 578",evidence="area-specific curated species; membership is not aggression"},
 ["a fractured crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 579",evidence="area-specific curated species; membership is not aggression"},
 ["a faceted crystalline entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Fractal Bloom; source line 580",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-crimson-coast"]={label="the Crimson Coast",areas={["the crimson coast"]=true},requires_rooms=false,mobs={
 ["a massive white gull"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 389",evidence="area-specific curated species; membership is not aggression"},
 ["a broad-nosed crocodile"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 390",evidence="area-specific curated species; membership is not aggression"},
 ["a large sand crab"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 391",evidence="area-specific curated species; membership is not aggression"},
 ["a minotaur smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 393",evidence="area-specific curated species; membership is not aggression"},
 ["a human smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 394",evidence="area-specific curated species; membership is not aggression"},
 ["an atavian smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 395",evidence="area-specific curated species; membership is not aggression"},
 ["an arborean smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 396",evidence="area-specific curated species; membership is not aggression"},
 ["a kelki smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 397",evidence="area-specific curated species; membership is not aggression"},
 ["a grook smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 398",evidence="area-specific curated species; membership is not aggression"},
 ["an arqeshi smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 399",evidence="area-specific curated species; membership is not aggression"},
 ["a dwarf smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 400",evidence="area-specific curated species; membership is not aggression"},
 ["a nazetu smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 401",evidence="area-specific curated species; membership is not aggression"},
 ["an imp smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 402",evidence="area-specific curated species; membership is not aggression"},
 ["an ogre smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 403",evidence="area-specific curated species; membership is not aggression"},
 ["a rajamala smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 404",evidence="area-specific curated species; membership is not aggression"},
 ["a tsol'aa smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 405",evidence="area-specific curated species; membership is not aggression"},
 ["a djeirani smuggler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 406",evidence="area-specific curated species; membership is not aggression"},
 ["a brawny, hook-handed kelki pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 409",evidence="area-specific curated species; membership is not aggression"},
 ["a wide-horned minotaur pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 410",evidence="area-specific curated species; membership is not aggression"},
 ["a stout, sure-footed dwarf pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 411",evidence="area-specific curated species; membership is not aggression"},
 ["a terribly-tattooed kobold pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 412",evidence="area-specific curated species; membership is not aggression"},
 ["a bespectacled orc pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 413",evidence="area-specific curated species; membership is not aggression"},
 ["a peg-legged imp pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 414",evidence="area-specific curated species; membership is not aggression"},
 ["a bare-chested nazetu pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 415",evidence="area-specific curated species; membership is not aggression"},
 ["a brutish orc pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 416",evidence="area-specific curated species; membership is not aggression"},
 ["a predatory, prism-finned kelki pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 417",evidence="area-specific curated species; membership is not aggression"},
 ["a gleaming arqeshi pirate"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Crimson Coast; source line 418",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-yuzurai-village"]={label="Yuzurai village",areas={["yuzurai village"]=true},requires_rooms=false,mobs={
 ["a sleek black rojalli"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Yuzurai village; source line 1421",evidence="area-specific curated species; membership is not aggression"},
 ["a savage rojalli"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Yuzurai village; source line 1422",evidence="area-specific curated species; membership is not aggression"},
 ["a massive rojalli matriarch"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Yuzurai village; source line 1423",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-spiral-of-the-corrupt"]={label="Spiral of the Corrupt",areas={["spiral of the corrupt"]=true},requires_rooms=false,mobs={
 ["a rot-infested swordfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption; source line 1083",evidence="exact static aggro comment"},
 ["an ethereal, scarred jellyfish"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption; source line 1084",evidence="exact static aggro comment"},
 ["a miasma-wreathed electric eel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption; source line 1085",evidence="area-specific curated species; membership is not aggression"},
 ["a five-tentacled octopus of jade"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption; source line 1086",evidence="area-specific curated species; membership is not aggression"},
 ["a taint-infested shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Spiral of corruption; source line 1087",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-welto-trench"]={label="the Welto Trench",areas={["the welto trench"]=true},requires_rooms=true,mobs={
 ["a black tiger shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1386",evidence="area-specific curated species; membership is not aggression"},
 ["a spotted hunter shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1387",evidence="area-specific curated species; membership is not aggression"},
 ["a grey tiger shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1388",evidence="area-specific curated species; membership is not aggression"},
 ["a storm-wing harpy"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1389",evidence="area-specific curated species; membership is not aggression"},
 ["a scarred welto shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1390",evidence="area-specific curated species; membership is not aggression"},
 ["a stone crab"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1393",evidence="area-specific curated species; membership is not aggression"},
 ["a blacktip shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Welto Trench; source line 1394",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-welto-trench"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
M.catalog["ac2-a-basilisk-lair"]={label="a basilisk lair",areas={["a basilisk lair"]=true},requires_rooms=false,mobs={
 ["a cave basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a basilisk lair; source line 301",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-forgotten-dome"]={label="the Forgotten Dome",areas={["the forgotten dome"]=true},requires_rooms=false,mobs={
 ["a gibbering kelki reaver"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Forgotten Dome; source line 569",evidence="exact static aggro comment"},
 ["a vile kelki prowler"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Forgotten Dome; source line 570",evidence="area-specific curated species; membership is not aggression"},
 ["a mutated kelki ravager"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Forgotten Dome; source line 571",evidence="area-specific curated species; membership is not aggression"},
 ["a deformed kelki ravener"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Forgotten Dome; source line 572",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-raugol-fissure"]={label="Raugol Fissure",areas={["raugol fissure"]=true},requires_rooms=false,mobs={
 ["a splintering earthrager"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Raugol Fissure; source line 922",evidence="exact static aggro comment"},
 ["a stonescale mephit"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Raugol Fissure; source line 923",evidence="exact static aggro comment"},
 ["a scything skitterer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Raugol Fissure; source line 924",evidence="area-specific curated species; membership is not aggression"},
 ["a stonescale ravager"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Raugol Fissure; source line 925",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-shastaan-warrens"]={label="the Shastaan Warrens",areas={["the shastaan warrens"]=true},requires_rooms=false,mobs={
 ["an aberrant, obscenely deformed kelki"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shastaan Warrens; source line 1018",evidence="area-specific curated species; membership is not aggression"},
 ["a wild-eyed kelki cultist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shastaan Warrens; source line 1019",evidence="area-specific curated species; membership is not aggression"},
 ["a ragged kelki cultist"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Shastaan Warrens; source line 1020",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-severed-grasp"]={label="the Severed Grasp",areas={["the severed grasp"]=true},requires_rooms=true,mobs={
 ["a fossilized construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 988",evidence="area-specific curated species; membership is not aggression"},
 ["a scarred and barbed boar of dyadic hunger"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 989",evidence="area-specific curated species; membership is not aggression"},
 ["a shadow-struck faceless chaos entity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 990",evidence="area-specific curated species; membership is not aggression"},
 ["a twin-headed solar abomination"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 991",evidence="area-specific curated species; membership is not aggression"},
 ["a contorting shadowdancer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 992",evidence="area-specific curated species; membership is not aggression"},
 ["a violent riftbearer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 993",evidence="area-specific curated species; membership is not aggression"},
 ["an oozing puddle of heliovoric crystal"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 994",evidence="area-specific curated species; membership is not aggression"},
 ["a wavering resolution of discordant harmonies"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 995",evidence="area-specific curated species; membership is not aggression"},
 ["a kaleidoscopic lepidopteran of ever-becoming"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 996",evidence="area-specific curated species; membership is not aggression"},
 ["a dissident cloud of celestial rage"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 997",evidence="area-specific curated species; membership is not aggression"},
 ["a blood-rusted gearwork behemoth"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 998",evidence="area-specific curated species; membership is not aggression"},
 ["a smoke-snorting ashlander"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 999",evidence="area-specific curated species; membership is not aggression"},
 ["a shadow-garbed chaos lady"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1000",evidence="area-specific curated species; membership is not aggression"},
 ["a beguiler of the depths"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1001",evidence="area-specific curated species; membership is not aggression"},
 ["a demonic jann"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1002",evidence="area-specific curated species; membership is not aggression"},
 ["a tormented angel of myriad meridian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1003",evidence="area-specific curated species; membership is not aggression"},
 ["an evanescent golden knight"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1004",evidence="area-specific curated species; membership is not aggression"},
 ["a grotesque soldier of spear and shield"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1005",evidence="area-specific curated species; membership is not aggression"},
 ["a sanity-straining eldritch monstrosity"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1006",evidence="area-specific curated species; membership is not aggression"},
 ["a crystalline entity of fractal phenomena"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1007",evidence="area-specific curated species; membership is not aggression"},
 ["an ethereal vulpine mystic"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1008",evidence="area-specific curated species; membership is not aggression"},
 ["a thaumaturgical construct"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1009",evidence="area-specific curated species; membership is not aggression"},
 ["a shatter-bright host"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Severed Grasp; source line 1010",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-severed-grasp"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
M.catalog["ac2-kkirrrr-shi-hive"]={label="Kkirrrr'shi Hive",areas={["kkirrrr'shi hive"]=true},requires_rooms=true,mobs={
 ["a feral hokkali soldier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khirrr'shi Hive; source line 718",evidence="area-specific curated species; membership is not aggression"},
 ["a freshly spawned hokkali ambusher"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khirrr'shi Hive; source line 719",evidence="area-specific curated species; membership is not aggression"},
 ["a twisted hokkali hunter"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khirrr'shi Hive; source line 720",evidence="area-specific curated species; membership is not aggression"},
 ["a malformed horkval priest"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khirrr'shi Hive; source line 721",evidence="area-specific curated species; membership is not aggression"},
 ["a rabid hokkali drone"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Khirrr'shi Hive; source line 722",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-kkirrrr-shi-hive"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
M.catalog["ac2-the-mannaseh-swamp"]={label="the Mannaseh Swamp",areas={["the mannaseh swamp"]=true},requires_rooms=false,mobs={
 ["a miscreated avian"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 814",evidence="area-specific curated species; membership is not aggression"},
 ["an amphibious malformation"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 815",evidence="exact static aggro comment"},
 ["a malformed stalker"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 816",evidence="exact static aggro comment"},
 ["an ichorous miscreation"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 817",evidence="exact static aggro comment"},
 ["a skittering miscreation"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 818",evidence="exact static aggro comment"},
 ["a hulking miscreation"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 819",evidence="exact static aggro comment"},
 ["a savage mutant pumpkin"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / Mannaseh Swamp; source line 820",evidence="exact static aggro comment"},
}}
M.catalog["ac2-clawhook-range"]={label="Clawhook Range",areas={["clawhook range"]=true},requires_rooms=false,mobs={
 ["a fleet-footed caentoi scout"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 377",evidence="area-specific curated species; membership is not aggression"},
 ["a skulking golban scout"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 378",evidence="area-specific curated species; membership is not aggression"},
 ["a spine-necked arrex"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 379",evidence="area-specific curated species; membership is not aggression"},
 ["a prowling barbed abosvi"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 380",evidence="area-specific curated species; membership is not aggression"},
 ["a sabre-toothed abosvi"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 381",evidence="area-specific curated species; membership is not aggression"},
 ["a caentoi rogue"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 382",evidence="area-specific curated species; membership is not aggression"},
 ["an utari warrior"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 383",evidence="area-specific curated species; membership is not aggression"},
 ["a golba brute"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 384",evidence="area-specific curated species; membership is not aggression"},
 ["a tarpen bombardier"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 385",evidence="area-specific curated species; membership is not aggression"},
 ["an ursal swordsman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Clawhook Range; source line 386",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-maul"]={label="the Maul",areas={["the maul"]=true},requires_rooms=false,mobs={
 ["a ravenous vakmut warhound"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 825",evidence="exact static aggro comment"},
 ["a lithe aslinn houndmaster"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 826",evidence="exact static aggro comment"},
 ["a wary aslinn slaver"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 827",evidence="exact static aggro comment"},
 ["an aslinn slave catcher"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 829",evidence="exact static aggro comment"},
 ["a wretched aslinn slaver"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 830",evidence="exact static aggro comment"},
 ["a snarling vakmut warhound"]={priority=100,aggressive=true,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 831",evidence="exact static aggro comment"},
 ["a menacing aslinn gladiator"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 832",evidence="area-specific curated species; membership is not aggression"},
 ["a scarred aslinn gladiator"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Maul; source line 833",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-bakal-chasm"]={label="the Bakal Chasm",areas={["the bakal chasm"]=true},requires_rooms=false,mobs={
 ["an agitated basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 312",evidence="area-specific curated species; membership is not aggression"},
 ["a juvenile basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 313",evidence="area-specific curated species; membership is not aggression"},
 ["a blinded basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 314",evidence="area-specific curated species; membership is not aggression"},
 ["a grey and brown basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 315",evidence="area-specific curated species; membership is not aggression"},
 ["an oversized, grey basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 316",evidence="area-specific curated species; membership is not aggression"},
 ["an armored, brown basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 317",evidence="area-specific curated species; membership is not aggression"},
 ["a spiked basilisk"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 318",evidence="area-specific curated species; membership is not aggression"},
 ["a basilisk hatchling"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / the Bakal Chasm; source line 319",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-a-deep-underground-cavern"]={label="a deep underground cavern",areas={["a deep underground cavern"]=true},requires_rooms=false,mobs={
 ["a chaos-warped gargantuan carrier centipede"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a deep underground cavern; source line 463",evidence="area-specific curated species; membership is not aggression"},
 ["a demonic chaos-warped spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a deep underground cavern; source line 464",evidence="area-specific curated species; membership is not aggression"},
 ["a chaos-warped egg-laying spider"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / a deep underground cavern; source line 465",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-tak-re"]={label="Tak-re",areas={["tak-re"]=true},requires_rooms=false,mobs={
 ["a mutated deer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Takre; source line 1110",evidence="area-specific curated species; membership is not aggression"},
 ["a warped squirrel"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Takre; source line 1111",evidence="area-specific curated species; membership is not aggression"},
 ["a horrifically deformed woodpecker"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Takre; source line 1112",evidence="area-specific curated species; membership is not aggression"},
 ["a hundred-strings jellyfish"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Takre; source line 1113",evidence="area-specific curated species; membership is not aggression"},
 ["a vicious, mutated shark"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Takre; source line 1114",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-forgotten-depths-of-mount-helba"]={label="the forgotten depths of Mount Helba",areas={["the forgotten depths of mount helba"]=true},requires_rooms=true,mobs={
 ["a towering fungal abomination"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / forgotten depths of helba; source line 565",evidence="area-specific curated species; membership is not aggression"},
 ["a withered fungal abomination"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / forgotten depths of helba; source line 566",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-the-forgotten-depths-of-mount-helba"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
M.catalog["ac2-the-forgotten-mausoleum"]={label="The Forgotten Mausoleum",areas={["the forgotten mausoleum"]=true},requires_rooms=false,mobs={
 ["a rotting dwarf archer"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / The Forgotten Mausoleum; source line 1228",evidence="area-specific curated species; membership is not aggression"},
 ["a decomposing dwarf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / The Forgotten Mausoleum; source line 1229",evidence="area-specific curated species; membership is not aggression"},
 ["a robed reanimated dwarf"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / The Forgotten Mausoleum; source line 1230",evidence="area-specific curated species; membership is not aggression"},
 ["a reanimated dwarf woman"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / The Forgotten Mausoleum; source line 1231",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-dovan-hollow"]={label="Dovan Hollow",areas={["dovan hollow"]=true},requires_rooms=true,mobs={
 ["a gaunt aslinn slaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 439",evidence="area-specific curated species; membership is not aggression"},
 ["a scarred aslinn slaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 440",evidence="area-specific curated species; membership is not aggression"},
 ["a sinewy aslinn slaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 441",evidence="area-specific curated species; membership is not aggression"},
 ["a hulking ursal brute"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 442",evidence="area-specific curated species; membership is not aggression"},
 ["a grim aslinn slaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 444",evidence="area-specific curated species; membership is not aggression"},
 ["a haughty caentoi slaver"]={priority=10,aggressive=false,provenance="AC2.2 / Msys / Bashing / Moblistings / Dovan Hollow; source line 445",evidence="area-specific curated species; membership is not aggression"},
}}
M.catalog["ac2-dovan-hollow"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
-- Darkside_New factual NPC-name supplement, independently implemented.
-- Source commit d084a567808e4132499afc2924eb89added15a15, attribution Linyive.
-- Informal README picking permission is NOT a repository-wide formal license.
-- No repository Lua, patterns, sender logic or route algorithms are copied.
M.catalog["darkside-a-memory-of-relovec-mansion"]={label="a memory of Relovec Mansion",areas={["a memory of relovec mansion"]=true},requires_rooms=false,mobs={
 ["an enraged memory of a female servant"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33625 / a memory of Relovec Mansion; source line 33625",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an enraged memory of a male servant"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33625 / a memory of Relovec Mansion; source line 33625",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an enraged memory of a female villager"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33625 / a memory of Relovec Mansion; source line 33625",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an enraged memory of a male villager"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33625 / a memory of Relovec Mansion; source line 33625",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-crags"]={label="the Crags",areas={["the crags"]=true},requires_rooms=false,mobs={
 ["a light grey stone worm"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33564 / the Crags; source line 33564",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a dark grey stone worm"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33564 / the Crags; source line 33564",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a steady cragling"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33564 / the Crags; source line 33564",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a vile snatcher"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33564 / the Crags; source line 33564",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a hulking snatcher"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33564 / the Crags; source line 33564",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-village-of-gorshire"]={label="the village of Gorshire",areas={["the village of gorshire"]=true},requires_rooms=false,mobs={
 ["a lithe weasel"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33562 / the village of Gorshire; source line 33562",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a large grey goose"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33562 / the village of Gorshire; source line 33562",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a large gray goose"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33562 / the village of Gorshire; source line 33562",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-valley-of-kalebb"]={label="the Valley of Kalebb",areas={["the valley of kalebb"]=true},requires_rooms=false,mobs={
 ["a long, thin grass snake"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a plump wild rabbit"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a speckled, brown turtle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a bald eagle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a large, speckled turtle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a small green water snake"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33662 / the Valley of Kalebb; source line 33662",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-valley-of-lodi"]={label="the Valley of Lodi",areas={["the valley of lodi"]=true},requires_rooms=false,mobs={
 ["a cave bat"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33561 / the Valley of Lodi; source line 33561",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a sheep"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33561 / the Valley of Lodi; source line 33561",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white hen"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33561 / the Valley of Lodi; source line 33561",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a juvenile wildcat"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33561 / the Valley of Lodi; source line 33561",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an adult wildcat"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33561 / the Valley of Lodi; source line 33561",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-forsaken-evlasu"]={label="Forsaken Evlasu",areas={["forsaken evlasu"]=true},requires_rooms=false,mobs={
 ["an unnaturally lithe, shadowy aberration"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33566 / Forsaken Evlasu; source line 33566",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a hideous winged aberration"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33566 / Forsaken Evlasu; source line 33566",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grotesque, warped aberration"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33566 / Forsaken Evlasu; source line 33566",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a corrupted cultist"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33566 / Forsaken Evlasu; source line 33566",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-tarean-caverns"]={label="the Tarean Caverns",areas={["the tarean caverns"]=true},requires_rooms=false,mobs={
 ["a small, black bat"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an unkempt trog"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a rotting rattlesnake"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an irritable, rabid zebra"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a blood-spattered leopard"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a frothing, manic buffalo"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a gigantic cave bear"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33563 / the Tarean Caverns; source line 33563",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-village-of-rahveir"]={label="the village of Rahveir",areas={["the village of rahveir"]=true},requires_rooms=false,mobs={
 ["a malevolent poltergeist"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33565 / the village of Rahveir; source line 33565",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a corrupted spirit"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33565 / the village of Rahveir; source line 33565",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-beaches-of-liris"]={label="the beaches of Liris",areas={["the beaches of liris"]=true},requires_rooms=false,mobs={
 ["a small, red crab"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a red hermit crab"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a slimy red-shelled snail"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a blue-shelled snail"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an orange-and-yellow stripped starfish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a gargantuan crab"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a yellow-finned bream fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33655 / the beaches of Liris; source line 33655",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-aureliana-forest"]={label="the Aureliana Forest",areas={["the aureliana forest"]=true},requires_rooms=false,mobs={
 ["a dark-furred, rabid boar"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45480 / the Aureliana Forest; source line 45480",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a wild boar"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45480 / the Aureliana Forest; source line 45480",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-undercity-of-djeir"]={label="the Undercity of Djeir",areas={["the undercity of djeir"]=true},requires_rooms=false,mobs={
 ["a gargantuan spider"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a mutated crawler fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a striped siriskal fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an electric eel"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an elusive black fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a giant squid"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a monstrous coelacanth"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a carnivorous weed"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a fearsome suria serpent"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33593 / the Undercity of Djeir; source line 33593",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a striped sea krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45504 / the Undercity of Djeir; source line 45504",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-caverns-of-telfinne"]={label="the Caverns of Telfinne",areas={["the caverns of telfinne"]=true},requires_rooms=false,mobs={
 ["a cave-dwelling avisme"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a fanged lugore"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a slimy aryeim"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tentacled morbol"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a draconic zogura"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a slender synicant"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33643 / the Caverns of Telfinne; source line 33643",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-ilhavon-forest"]={label="the Ilhavon Forest",areas={["the ilhavon forest"]=true},requires_rooms=false,mobs={
 ["a burrowing owl"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a golden scale rattlesnake"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a lumbering brown bear"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a plump duck"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a blackbird"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a bear cub"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a giant pugnax crab"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a catfish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a lake trout"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a school of fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an eerily glowing jellyfish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a harpoon scorpion"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a dull brown lamprey"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a large buck"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white tailed doe"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a moth"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a gargantuan cicada"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a magpie"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a frazzled-looking possum"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33657 / the Ilhavon Forest; source line 33657",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-asper"]={label="Asper",areas={["asper"]=true},requires_rooms=false,mobs={
 ["a fearsome icewyrm"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a malevolent spectre"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a failed experiment"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an animated golem of flesh"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a wild bobcat"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a snowshoe hare"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33592 / Asper; source line 33592",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-siroccian-tunnels"]={label="the Siroccian Tunnels",areas={["the siroccian tunnels"]=true},requires_rooms=false,mobs={
 ["a lurking shadow"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a spatial anomaly"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a crystal-encrusted golem"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a massive striped worm"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a disembodied soul"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a voracious blind-fish"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33651 / the Siroccian Tunnels; source line 33651",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-dolbodi-campsite"]={label="the Dolbodi Campsite",areas={["the dolbodi campsite"]=true},requires_rooms=false,mobs={
 ["a lithe buckawn"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33586 / the Dolbodi Campsite; source line 33586",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a great white stag"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45490 / the Dolbodi Campsite; source line 45490",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-siroccian-mountains"]={label="the Siroccian Mountains",areas={["the siroccian mountains"]=true},requires_rooms=false,mobs={
 ["a vicious wolverine"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33574 / the Siroccian Mountains; source line 33574",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a powerful wolverine"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33574 / the Siroccian Mountains; source line 33574",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-court-of-the-consortium"]={label="Court of the Consortium",areas={["court of the consortium"]=true},requires_rooms=true,mobs={
 ["a shambling skeleton"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33664 / Court of the Consortium; source line 33664",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a spatial anomaly"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33664 / Court of the Consortium; source line 33664",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a crystal-encrusted golem"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33664 / Court of the Consortium; source line 33664",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a massive striped worm"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33664 / Court of the Consortium; source line 33664",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a disembodied soul"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33664 / Court of the Consortium; source line 33664",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-court-of-the-consortium"].review_required="Court source waypoints cross Lava; exact reviewed private hunting rooms and native route access required"
M.catalog["darkside-catacombs-beneath-djeir"]={label="Catacombs beneath Djeir",areas={["catacombs beneath djeir"]=true},requires_rooms=false,mobs={
 ["a djeirani ghost"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33654 / Catacombs beneath Djeir; source line 33654",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-village-of-bihrkaen"]={label="the village of Bihrkaen",areas={["the village of bihrkaen"]=true},requires_rooms=false,mobs={
 ["a bihrkaen ambusher"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grotesque snapping turtle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a mire hound"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a bog hound"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a mire pup"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an alpha female hound"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["an alpha male hound"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33595 / the village of Bihrkaen; source line 33595",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a mossy hound"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a sickly carrion crow"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a bihrkaen huntress"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a horrifying bihrkaen"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a slender mud adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a speckled, brown turtle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33596 / the village of Bihrkaen; source line 33596",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-mount-heylai"]={label="Mount Heylai",areas={["mount heylai"]=true},requires_rooms=false,mobs={
 ["an armored dwarf"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33650 / Mount Heylai; source line 33650",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a dwarf geared up for battle"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33650 / Mount Heylai; source line 33650",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a dwarven warrior"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33650 / Mount Heylai; source line 33650",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-chapel-garden"]={label="Chapel Garden",areas={["chapel garden"]=true},requires_rooms=false,mobs={
 ["a diminutive necromancer"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33642 / Chapel Garden; source line 33642",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a zombie cleric"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33642 / Chapel Garden; source line 33642",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a foul-smelling zombie"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33642 / Chapel Garden; source line 33642",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-lost-city-of-iviofiyiedu"]={label="the lost city of Iviofiyiedu",areas={["the lost city of iviofiyiedu"]=true},requires_rooms=false,mobs={
 ["a ghost of a mhun soldier"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33645 / the lost city of Iviofiyiedu; source line 33645",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a ghost of a male mhun"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33645 / the lost city of Iviofiyiedu; source line 33645",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a ghost of a female mhun"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33645 / the lost city of Iviofiyiedu; source line 33645",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-den-of-shadows"]={label="the Den of Shadows",areas={["the den of shadows"]=true},requires_rooms=false,mobs={
 ["a horribly-mutated experiment"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33692 / the Den of Shadows; source line 33692",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan sidewinder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black boa"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan python"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white sidewinder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black python"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown cobra"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white boa"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white python"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown sidewinder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan boa"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey sidewinder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan cobra"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a tan krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown python"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey cobra"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black sidewinder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey boa"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a white adder"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a brown boa"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black krait"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grey python"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a black cobra"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:45508 / the Den of Shadows; source line 45508",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-tarblack-marshes"]={label="the Tarblack Marshes",areas={["the tarblack marshes"]=true},requires_rooms=true,mobs={
 ["a tarclaw caiman"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33689 / the Tarblack Marshes; source line 33689",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a lumbering stonefiend"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33689 / the Tarblack Marshes; source line 33689",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a rock scorpion"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33689 / the Tarblack Marshes; source line 33689",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a grotesque bloater"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33689 / the Tarblack Marshes; source line 33689",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-tarblack-marshes"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
M.catalog["darkside-the-feral-caves"]={label="the Feral Caves",areas={["the feral caves"]=true},requires_rooms=true,mobs={
 ["a small green blob"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33635 / the Feral Caves; source line 33635",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a slimy green blob"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33635 / the Feral Caves; source line 33635",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a massive green blob"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33635 / the Feral Caves; source line 33635",evidence="independently scoped factual species; reference is not aggression or movement authority"},
 ["a gigantic green blob"]={priority=10,aggressive=false,provenance="Darkside_New@d084a567808e4132499afc2924eb89added15a15 / DarksideScript.xml:33635 / the Feral Caves; source line 33635",evidence="independently scoped factual species; reference is not aggression or movement authority"},
}}
M.catalog["darkside-the-feral-caves"].review_required="native Lethal rating: exact hunting rooms and encounter/terrain review required"
-- Sunder factual species supplement; commit 8eb9891505232cc505527e33f455404579a03f07.
-- Historical 2024 labels only; no Sunder implementation, Match patterns,
-- entry aliases or optimistic readiness are imported. Existing flags retained.
do local row=assert(M.catalog["ac2-riparium"])
 row.mobs["an angler fish"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64866 / Riparium; source line 64866",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["festering"])
 row.mobs["a tiny black scorpion"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64868 / the Festering Wastes; source line 64868",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a small yellow rattlesnake"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64868 / the Festering Wastes; source line 64868",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["augerweald"])
 row.mobs["a large, snowy fox"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64886 / the Augerweald; source line 64886",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a tall, white elk"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64886 / the Augerweald; source line 64886",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ollin"])
 row.mobs["a blackened, ravenous shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64896 / the Isle of Ollin; source line 64896",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a massive black crab"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64896 / the Isle of Ollin; source line 64896",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a dark-furred, rabid boar"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64896 / the Isle of Ollin; source line 64896",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ac2-the-village-of-torston"])
 row.mobs["a venomous water snake"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64938 / the village of Torston; source line 64938",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a fierce crocodile"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64938 / the village of Torston; source line 64938",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ac2-the-morgun-forest"])
 row.mobs["a wild boar"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64947 / the Morgun Forest; source line 64947",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ac2-the-barony-of-dun-valley"])
 row.mobs["a dangerous water snake"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a poisonous snake"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a tree frog"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a greyish green crocodile"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a crab"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a large red crab"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a raccoon"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a bighorn sheep"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64954 / the Barony of Dun Valley; source line 64954",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ac2-the-welto-trench"])
 row.mobs["a black hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a spotted bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a scarred hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a brown hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a striped hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a great white welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a brown bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a bronze tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a black bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a spotted tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a grey hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a bronze welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a brown tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a spotted welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a striped welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a striped tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a striped bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a great white bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a brown welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a great white tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a great white hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a bronze bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a bronze hunter shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a scarred tiger shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a black welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a grey bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a grey welto shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a scarred bull shark"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a box jellyfish"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
 row.mobs["a giant manta ray"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64975 / the Welto Trench; source line 64975",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
do local row=assert(M.catalog["ac2-the-offspring"])
 row.mobs["a chromatic aquatic dragonfly"]={priority=10,aggressive=false,provenance="Sunder@8eb9891505232cc505527e33f455404579a03f07 / Sunder.xml:64986 / the Offspring; source line 64986",evidence="historical exact area/species fact; current native metadata/room/ownership and all existing policy required"}
end
return M
