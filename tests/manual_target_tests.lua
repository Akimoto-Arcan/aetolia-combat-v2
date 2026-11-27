-- NEW derived fixture; SYNTHETIC only; all 49 source modules unchanged.
-- Synthetic C++ bridges; registration Lua body is authenticated against actual Native dump. Never exported as Native ABI.
-- Deterministic fake-clock tests of the actual IH scheduler and Mudlet callbacks.
local root=assert(arg[1]);local realdofile=dofile;local realprint=print;print=function()end
local clock,handlers,triggers,aliases,timers,sent,nextid,gmcp_sent,room_refresh,auto_room_items,send_fault
function sendGMCP(msg)gmcp_sent[#gmcp_sent+1]=msg;room_refresh=true end
function getEpoch()return clock end
function getMudletHomeDir()return root:gsub('/[^/]+/$','')end
function getConnectionInfo()return 'fixture',0,true end
function send(cmd)
 sent[#sent+1]={command=cmd,time=clock}
 if cmd=='OSSO RIBCAGE'and send_fault then return false end
 -- Aetolia queues the explicit GMCP refresh until a command produces a prompt.
 -- Plain IH in an unchanged room emits no new item-list event in this fixture.
 if cmd=='ih' and room_refresh and auto_room_items then
  room_refresh=false;gmcp.Char={Items={List={location='room',items=auto_room_items}}}
  handlers['gmcp.Char.Items.List']()
 end
 return true
end
local native_events,native_ids
local native_keys={}
local function native_key(id)
 local folder=assert(os.getenv('TMPDIR'),'scratch TMPDIR required')
 local f=assert(io.open(folder..'/survival-callback-model-'..tostring(id)..'-'..tostring({}):gsub('[^%w]','')..'.tmp','w+'))
 native_keys[id]=f;return f
end
local platform=realdofile(root..'survival_native.lua')
local function configure_native()
 native_events={};native_ids={}
 local load=loadstring or load
 registerAnonymousEventHandler=assert(load(platform.register_reference,platform.source))()
 local function findStringEventHandler(existingHandlers,functionString)
  local functionExists=false
  if existingHandlers then for index,handlerFunction in pairs(existingHandlers)do
   local info=debug.getinfo(handlerFunction,'S');if info.source==functionString then functionExists=index;break end
  end end
  return functionExists
 end
 for i=1,100 do local name=debug.getupvalue(registerAnonymousEventHandler,i);if not name then break end
  if name=='handlers'then debug.setupvalue(registerAnonymousEventHandler,i,native_events)
  elseif name=='handlerIdsToHandlers'then debug.setupvalue(registerAnonymousEventHandler,i,native_ids)
  elseif name=='findStringEventHandler'then debug.setupvalue(registerAnonymousEventHandler,i,findStringEventHandler)
  elseif name=='highestHandlerId'then debug.setupvalue(registerAnonymousEventHandler,i,0)end
 end
 handlers=setmetatable({},{__index=function(_,event)
  return function(...)
   local indices={};for i in pairs(native_events[event]or{})do indices[#indices+1]=i end;table.sort(indices)
   for _,i in ipairs(indices)do local fn=native_events[event][i];if fn then fn(...)end end
  end
 end})
end
function killAnonymousEventHandler(id)
 local row=native_ids and native_ids[id]
 if row then native_events[row.event][row.index]=nil;native_ids[id]=nil end
end
function isActive(id,kind)return kind=='trigger'and triggers[id]and 1 or 0 end
function tempRegexTrigger(p,f)nextid=nextid+1;triggers[nextid]=f;debug.getregistry()[native_key(nextid)]=f;return nextid end
function tempPromptTrigger(f)nextid=nextid+1;triggers[nextid]=f;debug.getregistry()[native_key(nextid)]=f;return nextid end
function killTrigger(id)local key=native_keys[id];if key then debug.getregistry()[key]=nil;native_keys[id]=nil;key:close()end;triggers[id]=nil end
function tempAlias(p,f)nextid=nextid+1;aliases[nextid]=f;return nextid end
function killAlias(id)aliases[id]=nil end
function tempTimer(delay,f)nextid=nextid+1;timers[nextid]={at=clock+delay,fn=f,alive=true};return nextid end
function killTimer(id)if timers[id]then timers[id].alive=false end end
local real_loadfile=loadfile
loadfile=function(p,...)return real_loadfile(p:gsub('/combat_v2/','/'..assert(root:match('/([^/]+)/$'))..'/'),...)end
dofile=function(p)
 p=p:gsub("/combat_v2/", "/"..assert(root:match("/([^/]+)/$")).."/")
 if p:match('/survival_native.lua$')then local spec=realdofile(p);spec.require_c_intrinsics=false;return spec end
 if p:match('/gui.lua$')then return {create=function()end,refresh=function()end}end;return realdofile(p)
end
local count=0;local function check(v,msg)if not v then local c=combat_v2;local s=c and c.current;realprint('FAIL',msg,c and c.runner.status,s and s.target.name,s and s.hunting.preset and s.hunting.preset.id,s and s.hunting.area_dirty,s and s.hunting.area_recovery,s and s.hunting.ih and s.hunting.ih.active,s and s.hunting.ih and s.hunting.ih.pending)end;assert(v,msg);count=count+1 end
local function fresh(target)
 combat_v2=nil;gmcp={Char={Status={class="Monk"}}};clock=100;handlers={};triggers={};aliases={};timers={};sent={};nextid=0;gmcp_sent={};room_refresh=false;auto_room_items=nil
 configure_native()
 realdofile(root..'bootstrap.lua');if handlers and handlers['gmcp.Char.Status']then handlers['gmcp.Char.Status']()end
 local s=combat_v2.current;s.room.id=1;s.room.area="the Ia'shal Barrow"
 s.policy.area="the ia'shal barrow";s.policy.areas={["the ia'shal barrow"]=true};s.policy.areas_loaded=true;s.policy.players={};s.policy.players_known=true;s.policy.players_room=1;s.policy.self_name='self'
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
 -- Emit the genuine later entry prompt; ordinary malformed/retry fixtures
 -- retain their explicit prompt ordering below.
 local e=combat_v2.current.hunting.entry
 if e and not e.done and ((e.scan and e.scan==combat_v2.current.hunting.ih)or(e.fallback_scan and e.fallback_scan==combat_v2.current.hunting.ih))then triggers[combat_v2.prompt_trigger]()end
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
 local state=fresh('rat');state.player.class='Monk';state.player.mounted=false;assert(combat_v2.areas.configure(state,'iashal',"the Ia'shal Barrow"));gmcp.Room={Info={num=1,area="the Ia'shal Barrow",exits={n=2,e=3}}}
 check(combat_v2_walk('on'),'explicit WALK ON fixture')
 combat_v2_set_mode('BASH');local c=combat_v2
 check(state.walker.offer and not state.walker.active,'activation must offer, not move')
 check(combat_v2_walk_answer(state.walker.offer.token,true),'fresh Yes rejected')
 return c,state
end
local function empty()items({})end
local function arrival(id,players)
 gmcp.Room.Info={num=id,area="the Ia'shal Barrow",exits=graph[id]};handlers['gmcp.Room.Info']()
 if players~=false then gmcp.Room.Players={};handlers['gmcp.Room.Players']()end
end

local realopen=io.open
yajl={to_value=function(raw)assert(raw=='{"mount_id":"88001"}');return {mount_id='88001'}end}
io.open=function(path,mode)
 path=path:gsub('/combat_v2/','/'..assert(root:match('/([^/]+)/$'))..'/')
 if mode=='r'and path:match('convenience%-settings%.json$')then return {read=function()return '{"mount_id":"88001"}'end,close=function()end}end
 if mode=='r'and path:match('settings%.json$')then return nil end
 return realopen(path,mode)
end
mmp={envidsr={[7]='Path'},waterenvs={}}
function getRoomEnv()return 7 end

local function prompt()triggers[combat_v2.prompt_trigger]()end
local function npc(id,name,flags)return {id=id,name=name or 'an arctic wolf',attrib=flags or 'm'}end
local function room(id,area)
 gmcp.Room={Info={num=id,area=area,exits=graph[id]or{}}};handlers['gmcp.Room.Info']()
 gmcp.Room.Players={};handlers['gmcp.Room.Players']()
end
local function boot(area)
 for id,key in pairs(native_keys)do debug.getregistry()[key]=nil;key:close();native_keys[id]=nil end
 local s=fresh();s.player.mounted=false;s.mental.enabled=false
 check(combat_v2.mode=='OFF','startup OFF')
 room(1,area or 'Alaqsii Inlet')
 combat_v2_set_mode('BASH')
 return combat_v2,s
end
local function full(list)items(list);prompt()end
local function ready()
 clock=clock+0.5
 gmcp.Char.Vitals={hp='100',maxhp='100',mp='100',maxmp='100',balance='0',equilibrium='1',left_arm='0',right_arm='0',mounted='0'};handlers['gmcp.Char.Vitals']()
 clock=clock+0.5;gmcp.Char.Vitals.balance='1';gmcp.Char.Vitals.left_arm='1';gmcp.Char.Vitals.right_arm='1';handlers['gmcp.Char.Vitals']()
end
local c,s

-- Actual composed bootstrap, synthetic native callbacks; never a live fixture.
local function selected(id,list)
 if not s.room.items[tostring(id)]then full(list)end
 local ok,why=combat_v2_set_target(id);check(ok,'selection accepted: '..tostring(why))
 check(s.hunting.manual_target,'explicit choice retained as room-local intent')
 if not s.hunting.manual_target.id then full(list)end
end
local unlisted={npc('901','a curious beetle'),npc('902','a wolf')}
c,s=boot('not a catalog area');full(unlisted)
selected('901',unlisted)
check(#attacks()==1 and tostring(s.target.name)=='901','manual exact unlisted NPC uses canonical Runner')
ready();check(#attacks()==2 and tostring(s.target.name)=='901','manual NPC repeats through real recovery')
receive('You have slain a curious beetle.');full({npc('902','a wolf')});ready()
check(#attacks()==2 and not s.hunting.manual_target,'unknown area never falls back to global mobs after manual death')

-- Higher-priority approved competitor cannot steal a lower-priority explicit choice.
local rivals={npc('101','a blackened darkwalker'),npc('202','a gnarled spirit')}
c,s=boot('Drakuum');full(rivals);check(tostring(s.target.name)=='101','baseline catalog priority')
local wait,req,recovery,last=c.runner.waiting,c.runner.waiting_requires,c.runner.recovery_snapshot,c.runner.last_send
local oldtarget=s.target
selected('202',rivals)
check(c.runner.waiting==wait and c.runner.waiting_requires==req and c.runner.recovery_snapshot==recovery and c.runner.last_send==last and s.target==oldtarget,'mid-BAL selection preserves issued recovery and old target')
local n=#attacks();combat_v2_tick();check(#attacks()==n,'no pre-recovery attack')
ready();check(#attacks()==n+1 and tostring(s.target.name)=='202','explicit lower-priority target after actual recovery')
ready();check(#attacks()==n+2 and tostring(s.target.name)=='202','priority survives repeated attack')
receive('You have slain a gnarled spirit.');full({rivals[1]});ready()
check(tostring(s.target.name)=='101'and #attacks()>=n+3,'manual death falls through normal catalog')

-- OFF choice is room-local intent only, and needs new solicited proof after ON.
c,s=boot('Drakuum');combat_v2_set_mode('OFF');local before=#attacks()
check(combat_v2_set_target('202'),'before-BASH intent accepted');items(rivals);prompt()
check(#attacks()==before and not s.hunting.manual_target.id,'OFF cached list is not authority')
combat_v2_set_mode('BASH');items(rivals);check(#attacks()==before,'ON FULL alone cannot attack')
prompt();check(tostring(s.target.name)=='202'and #attacks()==before+1,'before-BASH priority reacquired in same room')

-- Missing/ambiguous/protected input HOLDS, never silently attacks an alternative.
for _,query in ipairs({'missing','spirit'})do
 c,s=boot('Bloodwood');full({});local list={npc('301','a distressed spirit'),npc('302','a lingering spirit')}
 combat_v2_set_target(query);full(list);ready();check(#attacks()==0 and s.hunting.manual_target and s.hunting.manual_target.hold,'absent/ambiguous query holds')
 selected('301',list);ready();check(tostring(s.target.name)=='301'and #attacks()>=1,'explicit replacement recovers hold')
end
for _,it in ipairs({npc('401','a guard'),npc('401','a loyal beast'),npc('401','a warhorse'),npc('401','a roc'),npc('401','Khabarak, the jeweler'),npc('401','a beetle','mx'),npc('401','a beetle','mV'),npc('401','Player','p'),npc('401','a beetle',''),npc('401','a beetle','md')})do
 c,s=boot();full({});combat_v2_set_target('401');full({it,npc('402')});ready()
 check(#attacks()==0,'hard exclusion holds even with ordinary eligible competitor: '..it.name..'/'..it.attrib)
end
c,s=boot();full({});s.policy.players['player']=true
combat_v2_set_target('Player');full({npc('451','Player')});ready();check(#attacks()==0,'room player identity never override')
for _,bad in ipairs({'901;look','901\nlook','901|look'})do check(not combat_v2_set_target(bad),'command separator rejected')end

-- Stale / malformed certificates solicit recovery via existing IH owner.
c,s=boot();full({});clock=clock+6
combat_v2_set_target('501');check(not s.hunting.manual_target.id,'stale proof cannot resolve selection')
items({npc('501')});check(#attacks()==0,'stale recovery needs later prompt');prompt();check(#attacks()==1,'stale later prompt recovers')
ready();local n=#attacks();gmcp.Char.Items.List={location='room',items={[2]=npc('501')}};handlers['gmcp.Char.Items.List']();prompt()
check(#attacks()==n,'malformed newer list revokes authority')
ready();advance(2.1);items({npc('501')});check(#attacks()==n,'malformed recovery FULL still waits prompt');prompt();ready();check(#attacks()>n,'legitimate fresh solicited recovery resumes')

-- Genuine Remove, identity/metadata drift, room scope, OFF and lifecycle revocation.
c,s=boot();full({});local pair={npc('601'),npc('602')};selected('601',pair)
gmcp.Char.Items.Remove={location='room',id='601'};handlers['gmcp.Char.Items.Remove']();full({npc('602')});ready()
check(not s.hunting.manual_target and tostring(s.target.name)=='602','Remove releases manual priority to ordinary candidate')
c,s=boot();full({});selected('701',{npc('701','a curious beetle')})
full({npc('701','a different beetle'),npc('702')});check(not s.hunting.manual_target,'FULL identity drift revokes immediately');ready();full({npc('701','a different beetle'),npc('702')});ready();check(not s.hunting.manual_target and tostring(s.target.name)=='702','same ID name drift revokes exact authority')
c,s=boot();full({});selected('711',{npc('711','a curious beetle')})
gmcp.Char.Items.Update={location='room',item=npc('711','a curious beetle','mx')};handlers['gmcp.Char.Items.Update']()
check(not s.hunting.manual_target,'metadata delta revokes before any later FULL')
for _,kind in ipairs({'room','OFF','disconnect','death'})do
 c,s=boot();full({});selected('801',{npc('801')});local n=#attacks()
 if kind=='room'then room(2,'Alaqsii Inlet')
 elseif kind=='OFF'then combat_v2_set_mode('OFF')
 elseif kind=='disconnect'then handlers['sysDisconnectionEvent']()
 else gmcp.Char.Vitals={hp='0',maxhp='100',balance='1',equilibrium='1'};handlers['gmcp.Char.Vitals']()end
 check(not s.hunting.manual_target,'manual intent revoked on '..kind)
 if kind~='room'then ready();full({npc('801')});check(#attacks()==n,'no lifecycle restart on '..kind)end
end
for _,area in ipairs({'Fengard Keep','Xaanhal'})do
 c,s=boot(area);combat_v2_set_target('901');full(unlisted);ready();check(#attacks()==0,'reviewed restricted encounter remains HOLD: '..area)
end
c,s=boot('not a catalog area');combat_v2_area_approve(s.policy.visit,false);combat_v2_set_target('901');full(unlisted);ready();check(#attacks()==0,'explicit visit denial wins manual selection')

-- Every distinct opaque/issued owner survives retarget intent, not just Runner BAL.
for _,slot in ipairs({'controller','runner','runner-root','controller-root','class'})do
 c,s=boot('Drakuum');full(rivals);ready()
 local issued={identity=slot,class='Monk'};local owner
 if slot=='controller'then owner=c
 elseif slot=='runner'then owner=c.runner
 elseif slot=='runner-root'then c.runner.root={};owner=c.runner.root
 elseif slot=='controller-root'then c.root={};owner=c.root
 else s.class_observations.issued=issued end
 if owner then owner.transport_unknown=issued end
 local old=s.target;local wait,req,snap=c.runner.waiting,c.runner.waiting_requires,c.runner.recovery_snapshot
 check(combat_v2_set_target('202'),'intent accepted behind '..slot)
 ready();check(s.target==old and c.runner.waiting_requires==req and c.runner.recovery_snapshot==snap,'target/recovery unchanged behind '..slot)
 check(owner and owner.transport_unknown==issued or not owner and s.class_observations.issued==issued,'issued owner identity retained '..slot)
end
-- Existing canonical aliases and cv2 controller, not third-party/global targeting.
c,s=boot();full({npc('991'),npc('992')});local old=#attacks()
matches={[2]='992'};aliases[c.target_alias]();matches=nil;ready()
check(tostring(s.target.name)=='992'and #attacks()==old+1,'t alias routes canonical manual controller')

c,s=boot('Drakuum');full(rivals)
matches={[2]='target gnarled'};aliases[c.alias]();matches=nil;ready()
check(tostring(s.target.name)=='202','cv2 target word keyword uses numeric execution')
check(attacks()[#attacks()].command:find('combo 202 ',1,true)~=nil,'never send raw keyword')
local before=#attacks();combat_v2_set_target('narled');ready()
check(#attacks()==before and s.hunting.manual_target.hold,'substring is not a whole-word target')
realprint('PASS manual-target actual-bootstrap assertions='..count)

