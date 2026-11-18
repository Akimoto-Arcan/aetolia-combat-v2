-- Authoritative observations and explicit manual corrections, never sent-action guesses.
local M={}
local limbs={left_arm=true,right_arm=true,left_leg=true,right_leg=true,torso=true,head=true}
function M.limb(v)
 local k=tostring(v or ""):lower():gsub("%s+","_")
 k=({la="left_arm",ra="right_arm",ll="left_leg",rl="right_leg"})[k] or k
 return limbs[k] and k or nil
end
local function now() return getEpoch and getEpoch() or os.clock() end
function M.matches(s,name)
 if not name or not s.target.name then return false end
 name=tostring(name):lower()
 return name==tostring(s.target.name):lower() or (s.target.display_name and name==s.target.display_name:lower()) or false
end
-- Bind a command alias only at our own attack header, never by globally fuzzy matching.
function M.bind_attack_name(s,display)
 local t=s.target
 if not t.name or t.attacked_generation~=s.target_generation or now()-(t.last_attack_at or -100)>=2 then return false end
 local wanted=tostring(t.name):lower();display=tostring(display or ""):lower()
 local function word_match(full,token)
  local a,z=full:find(token,1,true)
  return a and (a==1 or not full:sub(a-1,a-1):match("%w")) and (z==#full or not full:sub(z+1,z+1):match("%w"))
 end
 local candidate,count=nil,0
 for id,item in pairs(s.room.items or {}) do
  local flags=item.attrib or "";local full=tostring(item.name or ""):lower()
  if (flags:find("m",1,true) or item.icon=="monster") and not flags:find("d",1,true) and not flags:find("x",1,true) and
     (tostring(id)==wanted or (not wanted:match("^%d+$") and word_match(full,wanted))) then
   count=count+1
   if full==display then candidate={id=tostring(id),name=item.name} end
  end
 end
 if count~=1 or not candidate then return false end
 t.display_name=candidate.name;t.identity={id=candidate.id,room=s.room.id,generation=s.target_generation,source="own attack + unique room NPC",time=now()}
 return true
end
function M.apply(s,e)
 if type(e)~="table" or not M.matches(s,e.target) then return false,"other target" end
 if e.generation and e.generation~=s.target_generation then return false,"old generation" end
 local t=s.target;local kind=e.kind
 if ({broken=true,mangled=true,crippled=true,affliction=true,prone=true,shield=true,rebounding=true})[kind] and type(e.value)~="boolean" then return false,"observation flag must be boolean" end
 local pvp=({limb=true,damage=true,broken=true,mangled=true,crippled=true,affliction=true,prone=true,parry=true})[kind]
 if s.mode=="BASH" and pvp then return false,"bashing does not track PvP limbs/afflictions" end
 local key=kind
 if kind=="limb" or kind=="damage" then
  local limb=M.limb(e.limb);local n=tonumber(e.amount)
  if not limb or not n or n~=n or n<0 or n>100 then return false,"invalid trauma" end
  t.limbs[limb]=kind=="damage" and math.min(100,(t.limbs[limb] or 0)+n) or n;key="limb:"..limb
 elseif kind=="broken" or kind=="mangled" or kind=="crippled" then
  local limb=M.limb(e.limb);if not limb then return false,"invalid limb" end
  t[kind][limb]=e.value~=false or nil;key=kind..":"..limb
 elseif kind=="affliction" then
  local aff=tostring(e.name or ""):lower():gsub("%s+","_")
  if not aff:match("^[%a_]+$") or #aff>60 then return false,"invalid affliction" end
  t.afflictions[aff]=e.value~=false or nil;key="aff:"..aff
 elseif kind=="parry" then
  local limb=M.limb(e.limb);if not limb and e.limb~="none" then return false,"invalid parry limb" end
  t.parry_limb=limb;t.parry_confidence=math.max(0,math.min(1,tonumber(e.confidence) or 1));t.parry_at=now()
 elseif kind=="prone" or kind=="shield" or kind=="rebounding" then t[kind]=e.value~=false
 elseif kind=="death" then t.dead=true;s.stop_reason="target slain"
 else return false,"unknown observation" end
 t.evidence=t.evidence or {};t.evidence[key]={source=e.source or "manual",confidence=tonumber(e.confidence) or 1,time=now(),generation=s.target_generation}
 s.stats.observed=(s.stats.observed or 0)+1
 s.history[#s.history+1]={time=now(),kind="observe",target=t.name,detail=key,source=e.source or "manual"};while #s.history>100 do table.remove(s.history,1) end
 return true
end
function M.parried(s,limb)
 local t,c=s.target,s.config
 return t.parry_limb==limb and (t.parry_confidence or 0)>=c.parry_min_confidence and now()-(t.parry_at or 0)<=c.parry_ttl
end
return M
