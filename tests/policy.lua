-- Synthetic policy fixtures shaped like observed AREAS / WEB MEMBERS / GMCP payloads.
local root=assert(arg[1]);local clock=100;function getEpoch()return clock end
local S=dofile(root..'state.lua');local P=dofile(root..'policy.lua');local B=dofile(root..'bashing.lua');B.bind(S);B.bind_mobs(dofile(root..'mobs.lua'))
local R=dofile(root..'runner.lua');R.bind_policy(P.attack_allowed);local K=dofile(root..'monk.lua')
local count=0;local function check(ok,msg)assert(ok,msg);count=count+1 end
local function fresh()
 clock=100;local s=S.new();s.mode='BASH';P.init(s,{Char={Name={name='Hero'}},Room={Info={num=1,area='the Fixture Woods'},Players={}}})
 S.sync_gmcp(s,{Char={Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1}}})
 return s
end
local function areas(s)
 P.request_areas(s);P.text(s,'******************************[ Areas by level ]*******************************')
 P.text(s,'  20   Safe          the Fixture Woods                               12345')
 P.text(s,' 120+  Lethal        the Fixture Depths                              23456')
 P.text(s,'*******************************************************************************')
end
local function web(s,row)
 P.request_web(s);P.text(s,'Your web has the following members:');P.text(s,'-------------------------------------------------')
 P.text(s,row or 'Ally, Hero.');P.text(s,'-------------------------------------------------')
