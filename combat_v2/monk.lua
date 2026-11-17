local M={}
local function a(name,cmd,reason) return {name=name,command=cmd,reason=reason or "",confidence=1} end
function M.choose(s)
  local t,p=s.target,s.player
  if not t.name or t.name=="" then return a("wait","","no target") end
  if s.mode=="BASH" then
    return a("bash_spear","combo "..t.name.." sdk spp left_leg spp left_leg","fixed spear bashing route; no limb tracking")
  end
  if t.mangled.head and t.prone and p.balance then return a("axe_execute","axk "..t.name,"mangled head on prone target") end
  if t.prone and (t.crippled.left_leg or t.crippled.right_leg) and p.balance and p.left_arm_balance and p.right_arm_balance then
    return a("backbreaker","bbt "..t.name,"prone target with crippled leg")
  end
  if p.balance and p.left_arm_balance and p.right_arm_balance then
    local limb="left_leg"
    local best=101
    for _,x in ipairs({"left_leg","right_leg","left_arm","right_arm"}) do
      local n=t.limbs[x] or 0
      if n<best and not t.broken[x] then limb,best=x,n end
    end
    return a("combo","combo "..t.name.." sdk spp "..limb.." spp "..limb,"route builds damage on "..limb)
  end
  return a("wait","","balance or equilibrium unavailable")
end
return M