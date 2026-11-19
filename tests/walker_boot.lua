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
local graph={ [1]={n=2,e=3},[2]={s=1,n=4},[3]={w=1},[4]={s=2} }
function getRoomArea(id)return graph[id]and 7 or -1 end
function getAreaRooms()return {[0]=1,[11]=2,[39]=3,[78]=4}end
function getRoomExits(id)return graph[id]end
function roomLocked()return false end
function getRoomWeight()return 1 end
function getDoors()return {}end
local function moves()local n=0;for _,v in ipairs(sent)do if ({n=true,s=true,e=true,w=true})[v.command]then n=n+1 end end;return n end
local function start()
 local state=fresh('rat');gmcp.Room={Info={num=1,area='Fixture Hunt',exits={n=2,e=3}}}
 combat_v2_set_mode('BASH');local c=combat_v2
 check(state.walker.offer and not state.walker.active,'activation must offer, not move')
 check(combat_v2_walk_answer(state.walker.offer.token,true),'fresh Yes rejected')
 return c,state
end
local function empty()items({})end
local function arrival(id,players)
 gmcp.Room.Info={num=id,area='Fixture Hunt',exits=graph[id]};handlers['gmcp.Room.Info']()
 if players~=false then gmcp.Room.Players={};handlers['gmcp.Room.Players']()end
