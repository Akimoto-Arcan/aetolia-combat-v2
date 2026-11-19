-- OFFLINE ONLY: actual bootstrap/FSM/walker/travel/elementals/containers/buffs.
-- Only native GameIO, clock, mapper and GUI are synthetic. No client inheritance.
local root=(arg[1] or 'combat_v2/'):gsub('/+$','')..'/'
local realdofile,realopen,report=dofile,io.open,print
-- Synthetic persisted travel configuration exercises the actual bootstrap's
-- optional-attachment ordering; no file is created and no controller is faked.
yajl={to_value=function(raw)assert(raw=='{"mount_id":"88001"}');return {mount_id='88001'}end}
io.open=function(path,mode)
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
local function fresh(enemy)
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
report('restock_composed: '..tests..' tests, '..checks..' assertions passed (actual controllers; synthetic offline GameIO only)')
