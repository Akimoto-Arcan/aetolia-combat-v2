-- Anchored adapters from Fallout autosave.xml and AC2.2.xml; see docs/backend.md.
-- Only first-person, selected-target hit contexts can update estimated trauma.
local M={};local Tracker
function M.bind(tracker) Tracker=tracker end
local function now() return getEpoch and getEpoch() or os.clock() end
local function same(s,name)
 if Tracker then return Tracker.matches(s,name) end
 return s.target.name and tostring(s.target.name):lower()==tostring(name):lower()
end
local function observe(s,kind,fields)
 if not Tracker then return false end
 local e={kind=kind,target=s.target.name,source="combat text",confidence=1,generation=s.target_generation}
 for k,v in pairs(fields or {}) do e[k]=v end
 return Tracker.apply(s,e)
end
local function recovery(s,key)
 s.player[key]=true;s.recoveries[key]=(s.recoveries[key] or 0)+1
end
local function affliction(s,name,on)
 local normalized=name:lower():gsub("^an? ",""):gsub("%s+","_")
 local marker,limb=normalized:match("^(broken)_(.+)$")
 if not marker then marker,limb=normalized:match("^(crippled)_(.+)$") end
 if not marker then marker,limb=normalized:match("^(mangled)_(.+)$") end
 if not marker then limb,marker=normalized:match("^(.+)_(broken)$") end
 if not marker then limb,marker=normalized:match("^(.+)_(crippled)$") end
 if not marker then limb,marker=normalized:match("^(.+)_(mangled)$") end
 if marker and Tracker.limb(limb) then limb=Tracker.limb(limb);normalized=limb.."_"..marker;observe(s,marker,{limb=limb,value=on});if on and (marker=="broken" or marker=="mangled") and (limb:find("arm",1,true) or limb:find("leg",1,true)) then observe(s,"crippled",{limb=limb,value=true}) end end
 if normalized=="prone" or normalized=="fallen" then observe(s,"prone",{value=on}) end
 observe(s,"affliction",{name=normalized,value=on})
end
local attacks={sidekick={torso=true,kick=true},cometkick={torso=true,kick=true},snapkick={left_leg=true,right_leg=true,kick=true},moonkick={left_arm=true,right_arm=true,kick=true},whirlwind={head=true,kick=true},axe={head=true,kick=true},hammerfist={left_leg=true,right_leg=true},spear={left_arm=true,right_arm=true},hook={torso=true},uppercut={head=true}}
local function context(s)
 local ctx=s.hit_context
 if ctx and ctx.generation==s.target_generation and ctx.expires>=now() then return ctx end
 s.hit_context=nil
end
local function injury(s,actor,raw,kind)
 if not same(s,actor) then return false end
 local limb=Tracker and Tracker.limb(raw);if not limb then return false end
 observe(s,kind,{limb=limb,value=true})
 if (kind=="broken" or kind=="mangled") and (limb:find("arm",1,true) or limb:find("leg",1,true)) then observe(s,"crippled",{limb=limb,value=true}) end
 return true
