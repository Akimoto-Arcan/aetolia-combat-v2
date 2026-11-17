local M = {}

function M.new()
  return {
    mode = "SHADOW",
    player = {
      hp=0,maxhp=0,mana=0,maxmana=0,
      balance=false,equilibrium=false,left_arm_balance=false,right_arm_balance=false,
      afflictions={},
    },
    target = {
      name=nil, limbs={left_arm=0,right_arm=0,left_leg=0,right_leg=0,torso=0,head=0},
      crippled={},broken={},mangled={},afflictions={},prone=false,
    },
    last_event=nil,last_action=nil,
  }
end

function M.sync_gmcp(s, g)
  local v = g and g.Char and g.Char.Vitals or {}
  local p=s.player
  p.hp=tonumber(v.hp) or p.hp; p.maxhp=tonumber(v.maxhp) or p.maxhp
  p.mana=tonumber(v.mp) or p.mana; p.maxmana=tonumber(v.maxmp) or p.maxmana
  if v.hp~=nil then s.connected=true;p.dead=(p.hp<=0) end
  local function flag(x) return x==true or tonumber(x)==1 end
  for key,field in pairs({balance="balance",equilibrium="equilibrium",left_arm="left_arm_balance",right_arm="right_arm_balance"}) do
    if v[key]~=nil then p[field]=flag(v[key]) end
  end
  return s
end

return M