end
local c,state=start();advance(60)
check(moves()==0 and state.hunting.watch and #ihs()==3,'unanswered IH moved or repolled')
c,state=start();empty();check(moves()==1 and state.walker.pending.to=='2','confirmed empty did not move exactly once')
combat_v2_tick();check(moves()==1,'duplicate pending hop')
for _,mode in ipairs({'BASH','FULL_AUTO','ASSIST','SHADOW'})do
 combat_v2_set_mode(mode);combat_v2_tick();combat_v2_approve()
 check(moves()==1 and #attacks()==0 and state.walker.pending,'mode bypassed pending hop')
end
check(not combat_v2_walk('on')and not combat_v2_walk('yes'),'pending allowed offer/Yes')
check(not combat_v2_set_target('rat')and not state.walker.active,'manual target retained consent')
local generation=state.target_generation;matches={[2]='queue next'};aliases[c.alias]()
check(state.target_generation==generation and state.walker.pending,'real queue-next retargeted unresolved room')
combat_v2_stop();check(state.walker.pending and c.mode=='OFF','Stop erased hop')
arrival(2);check(not state.walker.pending and state.walker.arrival_hold and not state.walker.active,'OFF arrival failed evidence barrier')
combat_v2_set_mode('BASH');empty();check(not state.walker.arrival_hold and moves()==1,'fresh players + IH failed to settle')
c,state=start();empty();arrival(2,false)
check(state.walker.arrival_hold and moves()==1 and #attacks()==0,'arrival reused old room evidence')
items({{id=123,name='a rat',attrib='m'}});check(#attacks()==0,'unknown players permitted offense')
gmcp.Room.Players={};handlers['gmcp.Room.Players']();items({{id=123,name='a rat',attrib='m'}})
check(not state.walker.arrival_hold and #attacks()==1 and moves()==1,'arrival NPC did not interrupt walking')
check(attacks()[1].command=='combo 123 spk ucp ucp','production recipe changed')
for _,hold in ipairs({'waiting','balance','equilibrium','left_arm_balance','right_arm_balance','hp','prone','paralysis','players','mental','containers','globe','travel'})do
 c,state=start()
 if hold=='waiting'then c.runner.waiting=true
 elseif hold=='hp'then state.player.hp=20
 elseif hold=='prone'then state.player.prone=true
 elseif hold=='paralysis'then state.player.afflictions.paralysis=true
 elseif hold=='players'then state.policy.players_known=false
 elseif hold=='mental'then state.mental={eq_pending=clock}
 elseif hold=='containers'then c.containers_data.action_dispatching=true
 elseif hold=='globe'then c.elemental_recovery={committed=true}
 elseif hold=='travel'then c.travel_owner={pending={}};c.convenience={busy=function()return true end,hold=function()return true end,service_policy=function()return 'settle'end}
 else state.player[hold]=false end
 empty();combat_v2_tick();check(moves()==0,'movement bypassed '..hold)
end
c,state=start();state.player.balance=false;empty();check(state.walker.clear,'fixture lacks clearance')
gmcp.Char.Items.Update={location='room',item={id=199,name='unknown'}};handlers['gmcp.Char.Items.Update']()
state.player.balance=true;combat_v2_tick();check(moves()==0 and not state.walker.clear,'partial update retained clearance')
c,state=start();receive('There is nothing here.');check(moves()==0,'text-only empty invented clearance')
c,state=start();gmcp.Room.Info.exits.n=999;empty();check(moves()==0 and not state.walker.active,'exit mismatch moved')
c,state=start();local seq={};for i=1,10 do empty();if state.walker.pending then local to=tonumber(state.walker.pending.to);seq[#seq+1]=to;arrival(to)else break end end
check(table.concat(seq,',')=='2,4,2,1,3'and not state.walker.active and state.walker.status=='complete','finite pass failed: '..table.concat(seq,','))
local before=moves();advance(30);check(moves()==before,'completed walker restarted')
c,state=start();empty();clock=clock+6;combat_v2_tick();check(state.walker.pending and state.walker.fault and not state.walker.active,'timeout erased direction')
arrival(3);check(state.walker.pending and moves()==1,'wrong arrival released hop')
arrival(2);check(not state.walker.pending and not state.walker.active and state.walker.arrival_hold,'late arrival restarted')
c,state=start();empty();c.runner.mode='ASSIST';state.mode='ASSIST';c.runner.pending={command='combo 123 spk ucp ucp',generation=state.target_generation}
check(not c.runner_module.approve(c.runner)and #attacks()==0,'direct ASSIST bypass')
state.mode='FULL_AUTO';state.target.name='Victim';state.policy.players={victim=true};local mental=c.mental.state(state);mental.enabled=true;mental.status='idle';mental.retry_at=0
local old=#sent;c.mental.tick(state,send,false);check(#sent==old,'direct mental bypass')
for _,result in ipairs({'success','false','throw'})do
 c,state=start();local calls=0;c.walk_sender=function(cmd)
  calls=calls+1;arrival(2);combat_v2_stop();combat_v2_walk('on');combat_v2_set_mode('BASH');combat_v2_tick()
  if result=='false'then return false elseif result=='throw'then error('unknown')end
 end
 empty();check(calls==1 and not state.walker.dispatching,'nested duplicate direction')
 if result~='success'then check(state.walker.pending and state.walker.fault,'transport failure erased commit')end
end
state=fresh('rat');c=combat_v2;c.elemental_recovery={armed=true};gmcp.Room={Info={num=1,area='Fixture Hunt',exits=graph[1]}}
combat_v2_set_mode('BASH');check(not state.walker.offer and c.elemental_recovery.armed,'GLOBE ON offered or disarmed')
c,state=start();check(not combat_v2_globe('on')and state.walker.active,'GLOBE ON stole consent')
check(not combat_v2_globe('ON')and not combat_v2_globe('oN')and state.walker.active,'case-normalized global GLOBE bypass')
c.elemental_recovery={armed=true};state.walker.active=false;state.walker.offer=nil
check(not combat_v2_walk('ON')and not combat_v2_walk('oN')and c.elemental_recovery.armed,'case-normalized WALK bypass')
c,state=start();local token=state.walker.offers;empty();local pending=state.walker.pending
realdofile(root..'bootstrap.lua');c=combat_v2;check(c.mode=='OFF'and state.walker.pending==pending and not state.walker.active,'reload lost hop')
check(not combat_v2_walk_answer(token,true),'pre-reload Yes accepted')
state.buffs.fault='keep';combat_v2_reset_wait();check(c.mode=='OFF'and not state.walker.pending and state.walker.arrival_hold and state.room.id==nil and state.buffs.fault=='keep','reset cleared resources / cached location')
-- A real kill chain retains consent but never clears the genuine attack wait.
c,state=start();items({{id=123,name='a rat',attrib='m'}});check(#attacks()==1 and c.runner.waiting,'kill fixture did not attack')
receive('You have slain a rat.');empty();check(state.walker.active and moves()==0 and c.runner.waiting,'kill erased consent or physical wait')
receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.');combat_v2_tick()
check(moves()==1,'kill + IH + real recovery did not advance')
-- Disconnect cannot retain consent, including when no direction has been sent.
c,state=start();handlers['sysDisconnectionEvent']();check(not state.walker.active and not state.walker.offer,'disconnect retained consent')
state.connected=true;combat_v2_tick();check(moves()==0 and not state.walker.active,'reconnect restarted walking')
c,state=start();empty();local saved=state.walker.pending;handlers['sysDisconnectionEvent']();check(state.walker.pending==saved and not state.walker.active,'disconnect discarded hop')
-- Cached same-room metadata, partial Room.Info and partial items cannot settle a hop.
gmcp.Room.Info={num=1,area='Fixture Hunt',exits=graph[1]};handlers['gmcp.Room.Info']();check(state.walker.pending==saved,'cached origin acknowledged movement')
gmcp.Room.Info={area='Fixture Hunt'};handlers['gmcp.Room.Info']();check(state.walker.pending==saved,'partial Room.Info acknowledged movement')
-- Even genuine synchronous physical recovery cannot overlap a walker direction.
c,state=start();local observed=false;c.runner.sender=function(command)
 observed=state.walker.physical_dispatch~=nil
 receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.')
 combat_v2_stop();check(not combat_v2_reset_wait(),'nested reviewed reset erased physical dispatch')
 check(not combat_v2_set_mode('BASH')and not combat_v2_walk('on'),'nested physical transport allowed walking intent')
 combat_v2_tick();check(moves()==0,'walker overlapped physical sender')
end
items({{id=123,name='a rat',attrib='m'}});check(observed and not state.walker.physical_dispatch,'physical dispatch scope missing or stranded')
-- Trusted stand-in drives the real core mode/Room.Info/IH callbacks, not fake walker APIs.
c,state=start();state.player.class='Monk';c.buff_class_seen='Monk';gmcp.Char=gmcp.Char or {};gmcp.Char.Status={class='Monk'};c.restock_data={enabled=false,reserved=true}
c.restock_module={owns_transition=function(owner)return owner.restock_data.dispatching==true end,movement_borrowed=function(owner)return owner.restock_data.borrowed==true end,movement_reserved=function(owner)return owner.restock_data.reserved==true end}
empty();check(moves()==0 and state.walker.clear,'reservation should keep current clear room without moving')
local checkpoint=assert(c.walker_boot.restock_suspend(c,c.restock_data));local savedgraph,savedvisited=state.walker.graph,state.walker.visited
state.player.mounted=false
c.restock_data.dispatching=true;combat_v2_set_mode('OFF');c.restock_data.dispatching=false
check(not checkpoint.cancelled and not state.walker.active,'core owned OFF cancelled consent')
-- Unchanged/partial GMCP passes through canonical policy ingestion as in Mudlet.
gmcp.Room.Info={num=1,area='Fixture Hunt',exits=graph[1]};handlers['gmcp.Room.Info']()
check(not checkpoint.cancelled and not checkpoint.return_sequence,'same-room prep metadata cancelled checkpoint or forged return')
gmcp.Room.Info={name='partial LOOK metadata'};handlers['gmcp.Room.Info']()
check(not checkpoint.cancelled and not state.walker.inspection and not checkpoint.return_sequence,'partial prep metadata proved location or cancelled checkpoint')
c.restock_data.borrowed=true;gmcp.Room.Info={num=88,area='Fixture Shop',exits={}};handlers['gmcp.Room.Info']()
check(state.room.id==88 and state.room.area=='Fixture Shop'and not checkpoint.cancelled,'borrowed room event must ingest actual shop without cancellation')
c.restock_data.borrowed=false;gmcp.Room.Info={num=88,area='Fixture Shop',exits={}};handlers['gmcp.Room.Info']()
check(not checkpoint.cancelled and not checkpoint.return_sequence,'settled shop metadata cancelled checkpoint or forged return')
c.restock_data.borrowed=true;arrival(1);c.restock_data.borrowed=false
check(not c.walker_boot.restock_resume(c,checkpoint,c.restock_data),'return cache cannot restore checkpoint')
gmcp.Room.Info={num=1,area='Fixture Hunt',exits=graph[1]};handlers['gmcp.Room.Info']()
check(not checkpoint.cancelled and not state.walker.inspection,'settled return LOOK must retain checkpoint but require fresh IH')
c.restock_data.dispatching=true;combat_v2_set_mode('BASH');c.restock_data.dispatching=false
check(not state.walker.offer and not state.walker.active and not checkpoint.cancelled,'owned BASH made popup or reset plan')
empty();check(c.walker_boot.restock_resume(c,checkpoint,c.restock_data),'actual post-return IH did not release valid checkpoint')
check(state.walker.graph==savedgraph and state.walker.visited==savedvisited and not state.walker.clear,'actual callbacks reset route or reused old clearance')
check(not c.walker_boot.restock_resume(c,checkpoint,c.restock_data),'actual callback checkpoint replay')
-- An ordinary manual OFF after the owned OFF is a permanent cancellation.
c,state=start();state.player.class='Monk';c.buff_class_seen='Monk';gmcp.Char=gmcp.Char or {};gmcp.Char.Status={class='Monk'};c.restock_data={reserved=true}
c.restock_module={movement_reserved=function()return true end,owns_transition=function(owner)return owner.restock_data.dispatching==true end}
empty();checkpoint=assert(c.walker_boot.restock_suspend(c,c.restock_data));c.restock_data.dispatching=true;combat_v2_set_mode('OFF');c.restock_data.dispatching=false
combat_v2_set_mode('OFF');check(checkpoint.cancelled and not c.walker_boot.restock_resume(c,checkpoint,c.restock_data),'manual unchanged OFF did not revoke checkpoint')
print=realprint;print('PASS walker actual-bootstrap '..count..' assertions; fake-world only')
