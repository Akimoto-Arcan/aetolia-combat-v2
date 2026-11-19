-- Standalone Lua 5.1 regressions. Every sender and Mudlet API below is fake.
local root=arg[1] or '.'
local path=root..'travel.lua';local f=io.open(path,'r');if f then f:close()else path=root..'/combat_v2/travel.lua'end
local M=dofile(path)
local tests,assertions=0,0
local function eq(a,b,msg) assertions=assertions+1;assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));tests=tests+1 end
local function fixture(opts)
 opts=opts or {};local f={sent={},time=0,ready=true,pauses=0}
 local io={now=function() return f.time end,ready=function() return f.ready,'not ready' end,pause=function() f.pauses=f.pauses+1;return f.ready end,
 send=function(cmd) f.sent[#f.sent+1]=cmd;if f.on_send then return f.on_send(cmd) end end}
 f.t=M.new(io,opts.settings or {mount_id='17',timeout=20});f.s=f.t.state
 f.t.room('100');f.t.vitals('0')
 function f.items(present,full,room) f.version=(f.version or 0)+1;f.t.items(room or '100',present and {{id='17'}} or {},full~=false,f.version) end
 function f.route() f.t.text('Distance to Inside the outer gate: 2.');f.t.text('Path: e,');f.t.text(' se');f.t.text('Use PATH GO to travel there.') end
 return f
end
local function walking()
 local f=fixture();f.t.vitals('17');eq(f.t.request('pt','spinesreach'),true);eq(f.sent[1],'path find spinesreach');f.route();eq(#f.sent,1);f.t.prompt();eq(f.sent[2],'path go gallop');return f
end
test('destination allowlist',function()
 for _,v in ipairs({'spinesreach','Some Place',"A's-place",'123'}) do assert(M.destination(v)) end
 for _,v in ipairs({'','0','-1','a;quit','a\nb','a|b','123abc','a\\b','a\tb',string.rep('a',121)}) do eq(M.destination(v),nil,v) end
end)
test('attach-equivalent initial observation stays silent',function() local f=fixture();f.items(false);f.t.tick();f.t.prompt();eq(#f.sent,0);eq(f.pauses,0) end)
test('fresh mounted binds own id without config',function() local f=fixture({settings={}});f.t.vitals('42');eq(f.s.mount,'42');eq(#f.sent,0) end)
test('unknown mount never selects random loyal NPC',function() local f=fixture({settings={}});f.t.items('100',{{id='9',attrib='mx'}},true,1);eq(f.t.request('qm'),false);eq(#f.sent,0) end)
test('qm waits current snapshot then mounts',function() local f=fixture();eq(f.t.request('qm'),true);eq(#f.sent,0);f.items(true);eq(f.sent[1],'quickmount 17');f.t.prompt();eq(f.s.pending.kind,'mount');f.t.vitals('17');eq(f.s.pending,nil);eq(f.s.intent,nil) end)
test('qm missing recalls once and awaits fresh arrival',function() local f=fixture();f.items(false);f.t.request('qm');eq(f.sent[1],'recall 17');for i=1,4 do f.items(false);f.t.tick() end;eq(#f.sent,1);f.items(true);eq(#f.sent,1);f.t.prompt();eq(f.sent[2],'quickmount 17');f.t.vitals('17');eq(f.s.pending,nil) end)
test('rh never auto mounts',function() local f=fixture();eq(f.t.request('rh'),true);eq(f.sent[1],'recall 17');f.items(true);f.t.prompt();eq(#f.sent,1);eq(f.s.intent,nil);eq(f.s.pending,nil) end)
test('rh cannot spam',function() local f=fixture();f.t.request('rh');eq(f.t.request('rh'),false);eq(#f.sent,1) end)
test('first zero is not dismount',function() local f=fixture();f.items(true);f.t.vitals('0');eq(#f.sent,0) end)
test('all positive to zero transitions follow once',function() local f=fixture();f.items(true);f.t.vitals('17');f.t.vitals('0');eq(f.sent[1],'order 17 follow me');f.t.vitals('0');f.t.prompt();f.t.vitals('0');eq(#f.sent,1) end)
test('qd waits actual zero and follows',function() local f=fixture();f.items(true);f.t.vitals('17');f.t.request('qd');eq(f.sent[1],'quickdismount');f.t.prompt();eq(#f.sent,1);f.t.vitals('0');eq(f.sent[2],'order 17 follow me');f.t.prompt();eq(f.s.pending,nil) end)
test('dismount unknown presence waits fresh list',function() local f=fixture();f.t.vitals('17');f.t.vitals('0');eq(#f.sent,0);f.items(true);eq(f.sent[1],'order 17 follow me') end)
test('mounted absence never recalls',function() local f=fixture();f.t.vitals('17');f.items(false);eq(#f.sent,0) end)
test('confirmed loss recalls once and follows arrival',function() local f=fixture();f.items(true);f.items(false);eq(f.sent[1],'recall 17');f.items(false);eq(#f.sent,1);f.items(true);eq(f.sent[2],'order 17 follow me');f.t.prompt();eq(f.s.pending,nil) end)
test('partial absence is not loss',function() local f=fixture();f.items(true);f.items(false,false);eq(#f.sent,0) end)
test('old room list ignored and room transition waits snapshot',function() local f=fixture();f.items(true);f.t.room('101');f.items(false,true,'100');eq(#f.sent,0);eq(f.s.present,nil);f.items(false,true,'101');eq(f.sent[1],'recall 17') end)
test('PT full native protocol and prompt',function() local f=walking();eq(f.s.pending.kind,'go');f.t.room('101','Other');f.t.prompt();eq(f.s.pending.kind,'go');f.t.room('102','Inside the outer gate');eq(f.s.pending.kind,'go');f.t.prompt();eq(f.s.pending,nil);eq(f.s.intent,nil);eq(#f.sent,2) end)
test('numeric target exact room arrival',function() local f=fixture();f.t.vitals('17');f.t.request('pt','102');f.route();f.t.prompt();f.t.room('102','Anything');f.t.prompt();eq(f.s.pending,nil) end)
test('footer alone cannot walk',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.t.text('Use PATH GO to travel there.');f.t.prompt();eq(#f.sent,1) end)
test('quoted route headers cannot walk',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.t.text('Somebody says, "Distance to gate: 2."');f.t.text('Path: e, se');f.t.text('Use PATH GO to travel there.');f.t.prompt();eq(#f.sent,1) end)
test('invalid direction fails closed',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.t.text('Distance to gate: 2.');f.t.text('Path: e, kill');f.t.text('Use PATH GO to travel there.');f.t.prompt();eq(#f.sent,1) end)
test('stale ready prompt cannot authorize go',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.t.prompt();f.route();eq(#f.sent,1);f.t.prompt();eq(#f.sent,2) end)
test('current readiness required after native route proof',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.route();f.ready=false;f.t.prompt();eq(#f.sent,1);f.ready=true;f.t.tick();eq(#f.sent,2) end)
test('unmounted route never GO',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.route();f.t.vitals('0');f.t.prompt();eq(#f.sent,1) end)
test('room changes during FIND retain fault',function() local f=fixture();f.t.vitals('17');f.t.request('pt','spinesreach');f.t.room('101');f.route();f.t.prompt();eq(#f.sent,1);assert(f.s.fault) end)
test('mount confirmation must be GMCP not prompt',function() local f=fixture();f.items(true);f.t.request('pt','spinesreach');f.route();f.t.prompt();eq(#f.sent,1);eq(f.sent[1],'quickmount 17');f.t.vitals('17');eq(f.sent[2],'path find spinesreach') end)
test('false transport never retries',function() local f=fixture();f.items(true);f.on_send=function() return false end;eq(f.t.request('qm'),false);assert(f.s.pending);assert(f.s.fault);f.t.vitals('17');f.t.tick();eq(#f.sent,1);eq(f.t.request('qm'),false) end)
test('throwing transport never retries',function() local f=fixture();f.items(true);f.on_send=function() error('wire') end;eq(f.t.request('qm'),false);f.t.tick();eq(#f.sent,1);assert(f.s.pending) end)
test('timeout retains barrier',function() local f=fixture();f.items(true);f.t.request('qm');f.time=21;f.t.tick();assert(f.s.fault);assert(f.s.pending);f.t.vitals('17');eq(#f.sent,1);eq(f.t.unresolved(),true) end)
test('nested sender cannot double dispatch',function() local f=fixture();f.items(true);f.on_send=function(cmd) eq(f.t.request('qm'),false);f.t.vitals('17');f.t.prompt() end;f.t.request('qm');eq(#f.sent,1);f.t.tick();eq(#f.sent,1) end)
test('cancel walking sends one stop retains unknown ack',function() local f=walking();eq(f.t.cancel(),true);eq(f.sent[3],'path stop');eq(f.t.cancel(),false);f.t.prompt();eq(f.s.pending.kind,'stop');eq(#f.sent,3);eq(f.t.unresolved(),true) end)
test('cancel mount cannot erase committed action',function() local f=fixture();f.items(true);f.t.request('qm');eq(f.t.cancel(),false);eq(f.s.pending.kind,'mount') end)
-- Fake runtime registration and sender, never imports the live profile.
local ids,events,aliases,triggers,timers=0,{},{},{},{}
local function add(tab,key,fn) ids=ids+1;tab[ids]={key,fn};return ids end
function tempAlias(p,fn) return add(aliases,p,fn) end
function registerAnonymousEventHandler(p,fn) return add(events,p,fn) end
function tempPromptTrigger(fn) return add(triggers,'prompt',fn) end
function tempRegexTrigger(p,fn) return add(triggers,p,fn) end
function tempTimer(p,fn) return add(timers,p,fn) end
function killAlias(i) aliases[i]=nil end
function killAnonymousEventHandler(i) events[i]=nil end
function killTrigger(i) triggers[i]=nil end
function killTimer(i) timers[i]=nil end
local tcp=true
function getConnectionInfo() return 'host',23,tcp end
function getEpoch() return 0 end
local function runtime()
 local c={mode='BASH',runner={mode='BASH'},current={connected=true,room={id='100'},player={hp=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,mounted=false},buffs={wanted={vitality=true}}},travel_sender=function() error('override fake sender in test') end}
 function combat_v2_set_mode(mode) c.stops=(c.stops or 0)+1;c.mode=mode;c.runner.mode=mode;return true end
 return c
end
local function event(name) for _,v in pairs(events) do if v[1]==name then v[2]() end end end
test('all cross controller barriers checked before STOP',function()
 local paths={{'runner','waiting'},{'runner','pending'},{'runner','dispatching'},{'runner','transport_unknown'},{'runner','fault'}}
 for _,path in ipairs(paths) do local c=runtime();c[path[1]][path[2]]=true;eq(M.adapter(c).pause(),false);eq(c.stops,nil) end
 for _,key in ipairs({'buffs','mental','walker'}) do local c=runtime();c.current[key]={pending=true};eq(M.adapter(c).pause(),false);eq(c.stops,nil) end
 local c=runtime();c.containers_data={barrier={}};eq(M.adapter(c).pause(),false);c.containers_data=nil;c.elemental_recovery={committed=true};eq(M.adapter(c).pause(),false)
end)
test('TCP third return not vitals age',function() local c=runtime();c.current.vitals_at=-999999;eq(M.adapter(c).ready(),true);tcp=false;eq(M.adapter(c).ready(),false);tcp=true end)
test('runtime OFF leaves wanted and native curing alone',function() local c=runtime();eq(M.adapter(c).pause(),true);eq(c.current.buffs.wanted.vitality,true);eq(c.mode,'OFF');eq(c.stops,1) end)
test('attach owns aliases idempotently no startup send',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17'}));eq(M.attach(c),t);eq(c.travel_owner,t.state);eq(#sent,0);eq(c.stops,nil)
 local found={};for _,v in pairs(aliases) do found[v[1]]=true end
 assert(found['^pt (.+)$']);assert(found['^qm$']);assert(found['^qd$']);assert(found['^rh$'])
 gmcp={Char={Vitals={mounted='0'},Items={List={location='room',items={{id='17'}}}}},Room={Info={num=100}}}
 event('gmcp.Char.Vitals');event('gmcp.Char.Items.List');eq(t.state.present,nil);eq(#sent,0)
 eq(M.detach(c),true)
end)
test('runtime explicit correlated room list mounts and prevents detach',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17',room_for_items=function() return '100' end}))
 gmcp={Char={Vitals={mounted='0'},Items={List={location='room',items={{id='17'}}}}}};event('gmcp.Char.Vitals');event('gmcp.Char.Items.List')
 eq(t.request('qm'),true);eq(sent[1],'quickmount 17');eq(c.mode,'OFF');eq(M.detach(c),false)
 c.travel=nil;eq(M.attach(c),nil);c.travel=t
 gmcp.Char.Vitals.mounted='17';event('gmcp.Char.Vitals');eq(M.detach(c),true)
end)
test('read-only globe probe fault preserved across native STOP',function()
 local c=runtime();local p={kind='recovery',phase='probe'};local g={armed=false,phase='probe',fault='recovery timeout',pending=p,status='timed out'};c.elemental_recovery=g
 c.containers_data={quarantine='response timeout'}
 function combat_v2_set_mode(mode) c.mode=mode;c.runner.mode=mode;g.pending=nil;g.phase='idle';g.status='disarmed';return true end
 eq(M.blocked(c),false);eq(M.adapter(c).pause(),true);eq(g.pending,p);eq(g.fault,'recovery timeout');eq(g.phase,'probe');eq(g.armed,false);eq(c.containers_data.quarantine,'response timeout')
 p.kind='unknown';eq(M.blocked(c),true);p.kind='recovery';g.committed=true;eq(M.blocked(c),true)
end)
test('numeric destination keeps literal leading zeros and cap',function()
 eq(M.destination('000123'),'000123');eq(M.destination('0000'),nil);eq(M.destination(string.rep('1',121)),nil)
 local f=fixture();f.t.vitals('17');f.t.request('pt','000123');eq(f.sent[1],'path find 000123')
 f.route();f.t.prompt();f.t.room('123','Anything');f.t.prompt();eq(f.s.pending,nil)
end)
test('resolved mapped arrival handles gallop skipped rooms but waits prompt',function()
 local f=fixture({settings={mount_id='17',resolve_target_room=function(name,dest) eq(name,'Inside the outer gate');eq(dest,'spinesreach');return '150' end}})
 f.t.vitals('17');f.t.request('pt','spinesreach');f.route();eq(f.s.pending.target_room,'150');f.t.prompt()
 f.t.room('150','Inside the outer gate');eq(f.s.pending.kind,'go');f.t.prompt();eq(f.s.pending,nil)
end)
test('ambiguous map callback retains strict count fallback',function()
 local f=fixture({settings={mount_id='17',resolve_target_room=function() return nil end}})
 f.t.vitals('17');f.t.request('pt','spinesreach');f.route();f.t.prompt();f.t.room('150','Inside the outer gate');f.t.prompt();eq(f.s.pending.kind,'go')
end)
test('follow lane retains active route and stop transaction',function()
 for _,stop in ipairs({false,true}) do
  local f=walking();f.items(true);if stop then f.t.cancel() end
  local pending=f.s.pending;f.t.vitals('0');eq(f.sent[#f.sent],'order 17 follow me');eq(f.s.pending,pending)
  f.t.prompt();eq(f.s.pending,pending);eq(f.s.follow_pending,nil);eq(f.pauses,1)
 end
end)
test('follow failure retains route and independent barrier',function()
 local f=walking();f.items(true);local pending=f.s.pending
 f.on_send=function() return false end;f.t.vitals('0');assert(f.s.follow_fault);assert(f.s.follow_pending);eq(f.s.pending,pending)
 f.t.prompt();f.t.tick();eq(#f.sent,3);eq(f.t.unresolved(),true);eq(f.t.cancel(),false)
end)
test('follow timeout and reconstruction keep barrier',function()
 local f=fixture();f.items(true);f.t.vitals('17');f.t.vitals('0');f.time=21;f.t.tick();assert(f.s.follow_fault)
 local t=M.new({}, {},f.s);eq(t.unresolved(),true);eq(t.request('qm'),false)
end)
test('new dismount episode during pending follow is not lost',function()
 local f=fixture();f.items(true);f.t.vitals('17');f.t.vitals('0');f.t.vitals('17');f.t.vitals('0');eq(#f.sent,1)
 f.t.prompt();eq(#f.sent,2);f.t.prompt();eq(f.s.follow_pending,nil);eq(#f.sent,2);eq(f.pauses,0)
end)
test('automatic runtime follow preserves BASH waits and globe',function()
 local c=runtime();local sent={};local waiting={kind='combo'};c.runner.waiting=waiting;c.current.player.balance=false
 c.defense={plan=function() return {hold=true} end};c.elemental_recovery={armed=true,phase='idle'}
 c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17'}));t.items('100',{{id='17'}},true,1);t.vitals('17');t.vitals('0')
 eq(sent[1],'order 17 follow me');eq(c.mode,'BASH');eq(c.runner.waiting,waiting);eq(c.stops,nil);eq(c.elemental_recovery.armed,true)
 t.prompt();eq(t.state.follow_pending,nil);eq(M.detach(c),true)
end)
test('follow transport blockers do not confuse ordinary waiting',function()
 local c=runtime();c.runner.waiting={};local a=M.adapter(c);eq(a.follow_ready(),true)
 for _,field in ipairs({'dispatching','transport_unknown','transport_barrier','fault'}) do c.runner[field]=true;eq(a.follow_ready(),false);c.runner[field]=nil end
 c.runner.root={dispatching=true};eq(a.follow_ready(),false);c.runner.root=nil
 c.tattoo_owner={phase='inking'};eq(a.follow_ready(),false);eq(M.blocked(c),true)
 c.tattoo_owner={phase='idle'};eq(a.follow_ready(),true);c.tattoo_owner.txn={};eq(a.follow_ready(),false)
 c.tattoo_owner=nil;c.elemental_recovery={committed=true};eq(a.follow_ready(),false)
 c.elemental_recovery=nil;c.containers_data={barrier={}};eq(a.follow_ready(),false)
 c.containers_data=nil;tcp=false;eq(a.follow_ready(),false);tcp=true
end)
test('follow sender accepts exact own order only while BASH',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local a=M.adapter(c,{mount_id='17'});eq(a.send_follow('order loyals follow me'),false);eq(a.send_follow('order 18 follow me'),false)
 a.send_follow('order 17 follow me');eq(sent[1],'order 17 follow me');eq(c.mode,'BASH')
end)
test('automatic missing mount recalls without stopping BASH',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17'}));t.vitals('17');t.vitals('0');t.items('100',{},true,1);t.tick()
 eq(sent[1],'recall 17');eq(c.stops,nil);eq(c.mode,'BASH');eq(M.detach(c),false)
 t.items('100',{{id='17'}},false,2);eq(sent[2],'order 17 follow me');t.prompt();eq(t.state.pending,nil);eq(M.detach(c),true)
end)
test('follow disconnect and orphan replacement retain owner',function()
 local c=runtime();c.travel_sender=function() return true end
 local t=assert(M.attach(c,{mount_id='17'}));t.items('100',{{id='17'}},true,1);t.vitals('17');t.vitals('0')
 local pending=t.state.follow_pending;event('sysDisconnectionEvent');eq(t.state.follow_pending,pending);assert(t.state.fault);eq(M.detach(c),false)
 c.travel=nil;eq(M.attach(c),nil);c.travel=t
 -- Offline fixture teardown, not production recovery.
 t.state.follow_pending=nil;t.state.follow_due=nil;t.state.fault=nil;eq(M.detach(c),true)
end)
test('nested follow sender cannot preempt own dispatch',function()
 local f=fixture();f.items(true);f.t.vitals('17')
 f.on_send=function() f.t.prompt();f.t.tick();eq(f.t.request('qm'),false) end
 f.t.vitals('0');eq(#f.sent,1);assert(f.s.follow_pending);f.t.tick();eq(#f.sent,1);eq(f.s.follow_pending,nil)
end)
test('OFF stale read-only globe fault does not block travel',function()local c=runtime();c.elemental_recovery={phase='idle',fault='recovery timeout',armed=false};eq(M.adapter(c).ready(),true);c.elemental_recovery.committed=true;eq(M.adapter(c).ready(),false)end)
test('recall reserves genuine BASH recovery without clearing barriers',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17'}));local wait={kind='combo'};c.runner.waiting=wait;c.current.player.balance=false
 t.vitals('17');t.vitals('0');t.items('100',{},true,1)
 eq(t.state.recall_due,true);eq(c.runner.waiting,wait);eq(#sent,0);eq(c.stops,nil)
 c.current.player.balance=true;t.tick();eq(#sent,0);eq(c.runner.waiting,wait)
 c.runner.waiting=nil;t.tick();eq(sent[1],'recall 17');eq(c.mode,'BASH');eq(c.stops,nil)
 c.current.player.equilibrium=false;t.items('100',{{id='17'}},true,2);t.prompt();assert(t.state.pending)
 c.current.player.equilibrium=true;t.prompt();eq(t.state.pending,nil);eq(t.state.recall_due,nil);eq(M.detach(c),true)
end)
test('recall never clears ASSIST proposal or protected commitments',function()
 local c=runtime();local a=M.adapter(c,{mount_id='17'});local pending={command='combo'};c.runner.pending=pending
 eq(a.recall_ready(),false);eq(c.runner.pending,pending);c.runner.pending=nil
 for _,field in ipairs({'transport_unknown','dispatching','fault','transport_barrier'}) do c.runner[field]={};eq(a.recall_ready(),false);c.runner[field]=nil end
 c.elemental_recovery={committed=true};eq(a.recall_ready(),false);c.elemental_recovery=nil
 c.mode='FULL_AUTO';c.runner.mode='FULL_AUTO';eq(a.recall_ready(),false)
end)
test('recall send allowlist and canonical mounted race',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end;local a=M.adapter(c,{mount_id='17'})
 eq(a.send_recall('recall mount'),false);eq(a.send_recall('recall 18'),false)
 c.current.player.mounted=17;eq(a.recall_ready(),false);eq(a.send_recall('recall 17'),false)
 c.current.player.mounted=nil;eq(a.recall_ready(),false);c.current.player.mounted=false
 a.send_recall('recall 17');eq(sent[1],'recall 17');eq(c.stops,nil)
end)
test('mounted packet ordering and manual rh do not recall while riding',function()
 local f=fixture();f.items(true);f.t.vitals('17');f.items(false);f.t.tick();eq(#f.sent,0);eq(f.t.request('rh'),false);eq(#f.sent,0)
 f.t.vitals('0');eq(f.sent[1],'recall 17')
end)
test('recall false throw and timeout retain exact pending owner',function()
 for _,kind in ipairs({'false','throw','timeout'}) do
  local f=fixture();f.items(true);f.on_send=function() if kind=='false' then return false elseif kind=='throw' then error('wire') end end
  f.items(false);local pending=f.s.pending;assert(pending);eq(pending.kind,'recall');f.time=21;f.t.tick();assert(f.s.fault)
  f.items(true);f.t.prompt();eq(f.s.pending,pending);eq(f.t.cancel(),false);eq(#f.sent,1)
  eq(M.new({}, {},f.s).unresolved(),true)
 end
end)
test('own Remove solicits once and needs newer full snapshot',function()
 local f=fixture();local reads=0;f.t.io.refresh_items=function() reads=reads+1 end;f.items(true)
 eq(f.t.remove('999','17',2),false);eq(f.t.remove('100','18',2),false);eq(reads,0)
 eq(f.t.remove('100',{id='17'},2),true);eq(reads,1);eq(#f.sent,0);eq(f.s.present,nil)
 f.t.remove('100','17',3);f.t.tick();eq(reads,1);eq(#f.sent,0)
 f.t.items('100',{},false,4);eq(#f.sent,0);f.t.items('100',{},true,3);eq(#f.sent,0)
 f.t.items('100',{},true,5);eq(f.sent[1],'recall 17')
end)
test('native scoped Remove uses GMCP refresh then IH without STOP',function()
 local c=runtime();local sent={};c.travel_sender=function(cmd) sent[#sent+1]=cmd end
 local t=assert(M.attach(c,{mount_id='17',room_for_items=function() return '100' end,gmcp_sender=function(cmd) sent[#sent+1]=cmd end}))
 gmcp={Char={Items={List={location='room',items={{id='17'}}},Remove={location='room',item={id='17'}}}}}
 t.vitals('0');event('gmcp.Char.Items.List');event('gmcp.Char.Items.Remove')
 eq(sent[1],[[Char.Items.Room ""]]);eq(sent[2],'ih');eq(#sent,2);event('gmcp.Char.Items.Remove');eq(#sent,2);eq(c.mode,'BASH');eq(c.stops,nil)
 gmcp.Char.Items.List.items={};event('gmcp.Char.Items.List');eq(sent[3],'recall 17')
 -- offline teardown only
 t.state.pending=nil;t.state.recall_due=nil;t.state.follow_due=nil;eq(M.detach(c),true)
end)
test('mount loss during pending follow still reserves recall',function()
 local f=fixture();f.items(true);f.t.vitals('17');f.t.vitals('0');eq(f.sent[1],'order 17 follow me')
 f.items(false);eq(f.s.recall_due,true);f.t.prompt();eq(f.sent[2],'recall 17');eq(f.pauses,0)
end)
test('Remove refresh waits for transport gap and never polls',function()
 local f=fixture();local reads=0;local available=false
 f.t.io.refresh_ready=function() return available end;f.t.io.refresh_items=function() reads=reads+1 end
 f.items(true);f.t.remove('100','17',2);f.t.tick();eq(reads,0);eq(f.s.refresh_due,true)
 available=true;f.t.tick();eq(reads,1);f.t.tick();eq(reads,1)
 f.t.items('100',{},true,3);f.t.remove('100','17',4);eq(f.s.present,false);eq(reads,1)
end)
print('travel: '..tests..' tests, '..assertions..' assertions passed (fake senders only)')
