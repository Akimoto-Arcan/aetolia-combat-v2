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
function registerAnonymousEventHandler(e,f)handlers[e]=f;return e end
function killAnonymousEventHandler(e)handlers[e]=nil end
function tempRegexTrigger(p,f)nextid=nextid+1;triggers[nextid]=f;return nextid end
function killTrigger(id)triggers[id]=nil end
function tempAlias(p,f)nextid=nextid+1;aliases[nextid]=f;return nextid end
function killAlias(id)aliases[id]=nil end
function tempTimer(delay,f)nextid=nextid+1;timers[nextid]={at=clock+delay,fn=f,alive=true};return nextid end
function killTimer(id)if timers[id]then timers[id].alive=false end end
dofile=function(p)if p:match('/gui.lua$')then return {create=function()end,refresh=function()end}end;return realdofile(p)end
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
local s=fresh('rat');combat_v2_set_mode('BASH')
check(#ihs()==1 and #attacks()==0,'BASH must check IH before attacking')
receive('There is nothing here.');check(combat_v2.mode=='BASH','first miss halted early')
advance(1.9);check(#ihs()==1,'IH repeated before two seconds');advance(.1)
check(#ihs()==2 and ihs()[2].time==102,'second IH not at two seconds')
receive('There is nothing here.');check(combat_v2.mode=='BASH','second miss halted early');advance(2)
check(#ihs()==3 and ihs()[3].time==104,'third IH not at four seconds')
receive('There is nothing here.');check(combat_v2.mode=='BASH' and #attacks()==0,'third miss disabled persistent BASH')
advance(10);check(#ihs()==3 and combat_v2.mode=='BASH' and s.hunting.watch and not combat_v2.ih_timer,'third miss did not enter quiet GMCP watch')
s=fresh('rat');combat_v2_set_mode('BASH');receive('There is nothing here.');advance(2)
items({{id=123,name='a rat',attrib='m'}})
check(s.target.name=='123' and s.target.display_name=='a rat','IH did not resolve target to exact NPC ID')
check(#ihs()==2 and #attacks()==1,'target found on second IH did not resume once')
check(attacks()[1].command=='combo 123 spk spp spp','resumed attack did not use confirmed NPC ID')
advance(2);check(#ihs()==2 and #attacks()==1,'found target left retry timer active or duplicated attack')
s=fresh('rat');s.room.items['123']={name='a rat',attrib='m'};combat_v2_set_mode('BASH');combat_v2_ih_result()
check(#attacks()==0,'cached room list bypassed fresh IH')
receive('You can see the following 1 objects:');check(#attacks()==0,'IH header alone bypassed fresh GMCP')
items({{id=123,name='a rat',attrib='m'}},'inv');check(#attacks()==0,'inventory list was treated as room IH')
items({{id=123,name='a rat',attrib='m'}});check(#attacks()==1,'fresh room IH did not unlock attack')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a rat',attrib=''}})
check(#attacks()==0,'non-monster item selected')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a pirate',attrib='m'}})
check(#attacks()==0,'rat substring incorrectly matched pirate')
s=fresh('rat');combat_v2_set_mode('BASH');advance(6)
check(#ihs()==3 and combat_v2.mode=='BASH' and #attacks()==0 and s.hunting.watch,'unanswered IH did not cap at three and enter GMCP watch')
check(ihs()[1].time==100 and ihs()[2].time==102 and ihs()[3].time==104,'IH timeout requests not spaced exactly two seconds')
s=fresh('rat');combat_v2_set_mode('BASH');local stale=timers[combat_v2.ih_timer].fn;combat_v2_stop();advance(10);stale()
check(#ihs()==1 and combat_v2.mode=='OFF','manual STOP did not cancel retry')
items({{id=123,name='a rat',attrib='m'}});check(#attacks()==0,'late positive IH restarted a stopped executor')
s=fresh('rat');combat_v2_set_mode('BASH');local old=timers[combat_v2.ih_timer].fn;combat_v2_stop();combat_v2_set_mode('BASH');local current_timer=combat_v2.ih_timer;old()
check(combat_v2.ih_timer==current_timer and #ihs()==2,'stale callback clobbered the new scan')
s=fresh('rat');combat_v2_set_mode('BASH');combat_v2_set_mode('SHADOW');advance(6)
check(#ihs()==1 and #attacks()==0,'switching to SHADOW did not cancel IH')
s=fresh('rat');combat_v2_set_mode('BASH');handlers['sysDisconnectionEvent']();advance(6)
check(combat_v2.mode=='BASH' and #ihs()==1,'disconnect did not pause IH while retaining BASH')
s=fresh('rat');combat_v2_set_mode('BASH');gmcp.Room={Info={num=2}};handlers['gmcp.Room.Info']();advance(6)
check(combat_v2.mode=='BASH' and #ihs()==1,'room change did not pause old-room IH while retaining BASH')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a rat',attrib='m'}});receive("You can find no such target as '123'.")
check(#ihs()==2 and #attacks()==1 and s.hunting.ih.active,'missing target response did not start IH recovery')
items({});advance(2);items({});advance(2);items({})
check(combat_v2.mode=='BASH' and #ihs()==4 and #attacks()==1,'missing-target recovery disabled persistent BASH')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a rat',attrib='m'}});combat_v2.bashing.item_removed(s,{location='room',item=123});combat_v2_tick()
check(s.hunting.ih.active and #ihs()==2,'room removal did not start IH recovery')
s=fresh('rat');combat_v2_set_mode('BASH');receive('You can see the following 0 objects:');check(s.hunting.ih.active and not s.hunting.ih.pending and #attacks()==0,'zero-object IH header not handled as a failed check')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a rat',attrib='m'}});items({})
check(s.hunting.ih.active and #ihs()==2,'fresh room list missing current target did not initiate IH recovery')
s=fresh();combat_v2.bashing.add(s,'123');combat_v2.bashing.add(s,'456');combat_v2_set_mode('BASH');items({{id=456,name='a queued beast',attrib='m'}})
check(s.target.name=='456' and #attacks()==1,'IH did not find an explicitly queued alternative')
s=fresh();combat_v2_set_mode('BASH');items({{id=777,name='a neutral person',attrib='m'}})
check(#attacks()==0,'no selected/queued target must not attack an arbitrary NPC')
s=fresh('rat');combat_v2_set_mode('PVP');check(#ihs()==0,'PvP incorrectly issued NPC IH')
s=fresh('rat');combat_v2_set_mode('BASH');realdofile(root..'bootstrap.lua');advance(6)
check(combat_v2.mode=='OFF' and #ihs()==1,'reload left IH timer running')
s=fresh('spider');auto_room_items={{id=1001,name='a medium pulsating spider',attrib='m'},{id=1002,name='a medium pulsating spider',attrib='m'},{id=1003,name='a medium pulsating spider',attrib='m'}}
combat_v2_set_mode('BASH')
check(#gmcp_sent==1 and gmcp_sent[1]=='Char.Items.Room ""','IH did not explicitly request fresh room data before its prompt')
check(s.target.name=='1001' and #attacks()==1,'three unchanged spiders were not acquired and attacked through fresh GMCP')
check(not s.hunting.ih.active and combat_v2.ih_timer==nil,'synchronous refreshed response left a scan timer alive')
-- Continue the selected NPC type after each confirmed kill; never hunt x/d flags.
s=fresh('spider');auto_room_items={{id=1001,name='a medium pulsating spider',attrib='m'},{id=1002,name='a medium pulsating spider',attrib='m'},{id=1003,name='a medium pulsating spider',attrib='m'},{id=999,name='a medium pulsating spider',attrib='mx'}}
combat_v2_set_mode('BASH')
check(s.target.name=='1001','protected matching NPC was selected before a legal spider')
auto_room_items={{id=1001,name='a medium pulsating spider',attrib='md'},{id=1002,name='a medium pulsating spider',attrib='m'},{id=1003,name='a medium pulsating spider',attrib='m'},{id=999,name='a medium pulsating spider',attrib='mx'}}
receive('You have slain a medium pulsating spider.')
check(s.target.name=='1002' and s.hunting.kills==1,'first kill forgot selected NPC type instead of selecting next spider')
check(#attacks()==1,'target switch bypassed previous attack recovery')
receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.');advance(.4)
check(#attacks()==2 and attacks()[2].command=='combo 1002 spk spp spp','second spider did not attack after real balance recovery')
auto_room_items={{id=1003,name='a medium pulsating spider',attrib='m'},{id=999,name='a medium pulsating spider',attrib='mx'}}
receive('You have slain a medium pulsating spider.');check(s.target.name=='1003','second kill did not select third spider')
receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.');advance(.4)
check(#attacks()==3,'third spider not attacked after recovery')
auto_room_items={{id=999,name='a medium pulsating spider',attrib='mx'},{id=998,name='a medium pulsating spider',attrib='md'},{id=997,name='a stormwinged roc',attrib='m'}}
receive('You have slain a medium pulsating spider.');advance(4)
check(combat_v2.mode=='BASH' and #attacks()==3 and s.hunting.kills==3,'empty pool disabled persistent BASH or attacked loyal/dead/unselected NPC')
s=fresh('spider');auto_room_items={{id=1001,name='a medium pulsating spider',attrib='m'}};combat_v2_set_mode('BASH');combat_v2_stop();combat_v2_set_target('rat')
check(s.hunting.target_name==nil,'manual retarget retained old NPC-type filter')
auto_room_items={{id=1002,name='a medium pulsating spider',attrib='m'}};combat_v2_set_mode('BASH');advance(4)
check(combat_v2.mode=='BASH' and #attacks()==2 and s.target.name=='1002','AC2 fallback did not acquire an independently whitelisted NPC')
-- Integration: room movement preserves BASH but requires the new-room player list.
s=fresh('rat');combat_v2_set_mode('BASH');local prior_callback=timers[combat_v2.ih_timer].fn
auto_room_items={{id=222,name='a rat',attrib='m'}};gmcp.Room={Info={num=2,area='Fixture Hunt'}};handlers['gmcp.Room.Info']()
check(combat_v2.mode=='BASH' and #attacks()==0 and not s.policy.players_known,'room movement disabled BASH or bypassed unknown occupancy')
items({{id=111,name='an old rat',attrib='m'}});check(#attacks()==0,'late items bypassed unknown room occupancy')
gmcp.Room.Players={};handlers['gmcp.Room.Players']()
check(s.target.name=='222' and #attacks()==1,'new-room empty player list did not trigger IH and resume')
prior_callback();check(#attacks()==1,'old-room callback duplicated attack')
-- Integration: unknown areas pause, and approval is scoped to the area visit.
s=fresh('rat');gmcp.Room={Info={num=2,area='Fixture Town'},Players={}};handlers['gmcp.Room.Info']();handlers['gmcp.Room.Players']();combat_v2_set_mode('BASH')
check(combat_v2.mode=='BASH' and #ihs()==0 and #attacks()==0 and s.policy.prompted==s.policy.visit,'unknown area did not prompt and pause before IH')
local town_visit=s.policy.visit;auto_room_items={{id=333,name='a rat',attrib='m'}}
check(combat_v2_area_approve(town_visit,true) and #attacks()==1,'explicit current-area approval did not unlock safe hunting')
gmcp.Room.Info={num=3,area='Another Town'};handlers['gmcp.Room.Info']();gmcp.Room.Players={};handlers['gmcp.Room.Players']()
check(combat_v2.mode=='BASH' and #attacks()==1,'new unlisted area inherited previous approval')
check(not combat_v2_area_approve(town_visit,true),'old area prompt approved a different area')
-- Integration: only the solicited current web roster can exempt another player.
s=fresh('rat');gmcp.Room={Players={{name='Outsider'}}};handlers['gmcp.Room.Players']();combat_v2_set_mode('BASH')
check(combat_v2.mode=='BASH' and #ihs()==0 and #attacks()==0,'unverified player did not pause armed BASH')
receive('Your web has the following members:');receive('-------------------------------------------------');receive('Self.');receive('-------------------------------------------------')
check(#attacks()==0,'a non-web player was treated as trusted')
auto_room_items={{id=444,name='a rat',attrib='m'}};combat_v2.policy.request_web(s)
receive('Your web has the following members:');receive('-------------------------------------------------');receive('Outsider, Self.');receive('-------------------------------------------------')
check(#attacks()==1 and s.target.name=='444','confirmed web member did not allow group bashing')
gmcp.Room.AddPlayer={name='Unknown'};handlers['gmcp.Room.AddPlayer']()
receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.');advance(1)
check(#attacks()==1 and combat_v2.mode=='BASH','third-party entry did not immediately pause further attacks')
gmcp.Room.RemovePlayer='Unknown';handlers['gmcp.Room.RemovePlayer']();combat_v2.policy.request_web(s)
receive('Your web has the following members:');receive('-------------------------------------------------');receive('Outsider, Self.');receive('-------------------------------------------------')
check(#attacks()==2,'departure and fresh web roster did not resume attacks')
combat_v2_config('group_web','off');check(not combat_v2.policy.allowed(s),'solo setting failed to reject a web member')

s=fresh('rat');combat_v2_set_mode('FULL_AUTO');receive("The dummy's eyes dim as it ceases fighting.")
check(combat_v2.mode=='OFF' and s.training_battle_ended,'training end did not stop AUTO')
local end_count=#sent;s.player.hp=100;s.player.dead=false;advance(5)
check(combat_v2.mode=='OFF' and #sent==end_count,'training full-heal reset restarted attacks')
s=fresh('rat');combat_v2_set_mode('BASH');receive("The dummy's eyes dim as it ceases fighting.");advance(5)
check(combat_v2.mode=='OFF','persistent BASH ignored training match end')

s=fresh('rat');s.player.hp=100;s.player.maxhp=100;combat_v2_set_mode('FULL_AUTO')
receive('You are afflicted with anorexia.');receive('You are afflicted with asthma.');receive('You are afflicted with slickness.')
check(combat_v2.defense.hold(s) and combat_v2.runner.status:find('DEFENSE:',1,true),'live text ingestion did not pause full-auto at cure-lock')
local offense_before=0;for _,v in ipairs(sent)do if v.command:match('^combo ') or v.command:match('^mind ')then offense_before=offense_before+1 end end
advance(3)
local offense_after=0;for _,v in ipairs(sent)do if v.command:match('^combo ') or v.command:match('^mind ')then offense_after=offense_after+1 end end
check(offense_after==offense_before,'watchdog bypassed locked defense hold')
receive('You have cured slickness.');check(not combat_v2.defense.hold(s),'own cure did not release lock phase')
check(not combat_v2_config('defense_health_resume','40'),'invalid defensive hysteresis accepted')

s=fresh('rat');combat_v2_set_mode('FULL_AUTO');gmcp.Char={Afflictions={List={{name='ANOREXIA'},{name='asthma'},{name='slickness'}}}}
handlers['gmcp.Char.Afflictions.List']();check(combat_v2.defense.hold(s),'GMCP list did not run defensive gate immediately')
gmcp.Char.Afflictions.Remove='SLICKNESS';handlers['gmcp.Char.Afflictions.Remove']();check(not s.player.afflictions.slickness and not combat_v2.defense.hold(s),'normalized GMCP cure did not release lock')

-- A quiet watch sends no fourth IH, then uses fresh room data directly.
local function watched(target)
 local st=fresh(target);combat_v2_set_mode('BASH');receive('There is nothing here.');advance(2);receive('There is nothing here.');advance(2);receive('There is nothing here.');return st
end
s=watched('rat');advance(60);check(#ihs()==3 and s.hunting.watch and not combat_v2.ih_timer,'GMCP watch still polled IH after a minute')
items({{id=900,name='a stormwinged roc',attrib='mx'},{id=901,name='a guard',attrib='m'},{id=902,name='a rat corpse',attrib='md'}})
check(#attacks()==0 and #ihs()==3 and s.hunting.watch,'unsafe GMCP room objects woke attacks/IH')
items({{id=123,name='a rat',attrib='m'}})
check(s.target.name=='123' and #attacks()==1 and #ihs()==3 and not s.hunting.watch,'fresh GMCP list did not resume without IH')
s=watched('rat');gmcp.Char={Items={Add={location='inv',item={id=123,name='a rat',attrib='m'}}}};handlers['gmcp.Char.Items.Add']();check(#attacks()==0 and s.hunting.watch,'inventory add woke room watch')
gmcp.Char.Items.Add={location='room',item={id=123,name='a rat',attrib='m'}};handlers['gmcp.Char.Items.Add']()
check(#attacks()==1 and #ihs()==3 and s.target.name=='123','room Add did not wake GMCP watch')
s=watched('rat');gmcp.Char={Items={Add={location='room',item={id=123,name='a rat',attrib=''}}}};handlers['gmcp.Char.Items.Add']();check(#attacks()==0,'non-monster Add attacked')
gmcp.Char.Items.Update={location='room',item={id=123,attrib='m'}};handlers['gmcp.Char.Items.Update']()
check(#attacks()==1 and s.target.display_name=='a rat' and #ihs()==3,'partial room Update failed or lost cached name')
s=watched('rat');gmcp.Room={Players={{name='Unknown'}}};handlers['gmcp.Room.Players']();items({{id=123,name='a rat',attrib='m'}})
check(#attacks()==0 and #ihs()==3 and s.hunting.watch,'GMCP watch bypassed player safety')
gmcp.Room.Players={};handlers['gmcp.Room.Players']();check(#attacks()==1 and #ihs()==3,'safe occupancy did not reconsider deferred fresh room data')
s=watched('rat');gmcp.Room={Info={num=2,area='Fixture Hunt'}};handlers['gmcp.Room.Info']();check(not s.hunting.watch and #ihs()==3,'old-room watch survived movement or bypassed unknown occupancy')
gmcp.Room.Players={};handlers['gmcp.Room.Players']();advance(6)
check(#ihs()==6 and s.hunting.watch and s.hunting.watch.room_id==2,'new room did not get exactly three fresh IH attempts')
s=watched('rat');combat_v2_stop();items({{id=123,name='a rat',attrib='m'}});check(#attacks()==0 and #ihs()==3 and not s.hunting.watch,'stopped watch resumed on late GMCP')
s=watched('rat');combat_v2_start_ih('manual IH verification',true);check(#ihs()==4 and not s.hunting.watch and s.hunting.ih.active,'manual IH did not explicitly re-arm scanning')
s=watched('rat');s.hunting.killed_ids['123']=true;gmcp.Char={Items={Add={location='room',item={id=123,name='a rat',attrib='m'}}}};handlers['gmcp.Char.Items.Add']()
check(#attacks()==1 and not s.hunting.killed_ids['123'],'fresh living respawn retained a dead-ID blacklist')
s=fresh('rat');combat_v2_set_mode('BASH');gmcp.Char={Items={Add={location='room',item={id=123,name='a rat',attrib='m'}}}};handlers['gmcp.Char.Items.Add']();advance(7)
check(#ihs()==3 and #attacks()==1,'fresh Add during unanswered IH was forgotten when entering watch')

-- Auto-walking is opt-in and all movement goes to a fake sender in these fixtures.
local world={[1]={e=2},[2]={w=1,e=3},[3]={w=2}}
function getRoomArea(id)return world[tonumber(id)] and 7 or -1 end
function getAreaRooms()return {1,2,3}end
function getRoomExits(id)return world[tonumber(id)]end
function roomLocked()return false end
function getDoors()return {}end
function getRoomWeight()return 1 end
local function walker_fixture()
 local st=fresh('rat');local directions={}
 gmcp.Room={Info={num=1,area='Fixture Hunt',exits={e=2}}}
 combat_v2.walk_sender=function(dir)directions[#directions+1]=dir end
 combat_v2_set_mode('BASH');return st,directions
end
local function accept_walk(st)
 local offer=st.walker.offer;check(offer and not st.walker.active,'BASH did not offer opt-in walking')
 local ok=combat_v2_walk_answer(offer.token,true);check(ok and st.walker.active,'valid popup Yes did not enable walking')
end
local function arrive(id)
 gmcp.Room={Info={num=id,area='Fixture Hunt',exits=world[id]},Players={}};handlers['gmcp.Room.Info']();handlers['gmcp.Room.Players']()
end
local directions
s,directions=walker_fixture();advance(7);check(#directions==0 and not s.walker.active,'BASH or failed IH enabled movement without consent')
local token=s.walker.offer.token;combat_v2_walk_answer(token,false);check(#directions==0 and not s.walker.active and not s.walker.offer,'No did not leave stationary BASH')
s,directions=walker_fixture();accept_walk(s);advance(7)
check(#directions==0 and s.hunting.watch and s.walker.active,'unanswered IH authorized movement')
s,directions=walker_fixture();accept_walk(s);receive('There is nothing here.')
check(#directions==1 and directions[1]=='e' and s.walker.pending and #attacks()==0,'confirmed empty room did not issue one bounded move')
combat_v2_tick();combat_v2_tick();check(#directions==1,'pending movement duplicated a direction')
arrive(2);check(#directions==1 and not s.walker.pending and s.walker.active,'room arrival moved again without fresh room search')
items({{id=123,name='a rat',attrib='m'}})
check(#attacks()==1 and #directions==1,'walker did not stop and attack available NPC')
receive('You have slain a rat.');items({});check(#directions==1,'walk moved before physical attack recovery')
s.player.balance=false;s.player.equilibrium=false;s.player.left_arm_balance=false;s.player.right_arm_balance=false;combat_v2_tick()
s.player.balance=true;s.player.equilibrium=true;s.player.left_arm_balance=true;s.player.right_arm_balance=true
for _,key in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'})do s.recoveries[key]=(s.recoveries[key] or 0)+1 end
combat_v2_tick();check(#directions==2 and directions[2]=='e','fresh IH plus real recovery did not continue route')
arrive(3);receive('There is nothing here.');check(#directions==2 and not s.walker.active and s.walker.status=='complete' and combat_v2.mode=='BASH','finite route did not complete as stationary armed BASH')
s,directions=walker_fixture();accept_walk(s);s.player.hp=40;s.player.maxhp=100;receive('There is nothing here.')
check(#directions==0,'walker moved through defensive low-health hold');s.player.hp=100;combat_v2_tick();check(#directions==1,'healed walker did not resume safely')
s,directions=walker_fixture();accept_walk(s);s.player.balance=false;receive('There is nothing here.');check(#directions==0,'off-balance walker moved')
items({{id=123,name='a rat',attrib='m'}});s.player.balance=true;combat_v2_tick();check(#directions==0 and #attacks()==1,'new target did not revoke room-clear evidence')
s,directions=walker_fixture();accept_walk(s);gmcp.Room.Players={{name='Unknown'}};handlers['gmcp.Room.Players']();receive('There is nothing here.')
check(#directions==0,'walker bypassed unknown-player gate');gmcp.Room.Players={};handlers['gmcp.Room.Players']();receive('There is nothing here.');check(#directions==1,'safe occupancy did not release pending clearance')
s,directions=walker_fixture();accept_walk(s);gmcp.Room.Info.exits={e=99};receive('There is nothing here.');check(#directions==0 and not s.walker.active,'walker ignored live exit mismatch')
s,directions=walker_fixture();accept_walk(s);receive('There is nothing here.');advance(7);check(#directions==1 and not s.walker.active,'movement timeout retried blindly')
arrive(2);receive('There is nothing here.');check(#directions==1,'late movement acknowledgement rearmed walking')
s,directions=walker_fixture();accept_walk(s);receive('There is nothing here.');arrive(3);receive('There is nothing here.');check(#directions==1 and not s.walker.active,'unexpected destination preserved consent')
s,directions=walker_fixture();accept_walk(s);combat_v2_stop();receive('There is nothing here.');advance(10);check(#directions==0 and not s.walker.active and combat_v2.mode=='OFF','STOP did not revoke walking')
s,directions=walker_fixture();accept_walk(s);handlers.sysDisconnectionEvent();advance(10);check(#directions==0 and not s.walker.active,'disconnect did not revoke walking')
s,directions=walker_fixture();local stale=s.walker.offer.token;arrive(2);check(not combat_v2_walk_answer(stale,true) and #directions==0 and not s.walker.active,'stale room popup authorized movement')


s,directions=walker_fixture();accept_walk(s);combat_v2.walk_sender=function()error('fake movement transport failure')end;receive('There is nothing here.');advance(10);check(not s.walker.active and s.walker.fault and #directions==0,'sender failure left a retrying route')
s,directions=walker_fixture();accept_walk(s);combat_v2_walk('off');receive('There is nothing here.');advance(5);check(#directions==0 and combat_v2.mode=='BASH' and not s.walker.active,'walk off stopped BASH or retained movement')
s,directions=walker_fixture();accept_walk(s);combat_v2_set_target('other rat');receive('There is nothing here.');check(#directions==0 and not s.walker.active,'manual target retained movement consent')
s,directions=walker_fixture();accept_walk(s);s.player.afflictions.lameness=true;receive('There is nothing here.');check(#directions==0,'movement ignored leg hindrance');s.player.afflictions.lameness=nil;combat_v2_tick();check(#directions==1,'cleared hindrance did not resume')
s,directions=walker_fixture();accept_walk(s);s.player.balance=false;receive('There is nothing here.');items({{id=900,name='a loyal roc',attrib='mx'}});s.player.balance=true;combat_v2_tick();check(#directions==0 and s.hunting.ih.active,'changed room cache reused stale IH clearance');receive('There is nothing here.');check(#directions==1,'fresh reconfirmation did not release cache-change hold')
s,directions=walker_fixture();accept_walk(s);dofile(root..'bootstrap.lua');receive('There is nothing here.');check(combat_v2.mode=='OFF' and not s.walker.active and #directions==0,'reload retained walking consent')

-- Issued movement is an execution barrier, independent of route consent.
local function pending_hop()
 local st,dirs=walker_fixture();accept_walk(st);receive('There is nothing here.')
 check(#dirs==1 and st.walker.pending,'pending-hop fixture did not send exactly once')
 return st,dirs,st.walker.pending
end
local function command(text) matches={'',text};aliases[combat_v2.alias]();matches=nil end
local function add_rat()
 gmcp.Char=gmcp.Char or {};gmcp.Char.Items={Add={location='room',item={id=123,name='a rat',attrib='m'}}}
 handlers['gmcp.Char.Items.Add']()
end
s,directions=pending_hop();local hop=s.walker.pending
check(not combat_v2_walk('on') and s.walker.pending==hop and not s.walker.offer,'walk on replaced active pending hop')
combat_v2_walk('off');check(s.walker.pending==hop and not s.walker.active,'walk off forgot issued hop')
check(not combat_v2_walk('on') and not s.walker.offer,'walk on offered consent over pending hop')
check(not combat_v2_walk_answer(1,true),'pending hop accepted stale Yes')
receive('There is nothing here.');add_rat();advance(2)
check(#directions==1 and #attacks()==0 and s.walker.pending==hop,'off/on/empty IH/Add bypassed movement barrier')
handlers['gmcp.Room.Info']();check(s.walker.pending==hop,'same-room Room.Info masqueraded as arrival')
arrive(2);check(not s.walker.pending and not s.walker.active,'arrival after revoked consent failed to acknowledge')

for _,mode in ipairs({'FULL_AUTO','ASSIST','OFF','SHADOW','BASH'}) do
 s,directions,hop=pending_hop();combat_v2_set_mode(mode)
 if mode=='OFF' or mode=='SHADOW' then combat_v2_set_mode('BASH') end
 check(s.walker.pending==hop and not s.walker.active,'mode change erased hop: '..mode)
 combat_v2_set_target('Opponent');s.policy.players={opponent=true};s.policy.players_known=true
 local mental_sent=0;clock=clock+1
 combat_v2.mental.tick(s,function()mental_sent=mental_sent+1 end,false)
 check(mental_sent==0,'low-level mental bypassed hop: '..mode)
 local r=combat_v2.runner;local a=combat_v2.runner_module.propose(r)
 r.pending=a
 check(not combat_v2.runner_module.execute(r,a,true),'low-level runner bypassed hop: '..mode)
 check(not combat_v2_approve(),'ASSIST approval bypassed hop: '..mode)
 add_rat();advance(7)
 check(s.walker.pending==hop and hop.timed_out and not s.walker.active and #directions==1 and #attacks()==0,'mode/timeout permitted send: '..mode)
 check(not combat_v2_walk('on'),'timeout allowed new offer: '..mode)
 arrive(2);check(not s.walker.pending and not s.walker.active and #directions==1,'late arrival restored consent: '..mode)
end

for _,action in ipairs({'target','queue'}) do
 for _,phase in ipairs({'offer','active','pending'}) do
  s,directions=walker_fixture();local stale=s.walker.offer.token
  if phase~='offer' then accept_walk(s) end
  if phase=='pending' then receive('There is nothing here.') end
  hop=s.walker.pending
  if action=='target' then combat_v2_set_target('other rat')
  else combat_v2.bashing.add(s,'456');command('queue next');check(s.target.name=='456','manual queue next did not select queued target') end
  check(not s.walker.active and not s.walker.offer and not s.walker.ask_on_bash,'manual '..action..' retained '..phase..' consent')
  check(s.walker.pending==hop,'manual '..action..' lost pending barrier')
  check(not combat_v2_walk_answer(stale,true),'manual '..action..' retained stale popup')
  if hop then add_rat();advance(7);check(#attacks()==0 and #directions==1 and s.walker.pending==hop,'manual '..action..' bypassed unresolved location') end
 end
end
-- Automatic queue advancement must keep current walking consent.
s,directions=walker_fixture();accept_walk(s);combat_v2.bashing.add(s,'456')
s.target.display_name='a rat';combat_v2.bashing.killed(s)
check(s.walker.active and s.target.name=='456','automatic kill-chain revoked walking consent')

s,directions,hop=pending_hop();arrive(3);advance(7)
check(s.walker.pending==hop and not s.walker.active and #directions==1,'unexpected arrival released barrier')
local before,gmcp_before=#sent,#gmcp_sent
command('reset')
check(#sent==before and #gmcp_sent==gmcp_before and #directions==1,'reviewed reset sent a game command/request')
check(combat_v2.mode=='OFF' and s.mode=='OFF' and not s.walker.pending and not s.walker.active and not s.walker.offer,'reviewed reset did not stop and clear barrier')
check(not s.room.id and not s.room.area and not s.policy.players_known and next(s.room.items)==nil,'reviewed reset trusted stale location')
advance(10);check(#sent==before and #directions==1,'reset watchdog resumed combat')
combat_v2_set_mode('BASH');check(#attacks()==0 and #directions==1,'rearm without new room evidence sent offense')
arrive(3);check(not s.walker.active,'fresh room evidence silently restored walking')

s,directions,hop=pending_hop();dofile(root..'bootstrap.lua');combat_v2_set_mode('FULL_AUTO');advance(7)
check(s.walker.pending==hop and #attacks()==0 and #directions==1,'reload erased movement barrier')
arrive(2);check(not s.walker.pending and not s.walker.active,'reload prevented late arrival resolution')

s,directions,hop=pending_hop();handlers.sysDisconnectionEvent();advance(7)
check(s.walker.pending==hop and not s.walker.active and #directions==1,'disconnect forgot pending hop')
arrive(2);check(not s.walker.pending and not s.walker.active,'disconnect prevented expected arrival acknowledgement')

s,directions,hop=pending_hop();advance(7);handlers['gmcp.Room.Info']()
check(s.walker.pending==hop and hop.timed_out and not combat_v2_walk('on'),'timeout/same-room cache released movement barrier')
before,gmcp_before=#sent,#gmcp_sent
command('reset');check(#sent==before and #gmcp_sent==gmcp_before and combat_v2.mode=='OFF' and not s.room.id and not s.walker.pending,'timeout reset failed zero-send recovery')

print=realprint
print('PASS IH '..count..' assertions: bounded IH/GMCP watch, opt-in walker integration, room/combat/recovery/health/player gates, one-hop movement, revocation and cancellation')
