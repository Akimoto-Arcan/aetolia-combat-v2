local root=getMudletHomeDir().."/combat_v2/"
local convenience=dofile(root.."travel_boot.lua")
if combat_v2 and convenience.busy(combat_v2)then print("Reload refused: unresolved travel/inking retained");return end
combat_v2=combat_v2 or {};local c=combat_v2
for _,key in ipairs({"gmcp_handler","text_handler"}) do if c[key] then killAnonymousEventHandler(c[key]);c[key]=nil end end
for _,id in ipairs(c.handlers or {}) do killAnonymousEventHandler(id) end
for _,key in ipairs({"line_trigger","prompt_trigger","buff_prompt_trigger"}) do if c[key] then killTrigger(c[key]) end end
for _,key in ipairs({"alias","target_alias"}) do if c[key] then killAlias(c[key]) end end
for _,key in ipairs({"retry_timer","watch_timer","ih_timer","buff_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
c.state=dofile(root.."state.lua");c.current=c.state.upgrade(c.current)
c.tracker=dofile(root.."tracker.lua");c.bashing=dofile(root.."bashing.lua");c.bashing.bind(c.state);c.mobs=dofile(root.."mobs.lua");c.bashing.bind_mobs(c.mobs)
c.monk=dofile(root.."monk.lua");c.monk.bind(c.tracker)
c.events=dofile(root.."events.lua");c.events.bind(c.tracker)
c.runner_module=dofile(root.."runner.lua");c.curing=dofile(root.."curing.lua");c.gui=dofile(root.."gui.lua")
c.policy=dofile(root.."policy.lua");c.policy.init(c.current,gmcp or {});c.runner_module.bind_policy(c.policy.attack_allowed)
c.runner=c.runner_module.new(c.current,c.monk);c.cure=(c.cure and c.cure.status) and c.cure or c.curing.new()
c.defense=dofile(root.."defense.lua");c.runner_module.bind_defense(c.defense.hold)
if c.defense.attach then c.defense.attach(c)end
c.mental=dofile(root.."mental.lua");c.mental.bind_defense(c.defense);c.current.mental=nil;c.current.config.pvp_stance=c.current.config.pvp_stance or "eagle";c.current.config.finish_stance=c.current.config.finish_stance or "cobra"
c.mode="OFF";c.current.mode="OFF";c.current.hunting.active=false;c.current.stop_reason=nil
local function refresh() c.gui.refresh(c.current,c.runner,c.cure) end
-- Buff preparation/upkeep is separate from FIRSTAID's survival governor.
c.buffs=dofile(root.."buffs.lua");c.buffs.stop(c.current,"reload; upkeep disarmed");c.buff_class_seen=nil;c.buff_skill_seen=nil
-- Native affliction-priority framing must be validated by the native capture
-- owner. Defence priorities/DEF IDs are NEVER sensory policy evidence.
local function buff_now()return type(getEpoch)=="function"and getEpoch()or os.time()end
c.buff_sensory_source={requests={},serial=0}
function c.buff_sensory_revoke()
 local d=c.buff_sensory_source;d.policy=nil;d.audit=nil;d.frame=nil;d.complete=nil
 c.buffs.state(c.current).sensory_context=nil
end
function c.buff_sensory_policy(e)
 local d=c.buff_sensory_source;local b=c.buffs.state(c.current);local a=d.audit
 c.buff_sensory_revoke()
 if type(e)~="table"or e.valid_evidence~=true or e.source~="native_affliction_priority_list"or not a or e.request~=a.serial or e.class~=b.class or a.class~=b.class or buff_now()<a.at or buff_now()-a.at>12 or type(e.priorities)~="table"then return false end
 local p={};for _,k in ipairs({"blindness","deafness"})do
  local n=e.priorities[k];if type(n)~="number"or n%1~=0 or n<1 or n>26 then return false end;p[k]=n
 end
 d.policy={class=b.class,priorities=p};return c.buff_sensory_refresh()
end
function c.buff_sensory_vitals(v)
 local d=c.buff_sensory_source
 -- Missing herb in a partial Vitals payload cannot freshen old herb proof.
 if v.herb~=nil then d.vitals_at=buff_now()end
end
function c.buff_sensory_refresh()
 local s=c.current;local b=c.buffs.state(s);local d=c.buff_sensory_source
 if not c.buffs.set_sensory_context then return false end
 b.sensory_context=nil
 local defs=s.player.defences or {}
 local function active(v)return v==true or v==1 or v=="1"end
 d.blocked_reason=nil
 if active(b.have.mindseye)or active(defs.mindseye)or active(defs.allsight)then
  d.blocked_reason="BLOCKED: Mindseye one-time sensory protection active; controlled preparation required"
  return false
 end
 local epoch=b.sensory_epoch or 0
 if d.epoch~=epoch then
  if d.epoch~=nil then d.consumed_at=buff_now()end
  d.epoch=epoch
 end
 local p=d.policy
 local supply=c.supplies and c.supplies.state(c)or {};local stocks=supply.stocks or {}
 local values,evidence={},{};local oldest=d.vitals_at
 -- Tracked facts retain their ACTUAL observation time. Only fresh herb/vitals
 -- renew the short action context; a complete IC baseline stays event-tracked.
 local ledger=supply.ledger;local owner=c.supplies_owner
 local tracked=owner~=nil or ledger~=nil or c.ledger~=nil
 if tracked then
  if d.stock_owner~=owner then
   if d.stock_owner~=nil then
    d.owner_changed_at=buff_now();d.policy=nil
   end
   d.stock_owner=owner;d.stock_session=(d.stock_session or 0)+1;d.stock_witness={}
   if d.owner_changed_at then return false end
  end
  local ic=(supply.sources or {}).ic
  if not owner or owner.alive~=true or s.connected~=true or supply.tracked~=true or not ledger or not ic or ic.complete~=true or ic.stale~=false or ic.pending then return false end
  if type(ic.last_complete)~="number"or ic.last_complete~=ic.last_complete or ic.last_complete==-math.huge or ic.last_complete>buff_now()then return false end
  if d.owner_changed_at and ic.last_complete<=d.owner_changed_at then return false end
 end
 if not p or p.class~=b.class or not d.afflictions_known or not d.vitals_at then return false end
 if d.vitals_at>buff_now()or buff_now()-d.vitals_at>5 then return false end
 for _,pill in ipairs({"amaurosis","ototoxin"})do
  local key="ic:"..pill;local r=stocks[key]
  if r then
   if type(r.at)~="number"or r.at~=r.at or r.at>buff_now()then return false end
   if tracked then
    local fact=(ledger.cache or {})[key]
    local raw=c.supplies_data and c.supplies_data.stocks[key]
    local native=c.supply_ledger_data and c.supply_ledger_data.cache[key]
    local source=r.source
    local authoritative=source=="ic"or source=="gmcp.IRE.Rift.Change"or source=="native IC withdrawal"or source=="native IC deposit"
    if not authoritative or not fact or not raw or not native or fact.confidence~="observed"or fact.estimated~=false or fact.inferred==true or raw.inferred==true or raw.estimated==true or raw.confidence~=nil and raw.confidence~="observed" or native.inferred==true or r.inferred==true then return false end
    if fact.count~=r.count or raw.count~=r.count or fact.source~=source or raw.source~=source or fact.at~=r.at or fact.observed_at~=r.at or raw.at~=r.at then return false end
    if type(raw.version)~="number"or raw.version<1 or raw.version%1~=0 or raw.version==math.huge or fact.version~=nil and fact.version~=raw.version then return false end
    -- The ledger has no version field: pair its native record identity with
    -- the raw version once. A changed raw version without a new fact fails.
    local prior=d.stock_witness[key]
    if prior and prior.fact==native and prior.version~=raw.version then return false end
    d.stock_witness[key]={fact=native,version=raw.version}
    if type(r.count)~="number"or r.count<0 then return false end
    evidence[pill]={mode="tracked_ic_v1",tracked=true,count=r.count,source=source,observed_at=r.at,version=raw.version,owner_id=tostring(owner),session=d.stock_session}
   else
    -- Legacy standalone adapters have no ledger contract: never grant them
    -- indefinite stock freshness simply because they set a tracked flag.
    if buff_now()-r.at>5 or d.consumed_at and r.at<=d.consumed_at then return false end
    oldest=math.min(oldest,r.at)
   end
   values[pill]=r.count
  elseif tracked then return false end
 end
 if d.consumed_at and d.vitals_at<=d.consumed_at then return false end
 local r=c.runner or {};local m=s.mental or {};local w=s.walker or {};local g=c.elemental_recovery or {};local containers=c.containers_data or {}
 local phase=g.phase;if g.pending then phase=g.pending.phase end
 local globe_clear=not g.committed and (not c.elemental_recovery or phase=="idle"or phase=="waiting"or phase=="probe")
 local clear=not(r.waiting or r.fault or r.dispatching or r.transport_barrier or m.eq_pending or m.fault or w.pending or containers.barrier or containers.action_dispatching or g.dispatching)and globe_clear
 local hold=c.defense and c.defense.hold(s)
 local curing_clear=not hold and not(s.defense and s.defense.blocked and (s.defense.blocked.eat or s.defense.blocked.tree))
 for k,v in pairs(s.player.afflictions or {})do if (v==true or v==1 or v=="1")and k~="blindness"and k~="deafness"then curing_clear=false end end
 return c.buffs.set_sensory_context(s,{class=b.class,epoch=epoch,observed_at=oldest,herb=b.herb,priorities=p.priorities,stocks=values,stock_evidence=tracked and evidence or nil,eating_allowed=curing_clear,curing_clear=curing_clear,barriers_clear=clear})
end
-- Strict, solicited native 26-row transaction. A footer alone or omitted
-- sensory affliction is not priority 26. Wrapped bracket lists are staged.
function c.buff_sensory_text(text)
 local d=c.buff_sensory_source;local a=d.audit
 local line=tostring(text):gsub("\27%[[%d;]*m",""):match("^%s*(.-)%s*$")
 if line:lower():match("^you have .*priorit")or line:lower():match("cureset")then c.buff_sensory_revoke();return end
 if line=="Your affliction curing priorities:"then
  d.policy=nil;d.complete=nil;d.frame=nil
  c.buffs.state(c.current).sensory_context=nil
  if a and buff_now()>=a.at and buff_now()-a.at<=12 then d.frame={rows={},n=0,request=a.serial,class=a.class,lines=0}end
  return
 end
 local f=d.frame;if not f then return end
 f.lines=f.lines+1
 if not a or a.serial~=f.request or buff_now()-a.at>12 or f.lines>250 then c.buff_sensory_revoke();return end
 if line=="Affs with priority 26 are ignored."then
  d.frame=nil
  if f.n~=26 then c.buff_sensory_revoke();return end
  local names={};local priorities={}
  for i=1,26 do
   local body=f.rows[i]:match("^%s*(.-)%s*$")
   while body~=""do
    local category,list,tail=body:match("^([%a_]+)%s*:%s*%[([^%[%]]*)%]%s*(.*)$")
    if not category then c.buff_sensory_revoke();return end
    if list:match("^%s*,")or list:match(",%s*$")or list:match(",%s*,")then c.buff_sensory_revoke();return end
    for token in (list..","):gmatch("(.-),")do
     token=token:match("^%s*(.-)%s*$")
     if token~=""then
      local identifier=token:match("^[%a][%w_]*$")
      if not identifier then
       local part,amount=token:match("^pre%-restore ([a-z ]+) %((%d+%.?%d*)%%%)$")
       local parts={head=true,torso=true,arms=true,legs=true,["left arm"]=true,["right arm"]=true,["left leg"]=true,["right leg"]=true}
       if not part or not parts[part]or not tonumber(amount)or tonumber(amount)>100 then c.buff_sensory_revoke();return end
      end
      if names[token]then c.buff_sensory_revoke();return end
      names[token]=true;if token=="blindness"or token=="deafness"then priorities[token]=i end
     end
    end
    body=tail
   end
  end
  d.complete={valid_evidence=true,source="native_affliction_priority_list",request=f.request,class=f.class,priorities=priorities}
  return
 end
 local row,body=line:match("^(%d+)%)%s*(.*)$")
 if row then
  row=tonumber(row)
  if row~=f.n+1 or row>26 then c.buff_sensory_revoke();return end
  f.n=row;f.rows[row]=body
 elseif line~=""and f.n>0 then f.rows[f.n]=f.rows[f.n].." "..line
 elseif line~=""then c.buff_sensory_revoke()end
end
function c.buff_sensory_prompt()
 local d=c.buff_sensory_source;local evidence=d.complete
 if evidence then d.complete=nil;return c.buff_sensory_policy(evidence)end
 if d.frame then c.buff_sensory_revoke()end
 return false
end
local function buff_invalidate()
 c.buff_sensory_revoke();c.buff_sensory_source.vitals_at=nil;c.buff_sensory_source.afflictions_known=nil
  c.buffs.invalidate(c.current);local b=c.buffs.state(c.current);c.buff_skill_seen=nil
  b.native_priorities={};b.native_full_required=true;b.native_version=(b.native_version or 0)+1;b.native_listing=nil;b.native_status=nil;b.native_defences=nil
 if b.query and b.query.kind=="skills"then b.query=nil end
 if b.pending then b.pending.confirmed=false;b.pending.prompt=nil;b.pending.prompt_ready=false end
 -- Fence cached payloads across class/session boundaries, including in-place GMCP tables.
 local skills=gmcp and gmcp.Char and gmcp.Char.Skills or {}
 c.buff_groups_seen=skills.Groups;c.buff_list_seen=skills.List
end
buff_invalidate() -- cached pre-reload skill payloads are not fresh ownership
local function buff_snapshot(source)
 local g=gmcp or {};local v=g.Char and g.Char.Vitals or {};local status=g.Char and g.Char.Status or {}
 local name=tostring(status.class or "")
 if name~=c.buff_class_seen then
  if c.buff_class_seen~=nil then buff_invalidate()end
  c.buff_class_seen=name;c.buffs.set_class(c.current,name);c.current.player.class=name
 end
 for key,field in pairs({wp="willpower",maxwp="maxwillpower"})do if tonumber(v[key])then c.current.player[field]=tonumber(v[key])end end
 local skills=g.Char and g.Char.Skills or {}
 local groups,list=skills.Groups,skills.List
 -- Events also recognize payloads updated in place. Polling consumes new identities
 -- once only; a cached group cannot re-infer all after a restrictive List.
 local fresh_groups=source=="gmcp.Char.Skills.Groups" or groups~=c.buff_groups_seen
 local fresh_list=source=="gmcp.Char.Skills.List" or list~=c.buff_list_seen
 c.buff_groups_seen=groups;c.buff_list_seen=list
 c.buff_sensory_refresh()
 if not c.buffs.supported_class(c.current.player.class)then return end
 if fresh_groups then c.buffs.set_groups(c.current,groups) end
 if fresh_list and type(list)=="table" and type(list.group)=="string" and type(list.list)=="table" then
  c.buffs.set_group_known(c.current,list.group,list.list)
 end
end
-- Explicit event source is also the narrow hook for a handler-only loader.
c.buff_snapshot=buff_snapshot
local function buff_preferences(save)
 local path=root.."defup-settings.json";local d=c.buffs.state(c.current)
 if not yajl or not yajl.to_value or not yajl.to_string then return false,"JSON support unavailable; preferences not saved" end
 if not save then
  local file=io.open(path,"r");if not file then return true end
  local content=file:read("*a");file:close();local ok,data=pcall(yajl.to_value,content)
  if not ok or type(data)~="table"or data.version~=1 or type(data.wanted)~="table"then return false,"Invalid defense settings; safe defaults used" end
  for _,entry in ipairs(c.buffs.catalog)do if type(data.wanted[entry.key])=="boolean"then d.wanted[entry.key]=data.wanted[entry.key]end end
  return true
 end
 local wanted={};for _,entry in ipairs(c.buffs.catalog)do wanted[entry.key]=d.wanted[entry.key]==true end
 local encoded=yajl.to_string({version=1,wanted=wanted});local file,err=io.open(path..".new","w");if not file then return false,err end
 local wrote,why=file:write(encoded);file:close();if not wrote then return false,why end
 local ok,reason=os.rename(path..".new",path);if not ok then return false,reason end
 local check=io.open(path,"r");if not check then return false,"settings readback failed"end;local actual=check:read("*a");check:close()
 if actual~=encoded then return false,"settings readback mismatch"end
 return true
end
buff_snapshot();local prefs_ok,prefs_error=buff_preferences(false);if not prefs_ok then print(prefs_error)end
local function buff_timer()
 c.buff_timer=nil
 if c.buffs.has_work(c.current)then
  if not c.watch_timer then combat_v2_tick()end
  c.buff_timer=tempTimer(1,buff_timer)
 end
end
local function buff_dispatch(command)
 local audit=command=="defences"or command=="tattoos"or command=="firstaid"or command=="firstaid priority defence list"or command=="firstaid priority list"or command=="ic"
 for _,group in ipairs(c.buffs.audit_groups(c.current.player.class)or{})do if command=="ab "..group then audit=true end end
 local allowed=audit;local curative=false;local prepare=false
 for _,e in ipairs(c.buffs.catalog)do
  if command==e.command or command==e.off or e.curative and command==e.prepare then allowed=true end
  if e.curative and (command==e.command or command==e.prepare)then curative=true;prepare=command==e.prepare end
 end
 assert(allowed,"Defense command rejected")
 if prepare and not c.buff_sensory_refresh()then return false end
 c.state.record(c.current,audit and"buff_audit"or"buff_send",command)
 local result=(c.buff_sender or send)(command)
 -- Revalidate synchronous changes after OUTC before the backend considers EAT.
 -- After EAT, note the new epoch immediately without replaying old resources.
 if curative then c.buff_sensory_refresh()end
 return result
end
function c.buff_sensory_audit(stock)
 local s=c.current;local d=c.buff_sensory_source
 if not s.connected or s.player.dead then return false,"Disconnected"end
 if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false,"Disconnected"end end
 d.serial=d.serial+1;d.policy=nil;d.frame=nil;d.complete=nil;d.audit={serial=d.serial,class=c.buffs.state(s).class,at=buff_now()}
 c.buffs.state(s).sensory_context=nil
 local token=d.serial
 local ok,result=pcall(buff_dispatch,"firstaid priority list")
 if not ok or result==false then c.buff_sensory_revoke();return false,"Sensory policy audit failed"end
 if stock then local sent,result=pcall(buff_dispatch,"ic");if not sent or result==false then return false,"Sensory stock request failed"end end
 return true,token
end
local function buff_wake()
 if c.buffs.has_work(c.current) and not c.buff_timer then c.buff_timer=tempTimer(1,buff_timer)end
end
function combat_v2_supplies(action)
 action=tostring(action or"status"):lower()
 if not c.supplies then return false,"Supply monitor unavailable"end
 if action=="check"or action=="audit"then
  return c.supplies.audit(c,function(command)assert(command=="fluidcache"or command=="ic"or command=="fc missing"or command=="ic missing","Read-only supply command rejected");return send(command)end)
 elseif action=="usage"then for _,line in ipairs(c.supplies.report(c))do print(line)end;return true
 elseif action~="status"then return false,"cv2 supplies status | usage | check"end
 local s=c.supplies.state(c);print("FLUIDCACHE",s.level,s.status,"health",s.stocks.health and s.stocks.health.count or"unknown","mana",s.stocks.mana and s.stocks.mana.count or"unknown");return true
end
function combat_v2_globe(action)
 action=tostring(action or"status"):lower()
 if not c.elementals then return false,"Globe recovery module unavailable"end
 local b=c.elementals.state(c)
 if action=="on"or action=="off"then
  if action=="on"and not b.attached then c.elementals.attach(c)end
  local ok=c.elementals.arm(c,action=="on");refresh();return ok,b.status
 elseif action~="status"then return false,"cv2 globe on|off|status"end
 print("GLOBE: "..(c.mode=="BASH"and b.armed and"ON"or"OFF").." - "..tostring(b.status));return true,b.status
end
function combat_v2_buffs(action,rest)
 action=(action or "status"):lower();rest=(rest or ""):lower():match("^%s*(.-)%s*$")
 if action=="defup"then local sub,args=rest:match("^(%S+)%s*(.*)$");action=sub or "start";rest=args or ""end
 local ok,why=true,nil
 buff_snapshot()
 if action=="show"then return c.gui.show_defenses()end
 if action=="save"then local ok,why=buff_preferences(true);if ok then print("Defense choices saved; upkeep arm state is never saved")end;return ok,why end
 if action=="sensory"then return c.buff_sensory_audit(rest=="stock")end
 if action=="audit"then
  if not c.current.connected or c.current.player.dead then return false,"Disconnected: defense audit unavailable"end
  if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false,"Disconnected"end end
  local commands={}
  for _,group in ipairs(c.buffs.audit_groups(c.current.player.class)or{})do commands[#commands+1]="ab "..group end
  for _,command in ipairs({"tattoos","defences","firstaid","firstaid priority defence list"})do commands[#commands+1]=command end
  for _,command in ipairs(commands)do
   local sent,result=pcall(buff_dispatch,command)
   if not sent or result==false then return false,"Audit request failed: "..tostring(result)end
  end
  return true,"Read-only defense/ability/tattoo/native FIRSTAID audit requested"
 elseif action=="native"then
   local key,value=rest:match("^([%a_]+)%s+(%a+)$")
   if not key or not c.buffs.native_catalog or not c.buffs.native_catalog[key] or (value~="on"and value~="off")then return false,"Native defense requires a supported name and on|off"end
   if not c.current.connected or c.current.player.dead or (tonumber(c.current.player.hp)or 0)<=0 then return false,"Disconnected/dead: native defense configuration unavailable"end
   if getConnectionInfo then local _,_,tcp=getConnectionInfo();if not tcp then return false,"Disconnected"end end
   if c.buffs.native_priority(c.current,key)==nil then return false,"Native priorities unknown; use defup audit first"end
   local priority=value=="off"and 26 or c.buffs.native_enable_priority(c.current,key)
   if type(priority)~="number"or priority%1~=0 or priority<1 or priority>26 or (value=="on"and priority==26)then return false,"Invalid native priority"end
   local command="firstaid priority defence "..key.." "..priority
   if not c.buffs.native_request(c.current,key,priority)then return false,"Native priorities unknown; use defup audit first"end
   local sent,result=pcall(c.buff_sender or send,command)
   if not sent or result==false then return false,"Native defense setting failed; readback required"end
   c.state.record(c.current,"buff_native",command)
   local queried,qresult=pcall(c.buff_sender or send,"firstaid priority defence list")
   if not queried or qresult==false then return false,"Setting requested but readback failed; use defup audit"end
   return true,"Native priority requested; server readback required. Global FIRSTAID switches unchanged."
 elseif action=="status"then
  local d=c.buffs.state(c.current);print("DEFUP: "..tostring(c.buff_status or d.status or "idle").."; upkeep="..tostring(d.master))
  for _,entry in ipairs(c.buffs.catalog)do print(entry.key.." wanted="..tostring(d.wanted[entry.key]).." active="..tostring(d.have and d.have[entry.key]or false)..(entry.drain and " [DRAIN / OPT-IN]"or""))end;return true
 elseif action=="stop"then c.buffs.stop(c.current,"defup/upkeep stopped; committed action still acknowledged")
 elseif action=="reset"then combat_v2_stop("reviewed defup reset");c.buffs.reset(c.current);c.buff_status="Reviewed reset; combat/upkeep OFF"
 elseif action=="start"then
  ok,why=c.buffs.start(c.current)
 elseif action=="keep"then
  if rest=="on"or rest=="off"then
   ok,why=c.buffs.master(c.current,rest=="on")
   if rest=="off"then print("Upkeep paused; active drains remain. Use defkeep NAME off to cancel a specific supported defense.")end
  else
   local key,value=rest:match("^([%a_]+)%s+(%a+)$")
   if not key or (value~="on"and value~="off")then return false,"defkeep on|off|NAME on|off"end
   if c.buffs.native_catalog and c.buffs.native_catalog[key]then return combat_v2_buffs("native",rest)end
   if key=="blindness"or key=="deafness"then
    -- A saved wanted flag never grants current-session sensory opt-in.
    ok,why=c.buffs.select_sensory(c.current,key,value=="on")
    if not ok and c.buff_sensory_source.blocked_reason then why=c.buff_sensory_source.blocked_reason end
    if not ok and why~="CURABLE AFFLICTION: self-affliction retired" and value=="on"and not c.buff_sensory_source.blocked_reason then
     local d=c.buff_sensory_source;local need=key..":"..tostring(c.buffs.state(c.current).sensory_epoch or 0)
     if not d.requests[need]then
      d.requests[need]=true
      local stocks=c.supplies and c.supplies.state(c).stocks or {};local pill=key=="blindness"and"amaurosis"or"ototoxin";local r=stocks["ic:"..pill]
      local missing=not r or type(r.at)~="number"or buff_now()-r.at>5
      c.buff_sensory_audit(missing)
     end
    end
   else ok,why=c.buffs.toggle(c.current,key,value=="on")end
   if ok then local saved,err=buff_preferences(true);if not saved then print("Defense choice applied but NOT saved: "..tostring(err))end end
  end
 else return false,"defup [status|stop|audit|sensory [stock]|reset]; defkeep on|off|NAME on|off; cv2 defs"end
 if not ok then return false,why end
 buff_wake();combat_v2_tick();if why then print(why)end;return true,why
end

local function cancel_ih()
 if c.ih_timer then killTimer(c.ih_timer);c.ih_timer=nil end
 local scan=c.current.hunting.ih;if scan then scan.active=false;scan.pending=false end
end
local function enter_room_watch()
 local s=c.current;local scan=s.hunting.ih;cancel_ih()
 s.hunting.watch={room_id=s.room.id,checked_version=scan and scan.start_version or (s.room.item_version or 0)};s.hunting.verified_generation=nil
 c.runner.status="BASH armed: 3 IH checks exhausted; watching GMCP room updates"
 c.state.record(s,"ih_watch","3 checks exhausted; quiet GMCP watch");refresh();return false,c.runner.status
end
-- Failed IH checks retry at most three times, then wait for real room updates.
function combat_v2_ih_result()
 local s=c.current;local scan=s.hunting.ih
 if c.mode~="BASH" or not scan or not scan.active or not scan.pending or not scan.responded then return false end
 local ok,why=c.bashing.ih_select(s)
 if ok then
  cancel_ih();s.hunting.verified_generation=s.target_generation
  c.runner.status="IH confirmed target "..tostring(s.target.name);c.state.record(s,"ih_found",s.target.name)
  return combat_v2_tick()
 end
 if scan.attempts>=3 then scan.last_failure=why;return enter_room_watch() end
 scan.last_failure=why;c.state.record(s,"ih_miss",scan.attempts.."/3: "..why)
 c.runner.status="BASH armed: no matching target; IH check "..scan.attempts..", retry in 2s";refresh();return false
end
function combat_v2_request_ih()
 local s=c.current;local scan=s.hunting.ih
 if c.mode~="BASH" or not scan or not scan.active then return false end
 if not s.connected or (tonumber(s.player.hp) or 0)<=0 or s.player.dead then cancel_ih();c.runner.status="BASH paused: disconnected / dead";refresh();return false end
 local safe,reason=c.policy.allowed(s);if not safe then cancel_ih();c.runner.status=reason;refresh();return false end
 if scan.attempts>=3 then return enter_room_watch() end
 if not c.bashing.ih_request(s) then return false end
 c.runner.status="Checking IH "..scan.attempts;c.state.record(s,"ih_request",scan.attempts.."/3")
 c.ih_timer=tempTimer(2,function()
  if c.mode~="BASH" or c.current.hunting.ih~=scan or not scan.active then return end
  c.ih_timer=nil
  if scan.pending then scan.pending=false;scan.last_failure="IH response unavailable";c.state.record(s,"ih_timeout",scan.attempts.."/3") end
  combat_v2_request_ih()
 end)
 local ok,why=pcall(function()
  -- IH does not refresh an unchanged item list by itself. Aetolia flushes
  -- this explicit GMCP request when the following IH produces its prompt.
  sendGMCP([[Char.Items.Room ""]])
  local sender=c.ih_sender or send;sender("ih")
 end)
 if not ok then cancel_ih();c.runner.fault="IH send failed: "..tostring(why);c.runner.status=c.runner.fault;refresh();return false end
 refresh();return true
end
function combat_v2_start_ih(reason,force)
 if c.mode~="BASH" then return false end
 if force then c.current.hunting.watch=nil end
 if c.current.hunting.watch then return false,"watching GMCP room updates" end
 local scan=c.current.hunting.ih
 if scan and scan.active then return false,"IH already pending" end
 cancel_ih();c.bashing.ih_begin(c.current);c.runner.pending=nil
 if c.retry_timer then killTimer(c.retry_timer);c.retry_timer=nil end
 c.state.record(c.current,"ih_begin",reason or "target verification")
 return combat_v2_request_ih()
end
function combat_v2_stop(reason)
 if c.elementals then c.elementals.arm(c,false)end
 c.buffs.stop(c.current,reason or "OFF; upkeep disarmed")
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"OFF")end
 cancel_ih();c.current.hunting.watch=nil
 if c.current.training_battle_ended then
  local m=c.current.mental
  if m then if m.target then pcall(send,"mind cease") end;m.status="stopped";m.target=nil;m.lock_target=nil;m.eq_pending=nil end
 end
 c.runner_module.stop(c.runner,reason);c.mode="OFF";c.current.stop_reason=nil
 c.current.stats.stops=c.current.stats.stops+1;c.state.record(c.current,"stop",reason or "OFF")
 for _,key in ipairs({"retry_timer","watch_timer","ih_timer"}) do if c[key] then killTimer(c[key]);c[key]=nil end end
 refresh();return true
end
local function watchdog()
 c.watch_timer=nil
 if c.mode=="BASH" or c.mode=="FULL_AUTO" then combat_v2_tick()
 elseif c.runner_module.watchdog(c.runner) then combat_v2_stop(c.runner.status);return end
 if c.mode~="OFF" and c.mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
end
function combat_v2_area_approve(visit,yes)
 local ok,why=c.policy.approve(c.current,visit,yes~=false)
 if ok then combat_v2_tick() end
 return ok,why
end
local function area_prompt()
 local p=c.current.policy
 if p.areas_loaded and not c.policy.area_allowed(c.current) and p.prompted~=p.visit then
  p.prompted=p.visit
  print("BASH PAUSED: "..tostring(c.current.room.area).." is not in AREAS. Enable bashing for this area visit?")
  if echoLink then
   echoLink("[Enable here] ","combat_v2_area_approve("..p.visit..",true)","Approve only this area visit",true)
   echoLink("[Keep paused]\n","combat_v2_area_approve("..p.visit..",false)","Do not attack here",true)
  else print("cv2 area yes / cv2 area no") end
 end
end
function combat_v2_tick()
 local s=c.current;buff_snapshot()
 if s.stop_reason then
  if s.stop_reason=="training battle ended" then combat_v2_stop(s.stop_reason);return false,"training battle ended" end
  if s.stop_reason=="target slain" and c.mode=="BASH" and s.hunting.active then
   s.stop_reason=nil;local ok=c.bashing.killed(s)
   if not ok then s.hunting.active=true;s.stop_reason=nil end
   combat_v2_start_ih("target slain; refresh room");return false,"checking IH"
  elseif c.mode=="BASH" and (s.stop_reason=="target unavailable" or s.stop_reason=="target left room; confirmation required") then
   local why=s.stop_reason;s.stop_reason=nil
   if why=="target unavailable" then c.runner.waiting=false end
   combat_v2_start_ih(why);return false,"checking IH"
  elseif c.mode=="BASH" then local why=s.stop_reason;s.stop_reason=nil;cancel_ih();c.runner.status="BASH paused: "..why;refresh();return false,why
  else local why=s.stop_reason;combat_v2_stop(why);return false,why end
 end
 local defense=c.defense.service(s,c.defense_sender or send)
 c.runner_module.update_balance(c.runner)
 c.buff_sensory_refresh() -- recovery may have just released the prior attack wait
 local flurry_hold=c.mode=="BASH"and c.monk.flurry_active and c.monk.flurry_active(s)
 local buffs=c.buffs.service(s,c.runner,buff_dispatch,defense.hold or flurry_hold);c.buff_status=buffs.status
 if buffs.busy then c.runner.status="DEFUP: "..tostring(buffs.status);refresh();return false,c.runner.status end
 if defense.hold and (c.mode=="FULL_AUTO" or c.mode=="BASH") then c.runner_module.update_balance(c.runner);c.runner.pending=nil;c.runner.status="DEFENSE: "..defense.phase;refresh();return false,c.runner.status end
 if c.mode=="BASH" then
  c.runner_module.update_balance(c.runner);c.runner_module.watchdog(c.runner)
  if c.runner.fault then cancel_ih();c.runner.status=c.runner.fault;refresh();return false,c.runner.fault end
  for _,command in ipairs(c.policy.services(s)) do send(command) end
  local safe,why=c.policy.allowed(s)
  if not safe or not s.connected or s.player.dead or (tonumber(s.player.hp) or 0)<=0 then
   cancel_ih();s.hunting.verified_generation=nil;c.runner.pending=nil
   c.runner.status=not s.connected and "BASH paused: disconnected" or s.player.dead and "BASH paused: dead" or why
   area_prompt();refresh();return false,c.runner.status
  end
  if s.hunting.ih and s.hunting.ih.active then refresh();return false,"checking IH" end
  local watch=s.hunting.watch
  if watch then
   if watch.room_id~=s.room.id then s.hunting.watch=nil
   else
    local version=s.room.item_version or 0
    if version>(watch.checked_version or 0) then
     watch.checked_version=version
     if c.bashing.watch_select(s) then s.hunting.verified_generation=s.target_generation;c.state.record(s,"gmcp_found",s.target.name) end
    end
    if s.hunting.watch then c.runner.status="BASH armed: watching GMCP room updates (IH 3/3)";refresh();return false,c.runner.status end
   end
  end
  if not s.target.name or s.target.dead or s.hunting.verified_generation~=s.target_generation then combat_v2_start_ih("verify bashing target");return false,"checking IH" end
 end
 if c.mental.tick(s,c.mental_sender or c.runner.sender or send,c.runner.paused_health) then c.runner_module.update_balance(c.runner);refresh();return false,"Telepathy equilibrium pending" end
 local ok,why=c.runner_module.tick(c.runner);c.mode=c.runner.mode;s.mode=c.mode
 if why=="cooldown" and not c.retry_timer then c.retry_timer=tempTimer(.35,function() c.retry_timer=nil;combat_v2_tick() end) end
 refresh();return ok,why
end
function combat_v2_set_mode(mode)
 mode=string.upper(mode or "OFF");if mode=="AUTO" or mode=="PVP" then mode="FULL_AUTO" end
 if not ({OFF=true,SHADOW=true,ASSIST=true,BASH=true,FULL_AUTO=true})[mode] then return false,"invalid mode" end
 if c.monk.cancel_flurry and mode~=c.mode then c.monk.cancel_flurry(c.current,"mode changed")end
 if mode~="BASH"and c.elementals then c.elementals.arm(c,false)end
 if mode=="OFF" then return combat_v2_stop() end
 cancel_ih();c.current.hunting.watch=nil
 if c.current.training_battle_ended then c.current.training_battle_ended=nil;c.current.mental=nil end
 c.current.dismount_stance=nil
 if mode=="SHADOW"then c.buffs.stop(c.current,"SHADOW; upkeep disarmed")end
 c.mode=mode;c.runner.mode=mode;c.current.mode=mode;c.runner.pending=nil;c.current.hunting.active=false
 if mode=="BASH" then
  if c.supplies and (c.supplies_quiet==false or not c.supplies_data or not c.supplies_data.requested) then combat_v2_supplies("check")end
  local ok=c.bashing.start(c.current);if not ok then c.current.hunting.active=true;c.current.stop_reason=nil end
  c.current.hunting.verified_generation=nil
 end
 if not c.watch_timer and mode~="SHADOW" then c.watch_timer=tempTimer(1,watchdog) end
 return combat_v2_tick()
end
function combat_v2_reset_enemy_afflictions()
 local ok,why=c.tracker.clear_afflictions(c.current)
 if not ok then return false,why end
 c.runner.pending=nil
 if combat_v2_ui and combat_v2_ui.pages then combat_v2_ui.pages.enemy_afflictions=1 end
 c.state.record(c.current,"enemy_reset","cleared enemy afflictions/injury flags; preserved trauma and target")
 refresh();return true
end
function combat_v2_set_target(name)
 local previous=c.current.target_generation
 local ok,why=c.state.set_target(c.current,name)
 if ok then
  c.runner.pending=nil
  if c.current.target_generation~=previous and c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"manual target changed")end
  if c.current.target_generation~=previous then c.current.hunting.watch=nil;c.current.hunting.target_name=nil;c.current.hunting.killed_ids={};c.current.hunting.query=c.current.target.name end
 end
 refresh();return ok,why
end
function combat_v2_approve() local ok,why=c.runner_module.approve(c.runner);refresh();return ok,why end
function combat_v2_defense(cmd)
 local s=c.current;cmd=cmd~="" and cmd or "status"
 if cmd=="audit" then return c.defense.audit(s,c.defense_sender or send)
 elseif cmd=="setup" then combat_v2_stop("Explicit defensive FIRSTAID setup");return c.defense.setup(s,c.defense_sender or send)
 elseif cmd=="on" or cmd=="off" then s.config.defense_enabled=cmd=="on";refresh();return true
 elseif cmd~="status" then return false,"cv2 defense status|audit|setup|on|off" end
 local d=c.defense.plan(s);print("DEFENSE: "..d.phase.." (hold="..tostring(d.hold)..")")
 for channel,b in pairs(d.blocked)do print("FIRSTAID blocked "..channel.." curing "..b.aff.." at "..b.time)end
 for _,a in ipairs(d.proposals)do print("Proposed: "..a.command)end
 print("Class emergency skills require live AB verification; none auto-enabled")
 return true
end
function combat_v2_set_curing(on) local ok,why=c.curing.set(c.cure,c.current,on==true);refresh();return ok,why end
function combat_v2_reset_wait()
 -- Deliberate manual recovery; never release wait from a timer alone.
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"reviewed reset")end
 c.defense.reset(c.current);c.mental.reset(c.current);c.runner.fault=nil;c.runner.waiting=false;c.runner.pending=nil;c.runner.last_send=-100;c.runner.status="manually reset";c.state.record(c.current,"reset","manual waiting reset");refresh()
end
function combat_v2_propose() local a=c.runner_module.propose(c.runner);refresh();return a end
function combat_v2_observe(e)
 local ok,why=c.tracker.apply(c.current,e)
 if ok then c.state.record(c.current,"observation",e.kind);combat_v2_tick() else refresh() end
 return ok,why
end
function combat_v2_track(kind,key,value)
 local e={kind=kind,target=c.current.target.name,source="manual",confidence=1,generation=c.current.target_generation}
 if kind=="limb" or kind=="damage" then e.limb=key;e.amount=tonumber(value)
 elseif kind=="parry" then e.limb=key
 elseif kind=="aff" then e.kind="affliction";e.name=key;if value~="on" and value~="off" then return false,"use aff NAME on|off" end;e.value=value=="on"
 elseif kind=="broken" or kind=="mangled" or kind=="crippled" then e.limb=key;if value~="on" and value~="off" then return false,"use MARKER LIMB on|off" end;e.value=value=="on"
 elseif kind=="prone" or kind=="shield" or kind=="rebounding" then if key~="on" and key~="off" then return false,"use "..kind.." on|off" end;e.value=key=="on"
 else return false,"track limb/damage LIMB NUMBER; aff NAME on|off; parry LIMB|none; prone/shield/rebounding on|off; broken/crippled/mangled LIMB on|off" end
 return combat_v2_observe(e)
end
function combat_v2_set_route(route)
 if not ({legs=true,arms=true,head=true,torso=true,balanced=true})[route] then return false,"route legs|arms|head|torso|balanced" end
 c.current.config.route=route;c.runner.pending=nil;c.state.record(c.current,"route",route);refresh();return true
end
function combat_v2_config(key,value)
 if key=="pvp_stance" or key=="finish_stance" then if not ({eagle=true,cobra=true,dragon=true,tiger=true,wolf=true,scorpion=true,manual=true})[value] then return false,"stance eagle|cobra|dragon|tiger|wolf|scorpion|manual" end;c.current.config[key]=value;c.runner.pending=nil;refresh();return true end
 if key=="kaido" then if value~="on" and value~="off" then return false,"kaido on|off" end;c.mental.state(c.current).kaido=value=="on";return true end
 if key=="mindlock" then if value~="on" and value~="off" then return false,"mindlock on|off" end;c.mental.state(c.current).enabled=value=="on";return true end
 if key=="training_reports" then
  if value=="off" then c.current.training=nil;return true end
  if value~="on" or not c.current.target.name then return false,"select a target; training_reports on|off" end
  local present=false;for _,item in pairs(c.current.room.items)do if tostring(item.name):lower()=="a runed target dummy" then present=true end end
  if not present then return false,"No reporting runed target dummy in this room" end
  c.current.training={enabled=true,target=c.current.target.name,generation=c.current.target_generation,room=c.current.room.id};return true
 end
 if key=="group_web" then if value~="on" and value~="off" then return false,"group_web on|off" end;c.current.policy.group_web=value=="on";c.current.policy.web.at=nil;combat_v2_tick();return true end
 if key=="estimate_trauma" then
  if value~="on" and value~="off" then return false,"estimate_trauma on|off" end
  c.current.config.estimate_trauma=value=="on";return true
 end
 local bounds={defense_health_pause={1,94},defense_health_resume={2,100},defense_mana_reserve={0,90},defense_kai_reserve={0,80},health_pause={1,95},health_resume={2,100},ack_timeout={2,60},parry_ttl={1,60},parry_min_confidence={0,1},kick_trauma={0,100},punch_trauma={0,100},boost_kick_trauma={0,100},boost_punch_trauma={0,100}}
 local b=bounds[key];local n=tonumber(value)
 if not b or not n or n~=n or n<b[1] or n>b[2] then return false,"invalid config value/key" end
 local cfg=c.current.config
 if key=="defense_health_pause" and n>=(cfg.defense_health_resume or 65) or key=="defense_health_resume" and n<=(cfg.defense_health_pause or 45) then return false,"defense resume must exceed pause" end
 if key=="health_pause" and n>=cfg.health_resume or key=="health_resume" and n<=cfg.health_pause then return false,"resume must exceed pause" end
 cfg[key]=n;c.state.record(c.current,"config",key.."="..n);return true
end
function combat_v2_status()
 local s=c.current;print("Combat V2 "..c.mode.." route="..s.config.route.." target="..tostring(s.target.name).." status="..tostring(c.runner.status))
 print("sent="..s.stats.sent.." observations="..s.stats.observed.." kills="..s.hunting.kills.." queued="..#s.hunting.queue.." last vitals="..tostring(s.vitals_at))
end
function combat_v2_trace(n)
 local h=c.current.history;n=math.min(100,math.max(1,tonumber(n) or 12))
 for i=math.max(1,#h-n+1),#h do local e=h[i];print(tostring(e.time).." "..e.kind.." ["..tostring(e.target).."] "..tostring(e.detail)) end
end
c.handlers={}
local function handler(event,fn) c.handlers[#c.handlers+1]=registerAnonymousEventHandler(event,fn) end
handler("gmcp.Char.Status",function()buff_snapshot("gmcp.Char.Status");combat_v2_tick()end)
handler("gmcp.Char.Vitals",function() buff_snapshot("gmcp.Char.Vitals");c.state.sync_gmcp(c.current,gmcp);c.buffs.vitals(c.current,gmcp.Char.Vitals or {});c.buff_sensory_vitals(gmcp.Char.Vitals or {});combat_v2_tick() end)
for _,kind in ipairs({"Groups","List"})do
 local event="gmcp.Char.Skills."..kind
 handler(event,function()buff_snapshot(event);combat_v2_tick()end)
end
handler("sysDisconnectionEvent",function()
 if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"disconnect")end
 c.buffs.stop(c.current,"disconnect; upkeep disarmed");buff_invalidate();local b=c.buffs.state(c.current);b.defs_known=false;b.defs_at=nil
 c.current.defense=nil;c.current.mental=nil;c.current.training=nil;c.current.connected=false;c.cure.enabled=false;c.cure.status="disconnected"
 c.current.policy.players_known=false;c.current.policy.web.at=nil;cancel_ih()
 if c.mode=="BASH" then if c.runner.waiting then c.runner.fault="Disconnected during attack; cv2 reset after review" end;c.runner.status="BASH paused: disconnected";refresh()
 else combat_v2_stop("disconnected") end
end)
handler("gmcp.Char.Name",function() c.current.policy.self_name=tostring((gmcp.Char.Name or {}).name or ""):lower() end)
handler("gmcp.Room.Players",function() c.policy.players(c.current,gmcp.Room.Players);combat_v2_tick() end)
handler("gmcp.Room.AddPlayer",function() c.policy.player_add(c.current,gmcp.Room.AddPlayer);combat_v2_tick() end)
handler("gmcp.Room.RemovePlayer",function() c.policy.player_remove(c.current,gmcp.Room.RemovePlayer);combat_v2_tick() end)
local function collection(kind)
 handler("gmcp.Char."..kind..".List",function()
  if kind=="Defences"then buff_snapshot();c.buffs.sync(c.current,"List",gmcp.Char[kind].List)end
  if kind=="Afflictions"then c.buffs.affliction_flags(c.current,"List",gmcp.Char[kind].List);c.buff_sensory_source.afflictions_known=type(gmcp.Char[kind].List)=="table"end
  local dest=kind=="Afflictions" and "afflictions" or "defences";local t={}
  for _,a in ipairs(gmcp.Char[kind].List or {}) do local n=type(a)=="table" and a.name or a;if n then t[c.defense.key(n)]=true end end
  c.current.player[dest]=t
  if kind=="Afflictions" then c.current.player.prone=(t.prone or t.fallen) and true or false end
  combat_v2_tick()
 end)
 handler("gmcp.Char."..kind..".Add",function()
  if kind=="Defences"then buff_snapshot();c.buffs.sync(c.current,"Add",gmcp.Char[kind].Add)end
  if kind=="Afflictions"then c.buffs.affliction_flags(c.current,"Add",gmcp.Char[kind].Add)end
  local a=gmcp.Char[kind].Add;local n=type(a)=="table" and a.name or a
  if n then n=c.defense.key(n);c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=true end
  if kind=="Afflictions" and (n=="prone" or n=="fallen") then c.current.player.prone=true end
  combat_v2_tick()
 end)
 handler("gmcp.Char."..kind..".Remove",function()
  if kind=="Defences"then buff_snapshot();c.buffs.sync(c.current,"Remove",gmcp.Char[kind].Remove)end
  if kind=="Afflictions"then c.buffs.affliction_flags(c.current,"Remove",gmcp.Char[kind].Remove)end
  local a=gmcp.Char[kind].Remove;local values=type(a)=="table" and (a.name and {a.name} or a) or {a}
  for _,n in ipairs(values) do
   n=c.defense.key(n);c.current.player[kind=="Afflictions" and "afflictions" or "defences"][n]=nil
   if kind=="Afflictions" and (n=="prone" or n=="fallen") then local aff=c.current.player.afflictions;c.current.player.prone=(aff.prone or aff.fallen) and true or false end
  end
  combat_v2_tick()
 end)
end
collection("Afflictions");collection("Defences")
handler("gmcp.Char.Items.List",function()
 local changed=c.bashing.items(c.current,gmcp.Char.Items.List);combat_v2_ih_result()
 local s=c.current;local scan=s.hunting.ih
 if changed and c.mode=="BASH" and not (scan and scan.active) and s.hunting.verified_generation==s.target_generation and s.target.name and not s.room.items[tostring(s.target.name)] then
  s.stop_reason="target left room; confirmation required";combat_v2_tick()
 end
 if changed then combat_v2_tick() else refresh() end
end)
for _,kind in ipairs({"Add","Update"})do
 local item_kind=kind
 handler("gmcp.Char.Items."..item_kind,function()if c.bashing.item_changed(c.current,gmcp.Char.Items[item_kind],item_kind=="Add")then combat_v2_tick()end end)
end
handler("gmcp.Char.Items.Remove",function() c.bashing.item_removed(c.current,gmcp.Char.Items.Remove);combat_v2_tick() end)
handler("gmcp.Room.Info",function()
 local s=c.current;local info=gmcp.Room.Info or {};local changed=c.policy.room(s,info)
 if changed and c.monk.cancel_flurry then c.monk.cancel_flurry(s,"room changed")end
 if changed then
  s.hunting.watch=nil;s.training=nil;s.room.items={};s.hunting.killed_ids={};s.hunting.verified_generation=nil;cancel_ih()
  if c.mode=="BASH" then c.state.set_target(s,"");c.runner.pending=nil end
 end
 combat_v2_tick()
end)
handler("combat_v2.observation",function(_,kind,target,key,value,confidence)
 local e={kind=kind,target=target,source="integration",confidence=tonumber(confidence) or 1}
 if kind=="limb" or kind=="damage" then e.limb=key;e.amount=tonumber(value)
 elseif kind=="affliction" then e.name=key;e.value=value
 elseif kind=="parry" then e.limb=key
 elseif kind=="broken" or kind=="mangled" or kind=="crippled" then e.limb=key;e.value=value
 else e.value=value end
 combat_v2_observe(e)
end)
c.line_trigger=tempRegexTrigger("^.*$",function()
 local text=line or matches[1]
 c.buff_sensory_text(text)
 buff_snapshot()
 c.buffs.text(c.current,text)
 c.defense.text(c.current,text)
 c.mental.text(c.current,text)
 if c.policy.text(c.current,text) then combat_v2_tick();refresh();return end
 if c.bashing.ih_text(c.current,text) then combat_v2_ih_result();refresh();return end
 c.events.event(c.current,text);combat_v2_tick()
end)
if type(tempPromptTrigger)=="function" then
 c.prompt_trigger=tempPromptTrigger(function()
  buff_snapshot()
  c.buff_sensory_prompt()
  c.buffs.on_prompt(c.current);if c.buffs.has_work(c.current)then combat_v2_tick()end
  if c.gui.render_prompt then c.gui.render_prompt(c.current,c.runner) end
 end)
end
for _,id in ipairs(c.buff_aliases or {})do killAlias(id)end
c.buff_aliases={
 tempAlias([[^defup(?:\s+(.*))?$]],function()local ok,why=combat_v2_buffs("defup",matches[2] or "");if not ok then print(why)end end),
 tempAlias([[^defkeep(?:\s+(.*))?$]],function()local arg=matches[2]or"status";local ok,why=combat_v2_buffs(arg=="status"and"status"or"keep",arg);if not ok then print(why)end end)
}

c.alias=tempAlias([[^cv2(?:\s+(.*))?$]],function()
 local arg=(matches[2] or ""):match("^%s*(.-)%s*$");local cmd,rest=arg:match("^(%S+)%s*(.*)$");cmd=(cmd or "status"):lower();rest=rest or ""
 local ok,why=true,nil
 if cmd=="target" then ok,why=combat_v2_set_target(rest)
 elseif cmd=="approve" then ok,why=combat_v2_approve()
 elseif cmd=="stop" or cmd=="off" then combat_v2_stop()
 elseif cmd=="enemy" then if rest=="reset" then ok,why=combat_v2_reset_enemy_afflictions() else ok,why=false,"cv2 enemy reset" end
 elseif cmd=="supplies"then ok,why=combat_v2_supplies(rest~=""and rest or"status")
 elseif cmd=="globe"then ok,why=combat_v2_globe(rest~=""and rest or"status")
 elseif cmd=="defup"then ok,why=combat_v2_buffs("defup",rest)
 elseif cmd=="defkeep"then ok,why=combat_v2_buffs("keep",rest)
 elseif cmd=="defs"or cmd=="defences"then ok,why=combat_v2_buffs("show",rest)
 elseif cmd=="defense" then ok,why=combat_v2_defense(rest)
 elseif cmd=="curing" then if rest=="on" or rest=="off" then ok,why=combat_v2_set_curing(rest=="on") else ok,why=false,"cv2 curing on|off" end
 elseif cmd=="reload" then dofile(root.."bootstrap.lua")
 elseif cmd=="reset" then combat_v2_reset_wait()
 elseif cmd=="status" then combat_v2_status()
 elseif cmd=="trace" then combat_v2_trace(rest)
 elseif cmd=="ih" then ok,why=combat_v2_start_ih("manual IH verification",true)
 elseif cmd=="area" then if rest=="yes" or rest=="no" then ok,why=combat_v2_area_approve(c.current.policy.visit,rest=="yes") else ok,why=false,"cv2 area yes|no" end
 elseif cmd=="areas" then c.policy.request_areas(c.current);send("areas")
 elseif cmd=="web" then c.policy.request_web(c.current);send("web members")
 elseif cmd=="route" then ok,why=combat_v2_set_route(rest)
 elseif cmd=="config" then local k,v=rest:match("^(%S+)%s+(%S+)$");ok,why=combat_v2_config(k,v)
 elseif cmd=="track" then local k,a,b=rest:match("^(%S+)%s*(%S*)%s*(%S*)$");ok,why=combat_v2_track(k,a,b)
 elseif cmd=="queue" then
  local sub,name=rest:match("^(%S+)%s*(.*)$");sub=sub or "list"
  if sub=="add" then ok,why=c.bashing.add(c.current,name)
  elseif sub=="clear" then c.current.hunting.queue={};print("Queue cleared")
  elseif sub=="next" then if c.monk.cancel_flurry then c.monk.cancel_flurry(c.current,"manual queue next")end; ok,why=c.bashing.next(c.current,true);if ok then combat_v2_tick() elseif c.mode=="BASH" then c.current.hunting.active=true;c.current.stop_reason=nil;combat_v2_start_ih("queue empty") else combat_v2_stop(why) end
  elseif sub=="list" then print("Queued: "..table.concat(c.current.hunting.queue,", "))
  else ok,why=false,"cv2 queue add NAME | list | next | clear" end
 elseif cmd=="help" then if c.gui.show_help then c.gui.show_help() else print("Help GUI unavailable; see docs/backend.md") end
 else ok,why=combat_v2_set_mode(cmd) end
 if not ok and why then print(why) end
end)
c.target_alias=tempAlias([[^t(?:\s+(.*))?$]],function() local ok,why=combat_v2_set_target(matches[2] or "");if not ok then print(why) end end)
cancel_ih()
local cached_connected,cached_vitals=c.current.connected,c.current.vitals_at
c.state.sync_gmcp(c.current,gmcp or {})
c.current.connected=cached_connected;c.current.vitals_at=cached_vitals
if getConnectionInfo then local _,_,connected=getConnectionInfo();if not connected then c.current.connected=false end end
if c.elementals then c.elementals.detach(c)end
c.elementals=dofile(root.."elementals.lua");c.elementals.arm(c,false)
c.gui.create();refresh()
if c.supplies then c.supplies.detach(c)end
c.containers_required=true
c.containers=dofile(root.."containers.lua")
c.ledger=dofile(root.."ledger.lua")
c.supplies=dofile(root.."supplies.lua")
c.supplies.bind_containers(c,function(command)return send(command)end)
c.supplies.attach(c)
local convenience_file=io.open(root.."convenience-settings.json","r");if convenience_file then convenience_file:close();local ok,why=convenience.attach(c);if not ok then print("Convenience: "..tostring(why))end end
print("Combat V2 backend ready (OFF). t NAME; cv2 bash / pvp / assist; cv2 help; cv2 trace.")
