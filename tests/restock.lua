-- OFFLINE ONLY: every room, inventory, price and wallet below is synthetic.
local root=(arg[1] or '.'):gsub('/+$','')
-- The common runner passes the installed module directory, not the repo root.
local probe=io.open(root..'/restock.lua','r')
if probe then probe:close();root=root:gsub('/?combat_v2$','');if root==''then root='.'end end
local M=dofile(root..'/combat_v2/restock.lua')
local tests,assertions=0,0
local function eq(a,b,msg) assertions=assertions+1;assert(a==b,(msg or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));tests=tests+1 end
local function fixture(h,a)
 local f={time=0,sent={},routes={},queries={},pauses=0,arms=0,summons=0,gold=100000}
 f.v={class='Monk',globe_armed=true,upkeep_master=true,mode='BASH',room=73001,area=77,session=1,intent_epoch=0,ih_evidence={},item_version=1,connected=true,dead=false,ready=true,empty=true,room_known=true,players_known=true,players_room=73001,players={},self_name='fixture',hp_percent=100,mounted=false,globe_idle=true,travel_idle=true}
 f.stocks={health={count=h or 150,version=1},['ic:anabiotic']={count=a or 960,version=1}}
 local io={now=function() return f.time end,view=function() return f.v end,stocks=function() return f.stocks end,
  owned=function(d) return f.lease==nil or f.lease==d end,acquire=function(d) f.lease=d;return true end,release=function(d) if f.lease==d then f.lease=nil end end,
  paused_owned=function(grant) return grant==f.grant end,
  send=function(cmd) f.sent[#f.sent+1]=cmd;if f.on_send then return f.on_send(cmd) end end,
  travel=function(dest) f.routes[#f.routes+1]=dest;f.v.travel_idle=false;if f.on_route then return f.on_route(dest) end end,
  query_stock=function(k) f.queries[#f.queries+1]=k;if f.on_query then return f.on_query(k) end end,
  disarm_spawn=function() f.disarmed=true end,
  pause=function() f.pauses=f.pauses+1;f.v.mode='OFF';return true end,
  resume=function(master) f.resumed_master=master;f.v.mode='BASH';f.v.room_known=false;if f.on_resume then return f.on_resume() end;return true end,
  arm_globe=function() f.arms=f.arms+1;f.v.globe_armed=true;if f.on_arm then return f.on_arm() end;return true end,
  summon=function() f.summons=f.summons+1;f.v.globe_idle=false;if f.on_summon then return f.on_summon() end;return true end}
 io.walker_arriving=function() return f.hop==true or f.arrival==true end
 io.walker_ready=function() return not f.hop and not f.arrival end
 io.checkpoint=function(d)
  f.captures=(f.captures or 0)+1
  if not f.walk then return false end
  local cp={lease=d,room=f.v.room,area=f.v.area,cursor=f.walk.cursor,visited=f.walk.visited,consent=f.walk.consent,generation=f.walk.generation}
  f.cp=cp;f.walk.suspended=true;return cp
 end
 io.restore_checkpoint=function(cp,d)
  if cp~=f.cp or cp.lease~=d or cp.revoked then return false end
  f.restores=(f.restores or 0)+1;f.walk.cursor=cp.cursor;f.walk.visited=cp.visited;f.walk.suspended=false;return true
 end
 io.revoke_checkpoint=function(cp,d) eq(cp.lease,d);cp.revoked=true;f.revoked=(f.revoked or 0)+1 end
 f.io=io;f.t=M.new(io);f.d=f.t.state
 function f.arrive() f.v.room=tonumber(f.d.destination);f.v.area=f.v.room==73001 and 77 or 88;f.v.players={};f.v.players_room=f.v.room;f.v.travel_idle=true;f.t.prompt() end
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
  f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'73001')
 end
 function f.fresh() f.v.room_known=true;f.v.ih_evidence={};f.v.item_version=f.v.item_version+1;f.t.tick() end
 return f
end
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
 f.on_send=function(cmd) if cmd:match('^buy ') then local n=#f.sent;eq(f.t.start(),false);f.t.tick();f.t.text('You pay 675 gold sovereigns to add 1350 sips of an elixir of health to your fluidcache.');f.t.prompt();eq(#f.sent,n);eq(#f.queries,1) end end
 f.inventory();eq(f.d.pending.kind,'buy');f.t.tick();eq(f.d.pending.kind,'readback');eq(#f.queries,2)
 local n=0;for _,s in ipairs(f.sent) do if s:match('^buy ') then n=n+1 end end;eq(n,1)
end)
test('wrong health receipt retains resource uncertainty',function() local f=fixture();f.to_buy();f.t.text('You pay 1 gold sovereigns to add 1350 sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.d.active,false);assert(f.d.purchase) end)
test('health buy receipt alone never credits FC',function() local f=fixture();f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.stocks.health.count,150);eq(f.d.pending.kind,'readback');f.stockreply('health',200);eq(f.d.active,false);assert(f.d.purchase) end)
test('wallet cost mismatch retains transaction',function() local f=fixture();f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',p.expected);f.inventory(f.gold);eq(f.d.active,false);assert(f.d.purchase) end)
test('anabiotic BUY never increments cache and INCALL needs fresh absolute IC',function() local f=fixture();f.to_anab_buy();eq(f.stocks['ic:anabiotic'].count,960);f.t.prompt();eq(f.d.pending.kind,'incall');eq(f.stocks['ic:anabiotic'].count,960);f.t.prompt();eq(f.d.pending.kind,'readback');for i=1,3 do f.t.prompt() end;eq(f.d.pending.kind,'readback');f.stockreply('anabiotic',2000);eq(f.stocks['ic:anabiotic'].count,2000);eq(f.d.pending.kind,'inventory_after') end)
test('anabiotic absolute below target retains purchase',function() local f=fixture();f.to_anab_buy();f.t.prompt();f.t.prompt();f.stockreply('anabiotic',1040);eq(f.d.active,false);assert(f.d.purchase) end)
test('incall transport unknown no blind retry',function() local f=fixture();f.to_anab_buy();f.on_send=function(s) if s=='incall' then return false end end;f.t.prompt();eq(f.d.pending.kind,'incall');eq(f.d.active,false);local n=#f.sent;f.t.prompt();eq(#f.sent,n) end)

test('default OFF ignores saved enabled settings and sends nothing',function()
 local f=fixture();f.t=M.new(f.io,{enabled=true,active=true});for i=1,60 do f.t.tick();f.t.prompt() end;eq(f.t.state.enabled,false);eq(#f.sent,0);eq(#f.routes,0)
end)
test('ON while OFF is future permission, not BASH or travel',function()
 local f=fixture();f.v.mode='OFF';f.v.globe_armed=false;eq(f.t.start(),true);for i=1,10 do f.t.tick() end;eq(f.v.mode,'OFF');eq(#f.routes,0);eq(f.pauses,0);f.v.mode='BASH';f.t.tick();eq(f.pauses,1)
end)
test('strict 200 and unknown passive stocks never issue queries',function()
 for _,counts in ipairs({{200,200},{1500,2000}}) do local f=fixture(counts[1],counts[2]);assert(f.t.start());for i=1,60 do f.t.tick() end;eq(#f.queries,0);eq(#f.routes,0) end
 local f=fixture();f.stocks.health=nil;assert(f.t.start());f.t.tick();eq(#f.routes,0);eq(#f.queries,0)
end)
test('health-only, anabiotic-only, and both trigger without GLOBE',function()
 for _,counts in ipairs({{199,2000},{1500,199},{199,199}}) do local f=fixture(counts[1],counts[2]);f.v.globe_armed=false;assert(f.t.start());f.t.tick();eq(f.pauses,1);eq(f.d.return_room,73001);eq(f.d.return_area,77);eq(f.d.resume_globe,false);eq(f.d.pending.kind,'route') end
end)
test('reservation does not pause current fight or clear recovery',function()
 local f=fixture();f.v.empty=false;f.v.ready=false;assert(f.t.start());f.t.tick();eq(f.d.reserved,true);eq(f.d.busy,false);eq(f.pauses,0);eq(f.v.ready,false);f.v.empty=true;f.t.tick();eq(f.pauses,0);f.v.ready=true;f.t.tick();eq(f.pauses,1)
end)
test('OFF before trip cancels only reservation, zero movement',function()
 local f=fixture();f.v.empty=false;assert(f.t.start());f.t.tick();assert(f.d.reserved);f.t.off();f.v.empty=true;for i=1,4 do f.t.tick() end;eq(#f.routes,0);eq(f.pauses,0);eq(f.v.mode,'BASH');eq(f.d.enabled,false);eq(f.d.reserved,false)
end)
test('GLOBE OFF never disables independent restock permission',function()
 local f=fixture();assert(f.t.start());f.t.globe_off();f.v.globe_armed=false;f.t.tick();eq(f.d.enabled,true);eq(f.pauses,1);eq(f.d.resume_globe,false)
end)
test('walker pending hop and arrival proof settle before checkpoint',function()
 local f=fixture();f.walk={cursor=17,visited={['73000']=true},consent=9,generation=6};f.hop=true;assert(f.t.start());f.t.tick();eq(f.captures,nil);eq(f.pauses,0)
 f.v.room=73002;f.v.players_room=73002;f.hop=false;f.arrival=true;f.t.tick();eq(f.captures,nil);f.arrival=false;f.t.tick();eq(f.captures,1);eq(f.cp.room,73002);eq(f.d.return_room,73002);eq(f.cp.cursor,17);eq(f.cp.lease,f.d)
end)
test('stationary full two-cache trip restores no GLOBE',function()
 local f=fixture();f.v.globe_armed=false;f.complete_anab();eq(f.stocks.health.count,1500);eq(f.stocks['ic:anabiotic'].count,2000);f.arrive();eq(f.v.mode,'BASH');eq(f.d.busy,true);f.t.tick();eq(f.d.busy,true);f.fresh();eq(f.d.phase,'monitor');eq(f.d.busy,false);eq(f.arms,0);eq(f.summons,0);eq(#f.queries,4);eq(f.lease,nil)
end)
test('saved Globe intent rearms only after exact fresh return',function()
 local f=fixture();f.complete_anab();f.arrive();eq(f.arms,0);eq(f.summons,0);f.fresh();eq(f.arms,1);eq(f.summons,1);eq(f.d.pending.kind,'initial summon');f.v.globe_idle=true;f.t.prompt();eq(f.d.busy,false);eq(f.d.phase,'monitor')
end)
test('public Globe OFF during trip leaves restock ON but suppresses rearm',function()
 local f=fixture();f.complete_anab();f.t.globe_off();f.v.globe_armed=false;eq(f.d.enabled,true);f.arrive();f.fresh();eq(f.d.busy,false);eq(f.arms,0);eq(f.summons,0);eq(f.v.mode,'BASH')
end)
test('return restores original walker cursor and visited once, not a new path',function()
 local f=fixture();f.v.globe_armed=false;local visited={['72000']=true,['73000']=true};f.walk={cursor=17,visited=visited,consent=33,generation=6}
 f.complete_anab();eq(f.walk.suspended,true);eq(f.restores,nil);f.arrive();f.t.tick();eq(f.restores,nil);f.fresh();eq(f.restores,1);eq(f.walk.cursor,17);eq(f.walk.visited,visited);eq(f.walk.consent,33);for i=1,5 do f.t.tick() end;eq(f.restores,1)
end)
test('return same room wrong area never resumes',function()
 local f=fixture();f.complete_anab();f.v.room=73001;f.v.area=999;f.v.players_room=73001;f.v.players={};f.v.travel_idle=true;f.t.prompt();eq(f.v.mode,'OFF');eq(f.d.active,false);eq(f.arms,0)
end)
test('return fresh players strict, friend not exception',function()
 for _,bad in ipairs({'other','unknown','stale'}) do local f=fixture();f.complete_anab();f.v.room=73001;f.v.area=77;f.v.travel_idle=true;f.v.players_room=73001;f.v.players={};if bad=='other' then f.v.players.friend=true elseif bad=='unknown' then f.v.players_known=false else f.v.players=f.d.departure_players end;f.t.prompt();eq(f.v.mode,'OFF');eq(f.d.active,false) end
end)
test('fresh return IH and unmounted recovery fence checkpoint',function()
 local f=fixture();f.v.globe_armed=false;f.walk={cursor=17,visited={},consent=1,generation=2};f.complete_anab();f.arrive();f.v.room_known=true;f.t.tick();eq(f.restores,nil);f.v.ih_evidence={};f.v.item_version=f.v.item_version+1;f.v.mounted=true;f.t.tick();eq(f.restores,nil);f.v.mounted=false;f.v.ready=false;f.t.tick();eq(f.restores,nil);f.v.ready=true;f.t.tick();eq(f.restores,1)
end)
test('OFF mid route finishes known arrival and direct return with no new BUY',function()
 local f=fixture();f.v.globe_armed=false;assert(f.t.start());f.t.tick();f.t.off();eq(f.d.enabled,false);f.arrive();eq(f.d.destination,'73001');eq(f.d.pending.kind,'route');eq(#f.routes,2);f.arrive();f.fresh();eq(f.v.mode,'BASH');eq(f.d.busy,false);eq(f.d.active,false);eq(f.d.phase,'idle');eq(f.d.enabled,false);for _,cmd in ipairs(f.sent) do assert(not cmd:match('^buy ')) end
end)
test('OFF in committed health BUY settles receipt cache wallet then returns',function()
 local f=fixture();f.v.globe_armed=false;f.to_buy();local p=f.d.purchase;f.t.off();f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();eq(f.d.pending.kind,'readback');f.stockreply('health',p.expected);f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'73001');f.arrive();f.fresh();eq(f.d.busy,false);eq(f.d.enabled,false);local buys=0;for _,cmd in ipairs(f.sent) do if cmd:match('^buy ') then buys=buys+1 end end;eq(buys,1)
end)
test('OFF during anabiotic BUY permits only committed INCALL and readbacks',function()
 local f=fixture();f.v.globe_armed=false;f.to_anab_buy();local p=f.d.purchase;f.t.off();f.t.prompt();eq(f.d.pending.kind,'incall');f.t.prompt();f.stockreply('anabiotic',p.expected);f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'73001');f.arrive();f.fresh();eq(f.d.busy,false);eq(f.d.enabled,false)
end)
test('STOP preserves issued route while revoking automatic continuation',function()
 local f=fixture();assert(f.t.start());f.t.tick();local pending=f.d.pending;f.t.user_stop();eq(f.d.pending,pending);local n=#f.sent;f.arrive();eq(f.d.pending,nil);eq(f.d.route_settled,true);eq(f.v.mode,'OFF');eq(#f.sent,n);eq(#f.routes,1);eq(f.t.start(),false)
end)
test('STOP committed BUY remains retained, no new route or resume',function()
 local f=fixture();f.walk={cursor=17,visited={},consent=1,generation=1};f.to_buy();local p=f.d.pending;local purchase=f.d.purchase;f.t.user_stop();eq(f.revoked,1);local n=#f.sent;f.t.prompt();f.t.tick();eq(f.d.pending,p);eq(f.d.purchase,purchase);eq(#f.sent,n);eq(f.v.mode,'OFF');eq(f.d.resume_consent,false)
end)
test('class/session/intent/target/disconnect revoke checkpoint and retain transactions',function()
 for _,change in ipairs({'class','session','intent_epoch','target','disconnect'}) do
  local f=fixture();f.walk={cursor=17,visited={},consent=9,generation=1};f.to_buy();local p=f.d.pending;local buy=f.d.purchase
  if change=='class' then f.v.class='Archivist' elseif change=='session' then f.v.session=2 elseif change=='intent_epoch' then f.v.intent_epoch=1 elseif change=='target' then f.t.user_stop('manual target changed') else f.v.connected=false;f.t.disconnect() end
  f.t.tick();eq(f.d.active,false);eq(f.d.pending,p);eq(f.d.purchase,buy);eq(f.revoked,1);eq(f.d.resume_consent,false)
 end
end)
test('unexpected Room.Info during shopping revokes checkpoint',function()
 local f=fixture();f.walk={cursor=17,visited={},consent=1,generation=1};f.to_baseline();f.t.room_changed(99999,77,false);eq(f.d.active,false);eq(f.revoked,1);assert(f.d.pending)
end)
test('all globes exhausted does not stop ordinary stationary BASH',function()
 local f=fixture(1500,2000);f.v.globe_armed=false;f.v.globes_exhausted=true;assert(f.t.start());f.t.tick();eq(f.v.mode,'BASH');eq(f.pauses,0);eq(f.d.enabled,true)
end)
test('route timeout and sender unknown preserve barriers without retries',function()
 for _,failure in ipairs({'false','throw','timeout'}) do local f=fixture();if failure=='false' then f.on_route=function() return false end elseif failure=='throw' then f.on_route=function() error('synthetic') end end;assert(f.t.start());f.t.tick();if failure=='timeout' then f.time=301;f.t.tick() end;assert(f.d.pending);eq(f.d.active,false);local n=#f.routes;f.t.tick();eq(#f.routes,n);eq(f.t.start(),false) end
end)
test('checkpoint nil/malformed fails before mode OFF or PT',function()
 for _,case in ipairs({'nil','lease','area'}) do local f=fixture();f.io.checkpoint=function(d) if case=='nil' then return nil,'fixture denied' end;return {lease=case=='lease' and {} or d,room=f.v.room,area=case=='area' and 999 or f.v.area} end;assert(f.t.start());f.t.tick();eq(f.pauses,0);eq(#f.routes,0);eq(f.d.active,false) end
end)
test('return restored BASH may report false while arranging genuine IH',function()
 local f=fixture();f.v.globe_armed=false;f.on_resume=function() return false end;f.complete_anab();f.arrive();eq(f.v.mode,'BASH');eq(f.d.fault,nil);f.fresh();eq(f.d.busy,false)
end)
local function runtime()
 local c={mode='BASH',runner={mode='BASH'},current={connected=true,room={id=73001,area=77,items={},item_version=2},hunting={ih={room_id=73001,responded=true,start_version=1}},player={class='Monk',hp=100,maxhp=100,mana=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,mounted=false,afflictions={}},buffs={wanted={fixture=true}},policy={players_known=true,players_room=73001,players={},self_name='fixture'}},elemental_recovery={phase='idle',armed=true},travel_owner={phase='idle'},defense={plan=function() return {hold=false} end},supplies_data={stocks={health={count=199,version=1},['ic:anabiotic']={count=960,version=1}},sources={}}}
 c.supplies={state=function() return {stocks=c.supplies_data.stocks} end,audit=function(_,_,only,src) c.audit={only,src};return true end}
 local api={connected=function() return true end,clock=function() return 100 end,send=function() error('must inject test sender') end,combat_v2_set_mode=function(mode) c.stops=(c.stops or 0)+1;c.mode=mode;c.runner.mode=mode;c.current.mode=mode;return true end,combat_v2_globe=function() c.elemental_recovery.armed=true;return true end}
 c.current.hunting.ih.items=c.current.room.items;c.restock_api=api;return c,api,M.adapter(c,api)
end
test('native barriers never manufactured ready by STOP',function()
 local cases={{'runner','waiting'},{'runner','pending'},{'runner','transport_unknown'},{'runner','transport_barrier'},{'runner','fault'},{'runner','dispatching'},{'elemental_recovery','committed'},{'elemental_recovery','dispatching'},{'containers_data','barrier'},{'transport_unknown'}}
 for _,path in ipairs(cases) do local c,a=runtime();if #path==1 then c[path[1]]=true else c[path[1]]=c[path[1]] or {};c[path[1]][path[2]]=true end;local io=M.adapter(c,a);eq(io.view().ready,false);eq(io.pause(),false);eq(c.stops,nil) end
 for _,name in ipairs({'buffs','mental','walker'}) do local c,a=runtime();c.current[name]={pending={}};local io=M.adapter(c,a);eq(io.pause(),false);eq(c.stops,nil) end
end)
test('native containers quarantine untouched',function() local c,a,io=runtime();c.containers_data={quarantine='response timeout'};eq(io.pause(),true);eq(c.containers_data.quarantine,'response timeout') end)
test('native read-only probe retained across OFF',function() local c,a=runtime();local p={phase='probe',kind='recovery'};c.elemental_recovery.pending=p;c.elemental_recovery.phase='probe';c.elemental_recovery.fault='recovery timeout';a.combat_v2_set_mode=function() c.mode='OFF';c.elemental_recovery.pending=nil;c.elemental_recovery.phase='idle';return true end;eq(M.adapter(c,a).pause(),true);eq(c.elemental_recovery.pending,p);eq(c.elemental_recovery.fault,'recovery timeout') end)
test('native stock version and targeted audit only',function() local c,a,io=runtime();eq(io.stocks().health.version,1);io.query_stock('health');eq(c.audit[1],true);eq(c.audit[2],'fluidcache');io.query_stock('anabiotic');eq(c.audit[2],'ic') end)
test('native readiness includes TCP, afflictions, actual balances',function() local c,a=runtime();local io=M.adapter(c,a);eq(io.view().ready,true);a.connected=function() return false end;eq(io.view().ready,false);a.connected=function() return true end;c.current.player.left_arm_balance=false;eq(io.view().ready,false);c.current.player.left_arm_balance=true;c.current.player.afflictions.paralysis=true;eq(io.view().ready,false) end)
test('native stock unknown not fabricated',function() local c,a=runtime();c.supplies_data.stocks.health=nil;eq(M.adapter(c,a).stocks().health,nil) end)
test('adapter resume preserves wanted defenses and FirstAid independent state',function() local c,a,io=runtime();local wanted=c.current.buffs.wanted;c.firstaid={enabled=true};io.resume(false);eq(c.current.buffs.master,false);eq(c.current.buffs.wanted,wanted);eq(c.firstaid.enabled,true);io.resume(true);eq(c.current.buffs.master,true) end)
local function hooks(api)
 local id=0;local h={triggers={},events={},timers={},killed={}}
 local function add(kind,fn) id=id+1;h[kind][id]=fn;return id end
 api.tempRegexTrigger=function(_,fn) return add('triggers',fn) end;api.tempPromptTrigger=function(fn) return add('triggers',fn) end
 api.registerAnonymousEventHandler=function(_,fn) return add('events',fn) end;api.tempTimer=function(_,fn) return add('timers',fn) end
 api.killTrigger=function(i) h.triggers[i]=nil;h.killed[i]=true end;api.killAnonymousEventHandler=function(i) h.events[i]=nil;h.killed[i]=true end;api.killTimer=function(i) h.timers[i]=nil;h.killed[i]=true end
 return h
end

test('attach OFF idempotent; never modifies legacy owners',function()
 local c,a=runtime();local h=hooks(a);local legacy={active=true,cutoff_timer=999};c.lunch_duty=legacy;local t=assert(M.attach(c));eq(t.state.enabled,false);eq(t.state.active,false);eq(c.lunch_duty,legacy);eq(legacy.active,true);eq(h.killed[999],nil);eq(M.attach(c),t);eq(c.stops,nil);eq(M.detach(c),true);eq(next(h.triggers),nil);eq(next(h.events),nil);eq(next(h.timers),nil)
end)
test('registration rejects malformed IDs and cleans only owned successful handles',function()
 for _,method in ipairs({'tempRegexTrigger','tempPromptTrigger','registerAnonymousEventHandler','tempTimer'}) do
  for _,id in ipairs({false,0,-1,1.5,math.huge,'17','nil'}) do local c,a=runtime();local h=hooks(a);a[method]=function() if id~='nil' then return id end end;eq(M.attach(c),nil);eq(c.restock_controller,nil);eq(next(h.triggers),nil);eq(next(h.events),nil);eq(next(h.timers),nil) end
 end
end)
test('unresolved owner cannot detach or be replaced',function()
 local c,a=runtime();hooks(a);local t=assert(M.attach(c));t.state.pending={kind='buy'};t.state.purchase={};eq(M.detach(c),false);c.restock_controller=nil;eq(M.attach(c),nil)
end)
test('native callback uses exact walker checkpoint lease and preserves quarantine',function()
 local c,a,io=runtime();local d={};local cp={lease=d,room=73001,area=77,cursor=17,visited={},consent=8,generation=3};local calls={}
 c.current.walker={active=true}
 c.walker_module={restock_ready=function(root)eq(root,c);return true end,restock_suspend=function(root,lease)eq(root,c);eq(lease,d);calls.suspend=true;return cp end,restock_resume=function(root,p,lease)eq(root,c);eq(p,cp);eq(lease,d);calls.resume=true;return true end,restock_cancel=function(root,p,lease)eq(root,c);eq(p,cp);eq(lease,d);calls.cancel=true end}
 eq(io.walker_ready(d),true);eq(io.checkpoint(d),cp);eq(io.restore_checkpoint(cp,d),true);io.revoke_checkpoint(cp,d,'stop');eq(calls.suspend,true);eq(calls.resume,true);eq(calls.cancel,true)
 c.containers_data={quarantine='unchanged'};io.pause();eq(c.containers_data.quarantine,'unchanged')
end)
test('native real IH version, not text empty or cached table',function()
 local c,a,io=runtime();eq(io.view().room_known,true);c.current.hunting.ih.start_version=2;eq(io.view().room_known,false);c.current.hunting.ih.start_version=1;c.current.hunting.ih.items={};eq(io.view().room_known,false);c.current.hunting.ih.items=c.current.room.items;c.current.hunting.ih.pending=true;eq(io.view().room_known,false)
end)
test('native movement borrowing exact lease destination owner and serial',function()
 local c,a=runtime();local d={active=true,resume_consent=true,busy=true,phase='route',destination='12669',pending={kind='route'},route_serial=3,route_destination='12669'};local tr={serial=4,destination='12669',intent='pt'};d.route_owner=tr;c.restock_data=d;c.user_activity=d;c.travel_owner=tr
 eq(M.movement_borrowed(c),true);eq(M.owns_transition(c),false);d.dispatching=true;eq(M.owns_transition(c),true);d.dispatching=false;tr.destination='999';eq(M.movement_borrowed(c),false);tr.destination='12669';c.user_activity={};eq(M.movement_borrowed(c),false);c.user_activity=d;d.fault='unknown';eq(M.movement_borrowed(c),false)
end)
test('native global transport and genuine recovery barriers never cleared',function()
 local c,a=runtime();for _,key in ipairs({'transport_unknown','dispatching','pending','waiting','fault'}) do c.runner[key]=true;eq(M.adapter(c,a).view().ready,false);c.runner[key]=nil end
 c.elemental_recovery.committed=true;eq(M.adapter(c,a).view().ready,false);eq(c.elemental_recovery.committed,true)
end)

test('health-only full FSM skips already full anabiotic',function()
 local f=fixture(150,2000);f.v.globe_armed=false;f.complete_health();eq(f.d.destination,'73001');eq(#f.queries,2);f.arrive();f.fresh();eq(f.d.busy,false);eq(f.stocks.health.count,1500);eq(f.stocks['ic:anabiotic'].count,2000);eq(f.arms,0)
end)
test('anabiotic-only full FSM skips already full health',function()
 local f=fixture(1500,199);f.v.globe_armed=false;f.to_directory();f.directory('anabiotic');f.arrive();f.wares('anabiotic');f.stockreply('anabiotic');f.inventory();local p=f.d.purchase;eq(p.count,1801);f.t.prompt();f.t.prompt();f.stockreply('anabiotic',2000);f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'73001');f.arrive();f.fresh();eq(f.d.busy,false);eq(#f.queries,2)
end)
test('native captured combined WARES frame accepted with synthetic row only',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.lines({'Proprietor: Offline Fixture','-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','[CURATIVES AND OTHER CACHE-ABLES]','cask999 a refill of an elixir of health 196 25gp','You can see 1 item(s) being sold in this location.'});f.t.prompt();eq(f.d.pending.kind,'baseline');eq(f.d.item.id,'cask999')
end)
test('missing proprietor or duplicate native header fails before BUY',function()
 for _,bad in ipairs({'missing','duplicate'}) do local f=fixture();f.to_directory();f.directory('health');f.arrive();if bad=='duplicate' then f.t.text('Proprietor: Offline Fixture')end;f.t.text('-------------(Item)-(Description)-------------------------------(Stock)-(Price)-');if bad=='duplicate' then f.t.text('-------------(Item)-(Description)-------------------------------(Stock)-(Price)-')end;f.lines({'cask999 a refill of an elixir of health 196 25gp','You can see 1 item(s) being sold in this location.'});f.t.prompt();eq(f.d.active,false);eq(f.d.purchase,nil) end
end)
test('unobserved ambiguous anabiotic native unit cannot BUY',function()
 local f=fixture(1500,199);f.to_directory();f.directory('anabiotic');f.arrive();f.wares('anabiotic',{'pill888 anabiotic 5000 3gp'});eq(f.d.active,false);eq(f.d.purchase,nil);for _,cmd in ipairs(f.sent) do assert(not cmd:match('^buy ')) end
end)
test('BUY receipt alone cannot credit IC or prove wallet',function()
 local f=fixture();f.to_anab_buy();f.t.text('You purchase synthetic pills.');eq(f.stocks['ic:anabiotic'].count,960);f.t.prompt();f.t.prompt();eq(f.d.pending.kind,'readback');eq(f.stocks['ic:anabiotic'].count,960);assert(f.d.purchase)
end)
test('synthetic nonmultiple health refill targets full cache, never 1499',function()
 local f=fixture(199,2000);f.v.globe_armed=false;f.to_buy();local p=f.d.purchase;eq(p.count,27);eq(p.expected,1500);eq(p.maximum,1549);f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',1500);f.gold=f.gold-p.cost;f.inventory();eq(f.d.destination,'73001');eq(f.stocks.health.count,1500)
end)
test('authoritative cache beyond maximum purchased quantity is not accepted',function()
 local f=fixture();f.to_buy();local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.stockreply('health',9999);eq(f.d.active,false);assert(f.d.purchase)
end)
test('reentrant false or throwing BUY never credits staged synchronous evidence',function()
 for _,outcome in ipairs({'false','throw'}) do local f=fixture();f.to_baseline();f.stockreply('health');f.on_send=function(cmd) if cmd:match('^buy ') then local p=f.d.purchase;f.t.text('You pay '..p.cost..' gold sovereigns to add '..(p.count*50)..' sips of an elixir of health to your fluidcache.');f.t.prompt();f.t.tick();if outcome=='throw' then error('synthetic')end;return false end end;f.inventory();eq(f.d.pending.kind,'buy');eq(f.d.active,false);assert(f.d.purchase);local n=#f.sent;f.t.tick();f.t.prompt();eq(#f.sent,n);eq(#f.queries,1) end
end)
test('OFF during directory read-only settlement returns with zero purchases',function()
 local f=fixture();f.v.globe_armed=false;f.to_directory();local p=f.d.pending;f.t.off();eq(f.d.pending,p);f.directory('health');eq(f.d.destination,'73001');eq(f.d.enabled,false);f.arrive();f.fresh();eq(f.d.busy,false);for _,cmd in ipairs(f.sent)do assert(not cmd:match('^buy '))end
end)
test('OFF before unsent buy cannot strand planned purchase or issue BUY',function()
 local f=fixture();f.to_baseline();f.stockreply('health');f.v.ready=false;f.inventory();eq(f.d.phase,'buy');eq(f.d.pending,nil);assert(f.d.purchase);f.t.off();f.v.ready=true;f.t.tick();eq(f.d.purchase,nil);eq(f.d.destination,'73001');for _,cmd in ipairs(f.sent)do assert(not cmd:match('^buy '))end
end)
test('checkpoint deferred fresh inspection is a wait, invalid checkpoint is a fault',function()
 local f=fixture();f.v.globe_armed=false;f.walk={cursor=17,visited={},consent=9,generation=1};f.complete_anab();f.arrive();local original=f.io.restore_checkpoint;f.io.restore_checkpoint=function()return false,'awaiting fresh inspection'end;f.fresh();eq(f.d.fault,nil);eq(f.d.busy,true);f.io.restore_checkpoint=original;f.t.tick();eq(f.restores,1);eq(f.d.busy,false)
 local g=fixture();g.v.globe_armed=false;g.walk={cursor=17,visited={},consent=9,generation=1};g.complete_anab();g.arrive();g.io.restore_checkpoint=function()return false,'invalidated restock checkpoint'end;g.fresh();eq(g.d.active,false);eq(g.revoked,1)
end)
test('new return enemy gets BASH pressure before frozen checkpoint restoration',function()
 local f=fixture();f.v.globe_armed=false;f.walk={cursor=17,visited={},consent=9,generation=1};f.complete_anab();f.v.empty=false;f.arrive();eq(f.v.mode,'BASH');f.fresh();eq(f.restores,nil);eq(f.d.fault,nil);f.v.empty=true;f.fresh();eq(f.restores,1)
end)
test('cancelled low reservation can be explicitly enabled in a later session',function()
 local f=fixture();f.v.empty=false;assert(f.t.start());f.t.tick();f.t.off();f.v.session=2;f.v.intent_epoch=1;f.v.class='Archivist';assert(f.t.start());f.v.empty=true;f.t.tick();eq(f.pauses,1);eq(f.d.original_class,'Archivist');eq(f.d.original_session,2);eq(f.d.fault,nil)
end)
test('manual movement during low reservation revokes, valid pending hop can settle',function()
 local f=fixture();f.v.empty=false;assert(f.t.start());f.t.tick();eq(f.t.room_changed(73002,77,false),false);eq(f.d.active,false);eq(f.pauses,0)
 local g=fixture();g.hop=true;assert(g.t.start());g.t.tick();eq(g.t.room_changed(73002,77,false),true);g.v.room=73002;g.hop=false;g.t.tick();eq(g.d.return_room,73002)
end)
test('native stationary fallback refuses unknown active walker without API',function()
 local c,a,io=runtime();eq(io.checkpoint({}),false);c.current.walker={active=true};eq(io.walker_ready({}),false);eq(io.checkpoint({}),nil)
end)
test('native direct walker_boot adapter preferred over pure or alias planner',function()
 local c,a,io=runtime();c.current.walker={active=true};local d={};local cp={lease=d};c.walker_module={restock_suspend=function()error('must use native boot')end};c.walker={restock_suspend=function()error('pure planner must not be used')end};c.walker_boot={restock_suspend=function(root,lease)eq(root,c);eq(lease,d);return cp end};eq(io.checkpoint(d),cp)
end)


test('temporary XP cutoff during trip suppresses saved Globe but not BASH or restock',function()
 local f=fixture();f.complete_anab();f.v.globe_resume_allowed=false;f.arrive();f.fresh();eq(f.d.enabled,true);eq(f.d.resume_globe,false);eq(f.arms,0);eq(f.summons,0);eq(f.v.mode,'BASH');eq(f.d.busy,false)
end)
test('XP cutoff at rearm boundary is a revoked spawn, not a failed shopping trip',function()
 local f=fixture();f.complete_anab();f.arrive();f.on_arm=function()f.v.globe_resume_allowed=false;f.t.globe_off();return false end;f.fresh();eq(f.d.fault,nil);eq(f.d.enabled,true);eq(f.d.busy,false);eq(f.summons,0);eq(f.v.mode,'BASH')
end)
test('native XP latch prevents both Globe arm and new initial summon without touching observer',function()
 local c,a,io=runtime();local calls=0;local observer={enabled=true,triggered=true,module={},handles={91,92}};c.xp_globe_cutoff=observer;c.restock_data={return_room=73001};a.combat_v2_globe=function()calls=calls+1;return true end;c.elementals={service=function()calls=calls+1 end};eq(io.view().globe_resume_allowed,false);eq(io.arm_globe(),false);eq(io.summon(),false);eq(calls,0);eq(c.xp_globe_cutoff,observer);eq(c.xp_globe_cutoff.handles[1],91);observer.enabled=false;eq(io.view().globe_resume_allowed,true)
end)
test('duplicate wares item rows cannot authorize a purchase',function()
 local f=fixture();f.to_directory();f.directory('health');f.arrive();f.wares('health',{'cask999 a refill of an elixir of health 500 25gp','cask999 a refill of an elixir of health 500 99gp'});eq(f.d.active,false);eq(f.d.purchase,nil)
end)


test('reentrant STOP or OFF while acquiring cannot dispatch a new pause or route',function()
 for _,kind in ipairs({'stop','off'})do local f=fixture();f.io.acquire=function(d)f.lease=d;if kind=='stop'then f.t.user_stop()else f.t.off()end;return true end;assert(f.t.start());f.t.tick();eq(f.pauses,0);eq(#f.routes,0);eq(f.lease,nil)end
end)
test('reentrant STOP inside checkpoint revokes newly returned lease before any pause',function()
 local f=fixture();local cp;f.io.checkpoint=function(d)cp={lease=d,room=f.v.room,area=f.v.area};f.t.user_stop();return cp end;assert(f.t.start());f.t.tick();eq(f.pauses,0);eq(#f.routes,0);eq(cp.revoked,true);eq(f.d.active,false);eq(f.revoked,1)
end)


test('canonical native area is preserved instead of mapper numeric area_id',function()
 local c,a,io=runtime();c.current.room.area='Synthetic Native Area';c.current.room.area_id=77;eq(io.view().area,'Synthetic Native Area')
end)

test('idle-looking OFF preserves every real unresolved Restock barrier',function()
 for _,barrier in ipairs({'fault','query_quarantine','pending','purchase','busy','dispatching','checkpoint','owned_pause','route_owner'})do
  local f=fixture();local d=f.d;d.phase='monitor';d[barrier]=barrier=='fault' and 'original fault' or barrier=='query_quarantine' and 'old stream' or (barrier=='busy' or barrier=='dispatching' or barrier=='owned_pause') and true or {};local old=d[barrier]
  if barrier=='checkpoint'then old.lease=d end
  f.t.user_stop();eq(d[barrier],old,'retain '..barrier);eq(d.resume_consent,false);assert(d.fault);eq(f.t.start(),false)
 end
 local f=fixture();f.t.off();eq(f.t.user_stop(),true);eq(f.d.fault,nil);eq(f.t.start(),true);f.v.mode='OFF';f.t.tick();eq(#f.routes,0)
end)
test('partial scope holds complete query and BUY until full location, leases still expire',function()
 local f=fixture();f.to_baseline();f.stockreply('health');local p=f.d.pending
 f.v.room=nil;f.v.area=nil;f.t.room_changed(nil,nil,false);f.inventory();eq(f.d.pending,p);eq(p.gold,f.gold);eq(f.d.fault,nil);eq(f.d.purchase,nil)
 f.v.room=12668;f.v.area=88;f.t.room_changed(12668,88,false);f.t.tick();eq(f.d.pending.kind,'buy');assert(f.d.purchase)
 local g=fixture();g.to_directory();local query=g.d.pending;g.v.room=nil;g.v.area=nil;g.t.room_changed(nil,nil,false);g.time=61;g.t.tick();assert(g.d.fault:find('timeout:',1,true));eq(g.d.pending,query);assert(g.d.query_quarantine)
end)
test('native fixed-width directory padding for both supplies',function()
 local function padded(f,k,room,desc,price)
  eq(f.d.pending.kind,'directory');eq(f.d.kind,k)
  f.lines({'VNum   Owner           Description                                     Price','---------------------------------------------------------------------------','[Spinesreach]',string.format('%s  Fixture         %-48s %2dgp',room,desc,price),'---------------------------------------------------------------------------','You can locate the listed shops by doing PATH FIND <vnum>.'});f.t.prompt()
  eq(f.d.fault,nil,'padded native-style row must parse');eq(f.d.destination,room)
 end
 local h=fixture(150,960);h.to_directory();padded(h,'health','73002','a refill of an elixir of health',25)
 local a=fixture(150,960);a.complete_health();a.arrive();padded(a,'anabiotic','73003','an anabiotic pill',4)
end)
print('restock: '..tests..' tests, '..assertions..' assertions passed (offline fake IO only)')
