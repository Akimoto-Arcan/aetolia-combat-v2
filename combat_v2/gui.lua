-- Reusable combat dashboard: no command execution during layout or refresh.
local M={}
local C={card="#192735",text="#d7e5f2",muted="#91a5b8",accent="#78b8e8",good="#76d39b",warn="#e5c07b",bad="#ee8897"}
local function esc(v) return tostring(v or "none"):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
local function html(s) return "<div style='color:"..C.text..";font-family:DejaVu Sans;font-size:13px;'>"..s.."</div>" end
local function heading(s) return "<b style='color:"..C.accent..";'>"..s.."</b><br>" end
local function flag(v) return v==true or tonumber(v)==1 end
local function ready(v) return "<span style='color:"..(flag(v) and C.good or C.warn)..";'>"..(flag(v) and "READY" or "WAIT").."</span>" end
local limb_keys={"head","torso","left_arm","right_arm","left_leg","right_leg"}
local limb_short={left_arm="LA",right_arm="RA",left_leg="LL",right_leg="RL",torso="TORSO",head="HEAD"}
local scan_ink={unknown="#365b47",clear="#78f7a3",warning="#ffd166",broken="#ff755f",mangled="#ec83ff"}
-- This is a view of observations, never an estimator or a source of injuries.
function M.limb_snapshot(state,side,key)
 local actor=side=="self" and state.player or state.target
 local e=actor.evidence and actor.evidence["limb:"..key]
 local value=actor.limbs and tonumber(actor.limbs[key])
 if value==0 and not e then value=nil end
 local severity,marker=0,""
 for i,kind in ipairs({"crippled","broken","mangled"})do if actor[kind] and flag(actor[kind][key])then severity=i;marker=kind:upper()end end
 local compact=key:gsub("_","")
 for aff,v in pairs(actor.afflictions or {})do
  local a=tostring(aff):lower():gsub("[^%a]","")
  if flag(v) and a:find(compact,1,true) then
   for i,kind in ipairs({"crippled","broken","mangled"})do if a:find(kind,1,true) and i>severity then severity=i;marker=kind:upper()end end
   if a:find("damaged",1,true) and severity<2 then severity=2;marker="DAMAGED" end
  end
 end
 local color=severity==3 and "mangled" or severity==2 and "broken" or severity==1 and "warning" or value and value>=33.33 and "warning" or (value~=nil or side=="self" and state.connected) and "clear" or "unknown"
 local approximate=value~=nil and (not e or (e.confidence or 1)<1)
 local percent=value and ((approximate and "~" or "")..string.format("%.1f%%",value)) or "—"
 return {key=key,value=value,percent=percent,marker=marker,severity=severity,color=color,ink=scan_ink[color],approximate=approximate}
