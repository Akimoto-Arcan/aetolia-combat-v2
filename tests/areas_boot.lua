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
function tempPromptTrigger(f)nextid=nextid+1;triggers[nextid]=f;return nextid end
function tempAlias(p,f)nextid=nextid+1;aliases[nextid]=f;return nextid end
function killAlias(id)aliases[id]=nil end
function tempTimer(delay,f)nextid=nextid+1;timers[nextid]={at=clock+delay,fn=f,alive=true};return nextid end
function killTimer(id)if timers[id]then timers[id].alive=false end end
dofile=function(p)
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

-- Actual core/addon multicast callbacks, native selector, existing walking and restock adapter.
local function setup()
 local s=fresh();local c=combat_v2;s.player.class='Monk';s.room.area='Tcanna Island';s.policy.area='tcanna island';s.policy.areas={['tcanna island']=true}
 gmcp.Room={Info={num=1,area=s.room.area,exits=graph[1]}}
 local old=#sent;matches={[2]='area select tcanna'};aliases[c.alias]();check(s.hunting.preset and s.hunting.preset.id=='tcanna','actual cv2 alias preset command');check(#sent==old and not s.walker.active,'select emitted query/movement')
 combat_v2_set_mode('BASH');check(s.walker.offer and not s.walker.active,'BASH auto-walked')
 check(combat_v2_walk_answer(s.walker.offer.token,true),'fresh consent')
 return c,s
