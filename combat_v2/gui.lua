-- Reusable combat dashboard: no command execution during layout or refresh.
local M={}
local C={card="#192735",text="#d7e5f2",muted="#91a5b8",accent="#78b8e8",good="#76d39b",warn="#e5c07b",bad="#ee8897"}
local function esc(v) return tostring(v or "none"):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
local function html(s) return "<div style='color:"..C.text..";font-family:DejaVu Sans;font-size:13px;'>"..s.."</div>" end
local function heading(s) return "<b style='color:"..C.accent..";'>"..s.."</b><br>" end
local function flag(v) return v==true or tonumber(v)==1 end
local function ready(v) return "<span style='color:"..(flag(v) and C.good or C.warn)..";'>"..(flag(v) and "READY" or "WAIT").."</span>" end
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
 card("header",60)
 local bw=(cw-24)/5
 for i,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do place(ui.buttons[m],10+(i-1)*(bw+6),y,bw,30) end
 y=y+38;local compact=rh<800;card("status",compact and 86 or 100);card("target",compact and 70 or 80);card("limbs",compact and 90 or 102)
 local affY=y;local affH=rh-affY-188;local aw=(cw-10)/2
 ui.per_page=math.max(1,math.floor((affH-88)/19));ui.aff_height=affH
 for i,k in ipairs({"player_afflictions","enemy_afflictions"}) do
  local x=10+(i-1)*(aw+10);place(ui.cards[k],x,affY,aw,affH)
  place(ui.buttons[k.."_prev"],x+8,affY+affH-33,34,25)
  place(ui.buttons[k.."_next"],x+aw-42,affY+affH-33,34,25)
 end
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
 M.layout();return ui.root
end
function M.refresh(state,runner,cure)
 if not M.cards then M.create() end
 local ui=combat_v2_ui;local p,t=state.player,state.target
 M.cards.header:echo(html("<b style='font-size:18px;color:"..C.accent..";'>COMBAT V2</b> &nbsp; MONK / "..esc(runner.mode).."<br><span style='color:"..C.muted..";'>t &lt;target&gt; &nbsp; · &nbsp; cv2 bash / auto / assist / off</span>"))
 for _,m in ipairs({"OFF","SHADOW","ASSIST","BASH","FULL_AUTO"}) do M.buttons[m]:setStyleSheet("background-color:"..(m==runner.mode and "#386386" or "#233c51")..";color:"..C.text..";border:1px solid #507590;padding:5px;") end
 M.cards.status:echo(html(heading("PLAYER STATUS")..string.format("HP %s / %s &nbsp; · &nbsp; Mana %s / %s<br>Balance %s &nbsp; Eq %s &nbsp; Arms %s / %s<br>Executor: %s",esc(p.hp),esc(p.maxhp),esc(p.mana),esc(p.maxmana),ready(p.balance),ready(p.equilibrium),ready(p.left_arm_balance),ready(p.right_arm_balance),esc(runner.status or "idle"))))
 local a=runner.pending or state.last_action or {}
 M.cards.target:echo(html(heading("TARGET / ACTION").."<b>"..esc(t.name).."</b> &nbsp; "..esc(a.command and a.command~="" and a.command or "WAIT").."<br><span style='color:"..C.muted..";'>"..esc(a.reason or "Set a target, then select BASH or AUTO").."</span>"))
 local rows={}
 for _,k in ipairs({"left_arm","right_arm","left_leg","right_leg","torso","head"}) do
  local marker=t.mangled[k] and "MANGLED" or t.broken[k] and "BROKEN" or t.crippled[k] and "CRIPPLED" or ""
  local evidence=t.evidence and t.evidence["limb:"..k];local prefix=evidence and (evidence.confidence or 1)<1 and "~" or ""
  rows[#rows+1]=esc(k:gsub("_"," ")).." "..prefix..string.format("%.1f%%",tonumber(t.limbs[k]) or 0).." "..marker
 end
 M.cards.limbs:echo(html(heading("ENEMY LIMBS / OBSERVED STATE")..table.concat({rows[1].." &nbsp; | &nbsp; "..rows[2],rows[3].." &nbsp; | &nbsp; "..rows[4],rows[5].." &nbsp; | &nbsp; "..rows[6]},"<br>").."<br>Prone: "..(t.prone and "yes" or "no").." &nbsp; Parry: "..esc(t.parry_limb or "unknown")))
 affpanel(ui,"player_afflictions",p.afflictions,"YOUR AFFLICTIONS","GMCP observed",C.warn)
 affpanel(ui,"enemy_afflictions",t.afflictions,"ENEMY AFFLICTIONS","tracked / inferred",C.bad)
 M.cards.cure:echo(html(heading("SERVER FIRSTAID")..(cure.enabled and "ON requested" or "not enabled here").." &nbsp; "..esc(cure.status or "Use CURING to toggle")))
 M.cards.events:echo(html(heading("LAST EVENT")..esc(state.last_event or "Waiting for in-game data")))
end
return M
