-- Reusable combat dashboard: no command execution during layout or refresh.
local M={}
local C={card="#192735",text="#d7e5f2",muted="#91a5b8",accent="#78b8e8",good="#76d39b",warn="#e5c07b",bad="#ee8897"}
local function esc(v) return tostring(v or "none"):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
local function html(s) return "<div style='color:"..C.text..";font-family:DejaVu Sans;font-size:13px;'>"..s.."</div>" end
local function heading(s) return "<b style='color:"..C.accent..";'>"..s.."</b><br>" end
local function flag(v) return v==true or tonumber(v)==1 end
local function ready(v) return "<span style='color:"..(flag(v) and C.good or C.warn)..";'>"..(flag(v) and "READY" or "WAIT").."</span>" end
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
function M.prompt_text(state,runner)
 local p=state.player;local stance,stanced=M.stance(state)
 local color=stanced==true and "green" or stanced==false and "red" or "yellow"
 local function balance(key,tag) return "<white>"..tag..":<"..(flag(p[key]) and "green" or "yellow")..">"..(flag(p[key]) and "READY" or "WAIT") end
 local posture=flag(p.prone) and "<red>PRONE" or "<green>STANDING"
 local mount=flag(p.mounted) and "MOUNTED" or "ON FOOT"
 return "<white>[<cyan>STANCE: <"..color..">"..stance.."<white>] [<cyan>Kai: <white>"..(tonumber(p.kai) or "?").."] ["..balance("balance","B").." "..balance("equilibrium","E").." "..balance("left_arm_balance","L").." "..balance("right_arm_balance","R").."<white>] ["..posture.."<white> / "..mount.."] [<cyan>"..tostring(runner.mode or "OFF"):gsub("[^%w_]", "").."<white>]"
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
 card("header",60);place(ui.buttons.help,rw-90,12,70,30)
 local bw=(cw-24)/5
 for i,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do place(ui.buttons[m],10+(i-1)*(bw+6),y,bw,30) end
 y=y+38;local compact=rh<800;card("status",compact and 110 or 120);card("target",compact and 86 or 96);card("limbs",compact and 90 or 102)
 local affY=y;local affH=rh-affY-188;local aw=(cw-10)/2
 ui.per_page=math.max(1,math.floor((affH-88)/19));ui.aff_height=affH
 for i,k in ipairs({"player_afflictions","enemy_afflictions"}) do
  local x=10+(i-1)*(aw+10);place(ui.cards[k],x,affY,aw,affH)
  place(ui.buttons[k.."_prev"],x+8,affY+affH-33,34,25)
  place(ui.buttons[k.."_next"],x+aw-42,affY+affH-33,34,25)
 end
 local resetW=math.min(80,aw-100);place(ui.buttons.enemy_afflictions_reset,10+aw+10+(aw-resetW)/2,affY+affH-33,resetW,25)
 y=affY+affH+8;card("cure",52)
 local tw=(cw-16)/3
 for i,k in ipairs({"approve","curing","stop"}) do place(ui.buttons[k],10+(i-1)*(tw+8),y,tw,30) end
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
 for _,k in ipairs({"header","status","target","limbs","player_afflictions","enemy_afflictions","cure","events"}) do
  if not ui.cards[k] then label(ui,k) end
  ui.cards[k]:setStyleSheet("background-color:"..C.card..";color:"..C.text..";border:1px solid #294052;padding:8px;qproperty-alignment:'AlignTop | AlignLeft';")
 end
 if ui.cards.afflictions then ui.cards.afflictions:hide() end
 for _,mode in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do
  if not ui.buttons[mode] then button(ui,mode,mode=="FULL_AUTO" and "AUTO" or mode,function() combat_v2_set_mode(mode);combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end) end
 end
 local callbacks={approve=function()combat_v2_approve()end,curing=function()combat_v2_set_curing(not combat_v2.cure.enabled)end,stop=function()combat_v2_stop()end}
 for _,k in ipairs({"approve","curing","stop"}) do if not ui.buttons[k] then button(ui,k,k:upper(),function() callbacks[k]();combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end) end end
 for _,k in ipairs({"player_afflictions","enemy_afflictions"}) do
  for _,direction in ipairs({"prev","next"}) do
   local key=k.."_"..direction
   if not ui.buttons[key] then button(ui,key,direction=="prev" and "‹" or "›",function()
    local entries=sorted(k=="player_afflictions" and combat_v2.current.player.afflictions or combat_v2.current.target.afflictions)
    local pages=math.max(1,math.ceil(#entries/(ui.per_page or 1)))
    ui.pages[k]=((ui.pages[k] or 1)-1+(direction=="next" and 1 or -1))%pages+1
    combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure)
   end) end
  end
 end
 if not ui.buttons.enemy_afflictions_reset then button(ui,"enemy_afflictions_reset","RESET",function()local ok,why=combat_v2_reset_enemy_afflictions();if not ok and why then print(why)end end) end
 if not ui.buttons.help then button(ui,"help","HELP",function()combat_v2.gui.show_help()end) end
 M.layout();return ui.root
end
function M.refresh(state,runner,cure)
 if not M.cards then M.create() end
 local ui=combat_v2_ui;local p,t=state.player,state.target
 local mental=state.mental;local mind=mental and (mental.fault or mental.status) or "idle"
 M.cards.header:echo(html("<b style='font-size:18px;color:"..C.accent..";'>COMBAT V2</b> &nbsp; MONK / "..esc(runner.mode).."<br><span style='color:"..C.muted..";'>MIND: "..esc(mind).." &nbsp; · &nbsp; cv2 help</span>"))
 for _,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do M.buttons[m]:setStyleSheet("background-color:"..(m==runner.mode and "#386386" or "#233c51")..";color:"..C.text..";border:1px solid #507590;padding:5px;") end
 local stance,stanced=M.stance(state);local stance_color=stanced==true and C.good or stanced==false and C.bad or C.warn
 M.cards.status:echo(html(heading("PLAYER STATUS").."<b style='font-size:16px;color:"..stance_color..";'>STANCE: "..esc(stance).."</b> &nbsp; Kai: "..esc(p.kai or "?").."<br>"..string.format("HP %s / %s &nbsp; · &nbsp; Mana %s / %s<br>Balance %s &nbsp; Eq %s &nbsp; Arms %s / %s<br>Executor: %s",esc(p.hp),esc(p.maxhp),esc(p.mana),esc(p.maxmana),ready(p.balance),ready(p.equilibrium),ready(p.left_arm_balance),ready(p.right_arm_balance),esc(runner.status or "idle"))))
 local a=runner.pending or state.last_action or {}
 if state.defense and state.defense.hold and runner.mode~="OFF" then a={command="",reason="DEFENSE: "..state.defense.phase} end
 local restore=t.restoration;local restoration=""
 if restore and restore.active then local remaining=math.max(0,(restore.expected_end or 0)-(getEpoch and getEpoch() or os.clock()));restoration="<br><span style='font-size:11px;color:"..C.warn..";'>RESTORE: "..esc(restore.limb:gsub("_"," "))..(remaining>0 and string.format(" ~%.1fs",remaining) or " awaiting cure confirmation").."</span>" end
 M.cards.target:echo(html(heading("TARGET / ACTION").."<b>"..esc(t.name).."</b> &nbsp; "..esc(a.command and a.command~="" and a.command or "WAIT").."<br><span style='color:"..C.muted..";'>"..esc(a.reason or "Set a target, then select BASH or AUTO").."</span>"..restoration))
 local rows={}
 for _,k in ipairs({"left_arm","right_arm","left_leg","right_leg","torso","head"}) do
  local marker=t.mangled[k] and "MANGLED" or t.broken[k] and "BROKEN" or t.crippled[k] and "CRIPPLED" or ""
  local evidence=t.evidence and t.evidence["limb:"..k];local prefix=evidence and (evidence.confidence or 1)<1 and "~" or ""
  rows[#rows+1]=esc(k:gsub("_"," ")).." "..prefix..string.format("%.1f%%",tonumber(t.limbs[k]) or 0).." "..marker
 end
 M.cards.limbs:echo(html(heading("ENEMY LIMBS / OBSERVED STATE")..table.concat({rows[1].." &nbsp; | &nbsp; "..rows[2],rows[3].." &nbsp; | &nbsp; "..rows[4],rows[5].." &nbsp; | &nbsp; "..rows[6]},"<br>").."<br>Prone: "..(t.prone and "yes" or "no").." &nbsp; Parry: "..esc(t.parry_limb or "unknown")))
 affpanel(ui,"player_afflictions",p.afflictions,"YOUR AFFLICTIONS","GMCP observed",C.warn)
 affpanel(ui,"enemy_afflictions",t.afflictions,"ENEMY AFFLICTIONS","tracked / inferred",C.bad)
 local d=state.defense;local defense=not state.connected and "OFFLINE" or d and d.phase or "monitoring"
 M.cards.cure:echo(html(heading("DEFENSE / FIRSTAID").."<span style='color:"..(d and d.hold and C.bad or C.good)..";'>"..esc(defense).."</span> · FA: "..(cure.enabled and "requested" or "unverified")))
 M.cards.events:echo(html(heading("LAST EVENT")..esc(state.last_event or "Waiting for in-game data")))
end
return M