end
local s=fresh();check(not P.allowed(s),'unlisted area allowed before AREAS evidence');areas(s)
check(s.policy.areas_loaded and s.policy.areas['the fixture woods'] and s.policy.areas['the fixture depths'],'AREAS level/threat/name parsing failed')
check(P.allowed(s),'known area and empty room not permitted');P.players(s,{{name='Hero'}});check(P.allowed(s),'self counted as another player')
P.players(s,{{name='Ally'}});check(not P.allowed(s),'unverified player allowed');web(s)
check(P.allowed(s),'verified web member blocked');P.player_add(s,{name='Stranger'});web(s)
check(not P.allowed(s),'non-web visitor permitted alongside trusted member');P.player_remove(s,'Stranger');check(P.allowed(s),'departed stranger remained blocking')
s.policy.group_web=false;check(not P.allowed(s),'solo toggle allowed web member');s.policy.group_web=true
clock=104;check(not P.allowed(s),'stale web roster granted permission');web(s);check(P.allowed(s),'fresh roster failed to restore permission')
P.text(s,'Ally has left your web.');check(not P.allowed(s),'web notice failed to invalidate old roster');web(s,'Hero.');check(not P.allowed(s),'removed member remained trusted')
P.request_web(s);P.text(s,'(Web): Ally says, "Your web has the following members:"');P.text(s,'Ally, Hero.');check(not P.allowed(s),'chat spoof granted web permission')
web(s);P.text(s,'You are not the member of any web.');check(not P.allowed(s) and not s.policy.web.pending,'no-web response retained old trust');web(s);P.room(s,{num=2,area='the Fixture Woods'});check(not P.allowed(s) and not s.policy.players_known,'new room inherited old empty-room permission')
P.players(s,{});check(P.allowed(s),'new-room player snapshot did not restore permission')
P.room(s,{num=3,area='Esterport'});P.players(s,{});check(not P.allowed(s),'town permitted without consent')
local visit=s.policy.visit;check(P.approve(s,visit,true) and P.allowed(s),'current-area explicit consent failed')
P.room(s,{num=4,area='Another Town'});P.players(s,{});check(not P.approve(s,visit,true) and not P.allowed(s),'stale approval enabled another area')
check(P.approve(s,s.policy.visit,false) and not P.allowed(s),'decline did not retain pause')
P.approve(s,s.policy.visit,true);P.room(s,{num=5,area='the Fixture Woods'});P.players(s,{});check(P.allowed(s),'known hunting area did not automatically resume permission')
P.room(s,{num=6,area='Another Town'});P.players(s,{});check(not P.allowed(s),'consent persisted after leaving and re-entering an unlisted area')
s=fresh();areas(s);S.set_target(s,'guard');s.room.items['100']={name='a city guard',attrib='m'}
S.set_target(s,'100');s.hunting.verified_generation=s.target_generation;check(not P.attack_allowed(s),'guard passed executor policy')
s.room.items['100']={name='a stormwinged roc',attrib='mx'};check(not P.attack_allowed(s),'loyal mount passed executor policy')
s.room.items['100']={name='a Teshen worker',attrib='md'};check(not P.attack_allowed(s),'corpse passed executor policy')
s.room.items['100']={name='a Teshen worker',attrib='m'};check(P.attack_allowed(s),'verified worker rejected')
local r=R.new(s,K);r.mode='BASH';local sent={};r.sender=function(cmd)sent[#sent+1]=cmd end
P.player_add(s,{name='Stranger'});check(not R.tick(r) and #sent==0,'executor sent despite non-web player')
P.player_remove(s,'Stranger');check(R.tick(r) and #sent==1,'executor did not resume when alone')
clock=110;check(not R.watchdog(r) and r.mode=='BASH' and r.fault and #sent==1,'attack timeout failed to latch armed safe pause')
check(not R.tick(r) and #sent==1,'fault retried unknown attack')
s=fresh();areas(s);S.set_target(s,'teshen');B.start(s);B.ih_begin(s);B.ih_request(s)
B.items(s,{location='room',items={{id=10,name='a Teshen reaver',attrib='m'},{id=20,name='a Teshen worker',attrib='m'},{id=5,name='a stormwinged roc',attrib='mx'}}})
check(B.ih_select(s) and s.target.name=='10','initial Teshen selection failed');B.killed(s);B.ih_begin(s);B.ih_request(s)
B.items(s,{location='room',items={{id=20,name='a Teshen worker',attrib='m'},{id=5,name='a stormwinged roc',attrib='mx'}}})
check(B.ih_select(s) and s.target.name=='20','AC2 whitelist did not switch reaver to worker')
check(not dofile(root..'mobs.lua')['a stormwinged roc'],'mount unexpectedly present in imported mob whitelist')
s=fresh();areas(s);P.players(s,{{name='Ally'}});local commands=P.services(s)
check(commands[1]=='web members' and s.policy.web.pending,'presence did not request roster');check(#P.services(s)==0,'web roster request spammed before retry interval')
clock=102;check(#P.services(s)==1,'unanswered web roster did not retry');P.players(s,{{fullname='unknown'}});check(not P.allowed(s),'malformed player list failed open')
s=fresh();areas(s);P.players(s,{});local old=s.policy.visit;P.room(s,{num=2,area='the Fixture Woods'});check(s.policy.visit==old,'same-area room movement invalidated area visit unnecessarily')
check(P.services(s)[1]=='look','unknown room occupancy did not request fresh room description')
-- Private room identity is independent of mutable area/title, never an area wildcard.
s=fresh();check(next(s.policy.approved_rooms)==nil,'absent private settings changed defaults')
local allow={['73077']=true};check(P.set_approved_rooms(s,allow),'valid room map rejected');allow['73078']=true
check(not s.policy.approved_rooms['73078'],'setter retained caller-owned mutable map')
P.room(s,{num=73077,area='Unknown Area',name='A private fixture'});P.players(s,{})
check(P.allowed(s),'exact private numeric room denied')
P.room(s,{num=73077,area='Renamed Area',name='A changed title'});P.players(s,{})
check(P.allowed(s),'area/title rename revoked exact room approval')
P.room(s,{num='73077',name='No area supplied'});P.players(s,{})
check(P.allowed(s),'string room identity or absent area blocked exact approval')
P.room(s,{num=73078,area='Renamed Area',name='A changed title'});P.players(s,{})
check(not P.allowed(s),'same area/title granted a different private room')
P.room(s,{num=73077,area='Renamed Area'});P.players(s,{});areas(s)
check(P.allowed(s) and s.policy.approved_rooms['73077'],'AREAS reload erased private map')
-- A partial Room.Info must not retain permission, even in a listed/consented area.
P.room(s,{area='the Fixture Woods'});P.players(s,{})
check(not P.area_allowed(s) and not P.allowed(s),'partial Room.Info with nil id failed open')
for _,id in ipairs({'','0','-1','1.5',' 73077','073077',false,0,-1,1.5,math.huge})do
 s.room.id=id;check(not P.area_allowed(s),'invalid current identity accepted: '..tostring(id))
end
P.room(s,{num=73077,area='Renamed Area'})
check(not P.allowed(s),'room approval bypassed fresh occupancy requirement')
P.players(s,{{name='Ally'}});check(not P.allowed(s),'private approval bypassed roster verification');web(s)
check(P.allowed(s),'verified web member blocked in approved private room')
s.policy.group_web=false;check(not P.allowed(s),'private approval bypassed solo mode');s.policy.group_web=true
clock=104;check(not P.allowed(s),'private approval bypassed fresh web roster');web(s)
P.player_add(s,{name='Stranger'});web(s);check(not P.allowed(s),'private approval permitted non-web player')
P.players(s,{});S.set_target(s,'100');s.hunting.verified_generation=s.target_generation
for _,item in ipairs({{name='a city guard',attrib='m'},{name='a worker',attrib='md'},
 {name='a mount',attrib='mx'},{name='a rock',attrib=''}})do
 s.room.items['100']=item;check(not P.attack_allowed(s),'private approval bypassed protected/dead/guard/monster gate')
end
s.room.items['100']={name='a Teshen worker',attrib='m'};check(P.attack_allowed(s),'legal private-room monster rejected')
s.hunting.verified_generation=nil;check(not P.attack_allowed(s),'private approval bypassed target confirmation')
local invalid_maps={false,'73077',73077,{[73077]=true},{['0']=true},{['-1']=true},
 {['073077']=true},{['1.5']=true},{[' 73077']=true},{['*']=true},{['73077']=false},
 {['73077']=1},{['73077']='true'},{['73077']={}}, {['73077']=true,['bad']=true}}
for _,map in ipairs(invalid_maps)do
 P.set_approved_rooms(s,{['73077']=true})
 check(not P.set_approved_rooms(s,map) and next(s.policy.approved_rooms)==nil,'malformed map did not revoke all private approvals')
end
check(P.set_approved_rooms(s,{}) and next(s.policy.approved_rooms)==nil,'empty map rejected')

-- Fresh startup uses fake I/O and an explicit JSON decoder stub only. No _G fallback.
local valid_json='{"approved_rooms":{"73077":true}}'
local function startup(content,decoded,option)
 local stats={opens=0,reads=0,closes=0,decodes=0}
 local env={type=type,pairs=pairs,next=next,tostring=tostring,tonumber=tonumber,
  pcall=pcall,string=string,math=math,os={clock=function()return clock end}}
 env.getMudletHomeDir=function()return '/fixture-profile' end
 env.io={open=function(path,mode)
  stats.opens=stats.opens+1
  assert(path=='/fixture-profile/combat_v2/bashing-rooms.json' and mode=='r','unexpected settings access')
  if option=='missing' then return nil end
  if option=='open_error' then error('fixture open failure') end
  return {read=function(_,format)
   stats.reads=stats.reads+1;assert(format=='*a')
   if option=='read_error' then error('fixture read failure') end
   return content
  end,close=function()stats.closes=stats.closes+1 end}
 end}
 env.yajl={to_value=function(text)
  stats.decodes=stats.decodes+1
  assert(text==content,'decoder input changed')
  if option=='decode_error' then error('fixture malformed JSON') end
  assert(text==valid_json or text=='fixture-invalid-schema','unrecognized decoder fixture')
  return decoded
 end}
 if option=='no_home' then env.getMudletHomeDir=nil end
 if option=='no_io' then env.io=nil end
 if option=='no_decoder' then env.yajl=nil end
 local chunk
 if setfenv then chunk=assert(loadfile(root..'policy.lua'));setfenv(chunk,env)
 else chunk=assert(loadfile(root..'policy.lua','t',env)) end
 local policy=chunk();local state=S.new()
 policy.init(state,{Room={Info={num=73077,area='Unknown Area'},Players={}}})
 return state,policy,stats
end
local loaded,lp,stats=startup(valid_json,{approved_rooms={['73077']=true}})
check(lp.allowed(loaded) and loaded.policy.approved_rooms['73077'],'fresh startup did not load private JSON')
check(loaded.mode=='OFF','loading settings armed combat')
check(stats.opens==1 and stats.reads==1 and stats.closes==1 and stats.decodes==1,'startup did not read/close/decode exactly once')
for _,option in ipairs({'missing','open_error','read_error','decode_error','no_home','no_io','no_decoder'})do
 local state,policy,seen=startup(valid_json,{approved_rooms={['73077']=true}},option)
 check(not policy.allowed(state) and next(state.policy.approved_rooms)==nil,'optional settings failure opened policy: '..option)
 if option=='read_error' then check(seen.closes==1 and seen.decodes==0,'failed read leaked handle or decoded content') end
 if option=='no_home' or option=='no_io' or option=='no_decoder' then check(seen.opens==0,'missing facility attempted file access') end
end
for _,data in ipairs({false,{}, {approved_rooms=false}, {approved_rooms={['73077']=true},area='*'}})do
 local state,policy=startup('fixture-invalid-schema',data)
 check(not policy.allowed(state) and next(state.policy.approved_rooms)==nil,'invalid settings root failed open')
end
for _,map in ipairs(invalid_maps)do
 local state,policy=startup('fixture-invalid-schema',{approved_rooms=map})
 check(not policy.allowed(state) and next(state.policy.approved_rooms)==nil,'invalid decoded room map failed open')
end
print('PASS policy '..count..' assertions: exact private room JSON, strict validation, area consent, current occupancy, fresh web membership and executor guardrails')
