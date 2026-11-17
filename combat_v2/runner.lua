local M={}
local function now() return getEpoch and getEpoch() or os.clock() end
local function yes(x) return x==true or tonumber(x)==1 end
function M.new(s,monk) return {state=s,monk=monk,mode="OFF",waiting=false,enabled=true,last_send=-100,cooldown=.3,status="OFF"} end
function M.ready(r)
 local p=r.state.player
 return yes(p.balance) and yes(p.equilibrium) and yes(p.left_arm_balance) and yes(p.right_arm_balance)
end
function M.propose(r)
 r.state.mode=r.mode; local a=r.monk.choose(r.state); r.state.last_action=a; return a
end
function M.stop(r,reason) r.mode="OFF";r.state.mode="OFF";r.pending=nil;r.waiting=false;r.status=reason or "OFF" end
function M.execute(r,a,approved)
 local s,p=r.state,r.state.player
 local function deny(msg) r.status=msg;return false,msg end
 if r.mode=="OFF" or r.mode=="SHADOW" then return deny(r.mode) end
 if not s.connected then return deny("not logged in / disconnected") end
 if (tonumber(p.hp) or 0)<=0 or p.dead then return deny("dead / no vitals") end
 if not s.target.name or not tostring(s.target.name):match("^[%w%s'%-]+$") then return deny("no valid target") end
 if r.waiting then return deny("waiting for balance recovery") end
 if not M.ready(r) then return deny("waiting for full balance") end
 if now()-r.last_send<r.cooldown then return deny("cooldown") end
 if not a or type(a.command)~="string" or a.command=="" or a.command:find("[;\r\n]") then return deny("no valid action") end
 if r.mode=="ASSIST" and not approved then r.pending=a;return deny("approval required") end
 local sender=r.sender or send
 r.waiting=true;r.saw_unready=false;r.last_send=now();r.pending=nil;r.state.last_action=a;r.status="sent: "..a.command
 sender(a.command);return true,a.command
end
function M.approve(r)
 if r.mode~="ASSIST" or not r.pending then return false,"no pending action" end
 return M.execute(r,r.pending,true)
end
function M.update_balance(r)
 if r.waiting then
  if not M.ready(r) then r.saw_unready=true
  elseif r.saw_unready then r.waiting=false;r.saw_unready=false end
 end
end
function M.tick(r)
 M.update_balance(r)
 if r.mode=="OFF" then return false,"OFF" end
 return M.execute(r,M.propose(r))
end
return M
