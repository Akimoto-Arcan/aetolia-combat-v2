-- Offline only: fake clocks, native frames and injected fake transports.
local root=arg[1] or 'combat_v2/'
local M=dofile(root..'containers.lua')
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg or ('check '..checks)) end
local function has(c,s)
 for _,v in ipairs(M.state(c).issues) do if v:find(s,1,true) then return true end end
 return false
end
local required={vial={'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'},
 pipe={'reishi','willow','yarrow'},bandage={'caloric','epidermal','mass','mending','restoration','soothing'}}
local headers={vial='Vial           Elixir                           Sips        Decay',
 pipe='Pipe           Herb                     Puffs     Decay     Lit',
 bandage='Bandage           Poultice                      Presses     Decay'}
local querykind={viallist='vial',pipelist='pipe',bandagelist='bandage'}
local function fixture()
 local f={vial={},pipe={},bandage={}}
 for k,names in pairs(required) do for i,n in ipairs(names) do
  local label=k=='vial' and ('an elixir of '..n) or (k=='bandage' and ('a '..n..' poultice') or ({reishi='a reishi mushroom',willow='some willow bark',yarrow='a yarrow root'})[n])
  if n=='arcane' then label='an elixir of the arcane' end
  if n=='purgative' then label='a purgative concoction' end
  f[k][#f[k]+1]={id=k..(100+i),label=label,n=k=='pipe' and 10 or 60,decay='A',lit='Yes'}
 end end
 return f
end
local function context()
 local t=100;local c={mode='OFF',supplies_quiet=false}
 c.containers_clock=function()return t end;c.containers_connected=function()return true end
 c.advance=function(dt)t=t+dt end
 c.supplies={state=function()return {stocks={}} end}
 return c
end
local function frame(c,k,rows,footer,prompt)
 M.text(c,headers[k]);M.text(c,string.rep('-',71))
 for _,r in ipairs(rows) do
  M.text(c,r.id..'      '..r.label..'       '..r.n..'       '..r.decay..(k=='pipe' and ('       '..r.lit) or ''))
  M.text(c,'FIRSTAID: unrelated chatter is not a row.')
 end
 if footer~=false then M.text(c,string.rep('-',71)) end
 if prompt~=false then M.prompt(c) end
end
local function audit(c,f)
 local sent={};check(M.audit(c,function(cmd)sent[#sent+1]=cmd end),'audit dispatched')
 check(table.concat(sent,',')=='viallist,pipelist,bandagelist','only three native queries')
 for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
end
local function stock(c,name,n,age)
 c.supplies={state=function()return {stocks={[name]={count=n,at=c.containers_clock()-(age or 0)}}} end}
end
local function empty(r)r.label='empty';r.n=0 end
local function refill(r,label,n)r.label=label;r.n=n or 50 end
local c=context();local f=fixture()
check(M.state(c).stale and not M.state(c).complete,'unaudited unknown')
audit(c,f)
check(M.state(c).completefresh and #M.state(c).issues==0,'all 20 healthy, no healthy list')
check(M.state(c).containers.bandage101.count==60,'native 60 presses valid')
check(c.containers_pipe_assignments.pipe103=='yarrow','learn current IDs')
-- Each duplicate alarms independently; 4 warns, 5 and artifact A do not.
f.vial[1].decay='4';f.vial[2].decay='5';f.vial[3].decay='A'
f.vial[#f.vial+1]={id='vial999',label='an elixir of health',n=10,decay='1'}
f.pipe[1].n=2;f.bandage[1].n=10
audit(c,f)
check(has(c,'health vial101: expires in 4d'),'strict 4 boundary')
check(not has(c,'mana vial102: expires'),'5 not expiring')
check(not has(c,'speed vial103: expires'),'artifact never expires')
check(has(c,'health vial999: low (10)') and has(c,'health vial999: expires in 1d'),'duplicate still alarms')
check(has(c,'reishi pipe101: low (2)') and has(c,'caloric bandage101: low (10)'),'low boundaries')
local sends=0
check(not M.service(c,function()sends=sends+1 end) and sends==0,'never consume or fill low')
-- Return-to-healthy and per-ID deletion only after complete native frame + prompt.
f=fixture();audit(c,f);check(not M.state(c).containers.vial999,'remove missing IDs on complete')
check(#M.state(c).issues==0,'healthy only OK')
f.vial[1].n=1
check(M.audit(c,function()end),'staged audit')
frame(c,'vial',f.vial,true,false)
check(M.state(c).containers.vial101.count==60,'footer alone does not commit')
M.prompt(c);check(M.state(c).containers.vial101.count==1,'real prompt commits')
frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
-- Malformed/partial/timeouts preserve prior rows and warn, never omitted=empty.
check(M.audit(c,function()end),'partial audit')
frame(c,'vial',{},false,true)
check(M.state(c).containers.vial101.count==1 and M.state(c).stale,'partial does not remove')
frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
check(M.audit(c,function()end),'malformed audit')
M.text(c,headers.vial);M.text(c,'-------------------');M.text(c,'vial101 broken row');M.text(c,'-------------------');M.prompt(c)
check(M.state(c).containers.vial101.count==1 and M.state(c).stale,'malformed retains evidence')
c.advance(11);check(not M.state(c).pending and M.state(c).stale,'timeout bounded')
-- Synchronous callbacks must not commit false/throwing sender evidence.
for _,failure in ipairs({'false','throw'}) do
 local x=context();local fx=fixture()
 local result=M.audit(x,function(cmd)
  local k=querykind[cmd];frame(x,k,fx[k])
  check(not M.state(x).containers[k..'101'],'no synchronous speculative commit')
  check(not M.audit(x,function()error('reentry')end),'reentrant audit blocked')
  if failure=='throw' then error('fake failure') end
  return false
 end)
 check(not result and not M.state(x).complete,'failed query not proof')
 check(next(M.state(x).containers)==nil,'failed native callbacks discarded')
end
-- Empty FC containers require PRIOR same-ID knowledge and genuine reserve.
c=context();f=fixture();empty(f.vial[1]);audit(c,f)
stock(c,'health',100)
check(not M.service(c,function()error('unassigned')end),'unidentified empty spare never assigned')
check(has(c,'vial101: EMPTY (unassigned)') and has(c,'health: missing vial coverage'),'unassigned/missing coverage')
c=context();f=fixture();audit(c,f);empty(f.vial[1]);audit(c,f)
check(has(c,'health vial101: EMPTY'),'known empty warns')
for _,v in ipairs({{n=0,age=0},{n=10,age=91}}) do
 stock(c,'health',v.n,v.age)
 check(not M.service(c,function()error('no fresh stock')end),'zero/stale reserve blocks')
end
stock(c,'health',100);c.containers_refill_enabled=false
check(not M.service(c,function()error('optout')end),'explicit optout')
c.containers_refill_enabled=nil
local commands={};local function action(cmd) commands[#commands+1]=cmd;check(not M.service(c,action),'reentrant service blocked') end
local ok,cmd=M.service(c,action)
check(ok and cmd=='fluidcache fill health vial101' and commands[1]==cmd,'command STRING exact allowlisted syntax in OFF')
check(has(c,'health vial101: EMPTY') and M.state(c).refill,'send is not stock proof')
M.text(c,'You fill vial101 with an elixir of health.');M.prompt(c)
check(M.state(c).refill~=nil,'ACK alone not proof')
-- The stored audit sender is used exactly once, not arbitrary action transport.
M.service(c,action);check(#commands==1 and M.state(c).pending,'one post-action native audit')
frame(c,'vial',f.vial);frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
for i=1,10 do M.service(c,action) end
check(#commands==1 and M.state(c).refill,'empty readback never blind retry')
c.advance(16);M.service(c,action)
check(M.state(c).refill.fault and #commands==1,'bounded unresolved timeout')
M.invalidate(c);local barrier=c.containers_data.barrier
M=dofile(root..'containers.lua')
check(c.containers_data.barrier==barrier,'reload and invalidate retain barrier')
refill(f.vial[1],'an elixir of health');audit(c,f)
check(not M.state(c).refill and not has(c,'health vial101: EMPTY'),'NEW positive authoritative readback clears')
-- Transport failure remains latched; late positive evidence may settle it.
for _,failure in ipairs({'false','throw'}) do
 local x=context();local fx=fixture();audit(x,fx);empty(fx.bandage[4]);audit(x,fx);stock(x,'mending',100)
 local n=0
 check(not M.service(x,function(command)n=n+1;check(command=='fluidcache fill mending bandage104','bandage fill syntax');if failure=='throw' then error('fake')end;return false end),'failed refill return')
 check(M.state(x).refill.fault and has(x,'mending bandage104: EMPTY'),'failure sticky')
 M.service(x,function()n=n+1 end)
 for _,k in ipairs({'vial','pipe','bandage'}) do frame(x,k,fx[k]) end
 x.advance(11);M.service(x,function()n=n+1 end)
 check(n==1,'failure no blind action retry')
 refill(fx.bandage[4],'a mending poultice',56);audit(x,fx)
 check(not M.state(x).refill and M.state(x).containers.bandage104.count==56,'late genuine 56 presses resolves')
end
-- Three-pipe inference is unique and bounded; ambiguity never guesses.
c=context();f=fixture();empty(f.pipe[3]);audit(c,f)
check(M.state(c).containers.pipe103.type=='yarrow','exact unique missing herb inferred')
stock(c,'ic:yarrow',10);commands={}
check(M.service(c,function(cmd)commands[#commands+1]=cmd end),'pipe refill dispatch')
check(commands[1]=='put yarrow in pipe103','native put syntax')
M.service(c,function()error('no duplicate')end)
refill(f.pipe[3],'a yarrow root',10);f.pipe[3].lit='No'
frame(c,'vial',f.vial);frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
check(M.state(c).refill.phase=='needs light','positive but unlit requires bounded lighting')
check(M.service(c,function(cmd)commands[#commands+1]=cmd end),'light dispatch')
check(commands[2]=='light pipes','only validated unlit pipe triggers light')
M.service(c,function()error('no repeat light')end)
f.pipe[3].lit='Yes';frame(c,'vial',f.vial);frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
check(not M.state(c).refill and #commands==2,'positive lit readback completes')
for _,variant in ipairs({'twoempty','extra','duplicate'}) do
 local x=context();local fx=fixture();empty(fx.pipe[3])
 if variant=='twoempty' then empty(fx.pipe[2])
 elseif variant=='extra' then fx.pipe[4]={id='pipe999',label='empty',n=0,decay='A',lit='Yes'}
 else fx.pipe[2].label='a reishi mushroom' end
 audit(x,fx)
 check(not M.state(x).containers.pipe103.type and has(x,'pipe103: EMPTY (unassigned)'),'ambiguous pipe no inference '..variant)
end
-- Native autofill wins before helper dispatch: re-read stock callbacks, no duplicates.
c=context();f=fixture();audit(c,f);empty(f.vial[1]);audit(c,f)
c.supplies.state=function()
 refill(f.vial[1],'an elixir of health');audit(c,f)
 check(not M.service(c,function()error('nested stock')end),'stock-adapter reentry blocked')
 return {stocks={health={count=100,at=c.containers_clock()}}}
end
check(not M.service(c,function()error('native already refilled')end),'native positive wins at dispatch')
-- Queries begun during action transport do not clear the barrier.
c=context();f=fixture();audit(c,f);empty(f.vial[1]);audit(c,f);stock(c,'health',100)
M.service(c,function()
 refill(f.vial[1],'an elixir of health');audit(c,f)
 check(M.state(c).refill~=nil,'synchronous action callbacks not proof')
end)
check(M.state(c).refill~=nil,'post-transport version fence retained')
M.service(c,function()error('no repeat')end)
frame(c,'vial',f.vial);frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
check(not M.state(c).refill,'post-send NEW snapshot resolves')
-- Debounce receipts; never decrement an arbitrary duplicate.
c=context();f=fixture();audit(c,f)
M.text(c,'You take a drink from an elixir of health.');M.text(c,'You take a drink from an elixir of health.')
check(M.state(c).stale and M.state(c).containers.vial101.count==60,'use makes uncertain, not invented count')
M.service(c,function()error('no action')end);check(not M.state(c).pending,'receipt waits minimum five seconds')
c.advance(5);M.service(c,function()error('queries only')end);check(M.state(c).pending,'debounced refresh')
frame(c,'vial',f.vial);frame(c,'pipe',f.pipe);frame(c,'bandage',f.bandage)
check(M.state(c).completefresh,'receipt snapshot fresh')
c.advance(91);check(M.state(c).stale and not M.state(c).complete,'old snapshot never OK')
check(c.mode=='OFF','mode never changed')
-- Expiry every strict boundary and unknown crafting fluids excluded.
for _,days in ipairs({'0','1','2','3','4','5','A'}) do
 local x=context();local fx=fixture();fx.vial[5].decay=days;audit(x,fx)
 check(has(x,'levitation vial105: expires')==(days~='5' and days~='A'),'expiry boundary '..days)
end
c=context();f=fixture();f.vial[12]={id='vial900',label='a crafting venom',n=1,decay='0'};audit(c,f)
check(#M.state(c).issues==0,'venoms/crafting fluids not curative alerts')
-- All twenty curative types warn individually at low thresholds.
c=context();f=fixture()
for k,rows in pairs(f) do for _,r in ipairs(rows) do r.n=k=='pipe' and 2 or 10 end end
audit(c,f);check(#M.state(c).issues==20,'every one of 20 low types reported')
c.containers_vial_low=9;c.containers_bandage_low=9;c.containers_pipe_low=1
check(#M.state(c).issues==0,'configurable inclusive low thresholds')
-- Real-prompt staging supports all three native frames in a single transaction.
c=context();f=fixture();M.audit(c,function()end)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k],true,false) end
check(not M.state(c).completefresh and not next(M.state(c).containers),'no early multi-frame commit')
M.prompt(c);check(M.state(c).completefresh,'single real prompt commits wellformed frames')
-- A receipt newer than a query must fence that old snapshot, even before header.
M.audit(c,function()end);M.text(c,'You take a drink of an elixir of health.')
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
check(M.state(c).stale and not M.state(c).completefresh,'new use fences prior queries')
c.advance(5);M.service(c,function()error('read only')end)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
check(M.state(c).completefresh,'newer post-use audit restores evidence')
-- Duplicate rows and malformed rows after the footer cannot silently remove IDs.
for _,variant in ipairs({'duplicate','trailing','noheader'}) do
 local x=context();local fx=fixture();audit(x,fx);M.audit(x,function()end)
 if variant=='noheader' then M.text(x,'vialBROKEN  bad') end
 M.text(x,headers.vial);M.text(x,'-------------------')
 M.text(x,'vial101      an elixir of health      1      A')
 if variant=='duplicate' then M.text(x,'vial101      an elixir of health      2      A') end
 M.text(x,'-------------------')
 if variant=='trailing' then M.text(x,'vialBROKEN  bad') end
 M.prompt(x)
 check(M.state(x).containers.vial101.count==60 and M.state(x).stale,'malformed '..variant..' retains prior IDs')
end
-- An unsuccessful post-action read query is tried once; timeout never resends it.
c=context();f=fixture();audit(c,f);empty(f.vial[1]);audit(c,f);stock(c,'health',10)
local querycount=0;c.containers_data.querySender=function()querycount=querycount+1;return false end
M.service(c,function()end);M.service(c,function()error('duplicate')end)
for i=1,10 do c.advance(5);M.service(c,function()error('retry action')end) end
check(querycount==1 and M.state(c).refill.fault~=nil,'uncertain readback quarantines without more sends')
-- An empty pair yields only one committed candidate, even with both reserves.
c=context();f=fixture();audit(c,f);empty(f.vial[1]);empty(f.vial[2]);audit(c,f)
c.supplies.state=function()return {stocks={health={count=10,at=c.containers_clock()},mana={count=10,at=c.containers_clock()}}}end
local actions=0;M.service(c,function()actions=actions+1 end);M.service(c,function()actions=actions+1 end)
check(actions==1,'only one candidate outstanding')
-- Disconnection never sends; all connected modes permit the standing helper.
c.containers_connected=function()return false end
check(not M.audit(c,function()error('offline query')end) and not M.service(c,function()error('offline action')end),'offline fail closed')
for _,mode in ipairs({'OFF','SHADOW','ASSIST','BASH','FULL_AUTO'}) do
 local x=context();x.mode=mode;local fx=fixture();audit(x,fx);empty(fx.vial[1]);audit(x,fx);stock(x,'health',10)
 local n=0;check(M.service(x,function()n=n+1 end) and n==1 and x.mode==mode,'standing refill all modes '..mode)
end
-- Adversarial generation A: delayed EMPTY from an expired query must never
-- acquire a newer query version and refill a currently healthy vial. Since
-- native replies have no correlation ID, even the attempted newer HEALTHY
-- snapshot cannot restore trust after this timeout.
c=context();f=fixture();audit(c,f);stock(c,'health',100)
local old=fixture();empty(old.vial[1])
check(M.audit(c,function()end),'old empty generation dispatched')
c.advance(11)
local queries,actions=0,0
local function query()queries=queries+1 end
local function action()actions=actions+1 end
M.audit(c,query)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
M.audit(c,query)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,old[k]) end
M.service(c,action)
check(not M.state(c).completefresh and M.state(c).quarantine~=nil,'expired generation permanently unknown')
check(M.state(c).containers.vial101.count==60 and actions==0 and queries==0,'old EMPTY cannot authorize fill or relabel evidence')
-- Adversarial generation B: an old HEALTHY query dispatched before an action
-- transport returns false cannot clear its unresolved barrier after timeout.
-- New EMPTY, readback attempts and late HEALTHY frames must all remain inert.
c=context();f=fixture();audit(c,f);empty(f.vial[1]);audit(c,f);stock(c,'health',100)
queries=0;actions=0
check(not M.service(c,function()
 actions=actions+1
 check(M.audit(c,query),'pre-result healthy query dispatched')
 return false
end),'uncertain action committed')
local barrier=c.containers_data.barrier
check(barrier and barrier.fault,'uncertain action barrier exists')
c.advance(11);M.state(c)
M.audit(c,query)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
M.service(c,action)
local healthy=fixture()
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,healthy[k]) end
check(c.containers_data.barrier==barrier and M.state(c).containers.vial101.count==0,'late pre-result HEALTHY cannot clear barrier')
M.audit(c,query)
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k,f[k]) end
M.service(c,action)
check(actions==1 and queries==3 and not M.state(c).completefresh,'no second action or resumed readback after abandoned generation')
M.invalidate(c);M=dofile(root..'containers.lua');M.prompt(c)
c.containers_connected=function()return false end;M.state(c)
c.containers_connected=function()return true end
check(not M.audit(c,query) and c.containers_data.barrier==barrier and M.state(c).quarantine~=nil,'invalidate hotload prompt and connection flag cannot disarm quarantine')
-- Explicit cancellation and uncertain query sends abandon generations too.
for _,failure in ipairs({'invalidate','false','throw'}) do
 local x=context();local fx=fixture();audit(x,fx)
 if failure=='invalidate' then M.audit(x,function()end);M.invalidate(x)
 else M.audit(x,function()
  frame(x,'vial',fx.vial)
  if failure=='throw' then error('uncertain query') end
  return false
 end) end
 check(not M.audit(x,function()error('must not retry')end),'abandoned query cannot restart '..failure)
 for _,k in ipairs({'vial','pipe','bandage'}) do frame(x,k,fx[k]) end
 check(M.state(x).quarantine~=nil and not M.state(x).completefresh,'no delayed evidence after '..failure)
end
print('PASS carried containers '..checks..' assertions (pure fake transports; no live calls)')
