-- Tekura command syntax: https://wiki.aetolia.com/Tekura (AB in game remains authoritative).
local M={};local Tracker
function M.bind(tracker) Tracker=tracker end
local function action(name,cmd,reason,limb,kick_only)
 return {name=name,command=cmd,reason=reason,confidence=.9,limb=limb,
 requires={balance=true,equilibrium=true,left_arm_balance=not kick_only,right_arm_balance=not kick_only}}
end
local function wait(reason) return action("wait","",reason) end
local function now() return getEpoch and getEpoch() or os.clock() end
local function room(s) return s.room and s.room.id end
-- Selection is read-only. Lifecycle callers must cancel before manual target changes;
-- automatic vetted kill-chain changes may explicitly carry the self-buff scope forward.
function M.cancel_flurry(s)
 if s.hunting then s.hunting.flurry=nil;s.hunting.flurry_frame=nil end
 if s.tekura_inflight then s.tekura_inflight.cancelled=true end
end
function M.flurry_active(s)
 local f=s.hunting and s.hunting.flurry
 local frame=s.hunting and s.hunting.flurry_frame
 if not f and frame and now()-frame.created<=2 and frame.lines<=8 then f=frame end
 return f~=nil and s.mode=="BASH" and s.connected and not s.player.dead and (tonumber(s.player.hp) or 0)>0
  and f.room==room(s) and f.generation==s.target_generation
end
function M.continue_flurry(s)
 -- Only bootstrap's vetted AUTOMATIC kill-chain path may use this, never a manual retarget.
 local f=s.hunting and s.hunting.flurry
 if f and f.room==room(s) then f.generation=s.target_generation end
 local frame=s.hunting and s.hunting.flurry_frame
 if frame and frame.room==room(s) then frame.generation=s.target_generation end
end
local function settle(s,c)
 if c.cancelled or c.failed or c.rejected or not c.sent or not c.acknowledged or c.applied then return end
 if s.mode~="BASH" or c.generation~=s.target_generation or c.room~=room(s) then return end
 c.applied=true
 if c.flurry then
  local f=s.hunting and s.hunting.flurry
  if f~=c.flurry or f.index~=c.index then return end
  f.index=f.index+1
  if f.index>#f.tokens then s.hunting.flurry=nil end
 elseif c.variant then
  s.hunting.bash_variant=c.variant==1 and 2 or 1
 end
end
function M.begin_commit(s,a)
 if a.name~="flurry_strike" and a.name~="bash_strike" then return nil end
 local c={generation=s.target_generation,room=room(s),flurry=a.flurry,index=a.flurry_index,variant=a.bash_variant,
  expected=a.expected_headers,position=1,created=now()}
 s.tekura_inflight=c
 c.on_header=function(attack)
  if c~=s.tekura_inflight or c.cancelled or c.failed or c.rejected or c.acknowledged
   or c.generation~=s.target_generation or c.room~=room(s) or s.mode~="BASH" then return end
  if c.expected and attack==c.expected[c.position] then
   c.position=c.position+1
   -- The first own attack proves a normal combo executed, even on a miss/kill.
   if c.variant or c.position>#c.expected then c.acknowledged=true;settle(s,c) end
  end
 end
 return c
end
function M.finish_commit(s,c,ok)
 if not c then return end
 c.sent=ok;c.failed=not ok;settle(s,c)
end
local order={"left_leg","right_leg","left_arm","right_arm","torso","head"}
local routes={legs={"left_leg","right_leg"},arms={"left_arm","right_arm"},head={"head"},torso={"torso"},balanced=order}
local function parried(s,k)
 if Tracker then return Tracker.parried(s,k) end
 local t=s.target;return t.parry_limb==k and (t.parry_confidence or 0)>=.75
end
function M.select_limb(s)
 local t=s.target
 local function pick(pool)
  local best,n=nil,math.huge
  for _,k in ipairs(pool) do local restore=t.restoration;local restoring=restore and restore.active and restore.limb==k and (getEpoch and getEpoch() or os.clock())<(restore.expected_end or 0);if not restoring and not t.broken[k] and not t.mangled[k] and not parried(s,k) then local d=tonumber(t.limbs[k]) or 0;if d<n then best,n=k,d end end end
  return best
 end
 return pick(routes[s.config.route] or routes.legs) or pick(order)
