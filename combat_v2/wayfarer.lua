-- Pure Combat V2 proposal adapter. No sender, timers, globals, native requests or ABI.
-- Normalized evidence below is a LOCAL contract, not an invented GMCP schema.
local M = {class = 'Wayfarer'}
local function copy(t)
 if type(t) ~= 'table' then return t end
 local r = {}; for k,v in pairs(t) do r[k] = copy(v) end; return r
end
local function wait(why)
 return {name='wait',command='',reason='Wayfarer held: '..why,confidence=0,requires={balance=true,equilibrium=true}}
end
local recipes = {
 chop={group='Tenacity',ability='Chop',template='axe chop <target>',effect='single NPC damage; no predicted afflictions',source='AC22:4704; Sunder:77619-77634'},
 pvp_chop={group='Tenacity',ability='Chop',template='axe chop <target> torso curare',effect='single player torso strike with curare; outcome unconfirmed',source='AC22:4373:320'},
 ironskin={group='Wayfaring',ability='Ironskin',template='wayfare ironskin',effect='physical resistance',source='AC22:4356; Sunder:62646'},
 blindsense={group='Wayfaring',ability='Blindsense',template='wayfare blindsense on',effect='resists accuracy reduction; NOT permission to self-blind',source='AC22:4356; Sunder:62647'},
 resilience={group='Wayfaring',ability='Resilience',template='wayfare resilience on',effect='masks injury assessment, NOT healing',source='AC22:4356; Sunder:62652'},
 bloodtrails={group='Wayfaring',ability='Bloodtrails',template='wayfare bloodtrails on',effect='bloodtrail tracking',source='AC22:4356; Sunder:62659'},
 circulation={group='Wayfaring',ability='Circulation',template='wayfare circulation on',effect='strength/clotting benefit; higher clot cost; explicit opt-in',source='AC22:4356; Sunder:62654'}
}
M.source_index=copy(recipes)
-- One row per canonical defense. Metadata does not grant activation authority.
M.defense_catalog={}
for _,key in ipairs({'ironskin','blindsense','resilience','bloodtrails','circulation'}) do
 local r=recipes[key]; M.defense_catalog[#M.defense_catalog+1]={key=key,class='Wayfarer',group=r.group,ability=r.ability,command=r.template,default=false,owner='wayfarer',effect=r.effect,source=r.source}
end
local held={
 {'fleetfoot','Wayfaring','Fleetfoot','AC22:1422','activation syntax not corroborated'},
 {'greenheart','Wayfaring','Greenheart','Sunder:62648','greenink/tree tattoo consumption protocol unobserved'},
 {'endure','Wayfaring','Endure','Sunder:62649','current native cost/ACK unobserved'},
 {'mountaineer','Wayfaring','Mountaineer','AC22:1438/1439; Sunder:62650','room-wide effects excluded'},
 {'dustcoat','Wayfaring','Dustcoat','Sunder:62651; Darkside:11535','sources disagree: dustcoat versus dustcoat on'},
 {'desolation','Wayfaring','Desolation','AC22:1443; Sunder:62653','melee/ranged tradeoff requires explicit current-native validation'},
 {'brutality','Fury','Brutality','Sunder:62655','reactive fear consequences excluded'},
 {'axe_avert','Tenacity','Avert','Sunder:62656','axe/channel commitment unobserved'},
 {'axe_obstruct','Tenacity','Obstruct','Sunder:62657','reactive attack ownership excluded'},
 {'axe_repel','Tenacity','Repel','Sunder:62658','reaction/channel protocol unobserved'},
 {'phalanx','Fury','Battlechant','Sunder:62660','battlechant group/channel effects excluded'},
 {'anthem','Fury','Battlechant','Sunder:62661','battlechant group/channel effects excluded'},
 {'rallied','Fury','Battlechant','Sunder:62662','battlechant group/channel effects excluded'},
 {'bolstered_morale','Fury','Battlechant','Sunder:62663','battlechant group/channel effects excluded'},
 {'battlechant','Fury','Battlechant','Sunder:62664','tracking umbrella; no second producer'},
 {'dauntless','Fury','Dauntless','AC22:1434/1435/4356','on/off polarity and fury drain need native evidence'},
 {'survive','Wayfaring','Survive','AC22:1440/1441','emergency, not routine defense'},
 {'enrage','Fury','Enrage','AC22:1444/1445/1446','berserker/channel lifecycle unobserved'}
}
for _,r in ipairs(held) do M.defense_catalog[#M.defense_catalog+1]={key=r[1],class='Wayfarer',group=r[2],ability=r[3],source=r[4],held=r[5],default=false,owner='wayfarer'} end
local descriptions={
 ['Your skin is as hard as iron.']='ironskin',
 ['Your senses are attuned to the environment.']='blindsense',
 ['You are masking your pain.']='resilience',
 ['You are tracking the bloodtrails left by your targets.']='bloodtrails',
 ['You are focusing on circulating your blood more efficiently.']='circulation'
}
function M.new() return {armed=false,revision=0,learned={},resources={},protocols={},owners={},wanted={},observations={}} end
local function scoped(w,e)
 return type(e)=='table' and e.session==w.session and e.life==w.life and e.class=='Wayfarer' and e.epoch==w.epoch and e.native==true
end
local function base(s)
 local w=s and s.wayfarer; local p=s and s.player or {}
 if not w then return nil,'no normalized current-native evidence' end
 if not w.armed then return nil,'disarmed' end
 if p.class~='Wayfarer' or w.class~='Wayfarer' then return nil,'current class is not literal Wayfarer' end
 if not s.connected or p.dead or not tonumber(p.hp) or tonumber(p.hp)<=0 then return nil,'disconnected/dead/unknown vitals' end
 if w.session==nil or w.life==nil or w.epoch==nil then return nil,'scope unknown' end
 if not scoped(w,w.identity) then return nil,'genuine current server-pushed class identity required' end
 if w.room==nil then return nil,'current room unknown' end
 if w.issued then return nil,'issued commitment unresolved (preserved across invalidation)' end
 if not scoped(w,w.physical) or w.physical.ready~=true then return nil,'current physical/channel readiness unknown or blocked' end
 if p.prone~=false or p.mounted~=false then return nil,'posture/mount unknown or blocked' end
 if p.balance~=true or p.equilibrium~=true then return nil,'balance/equilibrium not ready' end
 return w
end
local function ability(w,key)
 local r=recipes[key]; local a=w.learned[r.group..'.'..r.ability];local pr=w.protocols[key]
 if not scoped(w,a) or a.learned~=true or a.active~=true then return nil,'current learned active '..r.group..' '..r.ability..' required; inactive/cached AB is not authority' end
 if not scoped(w,pr) or pr.template~=r.template or pr.costs_verified~=true or type(pr.costs)~='table' then return nil,'current-native syntax/resource-cost protocol missing for '..key end
 if pr.balance~=true or pr.equilibrium~=true then return nil,'current-native readiness requirements unverified' end
 if key=='pvp_chop' and (type(pr.costs.curare)~='number' or pr.costs.curare<=0) then return nil,'native curare dose cost unverified' end
 if pr.ready~=true then return nil,'ability cooldown/channel not ready' end
 for resource,cost in pairs(pr.costs) do
  local v=w.resources[resource]
  if type(cost)~='number' or cost<0 or cost~=cost or not scoped(w,v) or type(v.value)~='number' or v.value~=v.value or v.value<cost then return nil,'missing/insufficient current resource '..resource end
 end
 return pr
end
local function axe(w,pvp)
 local g=w.gear
 if not scoped(w,g) or g.kind~='throwingaxe' or type(g.id)~='string' or not g.id:match('^%d+$') or g.wielded~=true or g.usable~=true or g.in_flight~=false then return false,'verified usable wielded throwing axe required' end
 if g.venom_clean~=true then return false,'axe coating unknown; no incidental venom delivery' end
 if pvp then
  local v=w.resources.curare
  if not scoped(w,v) or type(v.value)~='number' or v.value<1 then return false,'verified curare stock required' end
 end
 return true
end
local function make(s,key,command,reason)
 local w=s.wayfarer
 return {name='wayfarer_'..key,command=command,reason=reason,confidence=.75,requires={balance=true,equilibrium=true},class='Wayfarer',adapter='wayfarer',recipe=key,generation=s.target_generation,revision=w.revision,session=w.session,life=w.life,epoch=w.epoch,mode=s.mode,effects_planned=recipes[key].effect}
end
function M.choose(s)
 local w,why=base(s); if not w then return wait(why) end
 if s.mode~='BASH' and s.mode~='ASSIST' and s.mode~='FULL_AUTO' then return wait('mode not authorized') end
 local t=s.target or {}; local e=w.target
 if not scoped(w,e) or e.generation~=s.target_generation or e.name~=t.name or e.room~=w.room or e.present~=true or e.alive~=true or t.dead then return wait('current exact target/location evidence required') end
 if type(t.name)~='string' or not t.name:match('^[%w%-]+$') then return wait('unsafe target token; use exact entity ID/name') end
 if e.own_loyal~=false or e.guard~=false or e.protected~=false or e.ally~=false or e.ambiguous~=false then return wait('protected/loyal/guard/ally/ambiguous target') end
 if e.shield~=false or e.rebounding~=false then return wait('shield/rebounding present or unknown; no unverified breaker') end
 local key='chop'
 if s.mode=='BASH' then
  if e.kind~='npc' or e.hunt_authorized~=true then return wait('PvE requires authorized NPC, never players') end
 else
  if e.kind~='player' or e.pvp_consent~=true or e.pvp_authorized~=true then return wait('bounded PvP requires explicit exact-player consent') end
  if e.torso_legal~=true or e.parry_torso~=false then return wait('torso legality/parry unknown or blocked') end
  key='pvp_chop'
 end
 local pr; pr,why=ability(w,key); if not pr then return wait(why) end
 local ok; ok,why=axe(w,key=='pvp_chop'); if not ok then return wait(why) end
 return make(s,key,recipes[key].template:gsub('<target>',t.name),s.mode=='BASH' and 'single-target hunting Chop; no PvP outcome estimates' or 'bounded torso/curare Chop; native outcome required')
end
function M.defense(s,key)
 local w,why=base(s); if not w then return wait(why) end
 local r=recipes[key]; if not r or key=='chop' or key=='pvp_chop' then return wait('defense tracking-only or unknown') end
 if w.owners[key]~='wayfarer' then return wait('canonical defense owned elsewhere/unassigned') end
 if w.wanted[key]~=true then return wait('defense not explicitly wanted') end
 if not scoped(w,w.defenses) or w.defenses.complete~=true or type(w.defenses.active)~='table' then return wait('complete current native defense list required') end
 if w.defenses.active[key] then return wait('defense already active') end
 local pr;pr,why=ability(w,key);if not pr then return wait(why) end
 return make(s,key,r.template,r.effect..'; class-specific sole canonical owner')
end
function M.validate(s,a)
 if type(a)~='table' or a.adapter~='wayfarer' or not s.wayfarer then return false,'not a Wayfarer proposal' end
 local w=s.wayfarer
 if a.revision~=w.revision or a.session~=w.session or a.life~=w.life or a.epoch~=w.epoch or a.mode~=s.mode or a.generation~=s.target_generation then return false,'stale proposal scope' end
 local current=(a.recipe=='chop' or a.recipe=='pvp_chop') and M.choose(s) or M.defense(s,a.recipe)
 if current.command=='' or current.command~=a.command or current.name~=a.name then return false,current.reason end
 return true
end
-- Call only from the existing owner immediately BEFORE its one physical send.
-- Transport uncertainty must leave this commitment in place; no retry timer here.
function M.mark_issued(s,a,token)
 if type(token)~='string' or token=='' then return false,'unique owner token required' end
 local ok,why=M.validate(s,a);if not ok then return false,why end
 local w=s.wayfarer;local costs=copy(w.protocols[a.recipe].costs)

 w.issued={token=token,proposal=copy(a),reserved=costs}
 -- A successful/uncertain transport cannot reuse the pre-send resource proof.
 -- The shared ledger must supply genuinely later stock evidence; do not guess a debit.
 for resource,cost in pairs(costs) do if cost>0 then w.resources[resource]=nil end end
 return true
end
-- Ingestion callback, not a status/plan operation. Preserve old issued barrier.
function M.invalidate(s,scope)
 local w=s.wayfarer or M.new();s.wayfarer=w
 w.armed=false;w.revision=w.revision+1
 w.class=scope and scope.class;w.session=scope and scope.session;w.life=scope and scope.life;w.epoch=scope and scope.epoch
 w.identity=nil;w.room=nil;w.learned={};w.protocols={};w.resources={};w.gear=nil;w.target=nil;w.physical=nil;w.defenses=nil;w.observations={}
 return true
end
-- Read-only parser: returns observations, NEVER activates capabilities or settles sends.
function M.observe_line(line)
 if descriptions[line] then return {kind='defense_present',key=descriptions[line],source='AC22 defense description; corroborate native canonical List'} end
 if line=='You can bring forth your fury again.' then return {kind='cooldown_ready',key='fury',source='AC22:1423'} end
 if line=='You cannot bring forth your Fury again just yet.' then return {kind='reject',key='fury',source='AC22:1424'} end
 if line=='You may once again expunge an affliction.' then return {kind='cooldown_ready',key='expunge',source='AC22:1430'} end
 local target,limb=line:match("^You chop into ([%w%-]+)'s (.-) with a powerful draw of a throwing axe, the blade sinking into .+ flesh%.$")
 if target then return {kind='attack_observed',ability='Chop',target=target,limb=limb,source='AC22:3171',afflictions_confirmed=false} end
 if line:match('^.- uses .- on you%.$') then return {kind='received_attack',raw=line,does_not_confirm_planned_outcome=true} end
 return nil
end
-- Caller supplies attribution from existing native ACK/reject owner, not guessed text.
-- A later prompt+ready is required even after ACK/reject; no guessed cooldown seconds.
function M.settle(s,event)
 local w=s.wayfarer;local issued=w and w.issued
 if not issued or type(event)~='table' or event.native~=true or event.token~=issued.token or event.attributed~=true then return false end
 if event.kind=='ack' or event.kind=='reject' then issued.result=event.kind;issued.sequence=event.sequence;return true end
 if event.kind=='recovered' and issued.result and type(event.sequence)=='number' and type(issued.sequence)=='number' and event.sequence>issued.sequence and event.ready==true then w.issued=nil;return true end
 return false
end
function M.status(s)
 local a=M.choose(s);local w=s.wayfarer
 return {class='Wayfarer',armed=w and w.armed==true or false,pending=w and w.issued~=nil or false,proposal=copy(a),native_protocol='not wired; normalized evidence only'}
end
return M
