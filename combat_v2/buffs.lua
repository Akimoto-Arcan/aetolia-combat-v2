-- Monk preparations only. No IO, global sender, emergency abilities or ENEMY changes.
-- Intent is revocable; an already dispatched action is a physical barrier until
-- confirmed AND followed by a real ready prompt. Only reset may waive that barrier.
local M={}
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
local function now() return getEpoch and getEpoch() or os.clock() end
local function norm(x) return tostring(x or ''):lower():gsub('[%s_%-]','') end
local index,aliases={},{}
for _,e in ipairs(M.catalog) do
 index[e.key]=e;aliases[norm(e.key)]=e.key;aliases[norm(e.label)]=e.key
 for _,id in ipairs(e.ids or {}) do aliases[norm(id)]=e.key end
end
local function key(x)
 if type(x)=='table' then x=x.name or x.id or x.key end
 return aliases[norm(x)]
end
local function yes(x) return x==true or tonumber(x)==1 end
local function ready(s)
 local p=s.player or {};local a=p.afflictions or {}
 if not (yes(p.balance) and yes(p.equilibrium) and yes(p.left_arm_balance) and yes(p.right_arm_balance)) then return false end
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
 return s.buffs
end
function M.stop(s,reason)
 local b=M.state(s);b.master=false;b.sequence=false;b.todo=nil;b.cancel={};b.query=nil
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
  b.known={};b.known_ready=false;b.listing=nil;b.ability_listing=nil
  if b.pending then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false end
 end
 if class~='monk' then M.stop(s,'Monk class required') end
 return class=='monk'
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
function M.set_known(s,names)
 local b=M.state(s);b.known={}
 each_name(names,function(v) local k=key(v);if k then b.known[k]=true end end)
 b.known_ready=true
 if b.query and b.query.kind=='skills' then b.query=nil end
 return true
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
 local b=M.state(s);b.have[k]=on or nil
 local p=s.player or {};p.defences=p.defences or {};s.player=p
 -- Keep legacy identifiers consumed by mental.lua coherent, without replacing
 -- generic GMCP defences (which include many unrelated abilities).
 p.defences[k]=on or nil
 if not on then
  for id in pairs(p.defences) do if key(id)==k then p.defences[id]=nil end end
 end
 if k=='trance' then p.defences.kai_trance=on or nil end
 if k=='boosting' then p.defences.boosted_regen=on or nil end
 if not on and index[k].cooldown_loss then b.cooldown[k]=now()+index[k].cooldown_loss end
 local pending=b.pending
 if pending and pending.key==k and pending.off==not on then pending.confirmed=true end
end
local function snapshot(s,have)
 local b=M.state(s)
 for _,e in ipairs(M.catalog) do
  -- Missing vitality in a first snapshot is NOT evidence it was triggered.
  if have[e.key] or b.have[e.key] or canonical_have(s,e.key) then observe(s,e.key,have[e.key]==true) end
 end
 b.have=have;b.defs_known=true;b.defs_at=now()
 local p=b.pending
 if p then p.confirmed=(have[p.key]==true)~=p.off end
 if b.query and b.query.kind=='defs' then b.query=nil end
