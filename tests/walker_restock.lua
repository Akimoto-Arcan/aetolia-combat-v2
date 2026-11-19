-- Standalone trusted-lease checkpoint acceptance. Never inherits a client root.
local root=assert(arg[1]);local W=dofile(root..'walker.lua');local M=dofile(root..'walker_boot.lua')
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local sends,popups=0,0
function getEpoch()return 100 end
function combat_v2_start_ih()end
function getRoomArea()return 7 end
function getAreaRooms()return {1,2,3}end
function getRoomExits(id)return ({[1]={n=2},[2]={s=1,n=3},[3]={s=2}})[id]end
function roomLocked()return false end
function getDoors()return {}end
function getRoomWeight()return 1 end
function getConnectionInfo()return '',0,true end
local function fixture()
 local c={walker=W,mode='BASH',current={mode='BASH',connected=true,player={class='Monk',mounted=false,hp=100,maxhp=100},config={},room={id=2,area='Hunt',items={},item_version=1},hunting={},policy={players={},players_known=true,players_room=2}},runner={},runner_module={ready=function()return true end},gui={hide_walk_prompt=function()end,show_walk_prompt=function()popups=popups+1 end,refresh=function()end},defense={hold=function()end}}
 c.policy={allowed=function()return true end};c.bashing={watch_select=function()return false end};c.restock_data={enabled=false}
 c.restock_module={owns_transition=function(o)return o.restock_data.dispatching==true end,movement_borrowed=function(o)return o.restock_data.borrowed==true end,movement_reserved=function(o)return o.restock_data.reserved==true end}
 function combat_v2_globe(action)if tostring(action):lower()=='on'then c.elemental_recovery={armed=true}end;return true end
 function combat_v2_tick()return true end
 function combat_v2_stop()c.mode='OFF';c.current.mode='OFF';return true end
 function combat_v2_set_mode(mode)if mode:upper()=='OFF'then return combat_v2_stop()end;c.mode=mode:upper();c.current.mode=c.mode;return true end
 function combat_v2_set_target()return true end
 function combat_v2_reset_wait()return true end
 M.attach(c)
 local w=W.state(c.current);w.active=true;w.offers=9;w.graph=assert(W.build(1,7,{['1']={area=7,exits={n=2}},['2']={area=7,exits={s=1,n=3}},['3']={area=7,exits={s=2}}}));w.area='Hunt';w.start='1';w.steps=17;w.visited={['1']=true,['2']=true};w.clear={room_id='2',version=1}
 w.inspection={room='2',area='Hunt',items=c.current.room.items,version=1,sequence=0}
 return c,w
end
local function inspect(c)
 local s=c.current;local w=W.state(s);s.room.item_version=s.room.item_version+1
 local scan={responded=true,room_id=s.room.id,items=s.room.items,walker_items=s.room.items,walker_version=s.room.item_version,start_version=s.room.item_version-1}
 return M.inspected(c,scan)
end
local function room(c,id,area)
 c.current.room.id=id;c.current.room.area=area or 'Hunt';c.current.policy.players_room=id;M.room(c,{num=id,area=c.current.room.area},true)
end
local function trip(c)
 c.restock_data.borrowed=true;room(c,88,'Shop');room(c,2,'Hunt');check(inspect(c),'fresh solicited inspection')
