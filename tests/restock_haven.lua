-- OFFLINE ONLY; syntax native, every account/location/amount synthetic.
local root=(arg[1] or 'combat_v2/'):gsub('/+$','')..'/'
local R=dofile(root..'restock.lua');local B=dofile(root..'restock_boot.lua')
local F=dofile(((arg[0] or ''):match('^(.*[/])') or 'tests/')..'restock.lua')
local tests,checks=0,0
local function eq(a,b,m)checks=checks+1;assert(a==b,(m or '')..' expected '..tostring(b)..' got '..tostring(a))end
local function test(name,fn)local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));tests=tests+1 end
local cfg={haven_room='73009',globe_haven_return=true}
local function fresh(globe,inside)
 local f=F.fixture(199,1200);f.v.globe_armed=globe;f.v.full_resources=true
 if inside then f.v.room=73009;f.v.area='Mutable Private Name';f.v.players_room=73009 end
 f.t=R.new(f.io,cfg);f.d=f.t.state;return f
end
local function room(f,id,area)
 f.v.room=id;f.v.area=area;f.v.players={};f.v.players_room=id;f.t.room_changed(id,area,false)
end
local function shopping(f)
 for i=1,45 do
  local p=f.d.pending
  if f.d.fault then error(f.d.fault)end
  if f.d.phase=='haven_wait' then return end
  if not p then f.t.tick()
  elseif p.kind=='route' then f.arrive()
  elseif p.kind=='directory' then
   f.directory(f.d.kind,f.d.kind=='anabiotic' and {'73007 Fixture an anabiotic pill 4gp','73006 Fixture an anabiotic pill 5gp'} or nil)
  elseif p.kind=='wares' then
   if f.d.kind=='anabiotic' then
    f.lines({'Proprietor: Synthetic Seller','-------------(Item)-(Description)-------------------------------(Stock)-(Price)-','[Pill Poppers Paradise]','          anabiotic an anabiotic pill                             3100      4gp','You can see 1 item(s) being sold in this location.'});f.t.prompt()
   else f.wares('health')end
  elseif p.kind=='baseline' then f.stockreply(f.d.kind)
  elseif p.kind=='inventory_before' then f.inventory()
  elseif p.kind=='buy' then
   if f.d.kind=='health' then local b=f.d.purchase;f.t.text('You pay '..b.cost..' gold sovereigns to add '..b.count*50 ..' sips of an elixir of health to your fluidcache.')end
   f.t.prompt()
  elseif p.kind=='incall' then f.t.prompt()
  elseif p.kind=='readback' then f.stockreply(f.d.kind,f.d.purchase.expected)
  elseif p.kind=='inventory_after' then f.gold=f.gold-f.d.purchase.cost;f.inventory()
  else error('unexpected phase '..f.d.phase..'/'..p.kind)end
 end
 error('shopping fixture bound exceeded')
