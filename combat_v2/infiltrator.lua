-- Independently written, offline candidate. No sender, timer, hook or discovery IO.
-- Official mechanics pin: sources.md. AC2 indexes are ZERO-BASED DATA references.
local M={class='Infiltrator',version=1}
local function now(t) return t or (getEpoch and getEpoch() or os.time()) end
local function wait(why) return {name='wait',command='',reason=why,confidence=0,requires={}} end
local function number(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
local function scope(s,w)
 return type(w)=='table' and s.session_id~=nil and s.life_generation~=nil and s.class_generation~=nil
  and w.session==s.session_id and w.life==s.life_generation and w.epoch==s.class_generation
end
local function fresh(s,w,t)
 return scope(s,w) and number(w.at) and number(w.expires) and w.at<=t and t<=w.expires
  and w.expires>=w.at and type(w.source)=='string' and w.source~='' and w.live==true
end
local function class_ok(s,c,t)
 return s.player and s.player.class=='Infiltrator' and s.connected==true and not s.player.dead
  and number(s.player.hp) and s.player.hp>0 and c and fresh(s,c.status,t)
  and c.status.source=='Char.Status' and c.status.class=='Infiltrator'
end
local function owned(s,c,g,k,t)
 local group=c.groups and c.groups[g];local skill=c.skills and c.skills[g..'.'..k]
 return fresh(s,group,t) and group.active==true and group.source=='Char.Skills.Groups'
  and fresh(s,skill,t) and skill.source=='Char.Skills.List' and skill.known==true
  and skill.learned==true and skill.active==true and skill.class=='Infiltrator'
end
local function base(s,t)
 local c=s.infiltrator
 if not class_ok(s,c,t) then return nil,'current Infiltrator status/ownership scope required' end
 if c.pending then return nil,'issued/unknown action barrier' end
 if c.intent_revoked then return nil,'intent revoked; explicit fresh re-arm required' end
 local r=c.readiness
 if not fresh(s,r,t) then return nil,'current physical/resource readiness required' end
 local p=s.player;local aff=p.afflictions or {}
 if p.prone==true or p.mounted==true or aff.paralysis or aff.paresis or aff.asleep or aff.stun or aff.stunned then return nil,'canonical self-state veto' end
 if r.channel~='idle' then return nil,'channel active or unknown' end
 if r.phased~=false or r.mounted~=false or r.prone~=false or r.entangled~=false
  or r.paralysed~=false or r.paresis~=false or r.asleep~=false or r.stunned~=false then
  return nil,'physical hindrance or unknown self state'
 end
 if r.balance~=true or r.equilibrium~=true then return nil,'balance/equilibrium unavailable' end
 return c
end
local function budget(s,c,row,t)
 if not owned(s,c,row.group,row.ability,t) then return false,'missing current learned active '..row.group..'.'..row.ability end
 local r=c.readiness
 for resource,cost in pairs(row.costs) do
  if not number(r[resource]) or r[resource]<cost then return false,'insufficient/unknown '..resource end
 end
 local cd=c.cooldowns and c.cooldowns[row.name]
 -- Per-action runtime cooldown observation is mandatory even if ability has no AB cooldown.
 if not fresh(s,cd,t) or not number(cd.ready_at) or t<cd.ready_at then return false,'cooldown unknown/not ready' end
 if row.arms==2 and (r.left_functional~=true or r.right_functional~=true) then return false,'both functional arms required' end
 if row.arms==1 and r.left_functional~=true and r.right_functional~=true then return false,'functional arm required' end
 return true
end
local function gear(s,c,kind,t)
 local g=c.gear and c.gear[kind]
 if not fresh(s,g,t) or g.kind~=kind or g.wielded~=true or type(g.id)~='string'
  or not g.id:match('^[a-z]+%d+$') or g.venoms_known~=true or g.venom_count~=0 then
  return nil,'fresh wielded clean '..kind..' required'
 end
 if g.arm~='left' and g.arm~='right' then return nil,'weapon hand unknown' end
 if c.readiness[g.arm..'_functional']~=true then return nil,'wielding arm not functional' end
 return g
end
M.actions={
 garrote={name='garrote',group='assassination',ability='garrote',costs={endurance=30},arms=2,gear='whip',source='official:Assassination/Garrote; AC2[4704]'},
 flay={name='flay',group='assassination',ability='flay',costs={endurance=20},arms=1,gear='whip',source='official:Assassination/Flay; AC2[4822,5081]'},
 dstab={name='dstab',group='assassination',ability='doublestab',costs={endurance=30},arms=1,gear='dirk',source='official:Assassination/Doublestab; AC2[5081]'}
}
-- One canonical owner only: parent must enroll these with Buffs, not a second service.
-- No foreign-class OFF routes. No FIRSTAID, tattoo or generic-curative duplicates.
M.defense_catalog={
 {key='warding',group='assassination',ability='warding',command='warding',costs={endurance=10},arms=0,index=4354,ack_index=1223},
 {key='finesse',group='assassination',ability='finesse',command='finesse',costs={endurance=5},arms=1,index=4354,ack_index=1351},
 {key='weaving',group='assassination',ability='weaving',command='weaving on',costs={endurance=10},arms=0,drain=true,index=4354,ack_index=1349},
 {key='shadowsight',group='subterfuge',ability='shadowsight',command='shadowsight',costs={willpower=20},arms=0,index=4354,ack_index=1347},
 {key='ghosted',group='subterfuge',ability='ghost',command='conjure ghost',costs={mana=50,willpower=10},arms=0,index=4354,ack_index=1348,duration=2200},
 {key='hiding',group='subterfuge',ability='hide',command='hide',costs={endurance=20},arms=1,index=4354},
 {key='pacing',group='assassination',ability='pacing',command='pacing on',costs={endurance=10},arms=0,drain=true,index=4354},
 {key='shroud',group='subterfuge',ability='cloak',command='conjure cloak',costs={mana=50,willpower=10},arms=0,index=4354,duration=2400},
 -- Channel/stealth hazards are intentionally tracking-only, not an escape promise.
 {key='phased',group='subterfuge',ability='phase',tracking_only=true,index=818},
 {key='phaseveil',group='subterfuge',ability='phaseveil',tracking_only=true,index=nil},
 {key='recuperating',group='assassination',ability='recuperating',tracking_only=true,index=nil}
}
for _,r in ipairs(M.defense_catalog) do
 r.class='infiltrator';r.default=false;r.owner='buffs';r.name='defense_'..r.key
 r.source='official:'..r.group..'/'..r.ability..(r.index and '; AC2['..r.index..']' or '')
 r.requires={balance=true,equilibrium=true};r.canonical_native_verified=false
end
local function proposal(s,c,row,command,t)
 local g=row.gear and c.gear[row.gear]
 return {name=row.name,command=command,reason='bounded '..row.name..'; effects require independent observation',
  confidence=.85,requires={balance=true,equilibrium=true},generation=s.target_generation,
  adapter='infiltrator',session=s.session_id,life=s.life_generation,epoch=s.class_generation,
  planned_at=t,target=s.target and s.target.name,weapon=g and g.id,source=row.source,
  costs=row.costs,defense_key=row.key}
end
local function target_ok(s,c,t)
 local target=s.target or {};local w=c.target
 if not fresh(s,w,t) or w.generation~=s.target_generation or w.name~=target.name
  or w.room~=s.room_id or w.same_elevation~=true or w.present~=true or w.dead~=false
  or target.dead or type(target.name)~='string' or #target.name>100
  or not target.name:match('^[%w][%w %-%\']*$') then return false,'target scope/presence unknown' end
 if w.own~=false or w.loyal~=false or w.guard~=false or w.ambiguous~=false then return false,'own/loyal/guard/ambiguous target veto' end
 if s.mode=='BASH' then
  if w.kind~='npc' or w.player~=false or w.strict_npc_eligible~=true or not target.name:match('^%a+%d+$') then
   return false,'strict eligible NPC ID required'
  end
 elseif s.mode=='ASSIST' or s.mode=='FULL_AUTO' then
  local d=c.designation
  if w.kind~='player' or w.player~=true or not target.name:match('^%a+$') or not fresh(s,d,t)
   or d.explicit~=true or d.name~=target.name or d.generation~=s.target_generation then return false,'explicit current designated player required' end
 else return false,'mode does not permit offense' end
 if type(w.shield)~='boolean' or type(w.rebounding)~='boolean' then return false,'shield/rebounding unknown' end
 return true
end
local function can(s,c,row,t)
 local ok,why=budget(s,c,row,t);if not ok then return false,why end
 local g,err=gear(s,c,row.gear,t);if not g then return false,err end
 return true
end
function M.choose(s,at)
 local t=now(at);local c,why=base(s,t);if not c then return wait(why) end
 local ok;ok,why=target_ok(s,c,t);if not ok then return wait(why) end
 local w=c.target;local row
 if w.shield or w.rebounding then
  row=M.actions.flay;ok,why=can(s,c,row,t);if not ok then return wait(why) end
  return proposal(s,c,row,'flay '..s.target.name..' '..(w.shield and 'shield' or 'rebounding'),t)
 end
 if s.mode=='BASH' then
  row=M.actions.garrote;ok,why=can(s,c,row,t);if not ok then return wait(why) end
  return proposal(s,c,row,'garrote '..s.target.name,t)
 end
 -- Only three finite PvP branches: observed defense strip, prone damage, or
 -- one conservative two-venom opener. No hypnosis queues, all-enemy or AOE.
 local a=c.afflictions
 if not fresh(s,a,t) or a.generation~=s.target_generation or a.name~=s.target.name
  or type(a.prone)~='boolean' then return wait('current target affliction evidence required') end
 if a.prone then
  row=M.actions.garrote;ok,why=can(s,c,row,t);if not ok then return wait(why) end
  return proposal(s,c,row,'garrote '..s.target.name,t)
 end
 if a.paresis~=false or a.paralysis~=false or a.asthma~=false then return wait('opener afflictions present/unknown; re-observe') end
 row=M.actions.dstab;ok,why=can(s,c,row,t);if not ok then return wait(why) end
 if not owned(s,c,'assassination','envenom',t) then return wait('current Envenom ownership required') end
 local v=c.venoms
 if not fresh(s,v,t) or v.curare_effect~='paresis' or v.kalmia_effect~='asthma' or v.container~='rag'
  or not number(v.curare) or not number(v.kalmia) or v.curare<1 or v.kalmia<1 then return wait('known venom effects and positive rag stock required') end
 return proposal(s,c,row,'dstab '..s.target.name..' curare kalmia',t)
end
function M.defense_plan(s,key,at)
 local t=now(at);local c,why=base(s,t);if not c then return wait(why) end
 local row;for _,r in ipairs(M.defense_catalog) do if r.key==key then row=r;break end end
 if not row or row.tracking_only then return wait('manual/tracking-only defense') end
 local d=c.defenses
 if not fresh(s,d,t) or d.complete~=true or type(d.have)~='table' or type(d.canonical_verified)~='table' or d.canonical_verified[key]~=true then return wait('native canonical defense identity/list required') end
 if d.have[key]==true or (s.player.defences or {})[key]==true or s.buffs and s.buffs.have and s.buffs.have[key]==true then return wait('defense already active') end
 if d.have[key]~=false then return wait('defense state unknown') end
 if not c.defense_owner or c.defense_owner[key]~='buffs' or not c.wanted or c.wanted[key]~=true then return wait('canonical Buffs owner/explicit intent required') end
 if row.drain and (not c.drain_optin or c.drain_optin[key]~=true or not number(c.readiness.willpower) or c.readiness.willpower<=0) then return wait('drain policy/resources not opted in') end
 local ok;ok,why=budget(s,c,row,t);if not ok then return wait(why) end
 return proposal(s,c,row,row.command,t)
end
function M.validate(s,a,at)
 if type(a)~='table' or a.adapter~='infiltrator' or not scope(s,a) then return false,'foreign/stale proposal' end
 local b=a.defense_key and M.defense_plan(s,a.defense_key,at) or M.choose(s,at)
 if b.command=='' or b.command~=a.command or b.name~=a.name or b.target~=a.target or b.defense_key~=a.defense_key or b.weapon~=a.weapon or b.generation~=a.generation then return false,b.reason end
 return true
end
function M.status(s,at)
 local a=M.choose(s,at);return {class='Infiltrator',proposal=a.command,reason=a.reason,pending=s.infiltrator and s.infiltrator.pending~=nil}
end
-- Explicit state-changing lifecycle entry points. The runner owns all sends.
function M.commit(s,a,seq,at)
 local ok,why=M.validate(s,a,at);if not ok then return false,why end
 if not number(seq) then return false,'event sequence required' end
 local c=s.infiltrator;c.pending={action=a,seq=seq,at=now(at),phase='issued',ack=false}
 return true
end
function M.invalidate(s,reason)
 local c=s.infiltrator;if not c then return end
 c.intent_revoked=true;c.status=nil;c.groups={};c.skills={};c.readiness=nil;c.target=nil;c.afflictions=nil
 c.gear={};c.venoms=nil;c.defenses=nil;c.cooldowns={};c.designation=nil;c.wanted={}
 if c.pending then c.pending.phase='unknown';c.pending.invalidated=reason or 'scope change' end
 -- Never claim a physical issue was unsent; no foreign-class OFF/cancel.
end
-- Anchored first-person source candidates, not native-verified protocol promises.
-- Patterns deliberately reject third-person lookalikes and retain source indexes.
M.patterns={
 {kind='defense_gain',key='warding',index=1223,confidence=.7,pattern='^You concentrate intensely, erecting an internal shield of warding against magical energies that would damage your body%.$'},
 {kind='defense_gain',key='finesse',index=1351,confidence=.7,pattern='^You will deliver your blade with trained finesse%.$'},
 {kind='defense_gain',key='weaving',index=1349,confidence=.7,pattern='^You summon up all your agility and begin to weave back and forth to avoid blows%.$'},
 {kind='defense_gain',key='shadowsight',index=1347,confidence=.7,pattern='^Your vision is already focused on the shadows%.$'},
 {kind='defense_gain',key='ghosted',index=1348,confidence=.7,pattern='^You project a net of light about yourself until your image becomes faded and ghostly%.$'},
 {kind='defense_loss',key='ghosted',index=1350,confidence=.7,pattern='^Your ghostly image slowly intensifies until you appear flesh and blood again%.$'},
 {kind='defense_gain_generic',index=833,confidence=.7,pattern='^You have gained the ([%a_]+) defence%.$'},
 {kind='defense_loss_generic',index=834,confidence=.7,pattern='^Your ([%a_]+) defence has been stripped%.$'},
 {kind='flay_ack',effect='shield',index=2993,confidence=.7,pattern='^You use Assassination Flay %(shield%) on ([%a]+)%.$'},
 {kind='flay_ack',effect='rebounding',index=2988,confidence=.7,pattern='^You use Assassination Flay %(rebounding%) on ([%a]+)%.$'},
 {kind='flay_reject',effect='shield',index=2993,confidence=.7,pattern='^You use Assassination Flay %(failure%-shield%) on ([%a]+)%.$'},
 {kind='flay_reject',effect='rebounding',index=2989,confidence=.7,pattern='^You use Assassination Flay %(failure%-rebounding%) on ([%a]+)%.$'},
 {kind='flay_none',index=2994,confidence=.7,pattern='^You use Assassination Flay %(none%) on ([%a]+)%.$'},
 {kind='affliction_observation',index=2996,confidence=.7,pattern='^You discern that ([%a]+) has been afflicted with ([%a_ ]+)%.$'},
 {kind='suggestion_queued',index=2998,confidence=.7,pattern="^You issue the suggestion, concealing it deep within ([%a]+)'s mind%.$"},
 {kind='channel_started',index=2980,confidence=.5,pattern='^You slip behind the prone body of ([%a]+) and with grim determination wrap your whip around [%a]+ neck tightly%.$'},
 {kind='channel_ended',index=2981,confidence=.5,pattern='^You lose your grip on ([%a]+), and back away%.$'},
 {kind='reject',index=2979,confidence=.7,pattern='^Your target must be proned, if you wish do that%.$'},
 {kind='shadow_unready',index=3006,confidence=.7,pattern='^You must have shadow balance to do that%.$'},
 {kind='shadow_ready',index=3007,confidence=.7,pattern='^You have recovered shadow balance%.$'}
}
function M.parse_line(line)
 if type(line)~='string' or #line>512 or line:find('[\r\n]') then return nil end
 for _,r in ipairs(M.patterns) do
  local a,b=line:match(r.pattern)
  if a then return {kind=r.kind,key=r.key,effect=r.effect,target=(r.kind=='defense_gain_generic' or r.kind=='defense_loss_generic') and nil or a,
   value=b or a,index=r.index,confidence=r.confidence,native_verified=false} end
 end
end
function M.observe(s,line,w,at)
 local t=now(at);local c=s.infiltrator
 if not c or not class_ok(s,c,t) or not fresh(s,w,t) or w.source~='native.text' or not number(w.seq) then return false end
 local e=M.parse_line(line);if not e then return false end
 -- Observations never write enemy afflictions/defenses or debit speculative stock.
 c.last_observation=e
 local p=c.pending
 if p and not p.invalidated and w.seq>p.seq and w.at>=p.at then
  local a=p.action
  if e.kind=='flay_ack' and a.name=='flay' and e.target==a.target and a.command=='flay '..a.target..' '..e.effect then p.ack=true;p.ack_seq=w.seq;p.phase='acknowledged'
  elseif e.kind=='flay_reject' and a.name=='flay' and e.target==a.target and a.command=='flay '..a.target..' '..e.effect then p.ack=true;p.rejected=true;p.ack_seq=w.seq;p.phase='rejected'
  elseif e.kind=='defense_gain' and a.defense_key==e.key or e.kind=='defense_gain_generic' and a.defense_key==e.value then p.ack=true;p.ack_seq=w.seq;p.phase='acknowledged'
  elseif e.kind=='reject' and a.name=='garrote' then p.ack=true;p.rejected=true;p.ack_seq=w.seq;p.phase='rejected' end
  if p.ack and p.ack_seq==w.seq then p.ack_at=w.at end
 end
 return true,e
end
function M.on_prompt(s,w,at)
 local t=now(at);local c=s.infiltrator;local p=c and c.pending
 if not p or p.invalidated or not class_ok(s,c,t) or not fresh(s,w,t) or w.source~='native.prompt'
  or not number(w.seq) or not p.ack or w.seq<=p.ack_seq or w.at<(p.ack_at or p.at) or w.balance~=true or w.equilibrium~=true then return false end
 c.last_settlement={action=p.action,phase=p.phase,effect_proven=false};c.pending=nil;return true
end
return M
