-- Tekura command syntax: https://wiki.aetolia.com/Tekura (AB in game remains authoritative).
local M={};local Tracker
function M.bind(tracker) Tracker=tracker end
local function action(name,cmd,reason,limb,kick_only)
 return {name=name,command=cmd,reason=reason,confidence=.9,limb=limb,
 requires={balance=true,equilibrium=true,left_arm_balance=not kick_only,right_arm_balance=not kick_only}}
end
local function wait(reason) return action("wait","",reason) end
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
 if t.shield then return action("shieldbreak","sck "..t.name,"scythekick removes observed magical shield",nil,true) end
 if t.rebounding then return wait("rebounding observed; clear or re-observe defence before attacking") end
 if s.mode=="BASH" then
  local stance=tostring(p.stance or ""):lower()
  if stance~="scorpion" and stance~="scs" then
   local a=action("stance","scs","enter Scorpion before SPK/UCP/UCP bashing",nil,true);a.stance="scorpion";return a
  end
  return action("bash_strike","combo "..t.name.." spk ucp ucp","Spinkick and two Uppercuts; no PvP limb tracking")
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