end
function M.event(s,text)
 if type(text)~="string" then return s end
 text=text:gsub(string.char(27).."%[[%d;]*m",""):match("^%s*(.-)%s*$")
 s.last_event=text;local low=text:lower();local p=s.player
 if text=="You sink back into the menacing stance of the Scorpion." then p.stance="scorpion";return s end
 if text=="Making a call to your own, you kip yourself up and sink back into the Scorpion stance." then p.stance="scorpion";p.prone=false;return s end
 local stance=text:match("^You are in the (%w+) stance%.$");if stance then p.stance=stance:lower();return s end
 local channels={['You have recovered balance on your left arm.']='left_arm_balance',['You have recovered balance on your right arm.']='right_arm_balance',['You have recovered balance on all limbs.']='balance',['You have recovered balance on your legs.']='balance',['You have recovered equilibrium.']='equilibrium'}
 if channels[text] then recovery(s,channels[text]);return s end
 if low=="you are prone." then p.prone=true end
 if low=="you have risen." or low=="you kip up." then p.prone=false end
 if low:match("^you have been slain by .+%.$") or low=="you have died." then p.hp=0;p.dead=true;s.stop_reason="player death";s.hit_context=nil;return s end
 local absent=text:match("^You can find no such target as '(.*)'%.$")
 if absent and same(s,absent) or low=="you detect nothing here by that name." or low=="nothing can be seen here by that name." or low=="you cannot see that being here." or low=="you can find nothing here by that name." or low=="you cannot see that here." or low=="there is nothing here by that name." or low=="no such target." then s.stop_reason="target unavailable";s.hit_context=nil;return s end
 local slain=text:match("^You have slain (.+)%.$") or text:match("^Having slain (.+), you retrieve the corpse%.$")
 local pending_numeric=slain and s.mode=="BASH" and s.hunting.active and tostring(s.target.name):match("^%d+$") and not s.target.display_name and s.target.attacked_generation==s.target_generation and now()-(s.target.last_attack_at or -100)<2
 if slain and (same(s,slain) or pending_numeric) then
  if pending_numeric then s.target.display_name=slain end
  if not s.hunting.active or s.target.attacked_generation==s.target_generation then s.target.dead=true;s.stop_reason="target slain";s.combat_response="kill";s.hit_context=nil end
  return s
 end
 -- Explicitly scoped training-proxy reports; ordinary speech is never combat truth.
 local training=s.training
 local report=text:match('^A runed target dummy says, "(.-)"$')
 if report and training and training.enabled and training.generation==s.target_generation and training.room==s.room.id and same(s,training.target) then
  local limb,amount,total=report:match("^My (.-) took ([%d%.]+)%% damage%. It is now at ([%d%.]+)%% total%.$")
  limb=limb and Tracker.limb(limb)
  if limb and tonumber(total) and tonumber(total)<=100 then
   local restore=s.target.restoration;local previous=s.target.limbs[limb] or 0;local evidence=s.target.evidence["limb:"..limb]
   if restore and restore.active and restore.limb==limb and evidence and evidence.source=="scoped training dummy report" and previous+(tonumber(amount) or 0)-tonumber(total)>.1 then
    restore.active=false;restore.confirmed_reduction=previous+(tonumber(amount) or 0)-tonumber(total);restore.confirmed_cure=now()
   end
   observe(s,"limb",{limb=limb,amount=tonumber(total),source="scoped training dummy report",confidence=1});return s
  end
  local gained=report:match("^I was afflicted with ([%a_]+)%.$")
  local cured=report:match("^I was cured of ([%a_]+)%.$")
  if gained or cured then
   affliction(s,gained or cured,gained~=nil)
   local restore=s.target.restoration
   if cured and restore and cured:find(restore.limb,1,true) then restore.active=false;restore.confirmed_cure=now() end
   return s
  end
 end
 local who,where=text:match("^(.+) presses a restoration poultice against %w+ (.-), rubbing .- into .- flesh%.$")
 if who and same(s,who) and Tracker.limb(where) and s.mode~="BASH" then
  s.target.restoration={limb=Tracker.limb(where),started=now(),expected_end=now()+4.1,active=true,source="observed poultice application",confidence=.65}
  return s
 end
 -- Named injury confirmations ported from AC2.2 generic salve attacks and Kaido.
 local victim,part=text:match("^(.+)'s (.+) breaks from all the damage%.$")
 if not victim then victim,part=text:match("^(.+)'s (.+) is shredded into meaty ribbons%.$") end
 if victim and injury(s,victim,part,"broken") then return s end
 victim,part=text:match("^(.+)'s (.+) has been beaten into uselessness%.$")
 if not victim then victim,part=text:match("^(.+)'s (.+) has been torn into uselessness%.$") end
 if victim and injury(s,victim,part,"mangled") then return s end
 victim,part=text:match("^(.+)'s (.+) is badly crippled under the .+%.$")
 if not victim then victim,part=text:match("^(.+)'s (.+) breaks in half%.$") end
 if victim and injury(s,victim,part,"crippled") then return s end
 victim=text:match("^(.+)'s broken legs cause .+ to fall to the ground in a heap%.$")
 if victim and same(s,victim) then observe(s,"crippled",{limb="left_leg",value=true});observe(s,"crippled",{limb="right_leg",value=true});observe(s,"prone",{value=true});return s end
 victim=text:match("^(.+) buckles to the ground with a shuddering fall%.$")
 if victim and same(s,victim) then observe(s,"prone",{value=true});return s end
 victim=text:match("^(.+) lifts itself upright from the ground%.$")
 if victim and same(s,victim) then observe(s,"prone",{value=false});return s end
 local actor,aff=text:match("^You discern that (%w+) has been afflicted with (.+)%.$")
 if actor and same(s,actor) then affliction(s,aff,true);return s end
 actor,aff=text:match("^You discern that (%w+) has cured the effects of (.+)%.$")
 if actor and same(s,actor) then affliction(s,aff,false);return s end
 actor=text:match("^You connect and send (.+) sprawling to the floor%.$") or text:match("^(.+) is knocked to the ground%.$") or text:match("^You knock the legs out from under (.+) and send %w+ sprawling%.$") or text:match("^You hear two loud snaps and see (%w+) fall to the ground%.$")
 if actor and same(s,actor) then observe(s,"prone",{value=true});observe(s,"affliction",{name="fallen",value=true});return s end
 actor=text:match("^(.+) stands up and stretches %w+ arms out wide%.$") or text:match("^(%w+) uses Tekura Kipup%.?$") or text:match("^(%w+) swings %w+ legs around and rises up from the ground%.$")
 if actor and same(s,actor) then observe(s,"prone",{value=false});observe(s,"affliction",{name="fallen",value=false});observe(s,"affliction",{name="prone",value=false});return s end
 actor=text:match("^A nearly invisible magical shield forms around (.+)%.$")
 if actor and same(s,actor) then observe(s,"shield",{value=true});return s end
 actor=text:match("^A dizzying beam of energy strikes you as your attack rebounds off of (.+)'s shield%.$")
 if actor and same(s,actor) then observe(s,"shield",{value=true});s.reject_sequence=s.reject_sequence+1;s.hit_context=nil;return s end
 actor=text:match("^The protective shield around (.+) dissipates%.$") or text:match("^(.+)'s magical shield is sheared straight through%.$")
 if actor and same(s,actor) then observe(s,"shield",{value=false});return s end
 actor=text:match("^You suddenly perceive the vague outline of an aura of rebounding around (%w+)%.$")
 if actor and same(s,actor) then observe(s,"rebounding",{value=true});return s end
 actor=text:match("^(%w+)'s aura of rebounding is pierced and shredded under the attack%.$")
 if actor and same(s,actor) then observe(s,"rebounding",{value=false});return s end
 local ctx=context(s)
 if text=="The attack rebounds back onto you!" and ctx then observe(s,"rebounding",{value=true});s.reject_sequence=s.reject_sequence+1;s.hit_context=nil;return s end
 local attack,target=text:match("^You use Tekura (%w+) on (.+)%.$")
 if not attack then target=text:match("^You form a spear hand and stab out towards (%w+)%.$");if target then attack="spear" end end
 if not attack then target=text:match("^You pump out at (%w+) with a powerful side kick%.$");if target then attack="sidekick" end end
 if attack then
  attack=attack:lower()
  local matched=same(s,target)
  if not matched and attacks[attack] and Tracker and Tracker.bind_attack_name then matched=Tracker.bind_attack_name(s,target) end
  if matched and attacks[attack] then s.hit_context={attack=attack,target=s.target.name,generation=s.target_generation,expires=now()+2,remaining=5} else s.hit_context=nil end
  return s
 end
 ctx=context(s)
 if ctx then
  local defender,limb=text:match("^(%w+) parries the attack on %w+ (.+) with a deft maneuver%.$")
  if not defender then defender,limb=text:match("^(%w+) guards the attack on %w+ (.+)%.$") end
  if not defender then defender,limb=text:match("^(%w+) steps into the attack on%s+%w+ (.+), grabs your arm, and shakes you violently%.$") end
  if not defender then defender,limb=text:match("^With a free hand, (%w+) fends off the attack on %w+ (.+)%.$") end
  if defender then if same(s,defender) then observe(s,"parry",{limb=limb}) end;s.hit_context=nil;return s end
  local dodger=text:match("^Stepping quickly out of the way, (%w+) dodges the attack%.$")
  if dodger or text=="You miss your strike by mere inches." or text=="Your swing falls short of its target." then s.hit_context=nil;return s end
  local hit=text:match("^You connect to the (.+)!$")
  if hit then
   local k=Tracker and Tracker.limb(hit);local spec=attacks[ctx.attack]
   if k and spec[k] then
    s.target.last_hit={limb=k,attack=ctx.attack,time=now(),source="confirmed connection"}
    if s.config.estimate_trauma then
     local stance=tostring(p.stance or ""):lower();local boost=stance=="tiger" or stance=="cobra"
     local amount=spec.kick and (boost and s.config.boost_kick_trauma or s.config.kick_trauma) or (boost and s.config.boost_punch_trauma or s.config.punch_trauma)
     observe(s,"damage",{limb=k,amount=amount,source="legacy estimate after confirmed hit",confidence=.65})
    end
   end
   s.hit_context=nil;return s
  end
  ctx.remaining=ctx.remaining-1;if ctx.remaining<=0 then s.hit_context=nil end
 end
 return s
end
return M
