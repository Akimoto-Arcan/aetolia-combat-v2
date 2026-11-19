-- Offline regression: real module, FakeClock and FakeSender only.
local root=arg[1] or 'combat_v2/'
local M=dofile(root..'containers.lua')
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg or ('check '..checks)) end
local kinds={'vial','pipe','bandage'}
local commands={viallist='vial',pipelist='pipe',bandagelist='bandage'}
local headers={vial='Vial Elixir Sips Decay',pipe='Pipe Herb Puffs Decay Lit',bandage='Bandage Poultice Presses Decay'}
local required={vial={'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'},
 pipe={'reishi','willow','yarrow'},bandage={'caloric','epidermal','mass','mending','restoration','soothing'}}
local function fixture()
 local f={vial={},pipe={},bandage={}}
 for k,ns in pairs(required) do for i,n in ipairs(ns) do
  local label=k=='vial' and ('an elixir of '..n) or k=='bandage' and ('a '..n..' poultice') or
   ({reishi='a reishi mushroom',willow='some willow bark',yarrow='a yarrow root'})[n]
  if n=='arcane' then label='an elixir of the arcane' end
  if n=='purgative' then label='a purgative concoction' end
  f[k][i]={id=k..(100+i),label=label,n=250,decay='A',lit='Yes'}
 end end
 return f
