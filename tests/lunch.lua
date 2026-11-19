-- OFFLINE ONLY. All prices, item IDs, wallet values and frames below are synthetic
-- fixtures, NOT captured server facts. No live profile, sockets or Mudlet loaded.
local root=(arg[1] or '.'):gsub('/+$','')
if root:match('/combat_v2$')then root=root:gsub('/combat_v2$','')end
if root:match('combat_v2/lunch%.lua$') then root=root:gsub('combat_v2/lunch%.lua$',''):gsub('/$','');if root=='' then root='.' end end
local M=dofile(root..'/combat_v2/lunch.lua')
local tests,assertions=0,0
local function eq(a,b,msg) assertions=assertions+1;assert(a==b,(msg or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));tests=tests+1 end
local function fixture(h,a)
 local f={time=0,sent={},routes={},queries={},pauses=0,arms=0,summons=0,gold=100000}
 f.v={class='Monk',globe_armed=true,upkeep_master=true,mode='BASH',room=55290,connected=true,dead=false,ready=true,empty=true,room_known=true,players_known=true,players_room=55290,players={},self_name='fixture',hp_percent=100,mounted=false,globe_idle=true,travel_idle=true}
 f.stocks={health={count=h or 199,version=1},['ic:anabiotic']={count=a or 960,version=1}}
 local io={now=function() return f.time end,view=function() return f.v end,stocks=function() return f.stocks end,
  owned=function(d) return f.lease==nil or f.lease==d end,acquire=function(d) f.lease=d;return true end,release=function(d) if f.lease==d then f.lease=nil end end,
  paused_owned=function(grant) return grant==f.grant end,
  send=function(cmd) f.sent[#f.sent+1]=cmd;if f.on_send then return f.on_send(cmd) end end,
  travel=function(dest) f.routes[#f.routes+1]=dest;f.v.travel_idle=false;if f.on_route then return f.on_route(dest) end end,
  query_stock=function(k) f.queries[#f.queries+1]=k;if f.on_query then return f.on_query(k) end end,
  disarm_spawn=function() f.disarmed=true end,
  pause=function() f.pauses=f.pauses+1;f.v.mode='OFF';return true end,
  resume=function(master) f.resumed_master=master;f.v.mode='BASH';if f.on_resume then return f.on_resume() end;return true end,
  arm_globe=function() f.arms=f.arms+1;if f.on_arm then return f.on_arm() end;return true end,
  summon=function() f.summons=f.summons+1;f.v.globe_idle=false;if f.on_summon then return f.on_summon() end;return true end}
 f.t=M.new(io);f.d=f.t.state
 function f.arrive() f.v.room=tonumber(f.d.destination);f.v.travel_idle=true;f.t.prompt() end
 function f.lines(rows) for _,line in ipairs(rows) do f.t.text(line) end end
 function f.directory(k,rows)
  eq(f.d.pending.kind,'directory');eq(f.d.kind,k)
  f.lines({'VNum Owner Description Price','--------------------------------','Spinesreach'})
  rows=rows or {k=='health' and '12668 City: Fixture a refill of an elixir of health 25gp' or '12667 City: Fixture an anabiotic pill 3gp'}
  f.lines(rows);f.t.text('You can locate the listed shops by doing PATH FIND <vnum>.');f.t.prompt()
 end
 function f.wares(k,rows)
  eq(f.d.pending.kind,'wares')
  f.lines({'Proprietor: Offline Fixture','Item Description Stock Price','--------------------------------'})
  f.lines(rows or {k=='health' and 'cask999 a refill of an elixir of health 500 25gp' or 'pill888 an anabiotic pill 5000 3gp'})
  f.t.text('You can see 1 item(s) being sold in this location.');f.t.prompt()
 end
 function f.stockreply(k,n)
  eq(f.d.pending.kind=='baseline' or f.d.pending.kind=='readback',true)
  local s=f.stocks[k=='health' and 'health' or 'ic:anabiotic'];s.count=n or s.count;s.version=s.version+1;f.t.prompt()
 end
 function f.inventory(gold) f.t.text('You are carrying '..(gold or f.gold)..' gold sovereigns.');f.t.prompt() end
 function f.to_directory() assert(f.t.start());f.t.tick();eq(f.d.pending.kind,'route');f.arrive();eq(f.d.pending.kind,'directory') end
 function f.to_baseline(k)
  f.to_directory();f.directory(k or 'health');f.arrive();f.wares(k or 'health');eq(f.d.pending.kind,'baseline')
 end
 function f.to_buy() f.to_baseline('health');f.stockreply('health');eq(f.d.pending.kind,'inventory_before');f.inventory();eq(f.d.pending.kind,'buy') end
 function f.complete_health()
  f.to_buy();local p=f.d.purchase
  f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.d.pending.kind,'readback')
  f.stockreply('health',p.expected);eq(f.d.pending.kind,'inventory_after');f.gold=f.gold-p.cost;f.inventory();eq(f.d.pending.kind,'route')
 end
 function f.to_anab_buy()
  f.complete_health();f.arrive();f.directory('anabiotic');f.arrive();f.wares('anabiotic');f.stockreply('anabiotic');f.inventory();eq(f.d.pending.kind,'buy')
 end
 function f.complete_anab()
  f.to_anab_buy();local p=f.d.purchase
  f.t.prompt();eq(f.d.pending.kind,'incall');f.t.prompt();eq(f.d.pending.kind,'readback');f.stockreply('anabiotic',p.expected)
  f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'55290')
 end
 return f
end

test('silent construction and ticks',function() local f=fixture();f.t.tick();f.t.prompt();eq(#f.sent,0);eq(#f.routes,0);eq(f.d.active,false) end)
test('start monitors but performs no proactive restock',function() local f=fixture(1300,960);assert(f.t.start());for i=1,200 do f.t.tick();f.t.prompt() end;eq(#f.routes,0);eq(#f.queries,0);eq(f.pauses,0) end)
test('strict threshold 200 not low',function() local f=fixture(200,200);assert(f.t.start());f.t.tick();eq(f.pauses,0);eq(f.d.phase,'monitor') end)
test('either cache 199 triggers',function() for _,counts in ipairs({{199,960},{1300,199}}) do local f=fixture(counts[1],counts[2]);assert(f.t.start());f.t.tick();eq(f.pauses,1);eq(f.routes[1],'12669') end end)
test('current fight and genuine runner wait never cleared',function() local f=fixture();f.v.empty=false;f.v.ready=false;assert(f.t.start());for i=1,10 do f.t.tick() end;eq(f.pauses,0);eq(#f.routes,0);eq(f.v.ready,false);eq(f.disarmed,true);f.v.empty=true;f.t.tick();eq(f.pauses,0);f.v.ready=true;f.t.tick();eq(f.pauses,1) end)
test('unknown stock never triggers guessed trip',function() local f=fixture();f.stocks.health=nil;eq(f.t.start(),false);eq(#f.routes,0) end)
test('scope and manual OFF stop before any travel',function() local f=fixture();assert(f.t.start());f.v.mode='OFF';f.t.tick();eq(f.d.active,false);eq(#f.routes,0) end)
test('wrong room cannot start',function() local f=fixture();f.v.room=55291;eq(f.t.start(),false) end)
test('disconnect monitoring no actions',function() local f=fixture();assert(f.t.start());f.v.connected=false;f.t.tick();eq(f.d.active,false);eq(#f.routes,0) end)
test('full two-cache shopping loop plus native initial summon',function()
 local f=fixture();f.complete_anab();f.arrive();eq(f.v.mode,'BASH');eq(f.summons,0);f.t.tick();eq(f.summons,1);eq(f.d.pending.kind,'initial summon');eq(f.d.busy,true)
 for i=1,10 do f.t.tick();f.t.prompt() end;eq(f.summons,1);f.v.globe_idle=true;f.t.prompt();eq(f.d.phase,'monitor');eq(f.d.busy,false);eq(f.d.purchase,nil)
 eq(f.stocks.health.count,1499);eq(f.stocks['ic:anabiotic'].count,2000);eq(#f.queries,4)
 local buys={};for _,s in ipairs(f.sent) do if s:match('^buy ') then buys[#buys+1]=s end end
 eq(#buys,2);eq(buys[1],'buy 26 refill of health for fluidcache');eq(buys[2],'buy 1040 pill888')
 eq(#f.routes,5);eq(f.routes[1],'12669');eq(f.routes[2],'12668');eq(f.routes[3],'12669');eq(f.routes[4],'12667');eq(f.routes[5],'55290')
end)
test('return existing NPC gets BASH before any new summon',function() local f=fixture();f.complete_anab();f.v.empty=false;f.arrive();f.t.tick();eq(f.v.mode,'BASH');eq(f.arms,1);eq(f.summons,0);eq(f.d.phase,'monitor') end)
test('return player blocks OFF even web friend',function() local f=fixture();f.complete_anab();f.v.players={friend=true};f.arrive();eq(f.v.mode,'OFF');eq(f.d.active,false);eq(f.summons,0);eq(f.arms,0) end)
test('unknown and wrong-room player lists block',function() for _,x in ipairs({'unknown','wrong'}) do local f=fixture();f.complete_anab();if x=='unknown' then f.v.players_known=false else f.v.players_room=12667 end;f.arrive();eq(f.v.mode,'OFF');eq(f.d.active,false) end end)
test('self player is excluded',function() local f=fixture();f.complete_anab();f.v.players={fixture=true};f.arrive();eq(f.v.mode,'BASH') end)
test('return actual readiness, dismount and 80 percent required',function()
 local f=fixture();f.complete_anab();f.v.ready=false;f.arrive();eq(f.v.mode,'OFF');f.v.ready=true;f.t.tick();eq(f.v.mode,'BASH');f.v.mounted=true;f.t.tick();eq(f.summons,0);f.v.mounted=false;f.v.hp_percent=79;f.t.tick();eq(f.summons,0);f.v.hp_percent=80;f.t.tick();eq(f.summons,1)
end)
test('native BASH false/checking IH is not a failure if mode restored',function() local f=fixture();f.on_resume=function() return false end;f.complete_anab();f.arrive();eq(f.v.mode,'BASH');eq(f.d.fault,nil) end)
test('manual OFF after owned pause never overwritten',function() local f=fixture();f.to_directory();f.t.user_stop();f.arrive();eq(f.d.active,false);eq(f.v.mode,'OFF');eq(#f.sent,1) end)
test('unexpected paused BASH user intent cancels',function() local f=fixture();f.to_directory();f.v.mode='BASH';f.t.tick();eq(f.d.active,false);eq(#f.sent,1) end)
test('route fault retained no retries',function() local f=fixture();assert(f.t.start());f.t.tick();local p=f.d.pending;f.v.travel_fault='unproved mount';f.t.tick();eq(f.d.pending,p);eq(f.d.active,false);f.t.tick();eq(#f.routes,1) end)
test('route arrival requires idle owner and real prompt',function() local f=fixture();assert(f.t.start());f.t.tick();f.v.room=12669;f.t.prompt();eq(f.d.pending.kind,'route');f.v.travel_idle=true;f.t.tick();eq(f.d.pending.kind,'directory') end)
test('route timeout retains pending',function() local f=fixture();assert(f.t.start());f.t.tick();local p=f.d.pending;f.time=301;f.t.tick();eq(f.d.active,false);eq(f.d.pending,p);eq(#f.routes,1) end)
test('query timeout quarantines locally',function() local f=fixture();f.to_directory();local p=f.d.pending;f.time=61;f.t.tick();eq(f.d.active,false);eq(f.d.pending,p);eq(f.d.busy,true);f.t.tick();eq(#f.sent,1) end)
test('directory footer alone never authorizes movement',function() local f=fixture();f.to_directory();f.t.text('You can locate the listed shops by doing PATH FIND <vnum>.');f.t.prompt();eq(f.d.active,false);eq(#f.routes,1) end)
test('quoted directory header is not own native frame',function() local f=fixture();f.to_directory();f.t.text('Someone says, VNum Owner Description Price');f.t.text('---');f.t.text('12668 Owner a refill of an elixir of health 25gp');f.t.text('You can locate the listed shops by doing PATH FIND <vnum>.');f.t.prompt();eq(f.d.active,false) end)
test('directory cheapest chosen, not premium first row',function() local f=fixture();f.to_directory();f.directory('health',{'12666 Guild a refill of an elixir of health 95gp','12668 City a refill of an elixir of health 25gp'});eq(f.routes[2],'12668') end)
test('matching complete health descriptions only',function() eq(M.directory_row('health','12668 Owner a refill of an elixir of healthfulness 25gp'),nil);eq(M.directory_row('health','12668 Owner a refill of an elixir of health 0gp'),nil);eq(M.directory_row('health','0 Owner a refill of an elixir of health 25gp'),nil) end)
test('anabiotic rows require explicit native pill units',function() eq(M.wares_row('anabiotic','pill888 anabiotic dust 2000 3gp'),nil);eq(M.wares_row('anabiotic','pill888 anabiotic 2000 3gp'),nil);eq(M.wares_row('anabiotic','pill888 an anabiotic pill 2000 0gp'),nil);assert(M.wares_row('anabiotic','pill888 an anabiotic pill 2000 3gp')) end)
test('bad stock tries another candidate without a buy',function() local f=fixture();f.to_directory();f.directory('health',{'12668 City a refill of an elixir of health 25gp','12666 City a refill of an elixir of health 35gp'});f.arrive();f.wares('health',{'cask999 a refill of an elixir of health 0 25gp'});eq(f.routes[3],'12666');eq(f.d.purchase,nil) end)
test('fallback bounded at three candidates',function() local f=fixture();f.to_directory();f.directory('health',{'12668 City a refill of an elixir of health 25gp','12666 City a refill of an elixir of health 35gp','12665 City a refill of an elixir of health 45gp','12664 City a refill of an elixir of health 55gp'});for i=1,3 do f.arrive();f.wares('health',{'cask999 a refill of an elixir of health 0 '..(15+i*10)..'gp'}) end;eq(f.d.active,false);eq(#f.routes,4);eq(f.d.purchase,nil) end)
test('directory WARES price mismatch never buys',function() local f=fixture();f.to_directory();f.directory('health');f.arrive();f.wares('health',{'cask999 a refill of an elixir of health 500 99gp'});eq(f.d.active,false);eq(f.d.purchase,nil) end)
test('no money stops before purchase',function() local f=fixture();f.to_baseline();f.stockreply('health');f.inventory(0);eq(f.d.active,false);eq(f.d.purchase,nil);eq(f.v.mode,'OFF');for _,s in ipairs(f.sent) do assert(not s:match('^buy ')) end end)
test('wallet quotation not authority',function() local f=fixture();f.to_baseline();f.stockreply('health');f.t.text('You say, You are carrying 100000 gold sovereigns.');f.t.prompt();eq(f.d.pending.kind,'inventory_before');f.time=61;f.t.tick();eq(f.d.active,false) end)
test('baseline requires changed authoritative version not proposed count',function() local f=fixture();f.to_baseline();for i=1,4 do f.t.prompt() end;eq(f.d.pending.kind,'baseline');eq(#f.queries,1);f.stockreply('health');eq(f.d.pending.kind,'inventory_before') end)
test('baseline cache changes before BUY fail closed',function() local f=fixture();f.to_baseline();f.stockreply('health');f.stocks.health.count=198;f.inventory();eq(f.d.active,false);eq(f.d.purchase,nil) end)
test('unknown resource send is never retried',function() local f=fixture();f.to_baseline();f.stockreply('health');f.on_send=function(cmd) if cmd:match('^buy ') then return false end end;f.inventory();eq(f.d.active,false);eq(f.d.pending.kind,'buy');assert(f.d.purchase);local n=#f.sent;for i=1,10 do f.t.tick();f.t.prompt() end;eq(#f.sent,n) end)
test('throwing sender retains purchase',function() local f=fixture();f.to_baseline();f.stockreply('health');f.on_send=function(cmd) if cmd:match('^buy ') then error('synthetic wire failure') end end;f.inventory();eq(f.d.pending.kind,'buy');eq(f.d.active,false);assert(f.d.purchase) end)
test('reentrant BUY cannot duplicate or start next stage before return',function()
 local f=fixture();f.to_baseline();f.stockreply('health')
 f.on_send=function(cmd) if cmd:match('^buy ') then local n=#f.sent;eq(f.t.start(),false);f.t.tick();f.t.text('You pay 650 gold sovereigns to add 1300 sips of an elixir of health to your fluidcache.');f.t.prompt();eq(#f.sent,n);eq(#f.queries,1) end end
 f.inventory();eq(f.d.pending.kind,'buy');f.t.tick();eq(f.d.pending.kind,'readback');eq(#f.queries,2)
 local n=0;for _,s in ipairs(f.sent) do if s:match('^buy ') then n=n+1 end end;eq(n,1)
end)
test('wrong health receipt retains resource uncertainty',function() local f=fixture();f.to_buy();f.t.text('You pay 1 gold sovereigns to add 1300 sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.d.active,false);assert(f.d.purchase) end)
test('health buy receipt alone never credits FC',function() local f=fixture();f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.stocks.health.count,199);eq(f.d.pending.kind,'readback');f.stockreply('health',200);eq(f.d.active,false);assert(f.d.purchase) end)
test('wallet cost mismatch retains transaction',function() local f=fixture();f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',p.expected);f.inventory(f.gold);eq(f.d.active,false);assert(f.d.purchase) end)
test('anabiotic BUY never increments cache and INCALL needs fresh absolute IC',function() local f=fixture();f.to_anab_buy();eq(f.stocks['ic:anabiotic'].count,960);f.t.prompt();eq(f.d.pending.kind,'incall');eq(f.stocks['ic:anabiotic'].count,960);f.t.prompt();eq(f.d.pending.kind,'readback');for i=1,3 do f.t.prompt() end;eq(f.d.pending.kind,'readback');f.stockreply('anabiotic',2000);eq(f.stocks['ic:anabiotic'].count,2000);eq(f.d.pending.kind,'inventory_after') end)
test('anabiotic absolute below target retains purchase',function() local f=fixture();f.to_anab_buy();f.t.prompt();f.t.prompt();f.stockreply('anabiotic',1040);eq(f.d.active,false);assert(f.d.purchase) end)
test('incall transport unknown no blind retry',function() local f=fixture();f.to_anab_buy();f.on_send=function(s) if s=='incall' then return false end end;f.t.prompt();eq(f.d.pending.kind,'incall');eq(f.d.active,false);local n=#f.sent;f.t.prompt();eq(#f.sent,n) end)
test('disconnected resource send retains all barriers',function() local f=fixture();f.to_buy();local p=f.d.pending;local buy=f.d.purchase;f.t.disconnect();f.v.connected=false;f.t.prompt();eq(f.d.pending,p);eq(f.d.purchase,buy);eq(f.d.busy,true);eq(f.d.active,false) end)
test('unexpected shopping movement cannot buy',function() local f=fixture();f.to_baseline();f.v.room=12666;f.stockreply('health');eq(f.d.active,false);eq(f.d.purchase,nil) end)
test('native initial summon timeout retains barrier',function() local f=fixture();f.complete_anab();f.arrive();f.t.tick();eq(f.d.pending.kind,'initial summon');f.time=61;f.t.tick();eq(f.d.active,false);eq(f.d.pending.kind,'initial summon');eq(f.summons,1) end)
test('native initial fault stops no repeats',function() local f=fixture();f.complete_anab();f.arrive();f.t.tick();f.v.globe_fault='unknown native receipt';f.t.tick();eq(f.d.active,false);eq(f.summons,1);assert(f.d.pending) end)
test('user stop reentrantly during globe arm prevents summon',function() local f=fixture();f.complete_anab();f.arrive();f.on_arm=function() f.t.user_stop();return true end;f.t.tick();eq(f.summons,0);eq(f.d.active,false) end)
test('waiting after stage ACK eventually dispatches only when ready',function() local f=fixture();f.to_directory();f.v.ready=false;f.directory('health');eq(f.d.phase,'route');eq(f.d.pending,nil);eq(#f.routes,1);f.v.ready=true;f.t.tick();eq(#f.routes,2) end)
test('global shopping deadline bounds ready stalls',function() local f=fixture();f.to_directory();f.v.ready=false;f.directory('health');f.time=1801;f.t.tick();eq(f.d.active,false);eq(f.d.busy,true) end)
test('response budget prevents unbounded frame memory',function() local f=fixture();f.to_directory();for i=1,301 do f.t.text('unclassified fixture line') end;eq(f.d.active,false) end)
test('native proven all globes exhausted stops only genuine ready gap',function() local f=fixture(1300,960);assert(f.t.start());f.v.globes_exhausted=true;f.v.ready=false;f.t.tick();eq(f.pauses,0);f.v.ready=true;f.v.empty=false;f.t.tick();eq(f.pauses,0);f.v.empty=true;f.t.tick();eq(f.pauses,1);eq(f.v.mode,'OFF');eq(f.d.phase,'done');eq(f.d.active,false);eq(#f.routes,0) end)
test('bare owned pause not enough to adopt',function() local f=fixture();f.v.mode='OFF';eq(f.t.adopt_pause({pending_restock=true}),false);eq(f.t.start(),false);eq(#f.routes,0) end)
test('explicit proved pause can be adopted once',function() local f=fixture();f.v.mode='OFF';f.grant={};eq(f.t.adopt_pause(f.grant),true);eq(f.d.busy,true);eq(f.d.destination,'12669');eq(f.t.adopt_pause(f.grant),false) end)

-- Native adapter exercised against fake APIs and real native field shapes only.
local function runtime()
 local c={mode='BASH',runner={mode='BASH'},current={connected=true,room={id=55290,items={},item_version=1},hunting={ih={room_id=55290,responded=true}},player={class='Monk',hp=100,maxhp=100,mana=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,mounted=false,afflictions={}},buffs={wanted={fixture=true}},policy={players_known=true,players_room=55290,players={},self_name='fixture'}},elemental_recovery={phase='idle',armed=true},travel_owner={phase='idle'},defense={plan=function() return {hold=false} end},supplies_data={stocks={health={count=199,version=1},['ic:anabiotic']={count=960,version=1}},sources={}}}
 c.supplies={state=function() return {stocks=c.supplies_data.stocks} end,audit=function(_,_,only,src) c.audit={only,src};return true end}
 local api={connected=function() return true end,clock=function() return 100 end,send=function() error('must inject test sender') end,combat_v2_set_mode=function(mode) c.stops=(c.stops or 0)+1;c.mode=mode;c.runner.mode=mode;c.current.mode=mode;return true end,combat_v2_globe=function() c.elemental_recovery.armed=true;return true end}
 c.lunch_api=api;return c,api,M.adapter(c,api)
end
test('native barriers never manufactured ready by STOP',function()
 local cases={{'runner','waiting'},{'runner','pending'},{'runner','transport_unknown'},{'runner','transport_barrier'},{'runner','fault'},{'runner','dispatching'},{'elemental_recovery','committed'},{'elemental_recovery','dispatching'},{'containers_data','barrier'},{'transport_unknown'}}
 for _,path in ipairs(cases) do local c,a=runtime();if #path==1 then c[path[1]]=true else c[path[1]]=c[path[1]] or {};c[path[1]][path[2]]=true end;local io=M.adapter(c,a);eq(io.view().ready,false);eq(io.pause(),false);eq(c.stops,nil) end
 for _,name in ipairs({'buffs','mental','walker'}) do local c,a=runtime();c.current[name]={pending={}};local io=M.adapter(c,a);eq(io.pause(),false);eq(c.stops,nil) end
end)
test('native no early disarm of committed DRAIN/SUMMON',function() local c,a,io=runtime();local g=c.elemental_recovery;g.committed=true;g.pending={phase='drain'};io.disarm_spawn();eq(g.armed,true);eq(g.committed,true);assert(g.pending);g.committed=nil;g.pending=nil;io.disarm_spawn();eq(g.armed,false) end)
test('native containers quarantine untouched',function() local c,a,io=runtime();c.containers_data={quarantine='response timeout'};eq(io.pause(),true);eq(c.containers_data.quarantine,'response timeout') end)
test('native read-only probe retained across OFF',function() local c,a=runtime();local p={phase='probe',kind='recovery'};c.elemental_recovery.pending=p;c.elemental_recovery.phase='probe';c.elemental_recovery.fault='recovery timeout';a.combat_v2_set_mode=function() c.mode='OFF';c.elemental_recovery.pending=nil;c.elemental_recovery.phase='idle';return true end;eq(M.adapter(c,a).pause(),true);eq(c.elemental_recovery.pending,p);eq(c.elemental_recovery.fault,'recovery timeout') end)
test('native stock version and targeted audit only',function() local c,a,io=runtime();eq(io.stocks().health.version,1);io.query_stock('health');eq(c.audit[1],true);eq(c.audit[2],'fluidcache');io.query_stock('anabiotic');eq(c.audit[2],'ic') end)
test('native readiness includes TCP, afflictions, actual balances',function() local c,a=runtime();local io=M.adapter(c,a);eq(io.view().ready,true);a.connected=function() return false end;eq(io.view().ready,false);a.connected=function() return true end;c.current.player.left_arm_balance=false;eq(io.view().ready,false);c.current.player.left_arm_balance=true;c.current.player.afflictions.paralysis=true;eq(io.view().ready,false) end)
test('native stock unknown not fabricated',function() local c,a=runtime();c.supplies_data.stocks.health=nil;eq(M.adapter(c,a).stocks().health,nil) end)
test('native spawn delegated to elemental owner, never raw send',function() local c,a,io=runtime();c.elementals={service=function(c) eq(c.elemental_recovery.pending.phase,'normal');c.elemental_recovery.committed=true end};eq(io.summon(),true);eq(c.elemental_recovery.committed,true);eq(io.summon(),false) end)
test('native exhaustion requires fresh owned pool proof',function() local c,a=runtime();local g=c.elemental_recovery;g.fault='all carried globes exhausted';local io=M.adapter(c,a);eq(io.view().globes_exhausted,false);g.pool={enabled=true,known=true,ever_owned=true,owned={fixture=true},exhausted={fixture=true}};eq(io.view().globes_exhausted,true);eq(io.view().ready,true);g.pool.exhausted.fixture=nil;eq(io.view().globes_exhausted,false);eq(io.view().ready,false) end)
test('native pause handoff checks epoch, identity, freshness and owned intent',function()
 local c,a=runtime();local old={pending_restock=true,owned_pause=true,original_mode='BASH',paused_at=99,intent_epoch=4};c.lunch_cutoff_handoff=old;c.lunch_intent_epoch=4;local io=M.adapter(c,a);local g={owner=old,intent_epoch=4};eq(io.paused_owned(g),true);c.lunch_intent_epoch=5;eq(io.paused_owned(g),false);c.lunch_intent_epoch=4;old.paused_at=80;eq(io.paused_owned(g),false);old.paused_at=99;old.owned_pause=false;eq(io.paused_owned(g),false)
end)
local function hooks(api)
 local id=0;local h={triggers={},events={},timers={},killed={}}
 local function add(kind,fn) id=id+1;h[kind][id]=fn;return id end
 api.tempRegexTrigger=function(_,fn) return add('triggers',fn) end;api.tempPromptTrigger=function(fn) return add('triggers',fn) end
 api.registerAnonymousEventHandler=function(_,fn) return add('events',fn) end;api.tempTimer=function(_,fn) return add('timers',fn) end
 api.killTrigger=function(i) h.triggers[i]=nil;h.killed[i]=true end;api.killAnonymousEventHandler=function(i) h.events[i]=nil;h.killed[i]=true end;api.killTimer=function(i) h.timers[i]=nil;h.killed[i]=true end
 return h
end
test('attach idempotent and off, retires only cutoff timer',function() local c,a=runtime();local h=hooks(a);c.lunch_duty={active=true,cutoff_timer=999};local t=assert(M.attach(c));eq(t.state.active,false);eq(h.killed[999],true);eq(c.lunch_cutoff_handoff.active,false);eq(M.attach(c),t);eq(c.stops,nil);t.tick();eq(c.stops,nil);eq(M.detach(c),true);eq(next(h.triggers),nil);eq(next(h.events),nil);eq(next(h.timers),nil) end)
test('pending resource owner refuses detach/reload',function() local c,a=runtime();hooks(a);local t=assert(M.attach(c));t.state.pending={kind='buy'};t.state.purchase={};eq(M.detach(c),false);c.lunch_controller=nil;eq(M.attach(c),nil) end)
test('explicit same-mode operator OFF revokes duty and increments epoch',function() local c,a=runtime();hooks(a);local t=assert(M.attach(c));assert(t.start());c.mode='OFF';M.user_stop(c);eq(c.lunch_intent_epoch,1);eq(t.state.active,false);eq(c.mode,'OFF') end)
test('unknown cache after grant drains current NPC then safely pauses without trip',function()
 local f=fixture(1300,960);assert(f.t.start());f.stocks.health=nil;f.v.empty=false;f.v.ready=false;f.t.tick();eq(f.disarmed,true);eq(f.pauses,0);eq(f.d.phase,'drain');f.v.empty=true;f.v.ready=true;f.t.tick();eq(f.v.mode,'OFF');eq(f.d.active,false);eq(#f.routes,0)
end)
test('drain readiness wait is bounded without clearing actual wait',function()
 local f=fixture();assert(f.t.start());f.v.ready=false;f.t.tick();f.time=601;f.t.tick();eq(f.d.active,false);eq(f.pauses,0);eq(f.v.ready,false)
end)
test('fresh native supplies Rift.Change is absolute and increments observation version',function()
 local c,a=runtime();local S=dofile(root..'/combat_v2/supplies.lua');c.supplies=S;c.supplies_clock=function() return 100 end;c.supplies_connected=function() return true end
 eq(S.rift(c,{name='anabiotic',amount='2000'}),true);local io=M.adapter(c,a);eq(io.stocks()['ic:anabiotic'].count,2000);local version=io.stocks()['ic:anabiotic'].version
 eq(S.rift(c,{name='anabiotic',amount='1997'}),true);eq(io.stocks()['ic:anabiotic'].count,1997);assert(io.stocks()['ic:anabiotic'].version>version)
 eq(S.rift(c,{name='anabiotic',amount='-1'}),false);eq(io.stocks()['ic:anabiotic'].count,1997)
end)
test('all transaction stages retain own evidence on disconnect',function()
 local stages={
  function(f) assert(f.t.start());f.t.tick() end,
  function(f) f.to_directory() end,
  function(f) f.to_directory();f.directory('health');f.arrive() end,
  function(f) f.to_baseline() end,
  function(f) f.to_baseline();f.stockreply('health') end,
  function(f) f.to_buy() end,
  function(f) f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt() end,
  function(f) f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',p.expected) end,
  function(f) f.to_anab_buy();f.t.prompt() end,
  function(f) f.complete_anab();f.arrive();f.t.tick() end}
 for _,setup in ipairs(stages) do local f=fixture();setup(f);local p=f.d.pending;assert(p);local purchase=f.d.purchase;local count=#f.sent;local routes=#f.routes;local queries=#f.queries
  f.t.disconnect();f.v.connected=false;for i=1,3 do f.t.tick();f.t.prompt() end
  eq(f.d.pending,p);eq(f.d.purchase,purchase);eq(f.d.active,false);eq(f.d.busy,true);eq(#f.sent,count);eq(#f.routes,routes);eq(#f.queries,queries)
 end
end)
test('not-ready ACK cannot strand baseline or readback dispatch',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.v.ready=false;f.wares('health');eq(f.d.phase,'baseline');eq(f.d.pending,nil);f.v.ready=true;f.t.tick();eq(f.d.pending.kind,'baseline');f.stockreply('health');f.inventory();local p=f.d.purchase
 f.v.ready=false;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.d.phase,'readback');eq(f.d.pending,nil);f.v.ready=true;f.t.tick();eq(f.d.pending.kind,'readback')
end)
test('failed hook installation preserves old cutoff owner',function()
 local c,a=runtime();local h=hooks(a);local old={active=true,cutoff_timer=999};c.lunch_duty=old;a.tempPromptTrigger=function() error('synthetic registration failure') end
 eq(M.attach(c),nil);eq(c.lunch_duty,old);eq(old.active,true);eq(h.killed[999],nil);eq(next(h.triggers),nil);eq(c.lunch_controller,nil)
end)
test('query quarantine stays local, never changes unrelated containers',function()
 local c,a=runtime();hooks(a);c.containers_data={quarantine='response timeout'};local t=assert(M.attach(c));t.state.pending={kind='directory'};t.user_stop();eq(t.state.query_quarantine,'operator stopped duty');eq(c.containers_data.quarantine,'response timeout');eq(M.busy(c),true)
end)
-- Native framing is captured structure; identifiers and wallet remain synthetic.
test('captured WARES combined header and category frame',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive()
 f.lines({'Proprietor: The City of Spinesreach','-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','[CURATIVES AND OTHER CACHE-ABLES]','         cask17 a refill of an elixir of health                196     25gp','You can see 1 item(s) being sold in this location.'});f.t.prompt()
 eq(f.d.pending.kind,'baseline');eq(f.d.item.id,'cask17');eq(f.d.item.stock,196);eq(f.d.item.price,25)
end)
test('captured wallet grammar with synthetic 500',function() local f=fixture();f.to_baseline();f.stockreply('health');f.inventory(500);eq(f.d.active,false);eq(f.d.purchase,nil) end)
test('native WARES header still requires proprietor',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.lines({'-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','cask17 a refill of an elixir of health 196 25gp','You can see 1 item(s) being sold in this location.'});f.t.prompt();eq(f.d.active,false);eq(f.d.purchase,nil)
end)
test('native WARES duplicate combined header rejected',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.lines({'Proprietor: Fixture','-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','cask17 a refill of an elixir of health 196 25gp','You can see 1 item(s) being sold in this location.'});f.t.prompt();eq(f.d.active,false)
end)
test('Monk proof required at start and adoption',function()
 for _,class in ipairs({'Archivist','',false}) do local f=fixture();f.v.class=class;eq(f.t.start(),false);f.v.mode='OFF';f.grant={};eq(f.t.adopt_pause(f.grant),false);eq(#f.routes,0) end
end)
test('class change preserves pending transaction and never restarts',function()
 local f=fixture();f.to_buy();local p,b=f.d.pending,f.d.purchase;f.v.class='Archivist';f.t.tick();eq(f.d.active,false);eq(f.d.pending,p);eq(f.d.purchase,b);eq(f.d.busy,true);f.v.class='Monk';eq(f.t.start(),false)
end)
test('manual GLOBE OFF stops healthy duty without rearm',function() local f=fixture(1300,960);assert(f.t.start());f.v.globe_armed=false;f.t.tick();eq(f.d.active,false);eq(f.arms,0);eq(#f.routes,0) end)
test('unknown GLOBE intent cannot start',function() local f=fixture();f.v.globe_armed=nil;eq(f.t.start(),false) end)
test('initial summon manual OFF retains barrier',function() local f=fixture();f.complete_anab();f.arrive();f.t.tick();local p=f.d.pending;f.v.globe_armed=false;f.v.globe_idle=true;f.t.tick();eq(f.d.pending,p);eq(f.d.busy,true);eq(f.d.active,false);eq(f.summons,1) end)
test('all-zero completion precedes GLOBE intent check',function() local f=fixture(1300,960);assert(f.t.start());f.v.globes_exhausted=true;f.v.globe_armed=false;f.t.tick();eq(f.d.phase,'done');eq(f.d.fault,nil) end)
test('upkeep master trip-time intent preserved',function() for _,master in ipairs({true,false}) do local f=fixture();assert(f.t.start());f.v.upkeep_master=master;f.t.tick();f.arrive();f.directory('health');f.arrive();f.wares('health');f.stockreply('health');f.inventory();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',p.expected);f.gold=f.gold-p.cost;f.inventory();f.arrive();f.directory('anabiotic');f.arrive();f.wares('anabiotic');f.stockreply('anabiotic');f.inventory();p=f.d.purchase;f.t.prompt();f.t.prompt();f.stockreply('anabiotic',p.expected);f.gold=f.gold-p.cost;f.inventory();f.arrive();eq(f.resumed_master,master) end end)
test('adapter resume preserves wanted defenses and FirstAid independent state',function() local c,a,io=runtime();local wanted=c.current.buffs.wanted;c.firstaid={enabled=true};io.resume(false);eq(c.current.buffs.master,false);eq(c.current.buffs.wanted,wanted);eq(c.firstaid.enabled,true);io.resume(true);eq(c.current.buffs.master,true) end)
test('pool reenable only after explicit return arm; old module compatible',function()
 local c,a,io=runtime();local calls=0;c.elementals={pool_enable=function(owner,on) eq(owner,c);eq(on,true);eq(c.mode,'BASH');eq(c.elemental_recovery.armed,true);calls=calls+1;return true end};eq(calls,0);eq(io.arm_globe(),true);eq(calls,1);c.mode='OFF';eq(io.arm_globe(),false);eq(calls,1);c.mode='BASH';c.current.player.class='Archivist';eq(io.arm_globe(),false);eq(calls,1)
end)
test('pool inventory settles without repeated arm or query',function()
 local f=fixture();f.complete_anab();f.arrive();f.v.globe_pool_ready=false;f.t.tick();for i=1,10 do f.t.tick();f.t.prompt() end;eq(f.arms,1);eq(f.summons,0);eq(f.d.busy,true);f.v.globe_pool_ready=true;f.t.tick();eq(f.summons,1);eq(f.arms,1)
end)
test('pool reenable failure retains lease',function() local f=fixture();f.complete_anab();f.arrive();f.on_arm=function() return false end;f.t.tick();eq(f.d.active,false);eq(f.d.busy,true);eq(f.summons,0) end)
test('native pool readiness is fresh owned inventory not mere ON',function()
 local c,a,io=runtime();eq(io.view().class,'Monk');eq(io.view().globe_armed,true);eq(io.view().upkeep_master,false);c.elementals={pool_enable=function() return true end};eq(io.view().globe_pool_ready,false);c.elemental_recovery.pool={enabled=true,known=true};eq(io.view().globe_pool_ready,true);c.elemental_recovery.pool.query={};eq(io.view().globe_pool_ready,false)
end)
test('registration rejects nil false invalid IDs at every stage',function()
 for _,method in ipairs({'tempRegexTrigger','tempPromptTrigger','registerAnonymousEventHandler','tempTimer'}) do
  for _,id in ipairs({false,0,-1,1.5,math.huge,'17','nil'}) do
   local c,a=runtime();local h=hooks(a);local old={active=true,cutoff_timer=999};c.lunch_duty=old;a[method]=function() if id~='nil' then return id end end
   eq(M.attach(c),nil);eq(c.lunch_duty,old);eq(old.active,true);eq(h.killed[999],nil);eq(c.lunch_controller,nil);eq(next(h.triggers),nil);eq(next(h.events),nil);eq(next(h.timers),nil)
  end
 end
end)
test('recurring timer invalid ID revokes active duty',function()
 local c,a=runtime();local h=hooks(a);local t=assert(M.attach(c));assert(t.start());local fn=h.timers[t.timer];c.supplies_data.stocks.health.count=1300;a.tempTimer=function() return false end;fn();eq(t.state.active,false);eq(t.timer,nil);eq(t.state.fault,'operator stopped duty')
end)
test('baseline observation version starts at actual dispatch not deferred scheduling',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.v.ready=false;f.wares('health');f.stocks.health.version=2;f.v.ready=true;f.t.tick();eq(f.d.baseline_version,2);f.t.prompt();eq(f.d.pending.kind,'baseline');f.stockreply('health');eq(f.d.pending.kind,'inventory_before')
end)
test('initial summon wrong-room arrival retains barrier',function() local f=fixture();f.complete_anab();f.arrive();f.t.tick();local p=f.d.pending;f.v.room=55291;f.v.globe_idle=true;f.t.tick();eq(f.d.pending,p);eq(f.d.active,false);eq(f.d.busy,true) end)
test('manual globe OFF during pool settle never rearms even unready',function() local f=fixture();f.complete_anab();f.arrive();f.v.globe_pool_ready=false;f.t.tick();f.v.globe_armed=false;f.v.ready=false;f.t.tick();eq(f.d.active,false);eq(f.arms,1);eq(f.d.busy,true) end)
test('route output cannot overflow an unrelated query frame',function()
 local f=fixture();assert(f.t.start());f.t.tick();eq(f.d.pending.kind,'route');for i=1,400 do f.t.text('A long ordinary native room description.')end;eq(f.d.active,true);eq(f.d.pending.kind,'route');eq(f.d.pending.lines,0)
end)
test('native adapter holds all unresolved travel owners',function()
 for _,k in ipairs({'pending','dispatching','intent','route','fault','follow_fault','follow_pending','follow_due','recall_due'})do
  local c,a=runtime();c.travel_owner={[k]=true};local v=M.adapter(c,a).view();eq(v.ready,false,k);assert(v.blocked,k..' barrier missing')
 end
end)
test('GLOBE OFF before low trigger never starts shopping',function()local f=fixture();assert(f.t.start());f.v.globe_armed=false;f.t.tick();eq(f.d.active,false);eq(f.d.busy,false);eq(#f.routes,0);eq(f.pauses,0)end)
print('lunch: '..tests..' tests, '..assertions..' assertions passed (offline fake IO only)')