end
local c,w=fixture();check(M.restock_ready(c),'ready clear active walker');local graph,visited=w.graph,w.visited
local cp=assert(M.restock_suspend(c,c.restock_data));check(cp.steps==17 and cp.visited==visited and cp.graph==graph,'exact checkpoint identity');check(not w.active and not w.clear and w.offers==9,'suspend does not revoke consent')
check(not combat_v2_globe('ON')and not combat_v2_globe('oN'),'suspended public GLOBE uppercase blocked')
c.restock_data.dispatching=true;combat_v2_set_mode('OFF');c.restock_data.dispatching=false;check(not cp.cancelled,'own OFF via actual stop callback retains checkpoint')
trip(c);check(not M.restock_resume(c,cp,c.restock_data),'OFF cannot resume')
c.restock_data.dispatching=true;combat_v2_set_mode('BASH');c.restock_data.dispatching=false
check(M.restock_resume(c,cp,c.restock_data),'valid resume');check(w.active and w.steps==17 and w.visited==visited and w.graph==graph and w.area=='Hunt' and cp.area=='Hunt' and cp.walk_area=='Hunt','route continuation exact');check(not w.clear and w.reinspect,'post-resume fresh IH required');check(not M.restock_resume(c,cp,c.restock_data),'cannot resume twice')
check(not combat_v2_globe('On'),'active public GLOBE mixed case blocked')
check(inspect(c),'new inspection');W.mark_clear(c.current,c.current.room.item_version);check(W.next(c.current).to=='3','old visited rooms not revisited as new route')
for _,action in ipairs({'stop','mode','target','walk','disconnect','class','consent'})do
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c)
 if action=='stop'then combat_v2_stop()elseif action=='mode'then combat_v2_set_mode('OFF')elseif action=='target'then combat_v2_set_target('rat')elseif action=='walk'then combat_v2_walk('OFF')elseif action=='disconnect'then c.current.connected=false;M.revoke(c,'disconnected')elseif action=='class'then c.current.player.class='Shaman'else M.offer(c)end
 check(not M.restock_resume(c,cp,c.restock_data),'cancelled '..action..' must not resume')
end
for _,barrier in ipairs({'pending','dispatching','physical_dispatch','arrival_hold'})do
 c,w=fixture();w[barrier]={};check(not M.restock_suspend(c,c.restock_data),'do not discard '..barrier);check(w[barrier]~=nil,'preserved '..barrier)
end
for _,problem in ipairs({'wrongroom','wrongarea','noIH','changeditems','otherplayer','mounted','lease','generation','epoch','unknown'})do
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c)
 if problem=='wrongroom'then c.current.room.id=3 elseif problem=='wrongarea'then c.current.room.area='Elsewhere'elseif problem=='noIH'then w.inspection=nil elseif problem=='changeditems'then c.current.room.item_version=99 elseif problem=='otherplayer'then c.current.policy.players.other=true elseif problem=='mounted'then c.current.player.mounted=222 elseif problem=='lease'then c.restock_data={}elseif problem=='generation'then w.offers=10 elseif problem=='epoch'then w.intent_epoch=99 else c.runner.transport_unknown=true end
 check(not M.restock_resume(c,cp,c.restock_data),'reject '..problem);check(not w.active,'no restore '..problem)
