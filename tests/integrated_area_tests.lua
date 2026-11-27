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
if arg[2]~='walker'then
c,s=boot()
check(s.hunting.preset and s.hunting.preset.id=='alaqsii','automatic native-area catalog was not selected')
check(#ihs()==1,'initial BASH owns one IH query')
items({npc('101'),npc('102')})
check(#attacks()==0,'FULL must wait for later prompt')
prompt();check(#attacks()==1 and tostring(s.target.name)=='101','first canonical Runner attack')
ready();check(#attacks()==2 and tostring(s.target.name)=='101','stationary multihit repeats until kill')
receive('You have slain an arctic wolf.');full({npc('102')});ready()
check(tostring(s.target.name)=='102'and #attacks()>=3,'kill advances to next eligible via fresh list')
local waiting=c.runner.waiting;local requirements=c.runner.waiting_requires
room(2,'Bloodwood')
check(c.runner.waiting==waiting and c.runner.waiting_requires==requirements,'room change retains physical wait and recovery identity')
check(not s.target.name and not s.hunting.verified_generation,'room change revokes old proposal')
full({npc('201','a distressed spirit'),npc('202')});ready()
check(s.hunting.preset.id=='bloodwood'and tostring(s.target.name)=='201','manual entry switches exact area without global union')
local before=#attacks();room(3,'not a catalog area');full({npc('303')});ready()
check(#attacks()==before and c.mode=='BASH'and c.runner.status:find('unknown native area',1,true),'unknown area stays armed HOLD')
room(4,"the Ia'shal Barrow");check(s.hunting.preset.id=='iashal','exact native alias accepted')
room(4,'Fengard Keep');check(c.runner.status:find('restricted',1,true),'same-room area change holds restricted preset')
room(4,'Xaanhal');check(c.runner.status:find('ambiguous',1,true),'overlapping restricted catalog never silently broadens')

c,s=boot();full({});check(s.hunting.watch and c.mode=='BASH','empty room stays armed')
local queries=#ihs();advance(5);check(#ihs()==queries,'empty room no repeated polling')
gmcp.Char.Items.Add={location='room',item=npc('401')};handlers['gmcp.Char.Items.Add']()
check(#ihs()==queries+1 and #attacks()==0,'new arrival needs fresh solicited FULL')
full({npc('401')});check(#attacks()==1,'new arrival resumes after FULL and later prompt')
combat_v2_set_mode(false);local n=#attacks();ready();full({npc('402')});advance(2);check(#attacks()==n and c.mode=='OFF','boolean OFF stops automation')

c,s=boot();items({npc('501')});gmcp.Char.Items.List={location='room',items={[2]=npc('502')}};handlers['gmcp.Char.Items.List']();prompt();check(#attacks()==0,'malformed FULL revokes old certification')
advance(2.1);items({npc('502')});check(#attacks()==0,'solicited recovery waits later prompt');prompt();check(#attacks()==1,'later prompt recovers malformed FULL')

c,s=boot('Khauskin Mines');full({npc('601','a statuesque dwarven guard'),npc('602','a burly dwarven miner','mp'),npc('603','a burly dwarven miner','mx'),npc('604','a burly dwarven miner','mV'),npc('605','a burly dwarven miner')})
check(tostring(s.target.name)=='605','hard metadata/guard/player/loyal exclusions preserved')

c,s=boot();full({npc('701')});local n=#attacks();room(2,'Alaqsii Inlet');local cached=gmcp.Char.Items.List
-- Duplicate Info cannot replay the previously cached items as authority.
handlers['gmcp.Room.Info']();prompt();check(#attacks()==n,'double Room.Info cannot reuse old FULL')
ready();full({npc('702')});check(tostring(s.target.name)=='702','duplicate entry later genuine FULL recovers')

-- No stale visit consent or lifecycle revival can manufacture a new attack.
c,s=boot();full({});local oldvisit=s.policy.visit;room(2,'Bloodwood');check(s.policy.visit~=oldvisit and s.policy.consent==s.policy.visit,'BASH discovery deliberately enrolls a new exact known visit')
combat_v2_area_approve(s.policy.visit,false);local q=#ihs();full({npc('801','a distressed spirit')});ready();check(#attacks()==0 and s.policy.denied==s.policy.visit,'explicit visit denial wins discovery intent')
c,s=boot();full({});handlers['sysDisconnectionEvent']();local q=#ihs();ready();room(2,'Alaqsii Inlet');full({npc('802')});check(#attacks()==0 and #ihs()==q and s.hunting.area_auto_suspended,'reconnect remains suspended pending fresh BASH')
c,s=boot();full({});gmcp.Char.Vitals={hp='0',maxhp='100',balance='1',equilibrium='1'};handlers['gmcp.Char.Vitals']();ready();full({npc('803')});check(#attacks()==0 and s.hunting.area_auto_suspended,'death and revived vitals do not restart offense')
c,s=boot();full({npc('804')});local unknown={kind='opaque test commitment'};c.transport_unknown=unknown;local wait=c.runner.waiting;local req=c.runner.waiting_requires;room(2,'Bloodwood');full({npc('805','a distressed spirit')});check(c.transport_unknown==unknown and c.runner.waiting==wait and c.runner.waiting_requires==req and #attacks()==1,'opaque commitment and physical recovery survive scope invalidation')

end
-- Existing explicit WALK path still offers/consents rather than auto-moving.
for id,key in pairs(native_keys)do debug.getregistry()[key]=nil;key:close();native_keys[id]=nil end
c,s=start();check(s.walker.active and s.hunting.preset.id=='iashal'and not s.hunting.area_auto,'WALK ON preserves explicit preset and owner')
check(moves()==0,'WALK does not move before fresh inspection')
empty();check(moves()==1 and s.walker.pending,'existing WALK issues one owned move after empty certified inspection')
local destination=tonumber(s.walker.pending.to);arrival(destination);empty();check(s.walker.active and not s.hunting.area_auto,'WALK arrival retains traversal owner instead of stationary discovery')
combat_v2_set_mode('OFF')
realprint('PASS integrated-area actual-bootstrap assertions='..count)


