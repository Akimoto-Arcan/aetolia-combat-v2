local M={}
function M.now() return getEpoch and getEpoch() or os.clock() end
function M.flag(x) return x==true or tonumber(x)==1 end
function M.valid_target(name)
 return type(name)=="string" and #name>0 and #name<=100 and not name:find("[\r\n]") and name:match("^[%w%s'%-]+$")~=nil
end
function M.target(name)
 return {name=name,limbs={left_arm=0,right_arm=0,left_leg=0,right_leg=0,torso=0,head=0},crippled={},broken={},mangled={},afflictions={},prone=false,shield=false,rebounding=false,evidence={},parry_confidence=0}
end
function M.new()
 return {mode="OFF",connected=false,target_generation=0,player={hp=0,maxhp=0,mana=0,maxmana=0,balance=false,equilibrium=false,left_arm_balance=false,right_arm_balance=false,afflictions={},defences={}},target=M.target(),
 config={route="legs",health_pause=30,health_resume=60,ack_timeout=8,stale_vitals=20,parry_ttl=8,parry_min_confidence=.75,estimate_trauma=true,kick_trauma=8.99,punch_trauma=5.49,boost_kick_trauma=10.8,boost_punch_trauma=6.6},
 hunting={queue={},active=false,kills=0,skipped=0},recoveries={},reject_sequence=0,history={},stats={sent=0,observed=0,stops=0},room={items={}},last_event=nil,last_action=nil}
end
local function merge(t,defaults)
 for k,v in pairs(defaults) do if t[k]==nil then t[k]=v elseif type(v)=="table" and type(t[k])=="table" then merge(t[k],v) end end
 return t
end
function M.upgrade(s) return merge(s or {},M.new()) end
function M.record(s,kind,detail)
 s.history=s.history or {};s.history[#s.history+1]={time=M.now(),kind=kind,detail=detail,target=s.target.name,generation=s.target_generation}
 while #s.history>100 do table.remove(s.history,1) end
end
function M.set_target(s,name)
 name=tostring(name or ""):match("^%s*(.-)%s*$")
 if name~="" and not M.valid_target(name) then return false,"invalid target" end
 name=name~="" and name or nil
 if s.target.name~=name then s.target=M.target(name);s.target_generation=(s.target_generation or 0)+1;s.hit_context=nil;s.last_action=nil;M.record(s,"target",name or "cleared") end
 s.stop_reason=nil;return true
end
function M.sync_gmcp(s,g)
 local v=g and g.Char and g.Char.Vitals or {};local p=s.player
 for key,field in pairs({hp="hp",maxhp="maxhp",mp="mana",maxmp="maxmana",kai="kai"}) do if tonumber(v[key]) then p[field]=tonumber(v[key]) end end
 if v.hp~=nil then s.connected=true;p.dead=p.hp<=0 end
 if next(v)~=nil then s.vitals_at=M.now() end
 for key,field in pairs({balance="balance",equilibrium="equilibrium",left_arm="left_arm_balance",right_arm="right_arm_balance",prone="prone",mounted="mounted"}) do if v[key]~=nil then p[field]=M.flag(v[key]) end end
 if v.stance then p.stance=tostring(v.stance) end
 return s
end
return M
