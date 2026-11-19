-- Deterministic fake-clock tests of the actual IH scheduler and Mudlet callbacks.
local root=assert(arg[1]);local realdofile=dofile;local realprint=print;print=function()end
local clock,handlers,triggers,aliases,timers,sent,nextid,gmcp_sent,room_refresh,auto_room_items
function sendGMCP(msg)gmcp_sent[#gmcp_sent+1]=msg;room_refresh=true end
function getEpoch()return clock end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,true end
function send(cmd)
 sent[#sent+1]={command=cmd,time=clock}
 -- Aetolia queues the explicit GMCP refresh until a command produces a prompt.
 -- Plain IH in an unchanged room emits no new item-list event in this fixture.
 if cmd=='ih' and room_refresh and auto_room_items then
  room_refresh=false;gmcp.Char={Items={List={location='room',items=auto_room_items}}}
  handlers['gmcp.Char.Items.List']()
 end
end
local event_listeners,event_serial,event_handler_table={},0,nil
function registerAnonymousEventHandler(event,fn)
 if event_handler_table~=handlers then event_listeners={};event_handler_table=handlers end
 event_serial=event_serial+1;local id=event_serial;event_listeners[id]={event,fn}
 handlers[event]=function(...)
  local ids={};for k,v in pairs(event_listeners)do if v[1]==event then ids[#ids+1]=k end end;table.sort(ids)
  for _,k in ipairs(ids)do local item=event_listeners[k];if item then item[2](...)end end
 end
 return id
end
function killAnonymousEventHandler(id)
 local item=event_listeners[id];event_listeners[id]=nil
 if item then local any=false;for _,v in pairs(event_listeners)do if v[1]==item[1]then any=true end end;if not any then handlers[item[1]]=nil end end
end
function tempRegexTrigger(p,f)nextid=nextid+1;triggers[nextid]=f;return nextid end
function killTrigger(id)triggers[id]=nil end
function tempAlias(p,f)nextid=nextid+1;aliases[nextid]=f;return nextid end
function killAlias(id)aliases[id]=nil end
function tempTimer(delay,f)nextid=nextid+1;timers[nextid]={at=clock+delay,fn=f,alive=true};return nextid end
function killTimer(id)if timers[id]then timers[id].alive=false end end
dofile=function(p)
 if p:match('/restock.lua$')then return {}end
 if p:match('/restock_boot.lua$')then return {attach=function(c)c.restock_data={enabled=false};combat_v2_restock=function()return true end end}end
 if p:match('/gui.lua$')then return {create=function()end,refresh=function()end}end;return realdofile(p)
end
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local function fresh(target)
 combat_v2=nil;gmcp={};clock=100;handlers={};triggers={};aliases={};timers={};sent={};nextid=0;gmcp_sent={};room_refresh=false;auto_room_items=nil
 realdofile(root..'bootstrap.lua')
 local s=combat_v2.current;s.room.id=1;s.room.area='Fixture Hunt'
 s.policy.area='fixture hunt';s.policy.areas={['fixture hunt']=true};s.policy.areas_loaded=true;s.policy.players={};s.policy.players_known=true;s.policy.players_room=1;s.policy.self_name='self'
 combat_v2.state.sync_gmcp(s,{Char={Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1}}});s.player.stance='scorpion'
 if target then combat_v2_set_target(target)end
 return s
end
local function advance(seconds)
 local goal=clock+seconds
 while true do
  local pick,at
  for id,t in pairs(timers)do if t.alive and t.at<=goal and (not at or t.at<at or t.at==at and id<pick)then pick,at=id,t.at end end
  if not pick then break end
  clock=at;local timer=timers[pick];timer.alive=false;timer.fn()
 end
 clock=goal
end
local function receive(text)line=text;triggers[combat_v2.line_trigger]();line=nil end
local function items(list,location)
 gmcp.Char=gmcp.Char or {};gmcp.Char.Items={List={location=location or 'room',items=list}}
 handlers['gmcp.Char.Items.List']()
end
local function ihs()local out={};for _,entry in ipairs(sent)do if entry.command=='ih'then out[#out+1]=entry end end;return out end
local function attacks()local out={};for _,entry in ipairs(sent)do if entry.command:match('^combo ') or entry.command:match('^sck ') then out[#out+1]=entry end end;return out end

local state=fresh('rat');local c=combat_v2;c.mode='BASH';c.runner.mode='BASH';state.mode='BASH'
c.runner.waiting=true;c.runner.recovery_snapshot={balance=10};c.runner.last_send=100;c.runner.waiting_requires={balance=true}
state.hunting.ih={active=true,pending=true,room_id=1,start_version=0};local ih=state.hunting.ih
state.mental={status='acquiring'};local mental=state.mental
c.elemental_recovery.armed=true;c.elemental_recovery.room=1
local runner,wait,snapshot,target,generation=c.runner,c.runner.waiting,c.runner.recovery_snapshot,state.target,state.target_generation
-- Model the actual previously installed GLOBE-scope guard without arming old duty.
local oldstops=0;c.lunch_module={user_stop=function()oldstops=oldstops+1 end};c.lunch_duty={active=false,busy=false,phase='idle'}
local oldboot=realdofile(root..'lunch_boot.lua');check(oldboot.bind(c),'old production guard fixture failed')
local oldguard=c.lunch_globe_guard
local buffFault,pipeBarrier={},{};state.buffs.fault=buffFault;c.containers_data=c.containers_data or {};c.containers_data.barrier=pipeBarrier
local xpbinds=0;local xpguard={enabled=true,triggered=false,module={bind=function(owner)check(owner==c,'XP guard rebound to wrong root');xpbinds=xpbinds+1 end}};c.xp_globe_cutoff=xpguard
local curing=c.cure;local before=#sent;local mod=realdofile(root..'walker_boot.lua');check(mod.attach(c))
check(c.xp_globe_cutoff==xpguard and xpbinds==1 and not xpguard.triggered,'hot attach lost/replayed temporary XP cutoff')
check(oldstops==0 and c.lunch_globe_guard==oldguard and c.restock_data.enabled==false,'hot attach called old scope guard or enabled RESTOCK')
check(state.buffs.fault==buffFault and c.containers_data.barrier==pipeBarrier and c.cure==curing,'hot attach cleared upkeep/pipes or replaced native curing')
check(#sent==before and c.mode=='BASH'and c.runner==runner and runner.waiting==wait and runner.recovery_snapshot==snapshot,'hot attach mutated runner or sent')
check(state.hunting.ih==ih and state.mental==mental and state.target==target and state.target_generation==generation,'hot attach replaced canonical scopes')
check(c.elemental_recovery.armed and c.elemental_recovery.room==1 and not state.walker.active and not state.walker.offer,'hot attach altered GLOBE or offered movement')
-- Published pending/dispatch/arrival guards operate below bootstrap and modes.
local R=arg[2]and realdofile(arg[2])or c.runner_module
R.bind_policy(function()return true end);R.bind_defense(function()return false end)
local S=c.state.new();S.connected=true;S.mode='ASSIST';S.player.hp=100;S.player.maxhp=100;S.player.mounted=false;S.target.name='123'
for _,key in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do S.player[key]=true end
local r=R.new(S,{choose=function()return {command='combo 123 spk ucp ucp'}end});r.mode='ASSIST';local escaped=0;r.sender=function()escaped=escaped+1 end
for _,key in ipairs({'pending','dispatching','arrival_hold'})do
 S.walker={[key]={}};r.pending={command='combo 123 spk ucp ucp',generation=S.target_generation};local ok,why=R.approve(r)
 check(not ok and escaped==0 and tostring(why):find('WALK',1,true),'WALK_GUARD_BYPASS: direct ASSIST '..key)
end
-- Native cures remain a separate public owner and are not disabled by walking.
check(c.cure.enabled==false,'fixture curing default changed')
-- Popup reuse, valid No, stale Yes, escaping and captured-token callbacks.
local objects={};Geyser={};local function new(self,o,parent)
 local obj={name=o.name,x=o.x,y=o.y,width=o.width,height=o.height,parent=parent}
 function obj:setStyleSheet(v)self.style=v end;function obj:move(x,y)self.x=x;self.y=y end
 function obj:resize(w,h)self.width=w;self.height=h end
 function obj:echo(v)self.text=v end;function obj:setClickCallback(v)self.callback=v end
 function obj:hide()self.hidden=true end;function obj:show()self.hidden=false end;function obj:raise()end
 objects[#objects+1]=obj;return obj
end
Geyser.Container={new=new};Geyser.Label={new=new};function getMainWindowSize()return 800,600 end
combat_v2_ui={};local gui=realdofile(root..'gui.lua');local answers={}
combat_v2_walk_answer=function(token,yes)answers[#answers+1]={token,yes};gui.hide_walk_prompt();return true end
gui.show_walk_prompt('<Area & Test>',4,1);local popup=combat_v2_ui.walk_popup;local stale=popup.yes.callback;local total=#objects
check(popup.root.x>=0 and popup.root.y>=0 and popup.root.x+popup.root.width<=800 and popup.root.y+popup.root.height<=600,'popup viewport')
check(popup.label.text:find('&lt;Area &amp; Test&gt;',1,true),'popup label injection')
gui.show_walk_prompt('next',4,2);check(#objects==total and combat_v2_ui.walk_popup==popup,'popup leaked widgets')
popup.no.callback();check(answers[#answers][1]==2 and answers[#answers][2]==false and popup.root.hidden,'No token or hidden state')
stale();check(answers[#answers][1]==1,'old callback silently approved new token')
-- The retained native shell gets an independent bounded RESTOCK control.
function getMainWindowSize()return 1100,900 end
function setBorderRight()end
combat_v2_ui=nil;c.gui=gui;gui.create()
c.restock_data={enabled=false};c.restock_module={busy=function()return false end}
local actions={};combat_v2_restock=function(action)actions[#actions+1]=action;c.restock_data.enabled=action=='on';return true end
gui.refresh(c.current,c.runner,c.cure);local button=combat_v2_ui.buttons.restock
check(button.text:find('RESTOCK OFF',1,true),'RESTOCK startup label not OFF')
local n=#objects;local shell=combat_v2_ui.root;gui.create();check(#objects==n and combat_v2_ui.root==shell,'RESTOCK shell reload leaked widgets')
button.callback();check(actions[1]=='on'and button.text:find('RESTOCK ON',1,true),'RESTOCK ON callback or rendering')
button.callback();check(actions[2]=='off'and button.text:find('RESTOCK OFF',1,true),'RESTOCK OFF callback or rendering')
c.restock_module.busy=function()return true end;gui.refresh(c.current,c.runner,c.cure);check(button.text:find('OFF *',1,true),'disabled unresolved RESTOCK must still show busy')
local footer={'approve','curing','globe','restock','stop'};local edge=0
for _,key in ipairs(footer)do local b=combat_v2_ui.buttons[key];check(b.x>=edge and b.x+b.width<=combat_v2_ui.width and b.y+b.height<=combat_v2_ui.height,'RESTOCK footer bounds/overlap '..key);edge=b.x+b.width end
print=realprint;print('PASS walker handler-only binding / low-level guards / popup '..count..' assertions')