end
local function begin(f)
 assert(f.t.start());f.t.tick()
 if f.d.phase=='haven_exit' then
  eq(f.d.pending.command,'exit haven');eq(#f.routes,0);room(f,73008,'Outside');eq(#f.routes,0);f.t.prompt()
 end
 eq(f.d.pending.kind,'route');shopping(f)
end

test('exact SKU allowlist only, no arbitrary command words',function()
 assert(R.wares_row('anabiotic','anabiotic an anabiotic pill 3000 4gp'))
 assert(R.wares_row('anabiotic','pill555 an anabiotic pill 3000 4gp'))
 for _,id in ipairs({'quit','anabiotic;quit','ANABIOTIC','cask555','pill','foo555'})do eq(R.wares_row('anabiotic',id..' an anabiotic pill 3000 4gp'),nil)end
 eq(R.wares_row('health','anabiotic a refill of an elixir of health 500 25gp'),nil)
end)
test('full Haven trip tops both caches, cheapest alphabetic SKU, no PT private',function()
 local f=fresh(true,true);begin(f);eq(f.d.origin_room,73009);eq(f.d.return_room,'73009');eq(f.d.checkpoint,nil)
 eq(f.stocks.health.count,1500);eq(f.stocks['ic:anabiotic'].count,2000)
 local buy=0;for _,cmd in ipairs(f.sent)do if cmd=='buy 800 anabiotic'then buy=buy+1 end end;eq(buy,1)
 for _,dest in ipairs(f.routes)do assert(dest~='73009' and dest~='73006')end
 eq(f.d.phase,'haven_wait');f.v.full_resources=false;f.t.tick();eq(f.d.pending,nil)
 f.v.full_resources=true;f.t.tick();eq(f.d.pending.kind,'haven_return');local p=f.d.pending
 f.time=f.time+21;f.t.prompt();eq(f.d.pending,p);eq(f.v.mode,'OFF')
 room(f,73010,'Wrong Haven');f.t.prompt();eq(f.d.pending,p)
 room(f,nil,nil);f.t.prompt();eq(f.d.pending,p)
 room(f,73009,'Entirely Renamed Plane');eq(f.d.pending,p);f.t.prompt();eq(f.d.fault,nil);eq(f.v.mode,'BASH');eq(f.arms,0)
 f.fresh();eq(f.arms,1);eq(f.summons,1);f.v.globe_idle=true;f.t.prompt();eq(f.d.busy,false)
 local exits,returns=0,0;for _,cmd in ipairs(f.sent)do if cmd=='exit haven'then exits=exits+1 elseif cmd=='return to haven'then returns=returns+1 end end;eq(exits,1);eq(returns,1)
end)
test('GLOBE ON started outside returns private ID not old origin',function()
 local f=fresh(true,false);begin(f);eq(f.d.origin_room,73001);eq(f.d.return_room,'73009');for _,cmd in ipairs(f.sent)do assert(cmd~='exit haven')end
 f.t.tick();eq(f.d.pending.kind,'haven_return');room(f,73009,'Renamed');f.t.prompt();eq(f.d.fault,nil)
end)
test('ordinary GLOBE OFF walker keeps exact cursor and has zero Haven commands',function()
 local f=fresh(false,false);f.walk={cursor=17,visited={},consent=6,generation=3};f.complete_anab();f.arrive();f.fresh();eq(f.walk.cursor,17);eq(f.restores,1);eq(f.d.haven_mode,false)
 for _,cmd in ipairs(f.sent)do assert(cmd~='exit haven' and cmd~='return to haven')end
end)
test('known parse and no-money failures release owned lease but retain FAULT',function()
 for _,kind in ipairs({'frame','money'})do
  local f=F.fixture();if kind=='frame'then f.to_directory();f.t.text('You can locate the listed shops by doing PATH FIND <vnum>.');f.t.prompt()else f.to_baseline();f.stockreply('health');f.inventory(0)end
  eq(f.d.active,false);eq(f.d.busy,false);eq(f.lease,nil);eq(f.d.recoverable,true);assert(f.d.fault);eq(f.v.mode,'OFF');eq(f.t.start(),false)
 end
end)
test('recoverable query refusal not shop fallback; unknown route stays held',function()
 local f=F.fixture();f.to_directory();f.directory('health');f.v.travel_idle=true;f.v.travel_refusal={kind='find_cooldown',reason='synthetic cooldown'};f.t.prompt();eq(f.d.busy,false);eq(#f.routes,2);eq(f.d.pending,nil);assert(f.d.fault)
 f=F.fixture();f.to_directory();f.v.travel_fault='acknowledgement timeout: find';f.t.tick();eq(f.d.busy,true);assert(f.d.pending)
end)
test('Haven exit waits actual different full scope and subsequent ready prompt',function()
 local f=fresh(true,true);assert(f.t.start());f.t.tick();local p=f.d.pending
 f.time=30;f.t.prompt();eq(f.d.pending,p);eq(#f.routes,0)
 room(f,73009,'Different labels same ID');f.t.prompt();eq(#f.routes,0)
 room(f,73008,nil);f.t.prompt();eq(#f.routes,0)
 room(f,73008,'Outside');f.v.ready=false;f.t.prompt();eq(#f.routes,0);f.v.ready=true;f.t.tick();eq(#f.routes,1)
end)
test('STOP/disconnect issued Haven transport settles location only, no replay',function()
 for _,why in ipairs({'stop','disconnect'})do
  local f=fresh(true,true);assert(f.t.start());f.t.tick();local p=f.d.pending
  if why=='stop'then f.t.user_stop()else f.t.disconnect()end
  eq(f.d.pending,p);eq(f.d.busy,true);room(f,73008,'Outside');f.t.prompt();eq(f.d.pending,nil);eq(f.d.haven_settled,true);eq(#f.routes,0);eq(f.v.mode,'OFF')
 end
end)
test('false/throw reentrant Haven sends remain unknown even with staged arrival',function()
 for _,outcome in ipairs({'false','throw'})do
  local f=fresh(true,true);f.on_send=function(cmd)if cmd=='exit haven'then room(f,73008,'Outside');f.t.prompt();eq(#f.routes,0);if outcome=='throw'then error('synthetic wire')end;return false end end
  assert(f.t.start());f.t.tick();eq(f.d.active,false);eq(f.d.pending.kind,'haven_exit');f.t.prompt();eq(f.d.pending.kind,'haven_exit');eq(#f.routes,0)
 end
end)
test('Haven timeout never grants arrival, OFF cannot erase issued return',function()
 local f=fresh(true,true);begin(f);f.t.tick();local p=f.d.pending;f.t.off();eq(f.d.pending,p);f.time=121;f.t.tick();eq(f.d.pending,p);eq(f.d.active,false);eq(f.arms,0);eq(f.v.mode,'OFF')
end)
test('public Globe OFF cancels unissued Haven return, issued return still settles',function()
 local f=fresh(true,true);begin(f);f.t.globe_off();f.t.tick();eq(f.d.pending,nil);eq(f.d.busy,false);eq(f.v.mode,'OFF');eq(f.arms,0)
 f=fresh(true,true);begin(f);f.t.tick();local p=f.d.pending;f.t.globe_off();eq(f.d.pending,p);room(f,73009,'Renamed');f.t.prompt();f.fresh();eq(f.arms,0);eq(f.summons,0)
end)
test('temporary XP cutoff still suppresses new Globe at Haven arrival',function()
 local f=fresh(true,true);begin(f);f.t.tick();f.v.globe_resume_allowed=false;room(f,73009,'Renamed');f.t.prompt();f.fresh();eq(f.arms,0);eq(f.summons,0);eq(f.d.enabled,true)
end)
test('strict settings parser never evaluates, defaults no permission',function()
 local c=assert(R.settings_json('{ "globe_haven_return": true, "haven_room": "73009" }'));eq(c.haven_room,'73009')
 for _,raw in ipairs({'return os.exit()','{}','{"haven_room":"73009","haven_room":"73008","globe_haven_return":true}','{"haven_room":"073009","globe_haven_return":true}','{"haven_room":"73009","globe_haven_return":1}','{"haven_room":"73009","globe_haven_return":true,}','{"haven_room":"73009","globe_haven_return":true,"enabled":true}'})do eq(R.settings_json(raw),nil)end
 local f=fresh(true,true);local t=R.new(f.io,c);eq(t.state.enabled,false);eq(t.state.active,false);local old={phase='idle',enabled=false,active=false,prompt=9};eq(R.new(f.io,c,old).state,old)
end)
test('adapter resource fullness uses canonical maxmana and >= max HP',function()
 local c,a=F.runtime();c.current.player.maxmana=100;c.current.player.mana=100;c.current.player.hp=101;eq(R.adapter(c,a).view().full_resources,true);c.current.player.mana=99;eq(R.adapter(c,a).view().full_resources,false)
end)
test('settings read failures are durable diagnostics not physical or UI barriers',function()
 local f=F.fixture();local api={getMudletHomeDir=function()return '/synthetic' end}
 for _,open in ipairs({function()error('read unavailable')end,function()return nil,'permission denied',13 end,function()return {read=function()error('read failed')end,close=function()end}end})do
  api.open_file=open;local settings,why=R.read_settings(api);assert(why)
  local t=R.new(f.io,settings,nil,why);eq(t.start(),false);t.tick();eq(t.state.pending,nil);eq(t.state.fault,nil);eq(t.state.busy,false)
  t.off();eq(t.start(),false);local old=t.state;old.fault='unknown BUY';old.pending={kind='buy'}
  local rebuilt=R.new(f.io,cfg,old);eq(rebuilt.state.configuration_error,why);eq(rebuilt.state.pending,old.pending);eq(rebuilt.state.fault,'unknown BUY');eq(rebuilt.start(),false)
 end
 api.open_file=function()return nil,'absent',2 end;local settings,why=R.read_settings(api);eq(why,nil);assert(R.new(f.io,settings).start())
end)
print('restock_haven: '..tests..' tests, '..checks..' assertions passed (offline only)')