end
function M.sync(s,kind,payload)
 local b=M.state(s);kind=norm(kind):match('([^%.]+)$')
 if kind=='list' then
  local have={};each_name(payload,function(v)local k=key(v);if k then have[k]=true end end);snapshot(s,have)
 elseif kind=='add' or kind=='remove' then
  each_name(payload,function(v)local k=key(v);if k then observe(s,k,kind=='add') end end)
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
 ['You are regenerating lost health through the power of Kaido.']='boosting',
 ['You are regenerating lost health through will.']='regeneration',
 ['You begin to concentrate on regeneration of your wounds.']='regeneration',
 ['Your regeneration is boosted.']='boosting'
}
function M.text(s,line)
 if type(line)~='string' then return end
 local b=M.state(s)
 if line=='You possess the following abilities in Kaido:' then b.ability_listing={};return end
 if b.ability_listing then
  if line:match('^Type AB KAIDO <ability>') then
   M.set_known(s,b.ability_listing);b.ability_listing=nil;return
  end
  local name=line:match('^%s*([%a][%a ]-)%s%s+%S')
  local k=name and key(name);if k then b.ability_listing[#b.ability_listing+1]=k end
 end
 if line=='You have the following active defences:' then b.listing={};return end
 if line:match('^You are protected by %d+ defences%.$') and b.listing then
  -- Our text recognizer is partial. Unrecognized rows are not absent defenses.
  -- Only a full GMCP List may clear existing positives or establish known absence.
  b.listing=nil;return -- Rows were observed immediately; never replay stale evidence.
 end
 local k=confirmations[line]
 if k then if b.listing then b.listing[k]=true end;observe(s,k,true);return end
 local name=line:match('^You have gained the ([%a_ %-]+) defence%.$')
 if name then k=key(name);if k then observe(s,k,true);if b.listing then b.listing[k]=true end end;return end
 name=line:match('^You have lost the ([%a_ %-]+) defence%.$')
 if name then k=key(name);if k then observe(s,k,false) end;return end
 if b.pending and (line=='You must regain balance first.' or line=='You must regain equilibrium first.' or
  line=='You do not possess that ability.' or line=='You have not learned that ability.' or line=='You do not know that ability.' or
  line=='You know of no such ability.' or line=='You cannot perform that ability.' or line=='You have not yet learned that ability.') then
  b.pending.rejected=true;b.retry[b.pending.key]=now()+5;fault(b,'Buff rejected: '..line..' Review/reset required')
 end
end
function M.start(s)
 local b=M.state(s)
 if b.class~='monk' then return false,'Monk class required' end
 if b.fault then return false,b.fault end
 if b.pending then return false,'Buff action unresolved; await confirmation/recovery or reviewed reset' end
 b.sequence=true;b.todo={};for _,e in ipairs(M.catalog) do if b.wanted[e.key] then b.todo[e.key]=true end end
 b.status='defup requested';return true,b.status
end
function M.master(s,on)
 local b=M.state(s)
 if on~=true then
  b.master=false;b.status='maintenance paused; active defences retained'
  return true,b.status -- Explicit off queue and one-shot intent are independent.
 end
 if b.class~='monk' then return false,'Monk class required' end
 if b.fault then return false,b.fault end
 b.master=true;b.status='maintenance armed';return true,b.status
end
function M.toggle(s,name,on)
 local b=M.state(s);local k=key(name);local e=k and index[k]
 if not e then return false,'Unknown defence' end
 if type(on)~='boolean' then return false,'Expected boolean' end
 if on then
  local ok,why=M.master(s,true);if not ok then return false,why end
  b.wanted[k]=true;b.cancel[k]=nil;return true,why
 end
 b.wanted[k]=false
 if b.todo then b.todo[k]=nil end
 -- Queue even if currently absent: a preceding in-flight ON can still succeed.
 if e.off then b.cancel[k]=true;return true,e.label..' off queued (confirmation required)' end
 return true,e.label..' upkeep off; no verified cancellation, active defence retained'
end
function M.on_prompt(s)
 local b=M.state(s);b.prompt=b.prompt+1
 if b.pending then b.pending.prompt=b.prompt;b.pending.prompt_ready=ready(s) end
end
local function percent(v,max)
 v,max=tonumber(v),tonumber(max);if not v or not max or max<=0 then return nil end
 return 100*v/max
end
local function eligible(s,b,e)
 local p=s.player;local hp=percent(p.hp,p.maxhp);local mp=percent(p.mana,p.maxmana)
 if not hp or not mp or hp<65 or mp<50 then return false,'resources' end
 if e.requires_full and (hp<100 or mp<100) then return false,'full HP and mana required' end
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
local function service(s,runner,sender,hold)
 local b=M.state(s);local t=now()
 if b.class~='monk' or not connected(s) or s.training_battle_ended then
  M.stop(s,'disconnected/dead/class/training stop');b.defs_known=false;b.known_ready=false
  b.listing=nil;b.ability_listing=nil
  if b.pending then b.pending.prompt=nil;b.pending.prompt_ready=false end
  return {busy=b.pending~=nil,status=b.status}
 end
 -- Recovery is processed even while intent is disarmed or survival holds.
 local p=b.pending
 if p then
  if not p.send_failed and not p.rejected and p.confirmed and p.prompt and p.prompt>p.dispatched_prompt and p.prompt_ready and ready(s) then
   b.pending=nil
   if b.fault==p.timeout_fault then b.fault=nil end
   b.retry[p.key]=t+2;b.status='confirmed: '..p.key
   return {busy=false,status=b.status}
  end
  if t-p.at>=12 and not b.fault then
   p.timeout_fault='Buff acknowledgement timed out; review/reset required';fault(b,p.timeout_fault)
  end
  -- One reconciliation only, after a real prompt, never activation retry.
  if not b.fault and not p.confirmed and p.prompt and p.prompt>p.dispatched_prompt and not p.queried then
   p.queried=true
   if not send_checked(b,sender,'defences') then p.send_failed=true end
  end
  return {busy=true,status=b.fault or 'awaiting buff confirmation and ready prompt'}
 end
 if b.fault then return {busy=false,status=b.fault} end
 if not b.master and not b.sequence and not next(b.cancel) then return {busy=false,status=b.status} end
 local can_cancel=false
 for _,e in ipairs(M.catalog) do
  if b.cancel[e.key] and e.off and b.known_ready and b.known[e.key] then can_cancel=true;break end
 end
 if (hold and not can_cancel) or (s.walker and s.walker.pending) or (runner and (runner.waiting or runner.fault)) or
  (s.mental and (s.mental.eq_pending or s.mental.fault)) or not ready(s) then return {busy=false,status='waiting for safe readiness'} end
 -- Unknown authoritative snapshots are solicited once, with a bounded wait.
 if b.query then
  if t-b.query.at>=12 then fault(b,'Buff '..b.query.kind..' snapshot timed out; review/reset required') end
  return {busy=false,status=b.fault or 'awaiting '..b.query.kind..' snapshot'}
 end
 if not b.known_ready then
  b.query={kind='skills',at=t};send_checked(b,sender,'ab kaido')
  return {busy=false,status=b.fault or 'requested Kaido abilities'}
 end
 if not b.defs_known then
  b.query={kind='defs',at=t};send_checked(b,sender,'defences')
  return {busy=false,status=b.fault or 'requested defence snapshot'}
 end
 local chosen,off
 for _,e in ipairs(M.catalog) do
  if b.cancel[e.key] then
   if e.off and b.known[e.key] then chosen=e;off=true;break end
   b.cancel[e.key]=nil -- Never send unlearned syntax.
  end
 end
 if not chosen and hold then return {busy=false,status='waiting for safe readiness'} end
 if not chosen then
  for _,e in ipairs(M.catalog) do
   local selected=b.sequence and b.todo[e.key] or b.master and b.wanted[e.key]
   if selected and b.wanted[e.key] then
    if b.todo then b.todo[e.key]=nil end -- one-shot skips once, never pins offense
    local ok=eligible(s,b,e)
    if not b.have[e.key] and not canonical_have(s,e.key) and b.known[e.key] and ok then chosen=e;break end
   end
  end
 end
 if not chosen then
  b.sequence=false;b.todo=nil;b.status=b.master and 'maintenance monitoring' or 'defup complete'
  return {busy=false,status=b.status}
 end
 if off then b.cancel[chosen.key]=nil end
 p={key=chosen.key,off=off==true,at=t,dispatched_prompt=b.prompt,confirmed=false}
 b.pending=p -- Before calling the sender: synchronous fake callbacks cannot double-send.
 local ok=send_checked(b,sender,off and chosen.off or chosen.command)
 if not ok then p.send_failed=true end
 b.status=b.fault or 'sent: '..(off and chosen.off or chosen.command)
 return {busy=true,status=b.status}
end
function M.service(s,runner,sender,hold)
 local b=M.state(s)
 if b.servicing then return {busy=b.pending~=nil,status='buff service reentrant; deferred'} end
 b.servicing=true
 local ok,result=pcall(service,s,runner,sender,hold)
 b.servicing=false
 if not ok then fault(b,'Buff service error: '..tostring(result)..'; review/reset required');return {busy=b.pending~=nil,status=b.fault} end
 return result
end
return M