end
local wolf={id=11,name='a gray wolf',attrib='m'};local python={id=12,name='a brown and tan python',attrib='m'}
local c,s=setup();items({wolf,python});check(s.target.name=='12'and #attacks()==1,'actual BASH did not consume python priority');check(moves()==0,'walked before killing')
local generation=s.target_generation;local wait=c.runner.waiting
items({wolf,{id=14,name=python.name,attrib='m'}})
check(s.target_generation==generation and c.runner.waiting==wait and #attacks()==1,'list preempted in-flight ACK')
check(not combat_v2_area_preset('off'),'preset switch erased in-flight action')
-- Release only fixture physical wait, not production; demonstrate recomputation after settlement.
c.runner.waiting=false;c.runner.transport_commit=nil;c.runner.transport_barrier=nil;c.runner.dispatching=nil
combat_v2_tick();check(s.hunting.ih.pending and s.target.name=='12','priority consumed unresolved replacement IH')
items({wolf,{id=14,name=python.name,attrib='m'}});check(s.target.name=='14','solicited replacement did not resolve new fresh ID')
-- A genuinely higher priority arrival must not change the in-flight target scope.
c,s=setup();items({wolf});check(s.target.name=='11'and #attacks()==1,'ordinary initial target')
local generation=s.target_generation
items({wolf,python});check(s.target.name=='11'and s.target_generation==generation and #attacks()==1,'python preempted attack ACK')
c.runner.waiting=false;c.runner.transport_commit=nil;c.runner.transport_barrier=nil
s.mental=s.mental or {};s.mental.eq_pending=clock
combat_v2_tick();check(s.target.name=='11','mental ACK bypassed by priority')
s.mental.eq_pending=nil;combat_v2_tick();check(s.target.name=='12','explicit threat not selected after settlement')
-- Unknown living NPCs never certify clear, even with an icon and no selected prey.
c,s=setup();items({{id=99,name='unlisted living NPC',icon='monster'}});check(moves()==0 and not s.walker.clear,'unknown NPC silently skipped')
-- Partial and duplicate records cannot fabricate an empty IH snapshot.
c,s=setup();items({{id=11,name=wolf.name,attrib='m'},{id=11,name=python.name,attrib='m'}});check(moves()==0 and #attacks()==0,'ambiguous duplicate list selected')
items({{id=12}});check(moves()==0 and #attacks()==0,'partial record selected')
-- Full empty response moves once; exact new room requires fresh occupancy and IH.
c,s=setup();empty();check(moves()==1 and s.walker.pending,'full empty did not move once')
gmcp.Room.Info={num=2,area='Tcanna Island',exits=graph[2]};handlers['gmcp.Room.Info']()
check(s.walker.arrival_hold and not s.hunting.area_snapshot,'arrival reused old priority data')
gmcp.Room.Players={};handlers['gmcp.Room.Players']();items({python,wolf});check(s.target.name=='12'and #attacks()==1 and moves()==1,'arrival failed to bash before next hop')
-- Re-stock uses the existing independent checkpoint adapter, never an old NPC ID.
c,s=setup();s.player.balance=false;empty();check(s.walker.active and s.walker.clear,'restock fixture clear')
local w=s.walker;local graph_identity,visited,steps=w.graph,w.visited,w.steps
local lease=c.restock_data;local cp,why=c.walker_boot.restock_suspend(c,lease)
check(cp and cp.was_active and not w.active,'native restock suspend '..tostring(why))
check(w.graph==graph_identity and w.visited==visited and w.steps==steps,'checkpoint changed route identities')
check(not combat_v2_globe('ON'),'suspended walk allowed GLOBE')
-- Existing restoration contract requires owned travel, exact return and fresh proof.
check(not c.walker_boot.restock_resume(c,cp,lease),'restock resumed without departure/return evidence')
check(c.walker_boot.restock_cancel(c,cp,lease,'fixture cancellation'),'checkpoint cancel')
check(not w.active and w.graph==graph_identity,'cancel restarted route')
-- Room multicast reaches both native ingestion and independent restock callbacks.
local listeners=0;for _,e in pairs(event_listeners)do if e[1]=='gmcp.Room.Info'then listeners=listeners+1 end end
check(listeners>=2,'actual bootstrap multicast lost addon listener')
-- Exact source ingestion is existing owned native line handler, not legacy triggers.
c,s=setup();receive('A gargantuan, nightmarish knight lets out a deafening howl, protectivecrimson shards forming upon his armor.')
check(s.hunting.encounter and s.hunting.encounter.role=='shard','native line ingestion missing encounter')
gmcp.Room.Info={num=1,area='Tcanna Island',exits=graph[1]};handlers['gmcp.Room.Info']()
check(s.hunting.encounter and s.hunting.encounter.role=='shard','unchanged Room.Info lost protective encounter')
items({python});check(#attacks()==0 and moves()==0,'unconfigured encounter attacked ordinary target')
gmcp.Room.Info={num=2,area='Tcanna Island',exits=graph[2]};handlers['gmcp.Room.Info']();check(not s.hunting.encounter,'encounter leaked to next room')
-- Native private configuration fences destinations and needs a new walking YES.
s=fresh();c=combat_v2;s.player.class='Monk'
check(combat_v2_area_configure('top-xaanhal',s.room.area,{['1']=true,['2']=true}),'private boundary configuration')
local preset=s.hunting.preset
combat_v2_set_mode('BASH');check(s.walker.offer and s.walker.offer.graph.room_count==2,'graph ignored private room allowlist')
check(not combat_v2_area_configure('tcanna',s.room.area),'configure while BASH must reject')
check(s.hunting.preset==preset,'rejected config mutated preset')
-- Installation/reload defaults remain OFF and no consent is manufactured.
s=fresh();c=combat_v2;check(c.mode=='OFF'and not s.walker.active and not s.hunting.preset,'startup not OFF')
-- A malformed newer FULL response revokes every older empty-list authority.
-- Exercise physical, mental and shared holds through the actual event callbacks.
local malformed={false,{[2]={id=99,name='unlisted living NPC',attrib='m'}},{{id=11,name='x'},{id=11,name='y'}},{{id=12}}}
for _,hold in ipairs({'physical','mental','shared'})do
 for _,bad in ipairs(malformed)do
  c,s=setup();s.mental=s.mental or {}
  local function held(value)
   if hold=='physical'then c.runner.transport_commit=value
   elseif hold=='mental'then s.mental.pending=value
   else c.elemental_recovery.committed=value end
  end
  held(true);items({});local scan=s.hunting.ih
  check(scan.responded and scan.pending,'fixture did not retain held empty response')
  items(bad);held(nil)
  check(not scan.responded and not scan.items and not scan.walker_version and not s.walker.clear and not s.walker.inspection and not s.hunting.verified_generation,'malformed FULL retained authority')
  receive('You can see the following 1 objects:');receive('There is nothing here.');receive('You can see the following 0 objects:')
  triggers[c.prompt_trigger]();combat_v2_tick()
  check(moves()==0 and scan.pending and scan.invalidated,'staged old header certified malformed FULL')
  check(not c.walker_boot.clear(c,scan),'direct clear accepted invalid certificate')
  check(not c.walker.mark_clear(s,s.room.item_version)and not s.walker.visited[tostring(s.room.id)],'real graph writer accepted invalid certificate')
  items({});triggers[c.prompt_trigger]()
  check(moves()==0,'unsolicited replacement revived poisoned request')
  advance(2);check(scan.pending and not scan.invalidated,'genuine retry not solicited')
  items({});check(moves()==0 and scan.pending,'recovery list moved before later prompt')
  triggers[c.prompt_trigger]();check(moves()==1,'fresh solicited complete empty plus later prompt failed recovery')
 end
end
-- Valid unknown NPCs (including icon-only and mounts) are never empty clearance.
for _,npc in ipairs({{id=99,name='unknown',attrib='m'},{id=99,name='unknown',icon='monster'},{id=99,name='mount',attrib='mM'}})do
 c,s=setup();items({npc});check(moves()==0 and not s.walker.clear,'living NPC certified empty')
end
c,s=setup();items({{id=99,name='player',attrib='pm'}});check(moves()==1,'player record was incorrectly treated as living NPC')
-- Quiet-watch and direct selectors cannot turn recovery evidence into authority.
c,s=setup();items(false);local original_scan=s.hunting.ih
s.hunting.watch={room_id=s.room.id};s.hunting.ih.active=false
items({python});check(not c.bashing.watch_select(s)and #attacks()==0,'quiet watch bypassed solicited recovery requirement')
check(not s.walker.clear and moves()==0,'quiet watch revived invalid clearance')
-- Every mutable entry point shares the same pure OFF/owner-settlement gate.
local function reject_all(label)
 local before=s.hunting.preset;local n=#sent
 check(not combat_v2_area_configure('tcanna',s.room.area),label..' private configure accepted')
 for _,cmd in ipairs({'select tcanna','off','pressure 2'})do check(not combat_v2_area_preset(cmd),label..' mutation accepted: '..cmd)end
 check(s.hunting.preset==before and #sent==n,label..' mutated identity or emitted command')
 check(combat_v2_area_preset('status')and combat_v2_area_preset('list'),label..' hid read-only controls')
end
for _,where in ipairs({'controller','runner','runner-root','shared-root'})do
 for _,field in ipairs({'transport_barrier','transportBarrier','transport_barriers','transportBarriers','transport_unknown','transportUnknown','transport_commit','transportCommit','action_dispatching','actionDispatching'})do
  s=fresh();c=combat_v2;c.root={};c.runner.root={}
  local owner=where=='controller'and c or where=='runner'and c.runner or where=='runner-root'and c.runner.root or c.root
  owner[field]={opaque='unresolved'};reject_all(where..' '..field)
  check(owner[field].opaque=='unresolved','gate cleared genuine barrier')
 end
end
for _,field in ipairs({'pending','intent','route','pumping','stopping','dispatching','fault','follow_pending','follow_fault','follow_due','recall_due','refresh_due','refresh_dispatching','haven_refresh'})do
 s=fresh();c=combat_v2;c.travel_owner=c.travel_owner or {};c.travel_owner[field]={opaque=true};reject_all('travel '..field)
end
for _,field in ipairs({'busy','reserved','owned_pause','owned_lease','lease','checkpoint','pending','purchase','query_quarantine','dispatching','route_owner','fault'})do
 s=fresh();c=combat_v2;c.restock_data[field]={opaque=true};reject_all('restock '..field)
end
for _,pair in ipairs({{'mental','eq_pending'},{'mental','fault'},{'buffs','pending'},{'buffs','dispatching'}})do
 s=fresh();c=combat_v2;s[pair[1]]=s[pair[1]]or {};s[pair[1]][pair[2]]={opaque=true};reject_all(pair[1]..' '..pair[2])
end
for _,pair in ipairs({{'elemental_recovery','pending'},{'elemental_recovery','committed'},{'containers_data','barrier'},{'tattoo_owner','txn'}})do
 s=fresh();c=combat_v2;c[pair[1]]=c[pair[1]]or {};c[pair[1]][pair[2]]={opaque=true};reject_all(pair[1]..' '..pair[2])
end
for _,field in ipairs({'active','offer','pending','dispatching','physical_dispatch','arrival_hold','restock_checkpoint','suspended'})do
 s=fresh();c=combat_v2;s.walker[field]={opaque=true};reject_all('walker '..field)
end
for _,where in ipairs({'controller','current','runner'})do
 s=fresh();c=combat_v2;local obj=where=='controller'and c or where=='current'and s or c.runner;obj.mode='BASH';reject_all('mode '..where)
end
s=fresh();c=combat_v2;c.restock_data.enabled=true;c.restock_data.active=true;c.restock_data.phase='monitor'
check(combat_v2_area_configure('tcanna',s.room.area),'idle OFF enabled monitor blocked configuration')
s=fresh();c=combat_v2;c.elemental_recovery.pool={query={readOnly=true}};reject_all('GLOBE read-only pool probe')
-- Mixed room metadata cannot reuse a solicited certificate from the old area.
c,s=setup();c.elemental_recovery.committed=true;items({});local scan=s.hunting.ih
gmcp.Room.Info={num=1,area='Other Area',exits=graph[1]};handlers['gmcp.Room.Info']()
c.elemental_recovery.committed=nil;receive('You can see the following 1 objects:');triggers[c.prompt_trigger]()
check(moves()==0 and not c.walker.mark_clear(s,s.room.item_version),'mixed room/area metadata certified old snapshot')
-- A retired GLOBE diagnostic and an unrelated timed-out container query stream
-- are not live resource ownership. Preserve both while configuring a fresh preset.
local function native_idle_shape()
 local state=fresh();local root=combat_v2;local g=root.elemental_recovery
 state.room.area='Tcanna Island';state.policy.area='tcanna island';state.policy.areas={['tcanna island']=true}
 -- Native profiles with convenience installed already publish this real module.
 root.travel_module=root.travel_module or realdofile(getMudletHomeDir()..'/combat_v2/travel.lua')
 g.armed=false;g.phase='idle';g.status='disarmed';g.fault='all carried globes exhausted';g.pending=nil;g.committed=nil;g.dispatching=nil
 g.pool={enabled=false,known=false,ever_owned=true,owned={},exhausted={},query=nil,dispatching=false}
 root.containers_data.quarantine='response timeout'
 return root,state,g
end
c,s,g=native_idle_shape();local q=g.pool;local co=c.containers_data;local before=#sent
check(combat_v2_area_settled(),'native retired-owner/passive-stream shape blocked')
check(combat_v2_area_configure('tcanna',s.room.area),'native shape could not configure')
check(combat_v2_area_preset('select tcanna'),'native shape could not select')
check(combat_v2_area_preset('off'),'native shape could not turn preset off')
check(g.fault=='all carried globes exhausted'and g.pool==q and not q.enabled and not q.known and not g.armed and co.quarantine=='response timeout','configuration rewrote resource diagnostics/authority')
check(#sent==before and #gmcp_sent==0 and c.mode=='OFF'and not s.walker.active,'native configuration emitted activity')
for _,field in ipairs({'pending','dispatching','committed','transport_unknown','transport_barrier','transport_commit','transport_barriers','transportBarriers'})do
 c,s,g=native_idle_shape();g[field]={unknown=true};reject_all('retired GLOBE '..field)
end
for _,field in ipairs({'query','dispatching','pending','fault'})do
 c,s,g=native_idle_shape();g.pool[field]={unknown=true};reject_all('retired pool '..field)
end
for _,field in ipairs({'pending','query','barrier','fault','action_dispatching','committed','transport_unknown','transport_barrier','transport_commit','transport_barriers','transportBarriers'})do
 c,s,g=native_idle_shape();c.containers_data[field]={unknown=true};reject_all('passive container stream with '..field)
end
for _,bad in ipairs({false,'wrong-type','throws','nonboolean'})do
 c,s,g=native_idle_shape()
 if bad==false then c.travel_module.terminal_globe_exhaustion=nil
 elseif bad=='wrong-type'then c.travel_module.terminal_globe_exhaustion={}
 elseif bad=='throws'then c.travel_module.terminal_globe_exhaustion=function()error('classifier unavailable')end
 else c.travel_module.terminal_globe_exhaustion=function()return 'true'end end
 reject_all('invalid terminal classifier '..tostring(bad))
end
c,s,g=native_idle_shape();g.pool.known=true;reject_all('inconsistent retired pool')
c,s,g=native_idle_shape();c.containers_data.quarantine='unproved transport';reject_all('unrecognized quarantine')
realprint('PASS actual-bootstrap area priorities, multicast, walker/restock barriers: '..count..' assertions')
