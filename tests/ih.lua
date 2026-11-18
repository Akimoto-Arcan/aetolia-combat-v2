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
 local s=combat_v2.current;s.room.id=1
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
local function attacks()local out={};for _,entry in ipairs(sent)do if entry.command~='ih'then out[#out+1]=entry end end;return out end
local s=fresh('rat');combat_v2_set_mode('BASH')
check(#ihs()==1 and #attacks()==0,'BASH must check IH before attacking')
receive('There is nothing here.');check(combat_v2.mode=='BASH','first miss halted early')
advance(1.9);check(#ihs()==1,'IH repeated before two seconds');advance(.1)
check(#ihs()==2 and ihs()[2].time==102,'second IH not at two seconds')
receive('There is nothing here.');check(combat_v2.mode=='BASH','second miss halted early');advance(2)
check(#ihs()==3 and ihs()[3].time==104,'third IH not at four seconds')
receive('There is nothing here.');check(combat_v2.mode=='OFF' and #attacks()==0,'third miss did not halt without attacks')
advance(10);check(#ihs()==3,'IH continued after third failed check')
s=fresh('rat');combat_v2_set_mode('BASH');receive('There is nothing here.');advance(2)
items({{id=123,name='a rat',attrib='m'}})
check(s.target.name=='123' and s.target.display_name=='a rat','IH did not resolve target to exact NPC ID')
check(#ihs()==2 and #attacks()==1,'target found on second IH did not resume once')
check(attacks()[1].command=='combo 123 sdk spp spp','resumed attack did not use confirmed NPC ID')
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
check(#ihs()==3 and combat_v2.mode=='OFF' and #attacks()==0,'unanswered IH must cap at three checks')
check(ihs()[1].time==100 and ihs()[2].time==102 and ihs()[3].time==104,'IH timeout requests not spaced exactly two seconds')
s=fresh('rat');combat_v2_set_mode('BASH');local stale=timers[combat_v2.ih_timer].fn;combat_v2_stop();advance(10);stale()
check(#ihs()==1 and combat_v2.mode=='OFF','manual STOP did not cancel retry')
items({{id=123,name='a rat',attrib='m'}});check(#attacks()==0,'late positive IH restarted a stopped executor')
s=fresh('rat');combat_v2_set_mode('BASH');local old=timers[combat_v2.ih_timer].fn;combat_v2_stop();combat_v2_set_mode('BASH');local current_timer=combat_v2.ih_timer;old()
check(combat_v2.ih_timer==current_timer and #ihs()==2,'stale callback clobbered the new scan')
s=fresh('rat');combat_v2_set_mode('BASH');combat_v2_set_mode('SHADOW');advance(6)
check(#ihs()==1 and #attacks()==0,'switching to SHADOW did not cancel IH')
s=fresh('rat');combat_v2_set_mode('BASH');handlers['sysDisconnectionEvent']();advance(6)
check(combat_v2.mode=='OFF' and #ihs()==1,'disconnect did not cancel IH')
s=fresh('rat');combat_v2_set_mode('BASH');gmcp.Room={Info={num=2}};handlers['gmcp.Room.Info']();advance(6)
check(combat_v2.mode=='OFF' and #ihs()==1,'room change did not cancel old-room IH')
s=fresh('rat');combat_v2_set_mode('BASH');items({{id=123,name='a rat',attrib='m'}});receive("You can find no such target as '123'.")
check(#ihs()==2 and #attacks()==1 and s.hunting.ih.active,'missing target response did not start IH recovery')
items({});advance(2);items({});advance(2);items({})
check(combat_v2.mode=='OFF' and #ihs()==4 and #attacks()==1,'missing-target recovery did not halt after its own three checks')
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
check(#attacks()==2 and attacks()[2].command=='combo 1002 sdk spp spp','second spider did not attack after real balance recovery')
auto_room_items={{id=1003,name='a medium pulsating spider',attrib='m'},{id=999,name='a medium pulsating spider',attrib='mx'}}
receive('You have slain a medium pulsating spider.');check(s.target.name=='1003','second kill did not select third spider')
receive('You have recovered balance on your left arm.');receive('You have recovered balance on your legs.');receive('You have recovered balance on your right arm.');advance(.4)
check(#attacks()==3,'third spider not attacked after recovery')
auto_room_items={{id=999,name='a medium pulsating spider',attrib='mx'},{id=998,name='a medium pulsating spider',attrib='md'},{id=997,name='a stormwinged roc',attrib='m'}}
receive('You have slain a medium pulsating spider.');advance(4)
check(combat_v2.mode=='OFF' and #attacks()==3 and s.hunting.kills==3,'empty eligible pool did not halt after three IH checks, or attacked loyal/dead/unselected NPC')
s=fresh('spider');auto_room_items={{id=1001,name='a medium pulsating spider',attrib='m'}};combat_v2_set_mode('BASH');combat_v2_stop();combat_v2_set_target('rat')
check(s.hunting.target_name==nil,'manual retarget retained old NPC-type filter')
auto_room_items={{id=1002,name='a medium pulsating spider',attrib='m'}};combat_v2_set_mode('BASH');advance(4)
check(combat_v2.mode=='OFF' and #attacks()==1,'missing new target fell back to previous spider type')
print=realprint
print('PASS IH '..count..' assertions: fresh presence gate, exact two-second retries, three-check halt, recovery, actor filtering, stale callbacks and cancellation')