end
c,w=fixture();c.restock_data.reserved=true;gmcp={Room={Info={num=2,exits={n=3}}}};c.walk_sender=function()sends=sends+1 end;check(not M.step(c),'reservation inhibits only next hop');check(w.active and w.clear,'reservation retains route and clearance')
c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));M.attach(c);check(w.restock_checkpoint==cp and not cp.cancelled,'handler reattach preserves checkpoint')
check(sends==0 and popups<=1,'no gameplay dispatch from checkpoint API')
-- Review regressions are individually selectable to prove pre-fix failures.
local selected=arg[2]
local function regression(name,fn)if not selected or selected==name then fn()end end
regression('protected',function()
 for _,item in ipairs({{id='corpse',name='a dead reaver',attrib='md'}, {id='mount',name='a loyal mount',attrib='mx'}, {id='loyal',name='a loyal beast',attrib='x',icon='monster'}})do
  c,w=fixture();c.current.room.items={item};inspect(c);check(M.restock_ready(c),'dead/protected metadata must not prevent checkpoint')
  cp=assert(M.restock_suspend(c,c.restock_data));trip(c);check(M.restock_resume(c,cp,c.restock_data),'dead/protected metadata must not prevent return')
 end
end)
regression('hostiles',function()
 for _,item in ipairs({{id='reaver',name='a reaver',attrib='m'}, {id='beast',name='a beast',icon='monster'}})do
  c,w=fixture();c.current.room.items={item};check(not M.restock_ready(c),'living NPC metadata blocks suspension')
  c.current.room.items={};inspect(c);cp=assert(M.restock_suspend(c,c.restock_data));trip(c);c.current.room.items={item};inspect(c)
  check(not M.restock_resume(c,cp,c.restock_data)and not w.active,'respawn keeps route suspended')
  c.current.room.items={};inspect(c);check(M.restock_resume(c,cp,c.restock_data),'fresh empty inspection resumes after hostile death')
 end
end)
regression('metadata',function()
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data))
 c.mode='OFF';c.current.mode='OFF';M.room(c,{num=2,area='Hunt'},false)
 check(not cp.cancelled and w.restock_checkpoint==cp,'same-room OFF preparation must retain checkpoint')
 check(not cp.return_sequence and not w.inspection,'same-room metadata grants no return or inspection')
 M.room(c,{name='partial room metadata'},true)
 check(not cp.cancelled and not cp.return_sequence and not w.inspection,'partial metadata must retain intent without proving arrival')
 c.restock_data.borrowed=true;room(c,88,'Shop');c.restock_data.borrowed=false
 M.room(c,{num=88,area='Shop'},false);M.room(c,{name='wares location metadata'},true)
 check(not cp.cancelled and not cp.return_sequence,'idle shop metadata is not manual movement or return')
 c.restock_data.borrowed=true;room(c,2,'Hunt');c.restock_data.borrowed=false
 local returned=cp.return_sequence;check(returned~=nil,'trusted real round trip establishes return')
 inspect(c);M.room(c,{num=2,area='Hunt'},false)
 check(not cp.cancelled and not w.inspection and cp.return_sequence==returned,'post-return LOOK retains checkpoint but invalidates inspection')
 c.mode='BASH';c.current.mode='BASH';check(not M.restock_resume(c,cp,c.restock_data),'same-room LOOK cannot substitute for fresh IH')
 check(inspect(c)and M.restock_resume(c,cp,c.restock_data),'fresh post-LOOK IH permits single restoration')
end)
regression('location',function()
 for _,change in ipairs({'room','area'})do
  c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c);c.restock_data.borrowed=false
  if change=='room'then room(c,3,'Hunt')else c.current.room.area='Spoof';M.room(c,{num=2,area='Spoof'},false)end
  check(cp.cancelled and not w.restock_checkpoint,'unowned changed '..change..' must permanently revoke checkpoint')
  c.current.room.id=2;c.current.room.area='Hunt';inspect(c);check(not M.restock_resume(c,cp,c.restock_data),'metadata cannot revive revoked '..change..' checkpoint')
 end
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));c.restock_data.borrowed=true;room(c,88,'Shop')
 c.current.room.id=2;c.current.room.area='Hunt';M.room(c,{num=2},true)
 check(not cp.return_sequence,'missing area cannot establish exact return from cached canonical area')
 c.current.room.id=nil;M.room(c,{area='Hunt'},true)
 check(not cp.return_sequence and not w.inspection,'unknown room number cannot establish arrival or freshness')
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));c.restock_data.borrowed=true
 room(c,2,'Spoof');room(c,2,'Hunt');inspect(c)
 check(cp.cancelled and not M.restock_resume(c,cp,c.restock_data),'same-number area spoof is not a borrowed departure and return')
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c)
 room(c,88,'Shop');check(not cp.return_sequence,'new borrowed departure invalidates earlier return sequence')
 c.current.room.id=2;c.current.room.area='Hunt';M.room(c,{num=2},true);inspect(c)
 check(not M.restock_resume(c,cp,c.restock_data),'incomplete second return cannot reuse first return sequence')
end)
regression('resume_hold',function()
 -- Compose the real restock hold with the walker resource gate. The restock
 -- owner must release only its own hold in resume, not unrelated reservations.
 local R=dofile(root..'restock_boot.lua')
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c)
 c.restock_module.busy=function()return true end
 c.restock_data.active=true;c.restock_data.resume_consent=true;c.restock_data.phase='resume'
 c.convenience={busy=function()return false end,hold=R.hold}
 check(not R.hold(c),'settled owned resume phase releases only its own convenience hold')
 c.travel_owner={recall_due=true};check(not M.restock_resume(c,cp,c.restock_data),'own resume exemption cannot waive recall reservation')
 c.travel_owner=nil;check(M.restock_resume(c,cp,c.restock_data),'composed settled own resume exemption avoids walker deadlock')