end
local function context()
 local t=1000;local connected=true
 local c={mode='OFF',queries={},actions={},stocks={}}
 c.containers_clock=function()return t end
 c.containers_connected=function()return connected end
 c.advance=function(dt)t=t+dt end
 c.connected=function(v)connected=v end
 c.supplies={state=function()return {stocks=c.stocks}end}
 c.query=function(cmd)c.queries[#c.queries+1]=cmd end
 c.action=function(cmd)c.actions[#c.actions+1]=cmd end
 return c
end
local function frame(c,k,rows,malformed)
 M.text(c,headers[k]);M.text(c,'-------------------------')
 for _,r in ipairs(rows) do M.text(c,r.id..'  '..r.label..'  '..r.n..'  '..r.decay..(k=='pipe' and ('  '..r.lit) or '')) end
 if malformed then M.text(c,k..'BROKEN  invalid') end
 M.text(c,'-------------------------');M.prompt(c)
end
local function audit(c,f,k)
 check(M.audit(c,c.query,k),'audit dispatch')
 for _,kind in ipairs(k and {k} or kinds) do frame(c,kind,f[kind]) end
end
local function supply(c,n,amount,age)c.stocks[n]={count=amount,at=c.containers_clock()-(age or 0)}end
local function use(c,n)M.text(c,'You take a drink of an elixir of '..n..' from an academy vial.')end
local function has(c,text)
 for _,v in ipairs(M.state(c).issues)do if v:find(text,1,true) then return true end end
 return false
end
local function empty(row)row.n=0;row.label='empty'end
local function run(c,n,dt)
 for i=1,n do c.advance(dt or 1);M.service(c,c.action)end
end
-- A hundred confirmed uses retain baseline time, never fan out queries.
local c=context();local f=fixture();audit(c,f)
local at=M.state(c).sources.vial.at
for i=1,100 do use(c,'vigor');run(c,1) end
local s=M.state(c)
check(#c.queries==3 and #c.actions==0 and not c.containers_data.stock_needed,'100 normal uses: no additional lists/actions/cache checks')
check(s.containers.vial104.count==150 and s.containers.vial104.verified_count==250,'unique known ID decremented exactly')
check(s.containers.vial104.estimated and s.containers.vial104.tracked and not s.containers.vial104.authoritative,'usage-derived fields distinct')
check(s.sources.vial.at==at and not s.sources.vial.fresh and s.sources.vial.tracked,'authoritative timestamp never refreshed')
check(s.complete and not s.completefresh and not s.stale,'tracked complete is not completefresh')
run(c,100,10)
check(#c.queries==3 and not has(c,'stale/unknown'),'no 90-second idle poll or stale flood')
check(M.state(c).containers.vial104.count==150,'time never consumes uses')
-- Ignore speech, proposals, unrelated fluids and malformed/unknown receipts.
for _,line in ipairs({'Bob says, "You take a drink of an elixir of vigor from an academy vial."',
 'You will take a drink of an elixir of vigor from an academy vial.',
 'You take a drink of an elixir of nonsense from an academy vial.',
 'You take a drink of an elixir of vigor from a mysterious container.',
 'You take a drink of an elixir of vigor from an academy vial. Extra text.',
 'You smoke something unknown.','You press something unknown against your body.'})do M.text(c,line)end
run(c,10)
check(M.state(c).containers.vial104.count==150 and #c.queries==3,'unrecognized receipts cannot consume/query')
-- Existing exact known smoke/press forms affect only their kinds.
M.text(c,'You smoke a reishi mushroom.')
M.text(c,'You press a mending poultice against your body.')
check(M.state(c).containers.pipe101.count==249 and M.state(c).containers.bandage104.count==249,'known conservative old use forms')
check(#c.queries==3,'other kinds also passive')
-- Duplicate fluid: bounded aggregate debt, never pick an exact ID.
c=context();f=fixture();f.vial[4].n=2
f.vial[#f.vial+1]={id='vial999',label='an elixir of vigor',n=20,decay='A'}
audit(c,f);use(c,'vigor');s=M.state(c)
check(s.containers.vial104.count==2 and s.containers.vial999.count==20,'duplicates never falsely selected')
check(s.sources.vial.debt.vigor==1 and s.containers.vial104.count_lower==1 and s.containers.vial999.count_lower==19,'conservative per-ID bounds')
M.service(c,c.action);check(#c.queries==3,'no premature readback')
use(c,'vigor');M.service(c,c.action)
check(#c.queries==4 and c.queries[4]=='viallist' and #c.actions==0,'possible empty queues ONE targeted readback')
check(c.containers_data.stock_needed=='fluidcache','possible vial exhaustion also requests FC proof once')
c.containers_data.stock_needed=nil
frame(c,'vial',f.vial,true)
for i=1,100 do use(c,'vigor');M.service(c,c.action)end
check(#c.queries==4 and #c.actions==0 and not c.containers_data.stock_needed,'malformed readback does not retry lists/cache proof or authorize inferred zero')
check(c.containers_data.sources.vial.stale,'malformed evidence still invalid')
-- Unknown matching ID/type never invents authority or searches every use.
c=context();f=fixture();table.remove(f.vial,4);audit(c,f)
for i=1,100 do use(c,'vigor');M.service(c,c.action)end
check(#c.queries==3 and #c.actions==0 and not M.state(c).containers.vial104,'missing type has no fake ID or fill')
check(M.state(c).sources.vial.unknown_uses==100,'unknown uses visible independently')
c=context();f=fixture();empty(f.vial[4]);audit(c,f);supply(c,'vigor',100)
use(c,'vigor');run(c,10)
check(#c.queries==3 and #c.actions==0 and not M.state(c).containers.vial104.type,'unknown empty ID not assigned from usage')
-- Native FC autofill last sip: usage zero is not empty authority.
c=context();f=fixture();f.vial[4].n=1;audit(c,f);supply(c,'vigor',100)
use(c,'vigor');s=M.state(c)
check(s.containers.vial104.count==0 and s.containers.vial104.estimated and not s.containers.vial104.empty,'derived zero not authoritative empty')
M.service(c,c.action)
check(#c.actions==0 and #c.queries==4 and c.queries[4]=='viallist','readback precedes any helper action')
f.vial[4].n=200;frame(c,'vial',f.vial);run(c,10)
check(#c.actions==0 and not M.state(c).containers.vial104.estimated and M.state(c).containers.vial104.count==200,'native autofill wins with authoritative count')
check(not c.containers_data.sources.vial.usage_readback,'positive native frame resets query budget')
-- A fresh EMPTY readback may refill with old other-kind lists.
c=context();f=fixture();f.vial[4].n=1;audit(c,f);c.advance(100)
supply(c,'vigor',100);use(c,'vigor');M.service(c,c.action)
empty(f.vial[4]);frame(c,'vial',f.vial)
check(not M.state(c).completefresh and M.state(c).sources.vial.fresh,'other kinds old; source-local proof remains fresh')
check(M.service(c,c.action) and c.actions[1]=='fluidcache fill vigor vial104','fresh kind, known empty, positive fresh stock permits fill')
M.text(c,'You fill vial104 with an elixir of vigor.')
check(M.state(c).refill and M.state(c).containers.vial104.count==0,'ack does not invent stock or clear barrier')
M.service(c,c.action)
check(#c.queries==5 and c.queries[5]=='viallist','post-refill readback targets only barrier.kind')
f.vial[4].label='an elixir of vigor';f.vial[4].n=150;frame(c,'vial',f.vial)
check(not M.state(c).refill and M.state(c).containers.vial104.count==150,'post-action positive native readback resolves barrier')
-- Fresh authoritative empty + unknown cache creates ONE stock proof request.
c=context();f=fixture();audit(c,f);empty(f.bandage[4]);audit(c,f,'bandage')
M.service(c,c.action)
check(c.containers_data.stock_needed=='fluidcache','empty bandage requests FC proof')
c.containers_data.stock_needed=nil;run(c,50)
check(c.containers_data.stock_needed==nil and #c.actions==0,'failed/unknown stock proof does not regenerate marker every tick')
audit(c,f,'bandage');M.service(c,c.action)
check(c.containers_data.stock_needed=='fluidcache','new native empty generation rearms stock proof budget')
c=context();f=fixture();audit(c,f);empty(f.pipe[2]);audit(c,f,'pipe');M.service(c,c.action)
check(c.containers_data.stock_needed=='ic','pipe requests IC only')
c.containers_data.stock_needed=nil;supply(c,'ic:willow',0);run(c,5)
check(#c.actions==0 and not c.containers_data.stock_needed,'fresh known depleted reserve does not request/buy stock')
-- Native cache adapter reentry cannot authorize fill after a positive readback.
c=context();f=fixture();audit(c,f);empty(f.vial[4]);audit(c,f,'vial')
c.supplies.state=function()
 f.vial[4].label='an elixir of vigor';f.vial[4].n=200;audit(c,f,'vial')
 return {stocks={vigor={count=100,at=c.containers_clock()}}}
end
check(not M.service(c,c.action) and #c.actions==0,'reentrant native autofill wins before transport')
-- Age decay is elapsed REAL days, not rendered ticks, and A never expires.
c=context();f=fixture();f.vial[1].decay='5';f.bandage[1].decay='6';audit(c,f)
check(not has(c,'health vial101: expires'),'exactly five days healthy')
c.advance(43200);s=M.state(c)
check(s.containers.vial101.decay==4.5 and has(c,'health vial101: expires in 4.5d'),'half-day decay derived from source.at')
check(s.containers.vial102.decay=='A' and not has(c,'mana vial102: expires'),'artifact never decays')
local decay=s.containers.vial101.decay;M.state(c)
check(M.state(c).containers.vial101.decay==decay,'render does not repeatedly subtract age')
c.connected(false);check(M.state(c).stale and not M.audit(c,c.query),'disconnect invalidates usability and blocks queries')
M.invalidate(c);c.connected(true);run(c,5)
check(M.state(c).stale and #c.queries==3,'invalidated baseline not resurrected by quiet/reconnect')
-- Policy changes must not clear explicit stale evidence.
c=context();f=fixture();audit(c,f);c.supplies_quiet=false
use(c,'vigor');c.supplies_quiet=true
check(c.containers_data.sources.vial.stale and M.state(c).stale,'quiet switch cannot erase legacy invalidation')
run(c,10);check(#c.queries==3,'old debounce ignored by quiet policy')
-- Legacy false retains existing broad use invalidation / all-three debounce.
c=context();c.supplies_quiet=false;f=fixture();audit(c,f)
use(c,'vigor');check(M.state(c).stale and M.state(c).containers.vial104.count==250,'legacy never decrements')
c.advance(5);M.service(c,c.action)
check(#c.queries==6,'explicit false preserves full all-kind use refresh')
-- Use arriving after dispatch fences that kind, even before its header.
c=context();f=fixture();audit(c,f);check(M.audit(c,c.query,'vial'),'targeted pre-use query')
use(c,'vigor');frame(c,'vial',f.vial)
check(M.state(c).containers.vial104.count==249 and c.containers_data.sources.vial.stale,'pre-use frame cannot overwrite usage')
check(M.state(c).sources.pipe.tracked,'unrelated kind not invalidated')
-- Failed/synchronous targeted query callbacks must never commit speculative data.
for _,failure in ipairs({'false','throw'})do
 c=context();f=fixture()
 check(not M.audit(c,function(cmd)
  check(cmd=='pipelist','targeted command strict')
  frame(c,'pipe',f.pipe)
  check(not M.state(c).containers.pipe101,'no speculative synchronous commit')
  check(not M.audit(c,c.query,'vial'),'reentrant audit rejected')
  if failure=='throw' then error('fake failure') end
  return false
 end,'pipe'),'uncertain targeted transport returns false')
 check(M.state(c).quarantine and not M.state(c).containers.pipe101,'false/throwing target quarantined')
end
-- Timeout quarantine and uncertain refill barriers survive all passive paths.
c=context();f=fixture();audit(c,f);empty(f.pipe[1]);audit(c,f,'pipe');supply(c,'ic:reishi',100)
check(not M.service(c,function(cmd)c.actions[#c.actions+1]=cmd;return false end),'uncertain refill send')
local barrier=c.containers_data.barrier
check(barrier and barrier.fault,'uncertain barrier latched')
M.service(c,c.action);check(c.queries[#c.queries]=='pipelist','uncertain action still receives only targeted readback')
c.advance(11);M.state(c)
check(M.state(c).quarantine,'timed-out readback quarantines stream')
M.invalidate(c);M=dofile(root..'containers.lua');M.prompt(c)
c.connected(false);M.state(c);c.connected(true);c.supplies_quiet=false;c.supplies_quiet=true
f.pipe[1].label='a reishi mushroom';f.pipe[1].n=250;frame(c,'pipe',f.pipe)
run(c,20)
check(c.containers_data.barrier==barrier and #c.actions==1 and M.state(c).quarantine,'reload/invalidate/reconnect/prompt/quiet do not disarm barriers')
check(not M.audit(c,c.query,'pipe') and M.state(c).containers.pipe101.count==0,'late uncorrelated healthy reply cannot authorize or clear barrier')
-- No repeated readback on recognized but malformed list, even more uses.
c=context();f=fixture();f.vial[4].n=1;audit(c,f);use(c,'vigor');M.service(c,c.action)
frame(c,'vial',f.vial,true);run(c,100)
check(#c.queries==4 and #c.actions==0,'malformed target has no timed retry')
check(not M.audit(c,c.query,'bogus') and #c.queries==4,'unknown audit kind rejected without side effects')
-- Per-kind last-use behavior and targeted pipe fill/light confirmations.
c=context();f=fixture();f.bandage[4].n=1;audit(c,f)
M.text(c,'You press a mending poultice against your body.');M.service(c,c.action)
check(c.queries[4]=='bandagelist' and #c.actions==0,'last bandage press gets only bandage readback')
check(c.containers_data.stock_needed=='fluidcache','bandage exhaustion requests one FC check')
c.containers_data.stock_needed=nil;run(c,3)
check(not c.containers_data.stock_needed,'bandage cache-proof budget retained while readback pending')
f.bandage[4].n=250;frame(c,'bandage',f.bandage)
check(M.state(c).containers.bandage104.count==250 and #c.actions==0,'native bandage autofill also wins')
c=context();f=fixture();audit(c,f);empty(f.pipe[1]);audit(c,f,'pipe');supply(c,'ic:reishi',100)
check(M.service(c,c.action) and c.actions[1]=='put reishi in pipe101','known pipe fill allowlisted')
M.service(c,c.action);check(c.queries[#c.queries]=='pipelist','pipe refill targets pipe readback')
f.pipe[1].label='a reishi mushroom';f.pipe[1].n=10;f.pipe[1].lit='No';frame(c,'pipe',f.pipe)
check(M.state(c).refill.phase=='needs light','native positive unlit pipe transitions barrier')
check(M.service(c,c.action) and c.actions[2]=='light pipes','one bounded light action')
M.service(c,c.action);check(c.queries[#c.queries]=='pipelist' and #c.queries==6,'lighting readback targets only pipe')
f.pipe[1].lit='Yes';frame(c,'pipe',f.pipe);run(c,5)
check(not M.state(c).refill and #c.actions==2,'positive lit native frame resolves final pipe barrier')
-- Ambiguous uses after an EMPTY readback cannot resurrect refill authority,
-- including aggregate debt saturated at zero.
c=context();f=fixture();f.vial[4].n=1
f.vial[#f.vial+1]={id='vial999',label='an elixir of vigor',n=1,decay='A'}
audit(c,f);use(c,'vigor');M.service(c,c.action)
empty(f.vial[4]);empty(f.vial[#f.vial]);frame(c,'vial',f.vial);supply(c,'vigor',100)
use(c,'vigor');M.service(c,c.action)
check(#c.actions==0 and #c.queries==4,'ambiguous post-readback use blocks helper even at zero debt')
check(M.state(c).containers.vial104.estimated and M.state(c).containers.vial999.estimated,'both ambiguous zero IDs remain estimates')
-- Cache requests coalesce FC and preserve intent behind an occupied IC marker.
c=context();f=fixture();f.vial[4].n=1;audit(c,f)
c.containers_data.stock_needed='ic';use(c,'vigor')
check(c.containers_data.stock_needed=='ic' and c.containers_data.sources.vial.stock_due=='fluidcache','occupied stock marker retains delayed FC intent')
c.containers_data.stock_needed=nil;M.service(c,c.action)
check(c.containers_data.stock_needed=='fluidcache','next service queues delayed FC once')
c.containers_data.stock_needed=nil;run(c,2)
check(not c.containers_data.stock_needed,'failed/unknown FC read retains generation budget')
f.vial[4].n=1;frame(c,'vial',f.vial);use(c,'vigor')
check(c.containers_data.stock_needed=='fluidcache','new positive native generation allows next exhaustion FC proof')
-- Pipe exhaustion requests no speculative IC check; native Rift owns totals.
c=context();f=fixture();f.pipe[1].n=1;audit(c,f)
M.text(c,'You smoke a reishi mushroom.');M.service(c,c.action)
check(c.queries[4]=='pipelist' and not c.containers_data.stock_needed,'pipe last use queues pipe only, not IC')
-- A valid empty readback without reserves does not spend a list per later use.
c=context();f=fixture();f.vial[4].n=1;audit(c,f);use(c,'vigor');M.service(c,c.action)
empty(f.vial[4]);frame(c,'vial',f.vial);M.service(c,c.action)
c.containers_data.stock_needed=nil
for i=1,100 do use(c,'vigor');M.service(c,c.action)end
check(#c.queries==4 and #c.actions==0,'empty native frame retains spent possible-empty budget')
check(not c.containers_data.stock_needed,'later uses cannot rearm failed reserve proof')
-- Hot-loaded old baseline acquires usage provenance without clearing stale flags.
c=context();f=fixture();audit(c,f)
c.containers_data.sources.vial.rows.vial104.verified_count=nil
c.advance(100);M=dofile(root..'containers.lua');use(c,'vigor')
check(M.state(c).containers.vial104.count==249 and M.state(c).containers.vial104.verified_count==250,'pre-tracking baseline retains original verified count')
-- Successful synchronous targeted frames commit only the selected kind.
c=context();f=fixture()
check(M.audit(c,function(cmd)frame(c,commands[cmd],f[commands[cmd]])end,'vial'),'synchronous targeted dispatch')
check(M.state(c).containers.vial104.count==250 and not M.state(c).containers.pipe101,'targeted synchronous commit is kind-local')
-- An unrecognized response spends its one readback and times out, never retries.
c=context();f=fixture();f.vial[4].n=1;audit(c,f);use(c,'vigor');M.service(c,c.action)
M.text(c,'This is not a native container frame.');M.prompt(c);run(c,100)
check(#c.queries==4 and M.state(c).quarantine and #c.actions==0,'unrecognized response times out and quarantines without retries')
print('PASS quiet carried usage '..checks..' assertions (offline FakeClock/FakeSender)')
