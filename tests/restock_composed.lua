-- OFFLINE ONLY: actual bootstrap/FSM/walker/travel/elementals/containers/buffs.
-- Only native GameIO, clock, mapper and GUI are synthetic. No client inheritance.
local root=(arg[1] or 'combat_v2/'):gsub('/+$','')..'/'
local realdofile,realopen,report=dofile,io.open,print
local haven_settings
-- Synthetic persisted travel configuration exercises the actual bootstrap's
-- optional-attachment ordering; no file is created and no controller is faked.
yajl={to_value=function(raw)assert(raw=='{"mount_id":"88001"}');return {mount_id='88001'}end}
io.open=function(path,mode)
 if path:match('/restock%-settings%.json$') and mode=='r' and haven_settings then return {read=function()return haven_settings end,close=function()end}end
 if path:match('/convenience%-settings%.json$') and mode=='r' then return {read=function()return '{"mount_id":"88001"}'end,close=function()end}end
 return realopen(path,mode)
end
local clock,ids,hooks,sent,popups
local tests,checks=0,0
local function eq(a,b,why) checks=checks+1;assert(a==b,(why or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function test(name,fn) if arg[2] and not name:find(arg[2],1,true) then return end;local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));tests=tests+1 end
local function add(kind,name,fn)ids=ids+1;hooks[ids]={kind=kind,name=name,fn=fn};return ids end
function getEpoch()return clock end
function getMudletHomeDir()local home=root:gsub('/?combat_v2/$','');return home=='' and '.' or home end
function getConnectionInfo()return 'offline synthetic',0,true end
function registerAnonymousEventHandler(name,fn)return add('event',name,fn)end
function killAnonymousEventHandler(id)hooks[id]=nil end
function tempAlias(name,fn)return add('alias',name,fn)end
function killAlias(id)hooks[id]=nil end
function tempRegexTrigger(name,fn)return add('line',name,fn)end
function tempPromptTrigger(fn)return add('prompt','',fn)end
function killTrigger(id)hooks[id]=nil end
function tempTimer(delay,fn)return add('timer',delay,fn)end
function killTimer(id)hooks[id]=nil end
function send(cmd)sent[#sent+1]=cmd;return true end
function sendGMCP()return true end
function getRoomArea()return 7 end
function getAreaRooms()return {1,2,3}end
function getRoomExits(id)return ({[1]={n=2},[2]={s=1,n=3},[3]={s=2}})[id]or {}end
function roomLocked()return false end
function getDoors()return {}end
function getRoomWeight()return 1 end
function getRooms()return {[12669]='Synthetic Directory',[2]='Synthetic Anchor'}end
function dofile(p)
 if p:match('/gui.lua$')then return {create=function()end,refresh=function()end,hide_walk_prompt=function()end,show_walk_prompt=function()popups=popups+1 end}end
 return realdofile(p)
end
print=function()end
local function multicast(kind,name)
 local selected={};for id,h in pairs(hooks)do if h.kind==kind and (not name or h.name==name)then selected[#selected+1]=id end end;table.sort(selected)
 for _,id in ipairs(selected)do if hooks[id]then hooks[id].fn()end end
end
local function text(s)line=s;multicast('line');line=nil end
local function prompt()multicast('prompt')end
local function event(name)multicast('event',name)end
local function count(command)local n=0;for _,s in ipairs(sent)do if s==command then n=n+1 end end;return n end
local function items(list)
 gmcp.Char=gmcp.Char or {};gmcp.Char.Items={List={location='room',items=list}};event('gmcp.Char.Items.List')
end
local function inspect(c,list)
 if not (c.current.hunting.ih and c.current.hunting.ih.active)then assert(combat_v2_start_ih('synthetic solicited inspection',true))end;items(list or {})
 for _=1,2 do
  if c.current.hunting.ih.active and c.ih_timer then
   local id=c.ih_timer;local timer=assert(hooks[id]);hooks[id]=nil;clock=clock+2;timer.fn();items(list or {})
  end
 end
end
local function fresh(enemy,cfg)
 haven_settings=cfg
 combat_v2=nil;gmcp={};clock=100;ids=0;hooks={};sent={};popups=0
 realdofile(root..'bootstrap.lua');local c=combat_v2;local s=c.current
 eq(c.travel.attached,true,'real travel owner attached before walker/restock')
 eq(c.restock_data.enabled,false,'default OFF');eq(#sent,0,'passive bootstrap');eq(popups,0)
 -- Synthetic pre-existing authorized BASH, not a public fresh activation.
 c.state.sync_gmcp(s,{Char={Status={class='Monk'},Vitals={hp=100,maxhp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1,mounted=0}}})
 s.player.class='Monk';s.player.stance='scorpion';s.player.mounted=false;s.connected=true
 s.room.id=2;s.room.area='Synthetic Hunt';s.room.items={};s.room.item_version=1
 s.policy.area='synthetic hunt';s.policy.areas={['synthetic hunt']=true};s.policy.areas_loaded=true;s.policy.players={};s.policy.players_known=true;s.policy.players_room=2;s.policy.self_name='self'
 c.mode='BASH';s.mode='BASH';c.runner.mode='BASH';s.hunting.active=true
 c.supplies.stock(c,'health',150,'offline synthetic baseline');c.supplies.stock(c,'ic:anabiotic',2000,'offline synthetic baseline');c.supplies_data.requested=true
 gmcp.Room={Info={num=2,area=s.room.area,exits={s=1,n=3}}}
 c.travel_owner.mount='88001' -- explicitly configured synthetic own mount
 c.travel.room(2);c.travel.vitals(0)
 if enemy then s.room.items={['99001']={id='99001',name='a massive elemental',attrib='m'}} end
 return c,s,c.restock_controller,c.restock_data
end
local KILL='You have slain a massive elemental.'
local SUCCESS='You concentrate on the raw elemental energy flowing about your body, coalescing some of its potential into a massive elemental.'
test('low cache suppresses actual own-kill spawn without holding current fight',function()
 local c,s,t,d=fresh(true);assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick()
 eq(d.phase,'drain');eq(d.resume_globe,true);eq(c.restock_boot.hold(c),false);eq(c.mode,'BASH')
 text(KILL);inspect(c,{});prompt();c.elementals.service(c);eq(count('summon elemental'),0,'LOW CACHE MUST SUPPRESS REAL GLOBE SPAWN');eq(c.elemental_recovery.armed,false);eq(d.resume_globe,true);eq(d.enabled,true)
end)
test('OFF before acquire restores only unchanged internally suppressed Globe intent',function()
 local c,s,t,d=fresh(true);assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick();assert(combat_v2_restock('off'))
 eq(c.elemental_recovery.armed,true,'restock-only OFF preserves original GLOBE');eq(c.mode,'BASH');eq(d.enabled,false);eq(d.reserved,false);eq(count('summon elemental'),0)
end)
test('explicit Globe OFF and XP cutoff independently suppress cancellation restoration',function()
 for _,why in ipairs({'globe','xp','class','session','epoch'})do
  local c,s,t,d=fresh(true);assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick()
  if why=='globe'then assert(combat_v2_globe('OFF'));eq(d.enabled,true)elseif why=='xp'then c.xp_globe_cutoff={enabled=true,triggered=true}elseif why=='class'then s.player.class='Shaman'elseif why=='session'then c.session_generation=22 else c.restock_intent_epoch=99 end
  combat_v2_restock('off');eq(c.elemental_recovery.armed,false,'no restoration after '..why);eq(count('summon elemental'),0)
 end
end)
test('unsent own-kill intent cancelled but unknown committed transaction retained',function()
 local c,s,t,d=fresh(true);assert(combat_v2_globe('on'));text(KILL);local g=c.elemental_recovery;eq(g.pending.phase,'normal');assert(combat_v2_restock('on'));t.tick();eq(g.pending,nil);eq(g.armed,false)
 c,s,t,d=fresh(true);assert(combat_v2_globe('on'));g=c.elemental_recovery;local p={phase='summon',kind='normal',started=clock,old_ids={}};g.pending=p;g.phase='summon';g.committed=true;g.fault='unknown transport';assert(combat_v2_restock('on'));t.tick();eq(g.pending,p);eq(g.committed,true);eq(g.fault,'unknown transport');eq(c.mode,'BASH')
end)
test('real read-only probe receives ACK then settles without native drain promotion',function()
 local c,s,t,d=fresh();inspect(c,{});assert(combat_v2_globe('on'));local g=c.elemental_recovery
 local p={phase='probe',kind='recovery',started=clock,dispatch_prompt=g.prompt};g.pending=p;g.phase='probe'
 assert(combat_v2_restock('on'));t.tick();eq(g.pending,p);eq(g.armed,true,'unsettled read-only probe must still ingest native ACK')
 text('This globe can be drained another 4 times.');eq(p.ack,true);prompt();eq(g.pending,nil,'known read-only probe settled status='..tostring(g.status)..' ready='..tostring(p.ready_prompt)..' fault='..tostring(g.fault));eq(g.armed,false);eq(g.committed,nil);eq(count('drain globe'),0);eq(count('summon elemental'),0)
end)
test('real committed summon bookkeeping settles then suppresses next own-kill spawn',function()
 local c,s,t,d=fresh(true);assert(combat_v2_globe('on'));local g=c.elemental_recovery
 local p={phase='summon',kind='normal',started=clock,dispatch_prompt=g.prompt,old_ids={}};g.pending=p;g.phase='summon';g.committed=true
 assert(combat_v2_restock('on'));t.tick();eq(g.pending,p);eq(g.armed,true);text(SUCCESS);prompt();eq(g.committed,nil);eq(g.pending,nil);c.elementals.service(c);eq(g.armed,false);text(KILL);prompt();eq(count('summon elemental'),0)
end)
local function walk_state(c)
 local w=c.walker.state(c.current)
 w.active=true;w.offers=9;w.graph=assert(c.walker.build(1,7,{['1']={area=7,exits={n=2}},['2']={area=7,exits={s=1,n=3}},['3']={area=7,exits={s=2}}}));w.area='Synthetic Hunt';w.start='1';w.steps=17;w.visited={['1']=true,['2']=true}
 return w
end
local MOUNT={id='88001',name='a synthetic loyal mount',attrib='mx'}
local function vitals(mounted,balance)
 gmcp.Char=gmcp.Char or {};gmcp.Char.Vitals={hp=100,maxhp=100,balance=balance or 1,equilibrium=1,left_arm=balance or 1,right_arm=balance or 1,mounted=mounted};event('gmcp.Char.Vitals')
end
local function arrive(room,area)
 gmcp.Room.Info={num=room,area=area,name=room==2 and 'Synthetic Anchor' or 'Synthetic Directory',exits=getRoomExits(room)};event('gmcp.Room.Info')
 gmcp.Room.Players={};event('gmcp.Room.Players')
end
local function drive_route(c,room,area)
 local tr=c.travel_owner
 if tr.pending and tr.pending.kind=='mount'then vitals('88001')end
 eq(tr.pending and tr.pending.kind,'find','real PATH FIND committed')
 text('Distance to '..(room==2 and 'Synthetic Anchor' or 'Synthetic Directory')..': 1.');text('Path: n');text('Use PATH GO to travel there.');prompt()
 eq(tr.pending and tr.pending.kind,'go','real native route ACK authorizes PATH GO')
 arrive(room,area);prompt();c.restock_controller.tick()
end
test('actual walker checkpoint captures exact lease and known canonical string area',function()
 local c,s,t,d=fresh();local w=walk_state(c)
 -- Reserve while scan is pending; native Items.List certifies before IH consumes it.
 assert(combat_v2_start_ih('synthetic checkpoint inspection',true));assert(combat_v2_restock('on'));t.tick();eq(d.phase,'drain');items({})
 t.tick();eq(d.fault,nil,'real walker resource lease capture');eq(d.busy,true);eq(d.checkpoint.lease,d);eq(d.checkpoint.area,'Synthetic Hunt');eq(d.checkpoint.graph,w.graph);eq(d.checkpoint.visited,w.visited);eq(d.checkpoint.steps,17);eq(w.active,false);eq(c.mode,'OFF');eq(d.pending.kind,'route');eq(d.destination,'12669');eq(popups,0)
 eq(c.restock_module.movement_borrowed(c),true);eq(c.travel_owner,c.travel.state);eq(c.travel.request('pt','999'),false)
end)
test('graceful independent OFF returns real native route and restores checkpoint once',function()
 local c,s,t,d=fresh();local w=walk_state(c)
 assert(combat_v2_start_ih('synthetic checkpoint inspection',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick()
 eq(d.fault,nil);local cp=d.checkpoint;eq(cp.lease,d);eq(c.travel_owner.pending.kind,'mount')
 assert(combat_v2_restock('off'));eq(d.enabled,false);eq(d.active,true)
 drive_route(c,12669,'Synthetic Shop');eq(d.fault,nil);eq(d.destination,'2');eq(cp.departed,true);eq(cp.cancelled,nil)
 drive_route(c,2,'Synthetic Hunt');eq(d.fault,nil);eq(cp.cancelled,nil);eq(cp.return_sequence~=nil,true);eq(c.mode,'BASH');eq(w.active,false)
 -- Real BASH preparation remains authorized; receive actual synthetic mounted
 -- and required-channel loss/recovery through the root multicast handlers.
 vitals(0,0);clock=clock+1;vitals(0,1)
 if s.hunting.ih and s.hunting.ih.active then items({MOUNT}) else inspect(c,{MOUNT})end
 prompt();t.tick();eq(d.fault,nil);eq(w.active,true,'exact original route resumed phase='..tostring(d.phase)..' ready='..tostring(t.io.view().ready)..' hold='..tostring(c.restock_boot.hold(c))..' waiting='..tostring(c.runner.waiting)..' status='..tostring(c.runner.status)..' ih='..tostring(s.hunting.ih and s.hunting.ih.pending)..' inspect='..tostring(w.inspection~=nil));eq(cp.resumed,true);eq(w.graph,cp.graph);eq(w.visited,cp.visited);eq(w.steps,17);eq(w.offers,9);eq(w.area,'Synthetic Hunt');eq(d.phase,'idle');eq(d.busy,false);eq(c.user_activity,nil);eq(popups,0);eq(count('directory health'),0);eq(count('buy '),0);eq(count('path go gallop'),2)
 eq(c.walker_boot.restock_resume(c,cp,d),false,'checkpoint cannot restore twice')
end)
test('stationary Globe trip creates no inactive walker checkpoint',function()
 local c,s,t,d=fresh();inspect(c,{});assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick()
 eq(d.fault,nil);eq(d.pending.kind,'route');eq(d.checkpoint,nil,'stationary BASH must not acquire inactive checkpoint');eq(s.walker.restock_checkpoint,nil);eq(d.resume_globe,true);eq(c.mode,'OFF')
end)
test('actual public retarget revokes checkpoint without dropping native route commitment',function()
 local c,s,t,d=fresh();local w=walk_state(c)
 assert(combat_v2_start_ih('synthetic checkpoint inspection',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick()
 local cp=d.checkpoint;local pending=d.pending;local native=c.travel_owner.pending
 combat_v2_set_target('a different synthetic enemy');eq(d.resume_consent,false,'public retarget immediately revokes restock resume');eq(d.active,false);eq(cp.cancelled~=nil,true);eq(w.restock_checkpoint,nil);eq(d.pending,pending);eq(c.travel_owner.pending,native);eq(w.active,false)
 t.tick();eq(w.active,false);eq(popups,0)
end)
test('idle OFF never poisons independent permission in actual bootstrap',function()
 for _,enabled in ipairs({false,true})do
  local c,s,t,d=fresh();if enabled then assert(combat_v2_restock('on'))else assert(combat_v2_restock('off'))end
  assert(combat_v2_set_mode('OFF'));eq(d.fault,nil,'IDLE OFF MUST NOT POISON RESTOCK');eq(d.resume_consent,false)
  assert(combat_v2_restock('on'));local n=#sent;t.tick();eq(c.mode,'OFF');eq(#sent,n,'Restock ON alone cannot act')
  assert(combat_v2_restock('off'));assert(combat_v2_restock('on'));combat_v2_set_mode('BASH');eq(c.mode,'BASH');inspect(c,{});t.tick();eq(d.fault,nil);eq(d.pending.kind,'route');eq(c.mode,'OFF')
 end
end)
test('partial Room.Info holds without false cancellation in actual bootstrap',function()
 for _,phase in ipairs({'drain','directory'})do
  local c,s,t,d=fresh();local w=walk_state(c)
  assert(combat_v2_start_ih('synthetic partial regression',true));assert(combat_v2_restock('on'));t.tick()
  if phase=='directory'then items({MOUNT});t.tick();drive_route(c,12669,'Synthetic Shop');eq(d.phase,'directory')end
  local function actions()local n=0;for _,cmd in ipairs(sent)do if cmd~='look' and cmd~='ih'then n=n+1 end end;return n end
  local cp=d.checkpoint;local p=d.pending;local n=actions()
  gmcp.Room.Info={name='partial, not movement'};event('gmcp.Room.Info')
  eq(d.fault,nil,'PARTIAL ROOM.INFO MUST NOT CANCEL RESTOCK');eq(d.active,true);if cp then eq(cp.cancelled,nil)end
  eq(s.room.id,nil,'canonical unknown must not be restored');eq(s.room.area,nil)
  prompt();t.tick();eq(d.fault,nil,'unknown scope tick must hold, not invent movement');eq(d.pending,p);eq(actions(),n,'unknown scope cannot dispatch phase='..phase..' sent='..table.concat(sent,' | '));eq(w.active,phase=='drain')
  gmcp.Room.Info={area=phase=='drain' and 'Synthetic Hunt' or 'Synthetic Shop'};event('gmcp.Room.Info');t.tick();eq(d.fault,nil);eq(actions(),n,'no-number metadata is not arrival')
  arrive(phase=='drain' and 2 or 12669,phase=='drain' and 'Synthetic Hunt' or 'Synthetic Shop');eq(d.fault,nil);if cp then eq(cp.cancelled,nil)end
 end
end)
test('explicit partial wrong location revokes actual checkpoint and retains pending',function()
 for _,info in ipairs({{num=99999},{area='Unexpected Area'}})do
  local c,s,t,d=fresh();walk_state(c);assert(combat_v2_start_ih('synthetic mismatch',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick();drive_route(c,12669,'Synthetic Shop')
  local cp=d.checkpoint;local pending=d.pending;gmcp.Room.Info=info;event('gmcp.Room.Info');eq(d.active,false);eq(d.resume_consent,false);assert(d.fault);assert(cp.cancelled);eq(d.pending,pending);eq(d.busy,true)
 end
end)
test('partial borrowed return cannot mint arrival or restore stale checkpoint evidence',function()
 local c,s,t,d=fresh();local w=walk_state(c);assert(combat_v2_start_ih('synthetic return partial',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick();local cp=d.checkpoint
 assert(combat_v2_restock('off'));drive_route(c,12669,'Synthetic Shop');eq(d.destination,'2');eq(cp.return_sequence,nil)
 text('Distance to Synthetic Anchor: 1.');text('Path: n');text('Use PATH GO to travel there.');prompt();eq(c.travel_owner.pending.kind,'go','genuine own return PATH GO')
 gmcp.Room.Info={num=2};event('gmcp.Room.Info');t.tick();eq(d.fault,nil);eq(cp.return_sequence,nil,'number-only is not CP permission');eq(w.active,false);eq(c.mode,'OFF');eq(d.pending.kind,'route')
 -- Native transport can settle before canonical area metadata arrives.
 prompt();eq(c.travel_owner.pending,nil)
 arrive(2,'Synthetic Hunt');eq(cp.return_sequence~=nil,true,'OWNED NUMBER-ONLY RETURN NEEDS LATER FULL SAME-ROOM PROOF');prompt();t.tick();eq(d.fault,nil);eq(c.mode,'BASH');eq(w.active,false)
 gmcp.Room.Info={name='partial at exact return'};event('gmcp.Room.Info');prompt();t.tick();eq(d.fault,nil);eq(w.active,false);eq(d.checkpoint_restored,nil)
 arrive(2,'Synthetic Hunt');t.tick();eq(d.fault,nil);eq(w.active,false,'complete metadata alone cannot replace fresh solo IH')
 vitals(0,0);clock=clock+1;vitals(0,1);inspect(c,{MOUNT});prompt();t.tick();eq(d.fault,nil);eq(w.active,true);eq(cp.resumed,true);eq(d.busy,false)
 eq(w.graph,cp.graph);eq(w.visited,cp.visited);eq(w.steps,17);eq(w.offers,9);eq(w.clear,nil);eq(w.inspection,nil);eq(c.walker_boot.restock_resume(c,cp,d),false,'number-only round-trip restores exactly once')
 local moves=count('n');eq(c.walker_boot.step(c),false,'old return IH cannot authorize next hop');eq(count('n'),moves)
 inspect(c,{MOUNT});eq(w.pending and w.pending.to,'3','fresh IH dispatches original route next hop');eq(count('n'),moves+1,'one next movement after new IH')
 assert(combat_v2_set_mode('OFF'));eq(d.fault,nil,'completed route identity cannot poison later idle OFF');eq(combat_v2_restock('on'),true)
end)
test('old query fault and native commitments survive public OFF in actual bootstrap',function()
 local c,s,t,d=fresh();walk_state(c);assert(combat_v2_start_ih('synthetic old fault',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick();drive_route(c,12669,'Synthetic Shop')
 local p=d.pending;local cp=d.checkpoint;local containers=c.containers_data;local root=c.runner.root;clock=clock+61;t.tick();local fault=d.fault;assert(fault);assert(d.query_quarantine)
 combat_v2_restock('off');combat_v2_set_mode('OFF');eq(d.fault,fault);eq(d.pending,p);eq(d.busy,true);assert(cp.cancelled);eq(c.containers_data,containers);eq(c.runner.root,root);eq(combat_v2_restock('on'),false)
end)
test('actual number-only candidate rejects wrong metadata and operator intent',function()
 for _,why in ipairs({'wrongarea','partialwrongarea','missingnum','retarget','mode','walkoff','disconnect','newconsent'})do
  local c,s,t,d=fresh();local w=walk_state(c);assert(combat_v2_start_ih('candidate fences',true));assert(combat_v2_restock('on'));t.tick();items({MOUNT});t.tick();local cp=d.checkpoint
  assert(combat_v2_restock('off'));drive_route(c,12669,'Synthetic Shop')
  text('Distance to Synthetic Anchor: 1.');text('Path: n');text('Use PATH GO to travel there.');prompt();eq(c.travel_owner.pending.kind,'go')
  gmcp.Room.Info={num=2};event('gmcp.Room.Info');assert(cp.return_candidate);eq(cp.return_sequence,nil)
  local ok,reason=t.io.restore_checkpoint(cp,d);eq(ok,false);eq(reason,'awaiting exact return room','real native adapter preserves actual walker waiting reason')
  if why=='wrongarea'then arrive(2,'Wrong')elseif why=='partialwrongarea'then gmcp.Room.Info={area='Wrong'};event('gmcp.Room.Info')
  elseif why=='missingnum'then gmcp.Room.Info={area='Synthetic Hunt'};event('gmcp.Room.Info');eq(cp.return_sequence,nil);eq(w.active,false);eq(s.room.id,nil);arrive(2,'Synthetic Hunt');assert(cp.return_sequence);eq(w.active,false)
  elseif why=='retarget'then combat_v2_set_target('manual')elseif why=='mode'then combat_v2_set_mode('OFF')elseif why=='walkoff'then combat_v2_walk('off')elseif why=='disconnect'then s.connected=false;event('sysDisconnectionEvent')else c.walker_boot.offer(c)end
  if why~='missingnum'then assert(cp.cancelled,'permanent revocation '..why);eq(cp.return_candidate,nil);arrive(2,'Synthetic Hunt');eq(c.walker_boot.restock_resume(c,cp,d),false);eq(w.active,false)end
 end
end)
test('native adapter preserves checkpoint awaiting reason and thrown errors',function()
 local c,s,t,d=fresh();local real=c.walker_boot.restock_resume
 c.walker_boot.restock_resume=function()return false,'awaiting exact return room'end
 local ok,why=t.io.restore_checkpoint({},d);eq(ok,false);eq(why,'awaiting exact return room','ADAPTER MUST PRESERVE SECOND RETURN')
 c.walker_boot.restock_resume=function()error('synthetic checkpoint throw')end
 local good,err=pcall(t.io.restore_checkpoint,{},d);eq(good,false);assert(tostring(err):find('synthetic checkpoint throw',1,true))
 c.walker_boot.restock_resume=real
end)
test('native Haven conditional exit and return uses ID despite renamed labels',function()
 local c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}')
 eq(c.restock_settings.haven_room,'73009');eq(d.enabled,false)
 c.policy.set_approved_rooms(s,{['73009']=true});arrive(73009,'Old Private Label');inspect(c,{})
 s.player.mana=100;s.player.maxmana=100
 assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick()
 eq(d.fault,nil);eq(d.phase,'haven_exit');eq(count('exit haven'),1);eq(count('path find 12669'),0);eq(d.checkpoint,nil)
 clock=clock+21;prompt();eq(d.phase,'haven_exit');eq(count('path find 12669'),0)
 arrive(73008,'Outside');items({MOUNT});prompt();t.tick();eq(d.fault,nil);eq(d.pending.kind,'route')
 -- Native path/actual arrival proves shopping handoff; graceful helper OFF
 -- cancels all unissued purchases without revoking the original GLOBE grant.
 assert(combat_v2_restock('off'));s.player.mana=99;drive_route(c,12669,'Synthetic Shop');eq(d.phase,'haven_wait')
 t.tick();eq(count('return to haven'),0);s.player.mana=100;t.tick();eq(d.pending.kind,'haven_return');eq(count('return to haven'),1)
 clock=clock+21;prompt();eq(d.pending.kind,'haven_return');eq(c.mode,'OFF');eq(count('path find 73009'),0)
 -- XP latch revokes future globe restoration but cannot unsend Haven transport.
 c.xp_globe_cutoff={enabled=true,triggered=true};arrive(73009,'Renamed Private Label');prompt();t.tick();eq(d.fault,nil);eq(c.mode,'BASH')
 vitals(0,0);clock=clock+1;vitals(0,1);inspect(c,{});prompt();t.tick()
 eq(d.fault,nil);eq(d.busy,false);eq(c.elemental_recovery.armed,false);eq(count('summon elemental'),0);eq(count('exit haven'),1);eq(count('return to haven'),1);eq(s.walker.active,false)
end)
test('native completed readonly fault releases lease and explicit mode controls only',function()
 local c,s,t,d=fresh();inspect(c,{MOUNT});assert(combat_v2_restock('on'));t.tick();drive_route(c,12669,'Synthetic Shop')
 eq(d.pending.kind,'directory');text('You can locate the listed shops by doing PATH FIND <vnum>.');prompt();t.tick()
 assert(d.fault);eq(d.recoverable,true);eq(d.busy,false);eq(c.user_activity,nil);eq(c.mode,'OFF');eq(c.restock_boot.hold(c),false)
 combat_v2_set_mode('SHADOW');eq(c.mode,'SHADOW');assert(d.fault);eq(combat_v2_globe('status'),true);eq(combat_v2_restock('on'),false)
end)
test('present invalid settings inhibit only new restock, absent retains ordinary trips',function()
 for _,raw in ipairs({'{"haven_room":"73009","globe_haven_return":tru}','{}'})do
  local c,s,t,d=fresh(false,raw);assert(c.restock_settings_error);assert(d.configuration_error)
  inspect(c,{MOUNT});assert(combat_v2_globe('on'));eq(combat_v2_restock('on'),false);t.tick()
  eq(d.pending,nil);eq(d.busy,false);eq(d.fault,nil);eq(c.restock_boot.hold(c),false);eq(count('quickmount 88001'),0);eq(count('path find 12669'),0)
  assert(combat_v2_restock('off'));eq(combat_v2_restock('on'),false);eq(c.mode,'BASH')
  -- Repair requires an explicit validated config and idle reattachment, not a fault reset.
  assert(c.restock_module.detach(c));assert(c.restock_module.attach(c,assert(c.restock_module.settings_json('{"haven_room":"73009","globe_haven_return":true}'))))
  eq(c.restock_settings_error,nil);eq(c.restock_data.configuration_error,nil);assert(combat_v2_restock('on'))
 end
 local c,s,t,d=fresh();inspect(c,{MOUNT});assert(combat_v2_restock('on'));t.tick();eq(d.pending.kind,'route')
end)
test('native private session hook is passive unique and invalidates every disconnect',function()
 local c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}')
 local T=c.travel_module;local tr=c.travel_owner;assert(c.haven_session_token);local token=c.haven_session_token;local handle=c.haven_session_binding.handle
 assert(T.bind_session(c,_G));eq(c.haven_session_token,token);eq(c.haven_session_binding.handle,handle)
 arrive(73009,'Private');tr.follow_due=true;tr.follow_episode=27;T.haven_deferred(c);local f=assert(c.haven_handoff.deferred_follow);eq(f.session,token);eq(tr.follow_due,nil)
 event('sysDisconnectionEvent');assert(c.haven_session_token~=token);local next_token=c.haven_session_token;event('sysDisconnectionEvent');assert(c.haven_session_token~=next_token)
 local fault=tr.fault;arrive(73008,'Outside');items({MOUNT});eq(T.haven_deferred(c),true);eq(c.haven_handoff.deferred_follow,f);eq(tr.follow_due,nil);eq(tr.fault,fault);eq(count('order 88001 follow me'),0)
end)
test('missing stale and legacy session or episode never restore deferred intent',function()
 for _,why in ipairs({'missing_session','missing_current','stale_session','old_episode','missing_episode','pending','fault','legacy'})do
  local c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}');local T=c.travel_module;local tr=c.travel_owner
  arrive(73009,'Private');tr.follow_due=true;tr.follow_episode=4;T.haven_deferred(c);local f=assert(c.haven_handoff.deferred_follow)
  if why=='missing_session'then f.session=nil elseif why=='missing_current'then c.haven_session_token=nil elseif why=='stale_session'then f.session={} elseif why=='old_episode'then tr.follow_episode=5 elseif why=='missing_episode'then f.episode=nil elseif why=='pending'then tr.follow_pending={} elseif why=='fault'then tr.follow_fault='unknown FOLLOW' else f.session=nil;f.version=nil end
  local pending=tr.follow_pending;local fault=tr.follow_fault
  arrive(73008,'Outside');items({MOUNT});eq(T.haven_deferred(c),true);eq(c.haven_handoff.deferred_follow,f);eq(tr.follow_due,nil);eq(tr.follow_pending,pending);eq(tr.follow_fault,fault);eq(count('order 88001 follow me'),0)
 end
end)
test('same native session and episode still require newer full outside presence',function()
 local c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}');local T=c.travel_module;local tr=c.travel_owner
 arrive(73009,'Private');tr.follow_due=true;tr.follow_episode=4;T.haven_deferred(c);local f=assert(c.haven_handoff.deferred_follow)
 arrive(73008,'Outside');eq(T.haven_deferred(c),true);items({MOUNT});eq(c.haven_handoff.deferred_follow,f);prompt();eq(c.haven_handoff.deferred_follow,nil)
end)
-- Room.Info does not promise an unsolicited Items.List while native core is OFF.
local function owned_exit()
 local c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}')
 c.policy.set_approved_rooms(s,{['73009']=true});arrive(73009,'Private');inspect(c,{MOUNT})
 s.player.mana=100;s.player.maxmana=100
 local tr=c.travel_owner;tr.follow_due=true;tr.follow_episode=27
 c.travel_module.haven_deferred(c);local f=assert(c.haven_handoff.deferred_follow)
 assert(combat_v2_globe('on'));assert(combat_v2_restock('on'));t.tick()
 eq(d.phase,'haven_exit');eq(count('exit haven'),1)
 return c,s,t,d,tr,f
end
local CONTENTS='Char.Items.Contents "room"'
test('owned outside handoff requests one read only full list and waits without gameplay',function()
 local c,s,t,d,tr,f=owned_exit();local requests=0;local prior=sendGMCP
 sendGMCP=function(cmd)eq(cmd,CONTENTS);requests=requests+1;return true end
 local before=#sent;arrive(73008,'Outside')
 -- Views and Room.Info capture evidence only; pump owns query dispatch.
 for i=1,4 do t.io.view() end;eq(requests,0)
 for i=1,8 do clock=clock+1;prompt();c.travel.tick();t.tick() end
 eq(requests,1);eq(#sent,before);eq(c.travel_module.haven_deferred(c),true);eq(c.haven_handoff.deferred_follow,f)
 eq(tr.pending,nil);eq(tr.follow_due,nil);eq(tr.recall_due,nil)
 local v=tr.item_version
 eq(c.travel.items(73007,{MOUNT},true,v+1),false)
 c.travel.items(73008,{MOUNT},false,v+1);eq(c.haven_handoff.deferred_follow,f);eq(#sent,before)
 eq(c.travel.items(73008,{MOUNT},true,v+1),false);eq(#sent,before)
 items({MOUNT});items({MOUNT});prompt();t.tick()
 eq(c.haven_handoff.deferred_follow,nil);eq(tr.haven_refresh.complete,true);eq(requests,1);eq(count('order 88001 follow me'),1)
 eq(tr.pending,nil);eq(tr.follow_pending~=nil,true);prompt();t.tick()
 eq(tr.pending and tr.pending.kind,'mount');eq(count('recall 88001'),0);eq(count('path go gallop'),0)
 sendGMCP=prior
end)
test('full outside absence releases deferral but grants no native safety bypass',function()
 local c,s,t,d,tr,f=owned_exit();local prior=sendGMCP;local requests=0
 sendGMCP=function(cmd)eq(cmd,CONTENTS);requests=requests+1;return true end
 local before=#sent;arrive(73008,'Outside');c.travel.tick();eq(requests,1);eq(#sent,before)
 items({});eq(c.haven_handoff.deferred_follow,f);eq(tr.present,false);eq(tr.presence_room,'73008');prompt();eq(c.haven_handoff.deferred_follow,nil)
 -- Read-only authority never overrides the existing lease/safety gameplay guard.
 eq(tr.recall_due,true);eq(count('recall 88001'),0);eq(count('path go gallop'),0)
 sendGMCP=prior
end)
test('owned read only query reserves attempt before reentrant true false or throw',function()
 for _,outcome in ipairs({'true','false','throw'})do
  local c,s,t,d,tr,f=owned_exit();local requests=0;local prior=sendGMCP;local before=#sent
  sendGMCP=function(cmd)
   eq(cmd,CONTENTS);requests=requests+1
   eq(tr.haven_refresh.dispatching,true);eq(c.travel.request('rh'),false);eq(c.travel.request('qm'),false);eq(c.travel.request('qd'),false)
   items({MOUNT});prompt();c.travel.tick();t.tick()
   eq(c.travel_module.haven_deferred(c),true);eq(c.haven_handoff.deferred_follow,f);eq(#sent,before)
   if outcome=='throw'then error('synthetic readonly wire')end;return outcome=='true'
  end
  arrive(73008,'Outside');c.travel.tick()
  eq(requests,1)
  if outcome=='true'then
   prompt();t.tick();eq(c.haven_handoff.deferred_follow,nil);eq(count('order 88001 follow me'),1)
  else
   assert(tr.haven_refresh.quarantine);eq(tr.fault,nil);eq(tr.follow_fault,nil)
   for i=1,8 do clock=clock+1;prompt();c.travel.tick();t.tick()end
   items({MOUNT});eq(requests,1);eq(#sent,before);eq(c.travel_module.haven_deferred(c),true)
   eq(c.travel.cancel(),true,'unsent route can be revoked despite readonly quarantine')
   eq(combat_v2_globe('status'),true,'read-only controls stay usable')
  end
  sendGMCP=prior
 end
end)
test('outside read only timeout malformed and revoked scope never retry or release',function()
 for _,why in ipairs({'timeout','malformed','revoked'})do
  local c,s,t,d,tr,f=owned_exit();local requests=0;local prior=sendGMCP
  sendGMCP=function(cmd)eq(cmd,CONTENTS);requests=requests+1;return true end
  local before=#sent;arrive(73008,'Outside');c.travel.tick();eq(requests,1)
  if why=='timeout'then clock=clock+21;c.travel.tick();assert(tr.haven_refresh.quarantine)
  elseif why=='malformed'then eq(c.travel.items(73008,{'bad row'},true,tr.item_version+1),false);assert(tr.haven_refresh.quarantine)
  else d.resume_consent=false end
  items({MOUNT});for i=1,8 do prompt();c.travel.tick()end
  eq(requests,1);eq(#sent,before);eq(c.travel_module.haven_deferred(c),true);eq(c.haven_handoff.deferred_follow,f);eq(tr.fault,nil)
  sendGMCP=prior
 end
end)
test('owned outside read lane rejects absent provenance wrong owner and physical barriers',function()
 for _,why in ipairs({'nil_session','current_session','session','episode','owner','lease','consent','active','root','follow','recall','fault','noexit','unknownroom'})do
  local c,s,t,d,tr,f=owned_exit();local requests=0;local prior=sendGMCP
  sendGMCP=function()requests=requests+1;return true end
  local before=#sent;arrive(73008,'Outside')
  if why=='nil_session'then f.session=nil elseif why=='current_session'then c.haven_session_token=nil
  elseif why=='session'then f.session={} elseif why=='episode'then tr.follow_episode=28
  elseif why=='owner'then f.owner={} elseif why=='lease'then c.user_activity={}
  elseif why=='consent'then d.resume_consent=false elseif why=='active'then d.active=false
  elseif why=='root'then c.runner.root={transport_unknown=true}
  elseif why=='follow'then tr.follow_pending={at=clock,prompt=tr.prompt,episode=27}
  elseif why=='recall'then tr.pending={kind='recall',at=clock,prompt=tr.prompt,serial=tr.serial}
  elseif why=='fault'then tr.follow_fault='unknown follow'
  elseif why=='noexit'then tr.haven_outside=nil else s.room.id=nil;s.room.area=nil end
  local pending=tr.pending;local fp=tr.follow_pending;local fault=tr.follow_fault
  for i=1,4 do c.travel.tick()end
  eq(requests,0,'query fence '..why);eq(#sent,before);eq(tr.pending,pending);eq(tr.follow_pending,fp);eq(tr.follow_fault,fault)
  sendGMCP=prior
 end
end)
test('outside query fences both facade and shared roots at actual sender',function()
 for _,target in ipairs({'facade','shared','runner'})do
  for _,field in ipairs({'fault','transport_unknown','dispatching','action_dispatching','transportBarriers','transport_barriers','transport_barrier','transport_commit'})do
   local c,s,t,d,tr,f=owned_exit();local prior=sendGMCP;local requests=0
   sendGMCP=function()requests=requests+1;return true end
   arrive(73008,'Outside');local w=tr.haven_outside
   local shared=c.runner.root or {};c.root=shared;c.runner.root={}
   local obj=target=='shared' and shared or target=='facade' and c.runner.root or c.runner
   obj[field]=field:find('transport') and {unknown=true} or true
   eq(c.travel.io.deferred_refresh_ready(w),nil)
   eq(c.travel.io.refresh_items(w),false);c.travel.tick();eq(requests,0,target..'.'..field)
   eq(c.haven_handoff.deferred_follow,f);sendGMCP=prior
  end
 end
end)
test('empty uncertainty maps do not deadlock the owned read lane',function()
 local c,s,t,d,tr=owned_exit();local prior=sendGMCP;local requests=0
 c.runner.root={transportBarriers={}};c.runner.transport_barriers={};c.runner.transport_commit=false
 sendGMCP=function()requests=requests+1;return true end
 arrive(73008,'Outside');c.travel.tick();eq(requests,1);sendGMCP=prior
end)
test('full snapshot and successful transport each need a strictly later prompt',function()
 for _,sync in ipairs({false,true})do
  local c,s,t,d,tr,f=owned_exit();local prior=sendGMCP;local requests=0;local n=#sent
  sendGMCP=function()
   requests=requests+1
   if sync then items({MOUNT});prompt();eq(#sent,n)end
   return true
  end
  arrive(73008,'Outside');c.travel.tick();eq(requests,1)
  if not sync then items({MOUNT})end
  local q=tr.haven_refresh;local fence=q.itemResponsePromptSequence
  eq(c.haven_handoff.deferred_follow,f);eq(#sent,n)
  for i=1,4 do items({MOUNT});c.travel.tick();t.tick();eq(#sent,n);eq(q.itemResponsePromptSequence,fence)end
  eq(c.travel.request('qd'),false);eq(#sent,n)
  prompt();eq(c.haven_handoff.deferred_follow,nil);eq(q.complete,true);eq(count('order 88001 follow me'),1)
  -- Completed proof is inert, including late unrelated full absence snapshots.
  c.travel.items(73008,{},true,tr.item_version+1);eq(q.quarantine,nil);eq(q.itemResponsePromptSequence,fence)
  sendGMCP=prior
 end
end)
test('unsolicited full owned exit revalidates scope before and after actual arrival',function()
 for _,when in ipairs({'before','after'})do
  for _,why in ipairs({'consent','active','lease','stop','session','episode','owner'})do
   local c,s,t,d,tr,f=owned_exit();local prior=sendGMCP;local requests=0;local n=#sent
   sendGMCP=function()requests=requests+1;return true end
   if when=='after'then arrive(73008,'Outside')end
   if why=='consent'then d.resume_consent=false elseif why=='active'then d.active=false
   elseif why=='lease'then c.user_activity={} elseif why=='stop'then assert(combat_v2_set_mode('OFF'))
   elseif why=='session'then c.haven_session_token={} elseif why=='episode'then tr.follow_episode=28 else f.owner={}end
   if when=='before'then arrive(73008,'Outside')end
   assert(tr.haven_outside,'issued EXIT provenance survives revoked arrival '..why)
   local pending=d.pending;local fault=d.fault
   items({MOUNT});eq(#sent,n,'no pre-prompt gameplay '..when..' '..why)
   for i=1,3 do prompt();c.travel.tick()end
   eq(requests,0);eq(tr.haven_refresh,nil);eq(#sent,n,when..' '..why)
   eq(c.haven_handoff.deferred_follow,f);eq(tr.follow_due,nil);eq(tr.recall_due,nil)
   if fault then eq(d.fault,fault,'existing unknown fault survives')end;if pending then eq(pending.transport_ok,true)end
   eq(combat_v2_globe('status'),true,'read-only UI stays available')
   sendGMCP=prior
  end
 end
end)
test('unsolicited full never promotes deferred intent through root uncertainty',function()
 for _,owned in ipairs({true,false})do
  for _,target in ipairs({'shared','facade','runner'})do
   for _,field in ipairs({'fault','transport_unknown','dispatching','action_dispatching','transportBarriers','transport_barriers','transport_barrier','transport_commit'})do
    local c,s,t,d,tr,f
    if owned then c,s,t,d,tr,f=owned_exit()else
     c,s,t,d=fresh(false,'{"haven_room":"73009","globe_haven_return":true}');tr=c.travel_owner
     arrive(73009,'Private');tr.follow_due=true;tr.follow_episode=27;c.travel_module.haven_deferred(c);f=assert(c.haven_handoff.deferred_follow)
    end
    local prior=sendGMCP;local requests=0;sendGMCP=function()requests=requests+1;return true end
    arrive(73008,'Outside');local n=#sent
    local shared=c.runner.root or {};c.root=shared;c.runner.root={}
    local obj=target=='shared' and shared or target=='facade' and c.runner.root or c.runner
    local token=field:find('transport') and {unknown=true} or true;obj[field]=token
    items({MOUNT});prompt();c.travel.tick()
    eq(requests,0);eq(#sent,n);eq(c.haven_handoff.deferred_follow,f);eq(tr.follow_due,nil,target..'.'..field)
    eq(obj[field],token,'unknown barrier preserved');eq(tr.haven_refresh,nil)
    -- Clear only the synthetic fault: no FOLLOW was latently restored while held.
    obj[field]=nil;eq(tr.follow_due,nil);eq(c.haven_handoff.deferred_follow,f)
    sendGMCP=prior
   end
  end
 end
end)
test('valid unsolicited owned full waits for later prompt when no query sent',function()
 local c,s,t,d,tr,f=owned_exit();local prior=sendGMCP;local requests=0;local n=#sent
 -- Exercise the passive no-query lane with the optional query transport absent.
 c.travel.io.refresh_items=nil
 sendGMCP=function()requests=requests+1;return true end
 arrive(73008,'Outside');items({MOUNT})
 eq(requests,0);eq(tr.haven_refresh,nil);eq(#sent,n);eq(c.haven_handoff.deferred_follow,f)
 prompt();eq(c.haven_handoff.deferred_follow,nil);eq(count('order 88001 follow me'),1);eq(requests,0)
 sendGMCP=prior
end)
test('Globe OFF terminal exhaustion passes real walker gate and owned ordinary route',function()
 for _,closed in ipairs({false,true})do
 for _,walking in ipairs({false,true})do
  local c,s,t,d=fresh(false,'{"haven_room":"73077","globe_haven_return":true}')
  c.supplies.stock(c,'health',199,'offline low cache');c.supplies.stock(c,'ic:anabiotic',1200,'offline low cache')
  local w=walking and walk_state(c)or s.walker;local graph=w.graph;local visited=w.visited
  local g=c.elemental_recovery
  g.armed=false;g.fault='all carried globes exhausted';g.phase='waiting';g.pending={phase='waiting'}
  g.pool={enabled=true,known=true,ever_owned=true,owned={},exhausted={}}
  if closed then
   g.phase='idle';g.status='disarmed';g.pending=nil
   g.pool.enabled=false;g.pool.known=false;g.pool.dispatching=false
  end
  local pending=g.pending;local pool=g.pool
  eq(t.io.view().ready,true,'restock view recognizes terminal exhaustion')
  eq(c.travel_module.blocked(c),false,'travel admits only proven non-transport terminal diagnostic')
  assert(combat_v2_start_ih('terminal exhaustion checkpoint inspection',true))
  assert(combat_v2_restock('on'));t.tick();eq(d.phase,'drain');items({MOUNT})
  eq(c.walker_boot.restock_ready(c),true,'terminal diagnostic must pass actual walker resources gate')
  eq(g.pending,pending,'classification must preserve bookkeeping');eq(g.pool,pool);eq(g.fault,'all carried globes exhausted')
  t.tick()
  eq(d.fault,nil);eq(d.busy,true);eq(d.pending.kind,'route');eq(d.destination,'12669');eq(d.resume_globe,false)
  eq(c.mode,'OFF');eq(c.travel_owner.pending.kind,'mount')
  local cp=d.checkpoint
  if walking then eq(cp.lease,d);eq(cp.graph,graph);eq(cp.visited,visited);eq(cp.steps,17);eq(w.active,false)
  else eq(cp,nil,'stationary trip needs no checkpoint')end
  -- Native travel, not a mocked readiness adapter, must send the first FIND.
  vitals('88001');eq(c.travel_owner.pending.kind,'find');eq(count('path find 12669'),1)
  -- Graceful independent OFF still returns by native travel and restores consent once.
  assert(combat_v2_restock('off'));drive_route(c,12669,'Synthetic Shop');drive_route(c,2,'Synthetic Hunt')
  vitals(0,0);clock=clock+1;vitals(0,1);inspect(c,{MOUNT});prompt();t.tick()
  eq(d.fault,nil);eq(d.phase,'idle');eq(c.mode,'BASH');eq(d.busy,false)
  if walking then eq(cp.resumed,true);eq(w.active,true);eq(w.graph,graph);eq(w.visited,visited);eq(w.steps,17);eq(w.offers,9);eq(c.walker_boot.restock_resume(c,cp,d),false)end
  eq(count('exit haven'),0);eq(count('return to haven'),0);eq(count('summon elemental'),0);eq(count('drain globe'),0)
  -- Existing native mode-OFF disarm may discard known unsent intent after
  -- acquisition; neither pure classifier nor the resource gate does so.
  eq(g.fault,'all carried globes exhausted');eq(g.pool,pool);eq(g.armed,false)
 end
 end
end)
local function retired(c)
 local g=c.elemental_recovery
 g.armed=false;g.phase='idle';g.status='disarmed';g.pending=nil;g.committed=nil;g.dispatching=nil;g.fault='all carried globes exhausted'
 g.pool={enabled=false,known=false,ever_owned=true,owned={},exhausted={},query=nil,dispatching=false,room=71001}
 return g
end
test('closed exhausted owner OFF monitor remains entirely passive',function()
 local c,s,t,d=fresh();assert(combat_v2_set_mode('OFF'));local g=retired(c);local pool=g.pool
 local prior=sendGMCP;local queries=0;sendGMCP=function()queries=queries+1;return true end
 assert(combat_v2_restock('on'));local before=#sent
 for i=1,5 do clock=clock+1;prompt();c.travel.tick();t.tick()end
 eq(#sent,before);eq(queries,0);eq(c.mode,'OFF');eq(g.armed,false);eq(pool.enabled,false);eq(pool.known,false);eq(g.pool,pool);eq(g.fault,'all carried globes exhausted');eq(d.enabled,true)
 local view=t.io.view();eq(view.globes_exhausted,true);eq(view.globe_pool_ready,false);eq(view.globe_desired,false);eq(view.globe_fault,g.fault)
 sendGMCP=prior
 -- Later explicit BASH consent may start only the ordinary native route.
 combat_v2_set_mode('BASH');eq(c.mode,'BASH');eq(g.armed,false)
 inspect(c,{MOUNT});t.tick();eq(d.fault,nil);eq(d.pending.kind,'route');eq(d.destination,'12669');eq(d.resume_globe,false)
 eq(count('exit haven'),0);eq(count('return to haven'),0);eq(count('summon elemental'),0);eq(count('drain globe'),0)
end)
test('restock shares typed helper and retains independent resource fences',function()
 for _,why in ipairs({'valid','missing','wrongtype','nontyped','throw','false','legacy','legacy_wrongtype','legacy_nontyped','legacy_throw','legacy_false','root','transport','defense','pending','commit','query','probe','stale_desired'})do
  local c,s,t,d=fresh(false,'{"haven_room":"73077","globe_haven_return":true}');local g=retired(c)
  if why=='missing'then c.travel_module.terminal_globe_exhaustion=nil
  elseif why=='wrongtype'then c.travel_module.terminal_globe_exhaustion=true
  elseif why=='nontyped'then c.travel_module.terminal_globe_exhaustion=function()return 'true'end
  elseif why=='throw'then c.travel_module.terminal_globe_exhaustion=function()error('synthetic classifier failure')end
  elseif why=='false'then c.travel_module.terminal_globe_exhaustion=function()return false end
  elseif why=='legacy'then c.travel_module=nil;g.pool.enabled=true;g.pool.known=true
  elseif why=='root'then c.runner.root={transport_unknown=true}
  elseif why=='transport'then c.transport_unknown=true
  elseif why=='defense'then c.defense.plan=function()return {hold=true}end
  elseif why=='pending'then g.pending={};g.phase='waiting'
  elseif why=='commit'then g.committed=true
  elseif why=='query'then g.pool.query={}
  elseif why=='probe'then g.phase='probe';g.pending={phase='probe',kind='recovery'}
  elseif why=='stale_desired'then g.desiredOnCurrent=true end
  local legacy=why:match('^legacy')~=nil
  if legacy and why~='legacy'then
   g.pool.enabled=true;g.pool.known=true
   if why=='legacy_wrongtype'then c.travel_module.terminal_globe_exhaustion=true
   elseif why=='legacy_nontyped'then c.travel_module.terminal_globe_exhaustion=function()return 'true'end
   elseif why=='legacy_throw'then c.travel_module.terminal_globe_exhaustion=function()error('synthetic fully-known helper failure')end
   else c.travel_module.terminal_globe_exhaustion=function()return false end end
  end
  local view=t.io.view()
  eq(view.ready,why=='valid'or why=='legacy','restock view '..why)
  eq(view.globe_pool_ready,legacy,'no invented inventory authority '..why)
  if why=='stale_desired'then
   inspect(c,{MOUNT});assert(combat_v2_restock('on'));local before=#sent;t.tick();eq(d.pending,nil);eq(#sent,before);eq(count('exit haven'),0);eq(g.armed,false)
  end
 end
end)
test('terminal exhaustion exception rejects unknown pool pending and physical commitments',function()
 for _,why in ipairs({'valid_empty','valid_owned','armed','commit','dispatch','query','pool_dispatch','unknown','disabled','never_owned','missing_owned','missing_exhausted','bad_owned','bad_id','not_exhausted','probe','phase','kind','fault','shared','facade','runner'})do
  local c=fresh();local g=c.elemental_recovery
  g.armed=false;g.fault='all carried globes exhausted';g.phase='waiting';g.pending={phase='waiting'}
  local q={enabled=true,known=true,ever_owned=true,owned={},exhausted={}};g.pool=q
  if why=='valid_owned'then q.owned['88002']=true;q.exhausted['88002']=true
  elseif why=='armed'then g.armed=true elseif why=='commit'then g.committed=true elseif why=='dispatch'then g.dispatching=true
  elseif why=='query'then q.query={} elseif why=='pool_dispatch'then q.dispatching=true elseif why=='unknown'then q.known=false
  elseif why=='disabled'then q.enabled=false elseif why=='never_owned'then q.ever_owned=false
  elseif why=='missing_owned'then q.owned=nil elseif why=='missing_exhausted'then q.exhausted=nil
  elseif why=='bad_owned'then q.owned['88002']=false elseif why=='bad_id'then q.owned['bad']=true;q.exhausted.bad=true
  elseif why=='not_exhausted'then q.owned['88002']=true
  elseif why=='probe'then g.phase='probe';g.pending={phase='probe',kind='recovery'}
  elseif why=='phase'then g.pending.phase='normal' elseif why=='kind'then g.pending.kind='normal'
  elseif why=='fault'then g.fault='owned inventory query failed'
  elseif why=='shared'then c.root={fault='unknown'};c.runner.root={}
  elseif why=='facade'then c.root={};c.runner.root={transport_barriers={unknown=true}}
  elseif why=='runner'then c.runner.transport_commit={}end
  local pending=g.pending;local fault=g.fault;local pool=g.pool
  local valid=why=='valid_empty'or why=='valid_owned'
  local root_fault=why=='shared'or why=='facade'or why=='runner'
  eq(c.travel_module.terminal_globe_exhaustion(c),valid or root_fault,'pure classification '..why)
  eq(c.travel_module.blocked(c),not valid,why)
  if not root_fault then eq(c.walker_boot.restock_ready(c),valid,'real resource gate '..why)end
  eq(g.pending,pending);eq(g.fault,fault);eq(g.pool,pool)
 end
end)
test('terminal helper fails closed and never bypasses independent walker resources',function()
 for _,why in ipairs({'absent','nontyped','false','no_pending','normal','wrong_phase','probe_timeout','runner','mental','buff','container','transport','inking','recall','follow','hop','arrival'})do
  local c,s=fresh();local g=c.elemental_recovery
  g.armed=false;g.fault='all carried globes exhausted';g.phase='waiting';g.pending={phase='waiting'}
  g.pool={enabled=true,known=true,ever_owned=true,owned={},exhausted={}}
  if why=='absent'then c.travel_module.terminal_globe_exhaustion=nil
  elseif why=='nontyped'then c.travel_module.terminal_globe_exhaustion=function()return 'true'end
  elseif why=='false'then c.travel_module.terminal_globe_exhaustion=function()return false end
  elseif why=='no_pending'then g.pending=nil
  elseif why=='normal'then g.phase='normal';g.pending.phase='normal'
  elseif why=='wrong_phase'then g.phase='unrecognized';g.pending.phase='unrecognized'
  elseif why=='probe_timeout'then g.fault='recovery timeout';g.phase='probe';g.pending={phase='probe',kind='recovery'};eq(c.travel_module.blocked(c),false,'travel read-only exception is not walker permission')
  elseif why=='runner'then c.runner.waiting={}
  elseif why=='mental'then s.mental={pending={}}
  elseif why=='buff'then s.buffs.pending={}
  elseif why=='container'then c.containers_data.barrier={}
  elseif why=='transport'then c.transport_unknown={}
  elseif why=='inking'then c.tattoo_owner.pending={}
  elseif why=='recall'then c.travel_owner.recall_due=true
  elseif why=='follow'then c.travel_owner.follow_fault='unknown'
  elseif why=='hop'then s.walker.pending={}
  elseif why=='arrival'then s.walker.arrival_hold=true end
  local p=g.pending;local q=g.pool;local f=g.fault
  eq(c.walker_boot.restock_ready(c),why=='no_pending'or why=='normal',why)
  eq(g.pending,p);eq(g.pool,q);eq(g.fault,f);eq(g.armed,false)
 end
end)
report('restock_composed: '..tests..' tests, '..checks..' assertions passed (actual controllers; synthetic offline GameIO only)')