end)
regression('barriers',function()
 for _,kind in ipairs({'convenience','recall','buff','runner','travel'})do
  c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));trip(c)
  if kind=='convenience'then c.convenience={busy=function()return true end,hold=function()return true end}
  elseif kind=='recall'then c.travel_owner={recall_due=true}
  elseif kind=='buff'then c.current.buffs={pending={}}
  elseif kind=='runner'then c.runner.waiting=true
  else c.travel_owner={pending={}}end
  check(not M.restock_resume(c,cp,c.restock_data)and not w.active,'resume must preserve '..kind..' barrier')
 end
end)
regression('number_only_candidate',function()
 local function candidate()
  local c,w=fixture();local d=c.restock_data;local cp=assert(M.restock_suspend(c,d))
  d.borrowed=true;room(c,88,'Shop');d.active=true;d.resume_consent=true;c.user_activity=d
  local tr={serial=12,destination='2',room='88',intent='pt',route='going',pending={kind='go',serial=12}}
  c.travel_owner=tr;d.route_owner=tr;d.route_serial=11;d.destination='2';d.route_destination='2';d.after_route='return_check';d.phase='route'
  c.current.room.id=2;c.current.room.area=nil;M.room(c,{num=2},true)
  check(cp.return_candidate and not cp.return_sequence,'committed own GO creates candidate only')
  tr.room='2';tr.pending=nil;tr.intent=nil;tr.route=nil;tr.phase='idle';d.borrowed=false;d.phase='return_check'
  return c,w,cp,d,tr
 end
 c,w,cp=candidate();M.room(c,{area='Hunt'},false);check(not cp.return_sequence,'area without explicit num cannot confirm candidate')
 room(c,2,'Hunt');check(cp.return_sequence and not cp.return_candidate,'full same-room confirmation after borrowed lease route settled')
 check(inspect(c)and M.restock_resume(c,cp,c.restock_data),'fresh inspection restores candidate once')
 for _,why in ipairs({'room','area','partialarea','lease','generation','epoch','class','owner','serial','routeserial','destination','phase','fault','unknown','revoke','departure'})do
  local d,tr;c,w,cp,d,tr=candidate()
  if why=='room'then room(c,99,'Hunt')elseif why=='area'then room(c,2,'Wrong')elseif why=='partialarea'then M.room(c,{area='Wrong'},false)
  elseif why=='lease'then c.restock_data={}elseif why=='generation'then w.offers=10 elseif why=='epoch'then w.intent_epoch=42 elseif why=='class'then c.current.player.class='Shaman'
  elseif why=='owner'then c.travel_owner={}elseif why=='serial'then tr.serial=13 elseif why=='routeserial'then d.route_serial=12 elseif why=='destination'then d.destination='99'
  elseif why=='phase'then d.phase='directory'elseif why=='fault'then tr.fault='unknown'elseif why=='unknown'then c.runner.transport_unknown=true
  elseif why=='revoke'then M.revoke(c,'operator intent')else d.borrowed=true;room(c,88,'Shop');d.borrowed=false end
  room(c,2,'Hunt');check(not cp.return_sequence and not cp.return_candidate,'candidate fenced by '..why)
  check(not M.restock_resume(c,cp,c.restock_data),'no forged restoration '..why)
 end
 -- No candidate: cached canonical area and later full same-room LOOK are not proof.
 c,w=fixture();cp=assert(M.restock_suspend(c,c.restock_data));c.restock_data.borrowed=true;room(c,88,'Shop')
 c.current.room.id=2;c.current.room.area='Hunt';M.room(c,{num=2},true);room(c,2,'Hunt')
 check(not cp.return_sequence and not cp.return_candidate,'full metadata without own native GO cannot invent return')
end)
print('walker_restock: '..count..' assertions passed')
