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
  for _,k in ipairs(pool) do if not t.broken[k] and not t.mangled[k] and not parried(s,k) then local d=tonumber(t.limbs[k]) or 0;if d<n then best,n=k,d end end end
  return best
 end
 return pick(routes[s.config.route] or routes.legs) or pick(order)
end
function M.choose(s)
 local t,p=s.target,s.player
 if not t.name or t.name=="" then return wait("no target") end
 if t.dead then return wait("target dead") end
 if t.shield then return action("shieldbreak","sck "..t.name,"scythekick removes observed magical shield",nil,true) end
 if t.rebounding then return wait("rebounding observed; clear or re-observe defence before attacking") end
 if s.mode=="BASH" then
  local stance=tostring(p.stance or ""):lower()
  if stance~="scorpion" and stance~="scs" then
   return action("bash_scorpion","combo "..t.name.." scs spp spp","enter scorpion and spear twice; no PvP limb tracking")
  end
  return action("bash_spear","combo "..t.name.." sdk spp spp","scorpion spear bashing; no PvP limb tracking")
 end
 if t.mangled.head and t.prone then return action("axe_execute","axk "..t.name,"prone target with observed mangled head",nil,true) end
 local crippled=next(t.crippled)~=nil
 if t.prone and crippled then return action("backbreaker","bbt "..t.name,"prone target with observed crippled limb") end
 if t.broken.left_arm and t.broken.right_arm then return action("thunderkick","tnk "..t.name,"both enemy arms observed broken",nil,true) end
 if not t.prone and (t.crippled.left_leg or t.crippled.right_leg or t.broken.left_leg or t.broken.right_leg) then return action("sweep","swk "..t.name,"observed leg injury; establish prone for throws",nil,true) end
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
