-- Persistent widgets: reloads update the same root instead of leaking Qt labels.
local M={}
local C={bg="#101923",card="#192735",text="#d7e5f2",muted="#91a5b8",accent="#78b8e8",good="#76d39b",warn="#e5c07b"}
local function esc(v) return tostring(v or "none"):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
local function html(s) return "<div style='color:"..C.text..";font-family:DejaVu Sans;font-size:12px;'>"..s.."</div>" end
local function heading(s) return "<b style='color:"..C.accent..";'>"..s.."</b><br>" end
local function flag(v) return v==true or tonumber(v)==1 end
local function ready(v) return "<span style='color:"..(flag(v) and C.good or C.warn)..";'>"..(flag(v) and "READY" or "WAIT").."</span>" end
local function names(t) local a={}; for k,v in pairs(t or {}) do if v then a[#a+1]=tostring(k) end end; table.sort(a); return #a>0 and esc(table.concat(a,", ")) or "none" end
local function label(ui,k,y,h)
 local o=Geyser.Label:new({name="cv2_live_"..k,x=10,y=y,width=400,height=h},ui.root)
 o:setStyleSheet("background-color:"..C.card..";color:"..C.text..";border:1px solid #294052;padding:8px;")
 ui.cards[k]=o; return o
end
local function button(ui,k,x,y,w,text,fn)
 local o=Geyser.Label:new({name="cv2_live_"..k,x=x,y=y,width=w,height=30},ui.root)
 o:setStyleSheet("background-color:#233c51;color:"..C.text..";border:1px solid #385a74;padding:5px;")
 o:echo(html("<center>"..text.."</center>")); o:setClickCallback(fn); ui.buttons[k]=o; return o
end
function M.layout()
 local ui=combat_v2_ui; if not ui then return end
 local w,h=getMainWindowSize(); ui.root:move(math.max(0,w-430),10); ui.root:resize(420,math.max(720,h-20))
 setBorderRight(440)
end
function M.create()
 if combat_v2_ui_resize then killAnonymousEventHandler(combat_v2_ui_resize) end
 combat_v2_ui_resize=registerAnonymousEventHandler("sysWindowResizeEvent",function() if combat_v2 and combat_v2.gui then combat_v2.gui.layout() end end)
 if combat_v2_ui and combat_v2_ui.root then
  M.root=combat_v2_ui.root; M.cards=combat_v2_ui.cards; M.buttons=combat_v2_ui.buttons; M.layout(); return M.root
 end
 -- Remove the known old visual shell, not engine or mapper objects.
 local old=Geyser.windowList and Geyser.windowList.combat_v2_clean_root
 if old then old:hide(); old:delete() end
 for _,prefix in ipairs({"combat_v2_","combat_v2_clean_"}) do
  for _,k in ipairs({"header","status","target","cure","events","log","modes","mode","mode_OFF","mode_SHADOW","mode_ASSIST","mode_BASH","mode_FULL_AUTO"}) do pcall(deleteLabel,prefix..k) end
 end
 local ui={cards={},buttons={}}
 ui.root=Geyser.Container:new({name="cv2_live_root",x=0,y=10,width=420,height=900})
 combat_v2_ui=ui; M.root=ui.root; M.cards=ui.cards; M.buttons=ui.buttons
 label(ui,"header",0,55)
 for i,mode in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do
  button(ui,mode,10+(i-1)*81,63,76,mode=="FULL_AUTO" and "AUTO" or mode,function() combat_v2_set_mode(mode); combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end)
 end
 label(ui,"status",102,132)
 label(ui,"target",242,100)
 label(ui,"limbs",350,118)
 label(ui,"afflictions",476,80)
 label(ui,"cure",564,68)
 button(ui,"approve",10,640,128,"APPROVE",function() combat_v2_approve(); combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end)
 button(ui,"curing",146,640,128,"CURING",function() combat_v2_set_curing(not combat_v2.cure.enabled); combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end)
 button(ui,"stop",282,640,128,"STOP",function() combat_v2_stop(); combat_v2.gui.refresh(combat_v2.current,combat_v2.runner,combat_v2.cure) end)
 label(ui,"events",678,95)
 label(ui,"help",781,85):echo(html(heading("CONTROLS").."t &lt;name or id&gt;<br>cv2 bash / auto / assist / off<br>cv2 approve / curing on / curing off"))
 M.layout(); return ui.root
end
function M.refresh(state,runner,cure)
 if not M.cards then M.create() end
 local p,t=state.player,state.target
 M.cards.header:echo(html("<b style='font-size:17px;color:"..C.accent..";'>COMBAT V2</b><br>MONK &nbsp; / &nbsp; "..esc(runner.mode).." &nbsp; / &nbsp; live executor"))
 for _,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do
  M.buttons[m]:setStyleSheet("background-color:"..(m==runner.mode and "#386386" or "#233c51")..";color:"..C.text..";border:1px solid #507590;padding:5px;")
 end
 M.cards.status:echo(html(heading("PLAYER STATUS")..string.format("HP &nbsp; %s / %s &nbsp; &nbsp; Mana &nbsp; %s / %s<br>Balance %s &nbsp; Eq %s<br>Left arm %s &nbsp; Right arm %s<br>Executor: %s",esc(p.hp),esc(p.maxhp),esc(p.mana),esc(p.maxmana),ready(p.balance),ready(p.equilibrium),ready(p.left_arm_balance),ready(p.right_arm_balance),esc(runner.status or (runner.waiting and "waiting for balance recovery" or "idle")))))
 local a=runner.pending or state.last_action or {}
 M.cards.target:echo(html(heading("TARGET / ACTION").."<b>"..esc(t.name).."</b><br>"..esc(a.command and a.command~="" and a.command or "WAIT").."<br><span style='color:"..C.muted..";'>"..esc(a.reason or "Set a target, then select BASH or AUTO").."</span>"))
 local rows={}
 for _,k in ipairs({"left_arm","right_arm","left_leg","right_leg","torso","head"}) do
  local marker=t.mangled[k] and "MANGLED" or t.broken[k] and "BROKEN" or t.crippled[k] and "CRIPPLED" or ""
  rows[#rows+1]=esc(k:gsub("_"," ")).." "..string.format("%.1f%%",tonumber(t.limbs[k]) or 0).." "..marker
 end
 M.cards.limbs:echo(html(heading("ENEMY LIMBS / OBSERVED STATE")..table.concat({rows[1].." &nbsp; | &nbsp; "..rows[2],rows[3].." &nbsp; | &nbsp; "..rows[4],rows[5].." &nbsp; | &nbsp; "..rows[6]},"<br>").."<br>Prone: "..(t.prone and "yes" or "no").." &nbsp; Parry: "..esc(t.parry_limb or "unknown")))
 M.cards.afflictions:echo(html(heading("AFFLICTIONS").."You: "..names(p.afflictions).."<br>Enemy: "..names(t.afflictions)))
 M.cards.cure:echo(html(heading("SERVER CURING")..(cure.enabled and "ON requested" or "not enabled here").." &nbsp; "..esc(cure.status or "Use CURING to toggle")))
 M.cards.events:echo(html(heading("LAST EVENT")..esc(state.last_event or "Waiting for in-game data")))
end
return M