end
function M.choose(s)
 local t,p=s.target,s.player
 local frame=s.hunting and s.hunting.flurry_frame
 if s.mode=="BASH" and not s.hunting.flurry and frame and frame.generation==s.target_generation and frame.room==room(s) and now()-frame.created<=2 and frame.lines<=8 then
  return wait("awaiting server Flurry Combo order")
 end
 if not t.name or t.name=="" then return wait("no target") end
 if t.dead then return wait("target dead") end
 if p.mounted==true or (tonumber(p.mounted) or 0)>0 then
  local a=action("dismount","quickdismount","dismount before stance or attacks",nil,true)
  a.after_stance=s.mode=="BASH" and "scorpion" or (s.config.pvp_stance or "eagle");return a
 end
 local stance_codes={scorpion="scs",eagle="egs",cobra="cbs",dragon="drs",tiger="tgs",wolf="wfs"}
 if s.dismount_stance and stance_codes[s.dismount_stance] and tostring(p.stance or ""):lower()~=s.dismount_stance then
  local a=action("stance",stance_codes[s.dismount_stance],"enter stance after confirmed dismount",nil,true);a.stance=s.dismount_stance;return a
 end
 if s.mode=="BASH" and M.flurry_active(s) then
  local f=s.hunting.flurry
  if f.awaiting or f.fault then return wait(f.fault or "awaiting server Flurry Combo order") end
  if t.shield or t.rebounding then return wait("Flurry target defence observed; do not substitute an out-of-order attack") end
 end
 if t.shield then return action("shieldbreak","sck "..t.name,"scythekick removes observed magical shield",nil,true) end
 if t.rebounding then return wait("rebounding observed; clear or re-observe defence before attacking") end
 if s.mode=="BASH" then
  local stance=tostring(p.stance or ""):lower()
  if stance~="scorpion" and stance~="scs" then
   local a=action("stance","scs","enter Scorpion before SPK/UCP/UCP bashing",nil,true);a.stance="scorpion";return a
  end
  local f=s.hunting and s.hunting.flurry
  if f and M.flurry_active(s) then
   if f.awaiting or f.fault then return wait(f.fault or "awaiting server Flurry Combo order") end
   local token=f.tokens[f.index]
   local names={hfp="hammerfist",spp="spear",hkp="hook",snk="snapkick",ucp="uppercut",sdk="sidekick",wwk="whirlwind",mnk="moonkick",jbp="jab",spk="spinkick"}
   if not names[token] then return wait("invalid Flurry state; reviewed cancellation required") end
   local a=action("flurry_strike",token.." "..t.name,"server-ordered One Thousand Blows; no PvP limb tracking")
   a.flurry=f;a.flurry_index=f.index;a.expected_headers={names[token]};a.cooldown=0
   return a
  end
  local variant=s.hunting and s.hunting.bash_variant==2 and 2 or 1
  local punch=variant==1 and "spp" or "ucp";local kick=variant==1 and "spk" or "sdk"
  local a=action("bash_strike","combo "..t.name.." "..kick.." "..punch.." "..punch,"Power Through: alternating disjoint kick/punch sets; no PvP limb tracking")
  a.bash_variant=variant;a.expected_headers={variant==1 and "spinkick" or "sidekick",variant==1 and "spear" or "uppercut",variant==1 and "spear" or "uppercut"}
  return a
 end
 local finish=t.prone and next(t.crippled)~=nil and not t.mangled.head
 local desired=finish and s.config.finish_stance or s.config.pvp_stance
 local codes={eagle="egs",cobra="cbs",dragon="drs",tiger="tgs",wolf="wfs",scorpion="scs"}
 if desired and codes[desired] and tostring(p.stance or ""):lower()~=desired then
  local a=action("stance",codes[desired],finish and "Cobra for confirmed BBT window" or "PvP preparation stance: "..desired,nil,true);a.stance=desired;return a
 end
 if t.mangled.head and t.prone then return action("axe_execute","axk "..t.name,"prone target with observed mangled head",nil,true) end
 local crippled=next(t.crippled)~=nil
 if t.prone and crippled then return action("backbreaker","bbt "..t.name,"prone target with observed crippled limb") end
 if t.broken.left_arm and t.broken.right_arm then return action("thunderkick","tnk "..t.name,"both enemy arms observed broken",nil,true) end
 if not t.prone and not t.sweep_attempted and (t.crippled.left_leg or t.crippled.right_leg or t.broken.left_leg or t.broken.right_leg) then return action("sweep","swk "..t.name,"observed leg injury; establish prone for throws",nil,true) end
 local limb=M.select_limb(s)
 if not limb then return wait("no legal unbroken, unguarded limb; review target state") end
 local side=limb:find("left",1,true) and "left" or "right"
 local parts
 if limb=="left_leg" or limb=="right_leg" then parts="snk "..side.." hfp "..side.." hfp "..side
 elseif limb=="left_arm" or limb=="right_arm" then parts="mnk "..side.." spp "..side.." spp "..side
 elseif limb=="head" then parts="wwk ucp ucp"
 else parts="sdk hkp hkp" end
 local cobra=tostring(p.stance or ""):lower()=="cobra"
 if cobra then
  if limb=="left_leg" or limb=="right_leg" then parts="snk "..side.." snk "..side
  elseif limb=="left_arm" or limb=="right_arm" then parts="mnk "..side.." mnk "..side
  elseif limb=="head" then parts="wwk wwk" else parts="sdk sdk" end
 end
 local a=action("combo","combo "..t.name.." "..parts,"route "..s.config.route.." builds "..limb.."; confirmed parry excluded",limb,cobra)
 local evidence=t.evidence["limb:"..limb]
 if not evidence then a.confidence=.5;a.reason=a.reason.."; trauma baseline unverified"
 elseif evidence.confidence<1 then a.confidence=evidence.confidence;a.reason=a.reason.."; trauma estimated" end
 return a
end
return M