end
local function limb_rows(state,side)
 local rows={}
 for _,pair in ipairs({{"left_arm","right_arm"},{"left_leg","right_leg"},{"torso","head"}})do
  local cells={}
  for _,key in ipairs(pair)do local d=M.limb_snapshot(state,side,key);local mark=({CRIPPLED="CRP",BROKEN="BRK",DAMAGED="DMG",MANGLED="MNG"})[d.marker] or ""
   cells[#cells+1]="<span style='color:"..(d.color=="unknown" and C.muted or d.ink)..";'>"..limb_short[key].." "..d.percent.." "..mark.."</span>"
  end
  rows[#rows+1]=table.concat(cells," &nbsp; | &nbsp; ")
 end
 return "<span style='font-size:12px;'>"..table.concat(rows,"<br>").."</span>"
end
local function body_asset(name)
 local path=(getMudletHomeDir and getMudletHomeDir() or "").."/combat_v2/assets/body/"..name..".png"
 return path:gsub("\\","/")
end
local function scan_label(body,name,x,y,w,h,parent)
 local o=Geyser.Label:new({name="cv2_scan_"..name,x=x,y=y,width=w,height=h},parent or body.window)
 o:setStyleSheet("background-color:transparent;color:#78f7a3;border:0;padding:0;qproperty-alignment:'AlignTop | AlignLeft';")
 return o
end
local function scan_html(s)return "<div style='font-family:DejaVu Sans Mono;font-size:13px;color:#78f7a3;'>"..s.."</div>"end
function M.show_body()
 if not Geyser.UserWindow then return false,"Native user window unavailable" end
 if not combat_v2_ui then M.create()end
 local ui=combat_v2_ui
 if not ui.body then
  local b={sides={}};ui.body=b
  b.window=Geyser.UserWindow:new({name="Combat V2 Body Scan",titleText="COMBAT V2 // BIOMETRIC MONITOR",x=70,y=80,width=920,height=620,autoDock=false,docked=false,restoreLayout=false})
  b.backdrop=scan_label(b,"backdrop",0,0,"100%","100%")
  b.backdrop:setBackgroundImage(body_asset("crt_grid"))
  b.title=scan_label(b,"title",22,17,740,32)
  b.subtitle=scan_label(b,"subtitle",22,53,875,25)
  b.close=scan_label(b,"close",806,18,90,28);b.close:setStyleSheet("background-color:#152e1e;color:#78f7a3;border:1px solid #4c9364;padding:3px;")
  b.close:echo(scan_html("<center>CLOSE [X]</center>"));b.close:setClickCallback(function()combat_v2_ui.body.window:hide()end)
  for i,side in ipairs({"enemy","self"})do
   local x=18+(i-1)*450;local pane={layers={},rows={}};b.sides[side]=pane
   pane.frame=scan_label(b,side.."_frame",x,88,434,448);pane.frame:setStyleSheet("background-color:rgba(7,18,11,175);border:1px solid #2f6946;")
   pane.heading=scan_label(b,side.."_heading",x+14,100,406,28)
   pane.sub=scan_label(b,side.."_sub",x+14,132,406,24)
   for j,key in ipairs(limb_keys)do
    pane.layers[key]=scan_label(b,side.."_"..key.."_art",x+216,171,200,320)
    pane.rows[key]=scan_label(b,side.."_"..key.."_readout",x+14,173+(j-1)*52,192,46)
   end
   pane.footer=scan_label(b,side.."_footer",x+14,511,406,20)
  end
  b.legend=scan_label(b,"legend",22,551,880,54)
  b.legend:echo(scan_html("<span style='color:#78f7a3;'>■ NO INJURY SEEN</span>  <span style='color:#ffd166;'>■ CRIPPLED / TRAUMA</span>  <span style='color:#ff755f;'>■ BROKEN</span>  <span style='color:#ec83ff;'>■ MANGLED</span><br><span style='color:#70987e;font-size:11px;'>— UNKNOWN TRAUMA · ~ ESTIMATE · INJURIES REQUIRE OBSERVATION · READ-ONLY DISPLAY</span>"))
 end
 -- Reflow reused widgets too, so an already-open scanner adopts the order.
 for i,side in ipairs({"enemy","self"})do
  local x=18+(i-1)*450;local p=ui.body.sides[side]
  p.frame:move(x,88);p.heading:move(x+14,100);p.sub:move(x+14,132);p.footer:move(x+14,511)
  for j,key in ipairs(limb_keys)do p.layers[key]:move(x+216,171);p.rows[key]:move(x+14,173+(j-1)*52)end
 end
 M.refresh_body(combat_v2.current,combat_v2.runner)
 ui.body.window:show();if raiseWindow then raiseWindow(ui.body.window.name) end;return true
end
function M.refresh_body(state,runner)
 local b=combat_v2_ui and combat_v2_ui.body;if not b then return end
 b.title:echo(scan_html("<b style='font-size:24px;letter-spacing:2px;'>V2 // BIOSTAT TERMINAL</b>"))
 b.subtitle:echo(scan_html("MONK ANATOMY SYSTEM  /  "..(state.connected and "<span style='color:#78f7a3;'>SIGNAL LIVE</span>" or "<span style='color:#ffd166;'>OFFLINE · CACHED</span>").."  /  MODE: "..esc(runner.mode)))
 for _,side in ipairs({"self","enemy"})do
  local p=b.sides[side];local actor=side=="self" and state.player or state.target
  p.heading:echo(scan_html("<b style='font-size:19px;'>"..(side=="self" and "02 // YOUR BODY" or "01 // ENEMY: "..esc(actor.name or "NO TARGET")).."</b>"))
  p.sub:echo(scan_html(side=="self" and ("HP "..esc(actor.hp).." / "..esc(actor.maxhp).."  |  MANA "..esc(actor.mana)) or "TRACKED TRAUMA / CONFIRMED INJURIES"))
  for _,key in ipairs(limb_keys)do
   local d=M.limb_snapshot(state,side,key);local art=p.layers[key]
   if art.cv2_color~=d.color then art:setBackgroundImage(body_asset(key.."_"..d.color));art.cv2_color=d.color end
   p.rows[key]:echo(scan_html("<span style='color:#70987e;font-size:11px;'>"..key:gsub("_"," "):upper().."</span><br><b style='font-size:16px;color:"..d.ink..";'>"..d.percent.."</b> <span style='font-size:11px;color:"..d.ink..";'>"..(d.marker~="" and d.marker or d.color=="unknown" and "NO DATA" or "NO INJURY SEEN").."</span>"))
  end
  p.footer:echo(scan_html("<span style='font-size:11px;color:#70987e;'>"..(side=="self" and "SELF % UNREPORTED: —  /  NOT ARM BALANCE" or "FRONT VIEW: BODY LEFT IS VIEWER RIGHT").."</span>"))
 end
end

-- Defense-manager rendering is read-only; only explicit operator clicks dispatch.
local function buff_core()
 local c=combat_v2
 if not c or not c.current or not c.buffs or type(c.buffs.rows)~="function" then return nil,"Defense manager core unavailable" end
 return c
end
local function buff_entry(key)
 if type(key)~="string" or not key:match("^[%a][%w_]*$") then return nil end
 local c=buff_core();if not c then return nil end
 for _,entry in ipairs(c.buffs.rows(c.current))do if entry.key==key then return entry end end
end
local function defense_toggleable(entry,revoking)
 -- Revoking local intent needs no activation resources; it grants no foreign OFF command.
 if revoking and entry.control=="class" and entry.relevant==true and entry.wanted==true and entry.tracking_only~=true then return true end
 return entry.available~=false and entry.can_toggle~=false and entry.known~=false and entry.tracking_only~=true and entry.relevant~=false
end
local function defense_class(state)return tostring(state.player.class or ""):lower()end
function M.defense_action(action,rest)
 local c,why=buff_core();if not c then return false,why end
 if action=="keep" or action=="native" then
  if action=="native" or (rest~="on" and rest~="off") then
   local key=type(rest)=="string" and rest:match("^([%a][%w_]*) on$")
   if not key and type(rest)=="string" then key=rest:match("^([%a][%w_]*) off$")end
   local entry=key and buff_entry(key)
   if not entry or (action=="keep" and entry.control~="class") or (action=="native" and entry.control~="native") then return false,"Unknown defense selection" end
   if action=="keep" and not defense_toggleable(entry,type(rest)=="string" and rest:match(" off$")~=nil) then return false,entry.availability or "Read-only / unavailable defense" end
   if action=="native" and (type(entry.priority)~="number" or entry.priority<1 or entry.priority>26 or entry.priority%1~=0) then return false,"Native priority UNKNOWN; audit FIRSTAID first" end
  end
 elseif action~="start" and action~="stop" then return false,"Unsupported defense action" end
 if type(combat_v2_buffs)~="function" then return false,"Defense manager callback unavailable" end
 local ok,message=combat_v2_buffs(action,rest or "")
 M.refresh_defenses(c.current)
 return ok,message
end
local function defense_label(p,key,x,y,w,h)
 local o=Geyser.Label:new({name="cv2_defenses_"..key,x=x,y=y,width=w,height=h},p.window)
 o:setStyleSheet("background-color:"..C.card..";color:"..C.text..";border:0;padding:3px;qproperty-alignment:'AlignTop | AlignLeft';")
 return o
end
local function defense_click(action,rest)
 local ok,why=combat_v2.gui.defense_action(action,rest);if ok==false and why then print(why)end
end
local function defense_rows(c,state,filter)
 local rows={};local seen={}
 local class=defense_class(state):upper()
 for _,e in ipairs(c.buffs.rows(state))do
  if type(e.key)=="string" and e.key:match("^[%a][%w_]*$") and not seen[e.key] then
   seen[e.key]=true
   local foreign=e.relevant==false or (e.owner=="MONK"or e.owner=="ARCHIVIST")and e.owner~=class
   local client=e.owner==class or e.owner=="SKILL"or e.owner=="TATTOO"or e.owner=="CURATIVE MANUAL"or e.owner=="CURATIVE"
   if not foreign and (filter=="ALL" or filter=="ACTIVE" and e.active==true or filter=="CLIENT" and client or e.owner==filter) then rows[#rows+1]=e end
  end
 end
 return rows
end
function M.defense_page(delta,filter)
 local p=combat_v2_ui and combat_v2_ui.defenses;if not p then return false end
 if filter then
  if filter~="ALL" and filter~="CLIENT" and filter~="FIRSTAID" and filter~="ACTIVE" then return false end
  p.filter=filter;p.page=1
 else p.page=(p.page or 1)+delta end
 return M.refresh_defenses()
end
function M.defense_slot(slot,expected)
 local p=combat_v2_ui and combat_v2_ui.defenses;local c=buff_core()
 local row=p and p.rows[slot];if not row or not c or not row.key then return false,"Unknown defense slot" end
 if expected and expected~=row.token then return false,"Stale defense slot"end
 local entries=defense_rows(c,c.current,p.filter)
 local e=entries[(p.page-1)*14+slot]
 if not e or e.key~=row.key or e.control~=row.control or row.class~=defense_class(c.current) or row.toggle.hidden then return false,"Stale defense slot" end
 if e.control~="class" and e.control~="native" then return false,"Read-only observation" end
 if e.control=="class" and not defense_toggleable(e,e.wanted==true) then return false,e.availability or "Read-only / unavailable defense" end
 return M.defense_action(e.control=="native" and "native" or "keep",e.key..(e.wanted==true and " off" or " on"))
end
function M.show_defenses()
 local c,why=buff_core();if not c then return false,why end
 if not Geyser.UserWindow then return false,"Native user window unavailable" end
 if not combat_v2_ui then M.create()end
 local ui=combat_v2_ui
 -- Retire the old catalog-keyed manager only; preserve every other popup.
 if ui.defenses and not ui.defenses.page then
  local old=ui.defenses
  for _,row in pairs(old.rows or {})do row.info:delete();row.toggle:delete()end
  for _,button in pairs(old.buttons or {})do button:delete()end
  for _,key in ipairs({"header","warning","columns","footer","window"})do if old[key]then old[key]:delete()end end
  ui.defenses=nil
 end
 if not ui.defenses then
  local p={rows={},buttons={},page=1,filter="ALL"};ui.defenses=p
  p.window=Geyser.UserWindow:new({name="Combat V2 Defenses",titleText="COMBAT V2 // DEFENSE MANAGER",x=80,y=60,width=860,height=740,autoDock=false,docked=false,restoreLayout=false})
  p.header=defense_label(p,"header",12,10,836,42)
  p.warning=defense_label(p,"warning",12,54,836,40)
  for i,spec in ipairs({{"defup","DEFUP","start"},{"keep_on","UPKEEP ON","keep","on"},{"keep_off","UPKEEP OFF","keep","off"},{"refresh","REFRESH"},{"stop","STOP","stop"}})do
   local action,rest=spec[3],spec[4];local b=defense_label(p,spec[1],12+(i-1)*168,98,158,30);p.buttons[spec[1]]=b
   b:setStyleSheet("background-color:#233c51;color:"..C.text..";border:1px solid #507590;padding:4px;")
   b:echo(html("<center>"..spec[2].."</center>"))
   b:setClickCallback(function()if action then defense_click(action,rest)else combat_v2.gui.refresh_defenses(combat_v2.current)end end)
  end
  for i,filter in ipairs({"ALL","CLIENT","FIRSTAID","ACTIVE"})do
   local f=filter;local b=defense_label(p,"filter_"..f,12+(i-1)*120,134,110,26);p.buttons[f]=b
   b:echo(html("<center>"..f.."</center>"));b:setClickCallback(function()return combat_v2.gui.defense_page(0,f)end)
  end
  p.buttons.prev=defense_label(p,"prev",504,134,65,26);p.buttons.prev:echo(html("PREV"));p.buttons.prev:setClickCallback(function()return combat_v2.gui.defense_page(-1)end)
  p.page_label=defense_label(p,"page",574,134,194,26)
  p.buttons.next=defense_label(p,"next",778,134,70,26);p.buttons.next:echo(html("NEXT"));p.buttons.next:setClickCallback(function()return combat_v2.gui.defense_page(1)end)
  p.columns=defense_label(p,"columns",12,164,836,26)
  p.columns:echo(html("<b>DEFENSE · STATE · OWNER / PRIORITY &nbsp; | &nbsp; WANTED</b>"))
  for i=1,14 do
   local slot=i;local y=194+(i-1)*34
   local row={info=defense_label(p,"slot_"..i,12,y,690,32),toggle=defense_label(p,"toggle_"..i,714,y,134,30)};p.rows[i]=row
   row.toggle:setClickCallback(function()
    local ok,message=combat_v2.gui.defense_slot(slot);if ok==false and message then print(message)end;return ok,message
   end)
  end
  p.footer=defense_label(p,"footer",12,674,836,62)
 end
 M.refresh_defenses(c.current)
 ui.defenses.window:show();if raiseWindow then raiseWindow(ui.defenses.window.name)end
 return true
end
function M.refresh_defenses(state)
 local p=combat_v2_ui and combat_v2_ui.defenses;if not p or not p.page then return end
 local c,why=buff_core()
 if not c then
  p.header:echo(html(heading("DEFENSE MANAGER")..esc(why)))
  for _,row in pairs(p.rows)do row.info:hide();row.toggle:hide()end
  return false,why
 end
 state=state or c.current
 -- Rebind an already-open paged manager without replacing its window or slots.
 if p.buttons.MONK then
  if p.buttons.CLIENT and p.buttons.CLIENT~=p.buttons.MONK then p.buttons.MONK:delete()
  else p.buttons.CLIENT=p.buttons.MONK end
  p.buttons.MONK=nil
 end
 if p.filter=="MONK"then p.filter="CLIENT"end
 for _,f in ipairs({"ALL","CLIENT","FIRSTAID","ACTIVE"})do
  local filter=f;local button=p.buttons[f]
  button:echo(html("<center>"..filter.."</center>"))
  button:setClickCallback(function()return combat_v2.gui.defense_page(0,filter)end)
 end
 -- Do not initialize the service or infer upkeep observations from native defences.
 local b=state.buffs or {}
 local status=c.buff_status
 if type(status)=="table" then status=status.reason or status.status or status.phase end
 p.header:echo(html(heading("DEFENSE MANAGER · MASTER "..(b.master==true and "ON" or "OFF"))..(state.connected and "LIVE" or "OFFLINE / CACHED").." · Mana "..esc(state.player.mana).." / "..esc(state.player.maxmana).." · "..esc(status or (b.sequence and "DEFUP in progress" or "idle"))))
 p.warning:echo(html("<span style='color:"..C.warn..";'>Row ON arms its owner; drains are opt-in. MASTER / DEFUP / STOP: client skills only.<br>FIRSTAID is independent. UPKEEP OFF does NOT cancel active drains.</span>"))
 local entries=defense_rows(c,state,p.filter);local pages=math.max(1,math.ceil(#entries/14))
 p.page=math.max(1,math.min(p.page,pages))
 p.page_label:echo(html("Page "..p.page.." / "..pages.." · "..#entries.." rows"))
 for _,f in ipairs({"ALL","CLIENT","FIRSTAID","ACTIVE"})do p.buttons[f]:setStyleSheet("background-color:"..(p.filter==f and "#315b46" or "#233c51")..";color:"..C.text..";padding:3px;")end
 for slot,row in ipairs(p.rows)do
  local entry=entries[(p.page-1)*14+slot]
  row.key=entry and entry.key;row.control=entry and entry.control;row.class=defense_class(state)
  -- A queued click retains the painted identity even after a class/filter repaint.
  local token={key=row.key,control=row.control,class=row.class};row.token=token
  local index=slot
  row.toggle:setClickCallback(function()
   local ok,message=combat_v2.gui.defense_slot(index,token);if ok==false and message then print(message)end;return ok,message
  end)
  if not entry then row.info:hide();row.toggle:hide()
  else
   row.info:show()
   local observed=entry.active==true and "ACTIVE" or entry.active==false and "MISSING" or "UNKNOWN"
   local color=entry.active==true and C.good or entry.active==false and C.bad or C.warn
   local priority=type(entry.priority)=="number" and entry.priority>=1 and entry.priority<=26 and entry.priority%1==0 and entry.priority or nil
   local notes={entry.owner or "OBSERVED"}
   if entry.required then notes[#notes+1]="REQUIRED" end
   if entry.availability then notes[#notes+1]=entry.availability end
   if entry.owner=="CURATIVE"and c.buff_sensory_source and c.buff_sensory_source.blocked_reason then notes[#notes+1]=c.buff_sensory_source.blocked_reason end
   if entry.passive then observed="PASSIVE" end
   if entry.control=="native" then notes[#notes+1]=priority==26 and "P26 OFF" or priority and "P"..priority or "PRIORITY UNKNOWN" end
   if entry.drain then notes[#notes+1]="DRAIN: "..(type(entry.drain)=="string" and entry.drain or "resources")end
   if entry.requires_full then notes[#notes+1]="full resources"end
   if entry.cooldown_loss then notes[#notes+1]="loss cooldown"end
   if entry.cooldown_activation then notes[#notes+1]="activation cooldown "..entry.cooldown_activation.."s"end
   notes[#notes+1]=entry.off and "OFF: verified cancel" or "OFF: upkeep only"
   row.info:echo(html("<span style='font-size:12px;'><b>"..esc(entry.label or entry.key).."</b> · <span style='color:"..color..";'>"..observed.."</span> · "..esc(table.concat(notes," · ")).."</span>"))
   if entry.control=="class" and defense_toggleable(entry,entry.wanted==true) or entry.control=="native" then
    row.toggle:show()
    row.toggle:setStyleSheet("background-color:"..(entry.wanted==true and "#315b46" or "#233c51")..";color:"..C.text..";border:1px solid #507590;padding:4px;")
    row.toggle:echo(html("<center>WANTED "..(entry.wanted==true and "ON" or entry.wanted==false and "OFF" or "UNKNOWN").."</center>"))
   else row.toggle:hide()end
  end
 end
 p.footer:echo(html("<span style='font-size:11px;color:"..C.muted..";'>ACTIVE is observed, never inferred from wanted. OBSERVED rows are read-only.<br>FIRSTAID ON: saved priority or default P8 only after full priority snapshot; OFF = P26.<br>defup audit: native DEF priorities.<br>Blindness/deafness are curable afflictions, not defenses. Mindseye provides one-time sensory protection.</span>"))
 return true
end

-- Shared, observed-only stance presentation for sidebar and the console subprompt.
function M.stance(state)
 if not state.connected then return "UNKNOWN (offline)",nil end
 if state.player.dead then return "NOT STANCED (dead)",false end
 local value=state.player.stance
 if value==nil then return "UNKNOWN",nil end
 local n=tostring(value):lower():match("^%s*(.-)%s*$")
 if n=="" or n=="none" or n=="0" or n=="unstanced" or n=="false" then return "NOT STANCED",false end
 if n=="unknown" or not n:match("^[%a][%a%s_%-]*$") then return "UNKNOWN",nil end
 if n=="scs" then n="scorpion" end
 return n:upper(),true
end
-- Display scope only: never alter cached class, stance, Kai or balances.
function M.monk_display(state)
 local class=state.player and state.player.class
 return type(class)=="string" and class:lower()=="monk"
end
function M.player_status_text(state,runner)
 local p=state.player;local prefix="";local balances="Balance %s &nbsp; Eq %s"
 local values={ready(p.balance),ready(p.equilibrium)}
 if M.monk_display(state) then
  local stance,stanced=M.stance(state);local color=stanced==true and C.good or stanced==false and C.bad or C.warn
  prefix="<b style='font-size:16px;color:"..color..";'>STANCE: "..esc(stance).."</b> &nbsp; Kai: "..esc(p.kai or "?").."<br>"
  balances=balances.." &nbsp; Arms %s / %s";values[#values+1]=ready(p.left_arm_balance);values[#values+1]=ready(p.right_arm_balance)
 end
 return html(heading("PLAYER STATUS")..prefix..string.format("HP %s / %s &nbsp; · &nbsp; Mana %s / %s<br>",esc(p.hp),esc(p.maxhp),esc(p.mana),esc(p.maxmana))..string.format(balances,(table.unpack or unpack)(values)).."<br>Executor: "..esc(runner.status or "idle")..(state.earthcaller and state.earthcaller.graft and ("<br>GRAFT: "..esc(state.earthcaller.graft.status)..((state.earthcaller.graft.status=="active" or state.earthcaller.graft.drain_possible) and " — drain 10 fragments/20s may continue outside BASH; OFF does not cease" or "")) or ""))
end
function M.prompt_text(state,runner)
 local p=state.player;local prefix="";local monk=M.monk_display(state)
 if monk then
  local stance,stanced=M.stance(state);local color=stanced==true and "green" or stanced==false and "red" or "yellow"
  prefix="<white>[<cyan>STANCE: <"..color..">"..stance.."<white>] [<cyan>Kai: <white>"..(tonumber(p.kai) or "?").."] "
 end
 local function balance(key,tag) return "<white>"..tag..":<"..(flag(p[key]) and "green" or "yellow")..">"..(flag(p[key]) and "READY" or "WAIT") end
 local balances=balance("balance","B").." "..balance("equilibrium","E")
 if monk then balances=balances.." "..balance("left_arm_balance","L").." "..balance("right_arm_balance","R") end
 local posture=flag(p.prone) and "<red>PRONE" or "<green>STANDING"
 local mount=flag(p.mounted) and "MOUNTED" or "ON FOOT"
 return prefix.."<white>["..balances.."<white>] ["..posture.."<white> / "..mount.."] [<cyan>"..tostring(runner.mode or "OFF"):gsub("[^%w_]", "").."<white>]"
end
function M.vitals_text(state,g)
 local p=state.player;local v=g and g.Char and g.Char.Vitals or {}
 local function resource(title,value,maximum)
  local n,m=tonumber(value),tonumber(maximum)
  if not n or not m or m<=0 then return "<white>[<cyan>"..title..": <yellow>?<white>]" end
  local pct=math.max(0,math.min(100,100*n/m));local color=pct<30 and "red" or pct<60 and "yellow" or "green"
  return "<white>[<cyan>"..title..": <"..color..">"..n.." ("..string.format("%.0f",pct).."%)<white>]"
 end
 local out={resource("HP",p.hp,p.maxhp),resource("MP",p.mana,p.maxmana)}
 if v.ep~=nil then out[#out+1]=resource("End",v.ep,v.maxep) end
 if v.wp~=nil then out[#out+1]=resource("Will",v.wp,v.maxwp) end
 if tonumber(v.xp) and (tonumber(v.maxxp) or 0)>0 then out[#out+1]="<white>[<cyan>XP: <white>"..string.format("%.2f%%",100*tonumber(v.xp)/tonumber(v.maxxp)).."]" end
 return table.concat(out," ")
end
function M.render_prompt(state,runner)
 if not cecho then return end
 -- This renderer is invoked only by the server-prompt trigger, never a GUI repaint.
 -- Replace the original prompt in place, preserving GMCP and other prompt handlers.
 if selectCurrentLine and replace then selectCurrentLine();replace("") end
 cecho(M.vitals_text(state,gmcp).."\n"..M.prompt_text(state,runner).."<reset>")
end
function M.help_text()
 return table.concat({
  "<cyan>COMBAT V2  |  MONK COMMAND GUIDE<white>",
  "Read-only help: nothing in this window starts attacks.",
  "",
  "<cyan>GET STARTED<white>",
  "  t NAME / NPC-ID       Select a target (e.g. t teshen).",
  "  cv2 bash              Arm persistent NPC bashing.",
  "  cv2 off               Stop attacks immediately. FIRSTAID is separate.",
  "  cv2 shadow            Observe proposals without attacking.",
  "  cv2 assist            Prepare actions for manual approval.",
  "  cv2 approve           Approve the current ASSIST action.",
  "",
  "<cyan>BASHING, AREAS & WEB MEMBERS<white>",
  "  BASH stays armed: up to 3 IH checks, then quiet GMCP room watch.",
  "  Fresh room checks choose selected/queued or AC2-whitelisted mobs.",
  "  Guards, corpses and loyal/protected NPCs are excluded.",
  "  Unlisted areas ask permission; unverified players pause attacks.",
  "  cv2 ih                Recheck current-room targets (BASH only).",
  "  BASH offers optional one-pass area walking; No stays stationary.",
  "  cv2 walk on / off     Request fresh Yes/No consent / stop walking.",
  "  cv2 walk status       Show area-walker progress or hold.",
  "  Walking requires GLOBE OFF; unknown IH never clears a room.",
  "  cv2 restock on|off|status  Independent opt-in BASH restocking (startup OFF).",
  "  RESTOCK waits for a safe clear room; it never interrupts current NPC attacks.",
  "  A trusted trip suspends WALK at the exact room and route position.",
  "  Resume needs the exact return room/area, fresh IH, no other players and recovery.",
  "  STOP, manual mode/target/queue, disconnect or fresh consent cancel automatic resume.",
  "  cv2 areas             Refresh the game's hunting-area list.",
  "  cv2 area yes / no     Answer the current area's approval prompt.",
  "  cv2 web               Refresh the current WEB MEMBERS roster.",
  "  cv2 config training_reports on / off",
  "                        Trust the local reporting dummy for this target only.",
  "  cv2 config group_web on / off",
  "                        Allow verified web members / strict solo mode.",
  "",
  "<cyan>OPTIONAL TARGET QUEUE<white>",
  "  cv2 queue add NAME    Add a preferred mob or numeric ID.",
  "  cv2 queue list        Show queued targets.",
  "  cv2 queue next        Skip to the next queued target.",
  "  cv2 queue clear       Clear the queue.",
  "",
  "<cyan>PVP & ROUTES<white>",
  "  cv2 config pvp_stance eagle / dragon / cobra / manual",
  "  cv2 config finish_stance cobra / manual",
  "  cv2 config mindlock on / off",
  "  cv2 config kaido on / off",
  "  AUTO builds a mindlock alongside Tekura; Blackout needs confirmed lock.",
  "  cv2 pvp / auto       Select FULL_AUTO for the current player target.",
  "  cv2 route legs / arms / head / torso / balanced",
  "  PvP is a testing backend, not a fully validated unattended system.",
  "",
  "<cyan>CURING & SAFETY<white>",
  "  cv2 curing on / off  Request native server FIRSTAID on/off.",
  "  cv2 defense status  Show cure blockers and survival hold.",
  "  cv2 defense audit   Read FIRSTAID/defences and Monk ability help.",
  "  cv2 defense setup   Stop attacks; request baseline FIRSTAID settings.",
  "  cv2 defense on/off  Enable/disable blocker-elevation governor.",
  "  cv2 config defense_health_pause 45 / defense_health_resume 65",
  "  cv2 config defense_mana_reserve 35 / defense_kai_reserve 20",
  "  Known blockers are elevated once per episode, not cured speculatively.",
  "  Emergency class abilities remain gated pending live AB verification.",
  "  cv2 config health_pause 30",
  "  cv2 config health_resume 60",
  "  cv2 config ack_timeout 8",
  "  Health/connection/recovery uncertainty blocks sending.",
  "  An unknown attack acknowledgement latches a safe pause.",
  "",
  "<cyan>OBSERVED TARGET CORRECTIONS<white>",
  "  Enemy-panel RESET / cv2 enemy reset",
  "    Clear enemy affs and injury/prone flags; keep target and numeric trauma.",
  "    Local correction only: no commands, mode change, or balance reset.",
  "  cv2 track limb ll 25       Set an observed limb percentage.",
  "  cv2 track damage ll 7.5    Add observed limb damage.",
  "  cv2 track crippled ll on   Also: broken / mangled, on / off.",
  "  cv2 track aff paralysis on",
  "  cv2 track prone on / off",
  "  cv2 track parry right_leg  Use none to clear.",
  "  cv2 track shield on / off",
  "  cv2 track rebounding on / off",
  "  Limbs: la, ra, ll, rl, torso, head. PvP tracking is ignored in BASH.",
  "",
  "<cyan>DIAGNOSTICS<white>",
  "  cv2 status            Show current execution state.",
  "  cv2 trace 20          Show recent evidence and actions.",
  "  cv2 reset             Clear a latched wait/fault AFTER reviewing trace.",
  "  cv2 reload            Reload the full backend; always starts OFF.",
  "  cv2 help              Reopen this movable, scrollable window.",
  "",
  "<cyan>PROMPT LEGEND<white>",
  "  Green stance = observed. Red NOT STANCED = explicitly out of stance.",
  "  Amber UNKNOWN = no current confirmation. Kai = observed Kai energy.",
  "  B / E = balance / equilibrium. L / R = left / right arm readiness.",
  "  The prompt also shows HP, mana, endurance, willpower, XP and mode.",
  "",
  "<white>Close with the window's X. Opening/closing help never changes modes.",
 },"\n").."<reset>\n"
end
function M.hide_walk_prompt()
 local ui=combat_v2_ui;if ui and ui.walk_popup then ui.walk_popup.root:hide() end
end
function M.show_walk_prompt(area,count,token)
 if not combat_v2_ui then M.create() end
 local ui=combat_v2_ui;local w,h=getMainWindowSize()
 if not ui.walk_popup then
  local p={};ui.walk_popup=p
  p.root=Geyser.Container:new({name="cv2_walk_prompt",x=0,y=80,width=340,height=150})
  p.label=Geyser.Label:new({name="cv2_walk_prompt_text",x=0,y=0,width=340,height=150},p.root)
  p.label:setStyleSheet("background-color:#192735;color:#d7e5f2;border:2px solid #507590;padding:10px;qproperty-alignment:'AlignTop | AlignLeft';")
  p.yes=Geyser.Label:new({name="cv2_walk_yes",x=12,y=110,width=152,height=28},p.root)
  p.no=Geyser.Label:new({name="cv2_walk_no",x=176,y=110,width=152,height=28},p.root)
  for _,b in ipairs({p.yes,p.no})do b:setStyleSheet("background-color:#233c51;color:#d7e5f2;border:1px solid #507590;padding:4px;")end
 end
 local p=ui.walk_popup;local width=math.max(1,math.min(340,w));local height=math.max(1,math.min(150,h));local half=math.max(1,(width-36)/2)
 p.root:resize(width,height);p.label:resize(width,height)
 p.yes:move(12,math.max(0,height-40));p.no:move(24+half,math.max(0,height-40));p.yes:resize(half,28);p.no:resize(half,28)
 p.root:move(math.max(0,(w-width)/2),math.max(0,math.min(100,h-height)))
 p.label:echo(html("<b style='font-size:17px;color:"..C.accent..";'>Auto bash this area?</b><br>"..esc(area).." · "..esc(count).."<br>One pass; fight first, IH, then walk.<br>Stays inside this mapped area."))
 p.yes:echo(html("<center>YES — WALK</center>"));p.no:echo(html("<center>NO — STAY HERE</center>"))
 p.yes:setClickCallback(function()local ok,why=combat_v2_walk_answer(token,true);if not ok and why then print(why)end end)
 p.no:setClickCallback(function()combat_v2_walk_answer(token,false)end)
 p.root:show();if type(p.root.raise)=="function"then p.root:raise()end
 return true
end

function M.show_help()
 if not openUserWindow then print("Combat V2 help: see docs/backend.md");return false end
 local ui=combat_v2_ui;local name="Combat V2 Help"
 if not ui.help_created then
  openUserWindow(name,false);ui.help_created=true
  resizeWindow(name,860,680)
  if setUserWindowTitle then setUserWindowTitle(name,"Combat V2 - Help & Commands") end
  if setBackgroundColor then setBackgroundColor(name,25,39,53) end
  if setFontSize then setFontSize(name,12) end
 end
 clearWindow(name);cecho(name,M.help_text());showWindow(name);if scrollTo then scrollTo(name,0) end;return true
end
local function sorted(t) local a={};for k,v in pairs(t or {}) do if v then a[#a+1]=tostring(k) end end;table.sort(a);return a end
local function label(ui,k)
 local o=Geyser.Label:new({name="cv2_live_"..k,x=10,y=0,width=600,height=50},ui.root)
 o:setStyleSheet("background-color:"..C.card..";color:"..C.text..";border:1px solid #294052;padding:8px;qproperty-alignment:'AlignTop | AlignLeft';")
 ui.cards[k]=o;return o
end
local function button(ui,k,text,fn)
 local o=Geyser.Label:new({name="cv2_live_"..k,x=10,y=0,width=70,height=30},ui.root)
 o:setStyleSheet("background-color:#233c51;color:"..C.text..";border:1px solid #385a74;padding:5px;")
 o:echo(html("<center>"..text.."</center>"));o:setClickCallback(fn);ui.buttons[k]=o;return o
end
local function place(o,x,y,w,h) o:move(x,y);o:resize(w,h) end
function M.layout()
 local ui=combat_v2_ui;if not ui then return end
 local w,h=getMainWindowSize();local rw=math.min(620,math.floor(w*.40));local rh=math.max(600,h-20);local cw=rw-20
 ui.width=rw;ui.height=rh;ui.root:move(w-rw-10,10);ui.root:resize(rw,rh);setBorderRight(rw+30)
 local y=0
 local function card(k,height) place(ui.cards[k],10,y,cw,height);y=y+height+8 end
 card("header",60);place(ui.buttons.defenses,rw-306,12,90,30);place(ui.buttons.body_scan,rw-208,12,110,30);place(ui.buttons.help,rw-90,12,70,30)
 local bw=(cw-24)/5
 for i,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do place(ui.buttons[m],10+(i-1)*(bw+6),y,bw,30) end
 y=y+38;local compact=rh<800;card("status",compact and 110 or 120);card("target",compact and 86 or 96);local limbH=compact and 90 or 102;local limbW=(cw-10)/2;place(ui.cards.limbs,10,y,limbW,limbH);place(ui.cards.self_limbs,20+limbW,y,limbW,limbH);y=y+limbH+8
 local affY=y;local affH=rh-affY-188;local aw=(cw-10)/2
 ui.per_page=math.max(1,math.floor((affH-88)/19));ui.aff_height=affH
 for i,k in ipairs({"player_afflictions","enemy_afflictions"}) do
  local x=10+(i-1)*(aw+10);place(ui.cards[k],x,affY,aw,affH)
  place(ui.buttons[k.."_prev"],x+8,affY+affH-33,34,25)
  place(ui.buttons[k.."_next"],x+aw-42,affY+affH-33,34,25)
 end
 local resetW=math.min(80,aw-100);place(ui.buttons.enemy_afflictions_reset,10+aw+10+(aw-resetW)/2,affY+affH-33,resetW,25)
 y=affY+affH+8;card("cure",52)
 local tw=(cw-48)/7
 for i,k in ipairs({"approve","curing","globe","walk","restock","unlock","stop"}) do place(ui.buttons[k],10+(i-1)*(tw+8),y,tw,30) end
 y=y+38;place(ui.cards.events,10,y,cw,rh-y)
 if ui.cards.help then ui.cards.help:hide() end
end
local function affpanel(ui,key,values,title,subtitle,color)
 local entries=sorted(values);local pages=math.max(1,math.ceil(#entries/ui.per_page));local page=math.max(1,math.min(ui.pages[key] or 1,pages));ui.pages[key]=page
 local rows={};local first=(page-1)*ui.per_page+1
 for i=first,math.min(#entries,first+ui.per_page-1) do rows[#rows+1]="<span style='color:"..color..";'>•</span> "..esc(entries[i]:gsub("_"," ")) end
 if #rows==0 then rows[1]="<span style='color:"..C.muted..";'>none observed</span>" end
 ui.cards[key]:echo(html("<b style='color:"..color..";'>"..title.." &nbsp; ["..#entries.."]</b><br><span style='font-size:11px;color:"..C.muted..";'>"..subtitle.." · "..page.."/"..pages.."</span><br><br><span style='font-size:14px;'>"..table.concat(rows,"<br>").."</span>"))
 ui.buttons[key.."_prev"]:echo(html("<center>‹</center>"));ui.buttons[key.."_next"]:echo(html("<center>›</center>"))
end
function M.unlock()
 local c=combat_v2
 if not c or not c.release_lock or type(c.release_lock.release)~="function" then
  local why="Recovery module unavailable; no locks changed";print("UNLOCK: "..why);return false,why
 end
 local ok,why=c.release_lock.release(c)
 local message=type(why)=="table" and why.reason or why
 print("UNLOCK: "..tostring(message or (ok and "Completed read-only lock released; automation remains OFF" or "No safe release available")))
 return ok,why
end
function M.create()
 if combat_v2_ui_resize then killAnonymousEventHandler(combat_v2_ui_resize) end
 combat_v2_ui_resize=registerAnonymousEventHandler("sysWindowResizeEvent",function()
  if combat_v2 and combat_v2.gui then combat_v2.gui.layout();combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end
 end)
 local ui=combat_v2_ui
 if not ui then
  local old=Geyser.windowList and Geyser.windowList.combat_v2_clean_root;if old then old:hide();old:delete() end
  for _,prefix in ipairs({"combat_v2_","combat_v2_clean_"}) do for _,k in ipairs({"header","status","target","cure","events","log","modes","mode","mode_OFF","mode_SHADOW","mode_ASSIST","mode_BASH","mode_FULL_AUTO"}) do pcall(deleteLabel,prefix..k) end end
  ui={cards={},buttons={},pages={}};ui.root=Geyser.Container:new({name="cv2_live_root",x=0,y=10,width=620,height=900});combat_v2_ui=ui
 end
 ui.pages=ui.pages or {};M.root=ui.root;M.cards=ui.cards;M.buttons=ui.buttons
 for _,k in ipairs({"header","status","target","limbs","self_limbs","player_afflictions","enemy_afflictions","cure","events"}) do
  if not ui.cards[k] then label(ui,k) end
  ui.cards[k]:setStyleSheet("background-color:"..C.card..";color:"..C.text..";border:1px solid #294052;padding:8px;qproperty-alignment:'AlignTop | AlignLeft';")
 end
 if ui.cards.afflictions then ui.cards.afflictions:hide() end
 for _,mode in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do
  if not ui.buttons[mode] then button(ui,mode,mode=="FULL_AUTO" and "AUTO" or mode,function() combat_v2_set_mode(mode);combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end) end
 end
 local callbacks={approve=function()combat_v2_approve()end,curing=function()combat_v2_set_curing(not combat_v2.cure.enabled)end,stop=function()combat_v2_stop()end,globe=function()local b=combat_v2.elemental_recovery;local on=b and b.armed and combat_v2.mode=="BASH";if combat_v2_globe then local ok,why=combat_v2_globe(on and "off"or"on");if not ok and why then print(why)end end end}
 callbacks.walk=function()if combat_v2_walk then local w=combat_v2.current.walker or {};local ok,why=combat_v2_walk(w.enabled and "off"or"on");if not ok and why then print(why)end end end
 callbacks.unlock=function()return combat_v2.gui.unlock()end
 callbacks.restock=function()if combat_v2_restock then local d=combat_v2.restock_data or {};local ok,why=combat_v2_restock(d.enabled and "off"or"on");if not ok and why then print(why)end end end
 for _,k in ipairs({"approve","curing","globe","walk","restock","unlock","stop"}) do if not ui.buttons[k] then button(ui,k,k:upper(),function() callbacks[k]();combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end) end end
 for _,k in ipairs({"player_afflictions","enemy_afflictions"}) do
  for _,direction in ipairs({"prev","next"}) do
   local key=k.."_"..direction
   local click=function()
    local entries=sorted(k=="player_afflictions" and combat_v2.current.player.afflictions or combat_v2.current.target.afflictions)
    local pages=math.max(1,math.ceil(#entries/(ui.per_page or 1)))
    ui.pages[k]=((ui.pages[k] or 1)-1+(direction=="next" and 1 or -1))%pages+1
    combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure)
   end
   if not ui.buttons[key] then button(ui,key,direction=="prev" and "‹" or "›",click)else ui.buttons[key]:setClickCallback(click)end
  end
 end
 if not ui.buttons.enemy_afflictions_reset then button(ui,"enemy_afflictions_reset","RESET",function()local ok,why=combat_v2_reset_enemy_afflictions();if not ok and why then print(why)end end) end
 if not ui.buttons.defenses then button(ui,"defenses","DEFENSES",function()local ok,why=combat_v2.gui.show_defenses();if not ok and why then print(why)end;return ok,why end) end
 if not ui.buttons.body_scan then button(ui,"body_scan","BODY SCAN",function()combat_v2.gui.show_body()end) end
 if not ui.buttons.help then button(ui,"help","HELP",function()combat_v2.gui.show_help()end) end
 M.layout();return ui.root
end
function M.event_feed(state)
 local history=state.recent_events;local rows={}
 if history and #history>0 then
  for i=1,math.min(3,#history)do
   local item=history[i];local text=item.text or ""
   if #text>84 then text=text:sub(1,81):gsub("[\194-\244][\128-\191]*$","").."…" end
   local stamp=os.date("%H:%M:%S",math.floor(item.time or 0))
   rows[#rows+1]="<span style='color:"..C.muted..";'>"..stamp.."</span> "..esc(text)
  end
 elseif state.last_event then rows[1]=esc(state.last_event)
 else rows[1]="<span style='color:"..C.muted..";'>Waiting for non-prompt game events</span>" end
 return html(heading("RECENT EVENTS").."<span style='font-size:11px;'>"..table.concat(rows,"<br>").."</span>")
end

function M.walker_progress(state)
 local w=type(state)=='table'and state.walker
 if type(w)~='table'or not(w.enabled or w.active or w.restock_checkpoint)then return nil end
 if w.offer then return 'WALK: awaiting route confirmation' end
 local cp=w.restock_checkpoint
 if not w.active and not cp and not tostring(w.status or ''):lower():find('complete',1,true)then return 'WALK: ON - awaiting route' end
 local graph=cp and cp.graph or w.graph
 if type(graph)~='table'or type(graph.nodes)~='table'then return 'WALK: rooms left unknown' end
 local seen,total,visited={},0,0;local history=cp and cp.visited or w.visited or {}
 for id,node in pairs(graph.nodes)do
  local key=tostring(id)
  if key:match('^%d+$')and type(node)=='table'and not seen[key]then
   seen[key]=true;total=total+1
   if history[key]==true or history[tonumber(key)]==true then visited=visited+1 end
  end
 end
 if total==0 then return 'WALK: rooms left unknown' end
 return string.format('WALK%s: %d rooms left | %d/%d visited',cp and ' (restocking)'or '',total-visited,visited,total)
end
-- Read-only presentation: permission is not proof of movement/combat.
function M.range_controls(state,runner)
 local c=combat_v2 or {};local a=c.tour_attachment;local st=c.tour and c.tour.state
 local grant=st and st.grant
 local phases={ratings=true,next=true,transfer=true,prepare=true,hunt=true,retiring=true,retired=true,finishing=true}
 local intent=not not(a and a.attached and grant and grant.session==a.session
  and grant.class==state.player.class and grant.generation==st.generation
  and phases[st.phase] and state.connected and not state.player.dead)
 local w=state.walker or {};local d=c.restock_data or {}
 return {bash=runner.mode=='BASH'and 'ON'or intent and 'ARMED'or 'OFF',
  walk=w.active and 'ON'or(w.enabled or intent)and 'ARMED'or 'OFF',
  restock=d.enabled and(d.active and 'ON'or 'ARMED')or 'OFF',busy=d.busy==true}
end
function M.refresh(state,runner,cure)
 if not M.cards then M.create() end
 local ui=combat_v2_ui;local p,t=state.player,state.target
 local globe=combat_v2 and combat_v2.elemental_recovery;local globe_on=runner.mode=="BASH"and globe and globe.armed and not globe.fault
 M.buttons.globe:echo(html("<center>GLOBE "..(globe_on and"ON"or"OFF").."</center>"))
 local ws=state.walker or {};M.buttons.walk:echo(html("<center>WALK "..(ws.enabled and "ON"or"OFF").."</center>"));M.buttons.walk:setStyleSheet("background-color:"..(ws.enabled and "#22563e"or"#233c51")..";color:"..C.text..";border:1px solid #507590;padding:1px;font-size:10px;")
 local rs=combat_v2 and combat_v2.restock_data or {};local rsm=combat_v2 and combat_v2.restock_module
 local rsbusy=rsm and rsm.busy and rsm.busy(combat_v2)
 M.buttons.restock:echo(html("<center>RESTOCK "..(rs.enabled and "ON"or"OFF")..(rsbusy and " *"or"").."</center>"))
 M.buttons.restock:setStyleSheet("background-color:"..(rs.enabled and "#22563e"or"#233c51")..";color:"..C.text..";border:1px solid #507590;padding:1px;font-size:9px;")
 M.buttons.globe:setStyleSheet("background-color:"..(globe_on and"#22563e"or"#233c51")..";color:"..C.text..";border:1px solid #507590;padding:3px;font-size:10px;")
 local mental=state.mental;local mind=mental and (mental.fault or mental.status) or "idle"
 M.cards.header:echo(html("<b style='font-size:18px;color:"..C.accent..";'>COMBAT V2</b> &nbsp; "..esc(type(p.class)=="string"and p.class~=""and p.class:upper()or "UNKNOWN").." / "..esc(runner.mode).."<br><span style='color:"..C.muted..";'>MIND: "..esc(mind).." &nbsp; · &nbsp; cv2 help</span>"))
 for _,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do M.buttons[m]:setStyleSheet("background-color:"..(m==runner.mode and "#386386" or "#233c51")..";color:"..C.text..";border:1px solid #507590;padding:5px;") end
 M.cards.status:echo(M.player_status_text(state,runner))
 local a=runner.pending or state.last_action or {}
 if state.defense and state.defense.hold and runner.mode~="OFF" then a={command="",reason="DEFENSE: "..state.defense.phase} end
 local restore=t.restoration;local restoration=""
 if restore and restore.active then local remaining=math.max(0,(restore.expected_end or 0)-(getEpoch and getEpoch() or os.clock()));restoration="<br><span style='font-size:11px;color:"..C.warn..";'>RESTORE: "..esc(restore.limb:gsub("_"," "))..(remaining>0 and string.format(" ~%.1fs",remaining) or " awaiting cure confirmation").."</span>" end
 local wp=M.walker_progress(state);local walkline=wp and ("<br><span style='font-size:11px;color:"..C.accent..";'>"..esc(wp).."</span>")or ""
 M.cards.target:echo(html(heading("TARGET / ACTION").."<b>"..esc(t.name).."</b> &nbsp; "..esc(a.command and a.command~="" and a.command or "WAIT").."<br><span style='color:"..C.muted..";'>"..esc(a.reason or "Set a target, then select BASH or AUTO").."</span>"..restoration..walkline))
 M.cards.limbs:echo(html(heading("ENEMY LIMBS")..limb_rows(state,"enemy").."<br><span style='font-size:11px;'>Prone: "..(t.prone and "yes" or "no").." · Parry: "..esc(t.parry_limb or "unknown").."</span>"))
 M.cards.self_limbs:echo(html(heading("YOUR LIMBS")..limb_rows(state,"self").."<br><span style='font-size:11px;'>Prone: "..(flag(p.prone) and "yes" or "no").." · — = unreported %</span>"))
 M.refresh_body(state,runner)
 M.refresh_defenses(state)
 affpanel(ui,"player_afflictions",p.afflictions,"YOUR AFFLICTIONS","GMCP observed",C.warn)
 affpanel(ui,"enemy_afflictions",t.afflictions,"ENEMY AFFLICTIONS","tracked / inferred",C.bad)
 local d=state.defense;local defense=not state.connected and "OFFLINE" or d and d.phase or "monitoring"
 M.cards.cure:echo(html(heading("DEFENSE / FIRSTAID").."<span style='color:"..(d and d.hold and C.bad or d and d.low_health and C.warn or C.good)..";'>"..esc(defense).."</span> · FA: "..(cure.enabled and "requested" or "unverified")))
 M.cards.events:echo(M.event_feed(state))
 -- Render last: retain selected OFF during travel; never change GLOBE here.
 local controls=M.range_controls(state,runner)
 for _,key in ipairs({'bash','walk','restock'})do
  local value=controls[key];local b=M.buttons[key=='bash'and 'BASH'or key]
  local label=key=='bash'and(value=='OFF'and 'BASH'or 'BASH '..value)or key:upper()..' '..value
  if key=='restock'and rsbusy then label=label..' *'end
  b:echo(html("<center style='font-size:"..(key=='restock'and '8'or '10').."px;'>"..label..'</center>'))
  local color=value=='ARMED'and '#79551f'or value=='ON'and(key=='bash'and '#386386'or '#22563e')or '#233c51'
  b:setStyleSheet('background-color:'..color..';color:'..C.text..';border:1px solid #507590;padding:1px;font-size:'..(key=='restock'and '9'or '10')..'px;')
 end
end
return M
