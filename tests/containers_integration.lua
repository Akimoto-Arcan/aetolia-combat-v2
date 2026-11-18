-- Integration contract tests; pure backend is intentionally stubbed here.
local root=assert(arg[1]);local realdofile=dofile;local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local t,online,ids=100,true,0
local timers,handlers,sends={},{},{}
local snapshot={issues={},stale=true,pending=false,containers={}}
local calls={audit=0,text=0,prompt=0,service=0,invalidate=0}
local backend={}
function backend.state(c)return snapshot end
function backend.audit(c,sender)
 calls.audit=calls.audit+1
 for _,cmd in ipairs({'viallist','pipelist','bandagelist'})do sender(cmd)end
 return true
end
function backend.text(c,line)calls.text=calls.text+1;calls.last_line=line end
function backend.prompt(c)calls.prompt=calls.prompt+1 end
function backend.service(c,sender)calls.service=calls.service+1;calls.action_sender=sender end
function backend.invalidate(c)calls.invalidate=calls.invalidate+1;snapshot.stale=true end
function getEpoch()return t end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,online end
function registerAnonymousEventHandler(e,f)ids=ids+1;handlers[ids]={e,f};return ids end
function killAnonymousEventHandler(id)handlers[id]=nil end
function tempAlias()ids=ids+1;return ids end
function killAlias()end
function tempRegexTrigger()ids=ids+1;return ids end
function tempPromptTrigger()ids=ids+1;return ids end
function killTrigger()end
function tempTimer(delay,f)ids=ids+1;timers[ids]={delay=delay,fn=f};return ids end
function killTimer(id)timers[id]=nil end
function send(cmd)sends[#sends+1]=cmd end
function sendGMCP()end
function dofile(path)
 if path:match('/gui.lua$')then return {create=function()end,refresh=function()end}end
 if path:match('/containers.lua$')then return backend end
 return realdofile(path)
end
local label={}
function label:move(x,y)self.x=x;self.y=y end
function label:resize(w,h)self.w=w;self.h=h end
function label:echo(text)self.text=text end
function label:setStyleSheet()end
function label:delete()end
Geyser={Label={new=function()return label end}}
gmcp={Char={Vitals={hp=100,maxhp=100,mp=100,maxmp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1},Status={class='Monk'}},Room={Info={num=1,area='Fixture'},Players={}}}
realdofile(root..'bootstrap.lua')
local c=combat_v2;local S=c.supplies
c.supplies_clock=function()return t end
check(c.containers==backend and c.containers_required,'bootstrap backend missing')
check(c.mode=='OFF' and #sends==0 and calls.audit==0,'startup sent or armed')
check(c.containers_refill_enabled==true,'explicit feature refill default missing')
local runner,target,globe=c.runner,c.current.target,c.elemental_recovery
local query,action=c.containers_query_sender,c.containers_action_sender
for _,cmd in ipairs({'viallist','pipelist','bandagelist'})do check(query(cmd)~=false,'query rejected')end
for _,cmd in ipairs({'bandagelist short','viallist\nquit','inventory','fluidcache','firstaid off','light pipes'})do
 check(query(cmd)==false,'query capability escaped')
end
local fluids={vial={'infusion','prudence','purgative','health','mana','speed','vigor','levitation','harmony','arcane','immunity'},bandage={'soothing','mass','caloric','epidermal','mending','restoration'}}
for family,list in pairs(fluids)do for _,fluid in ipairs(list)do
 check(action('fluidcache fill '..fluid..' '..family..'123')~=false,'valid family rejected')
end end
for _,herb in ipairs({'reishi','willow','yarrow'})do check(action('put '..herb..' in pipe123')~=false,'valid pipe refill rejected')end
check(action('light pipes')~=false,'lighting rejected')
for _,cmd in ipairs({'fluidcache fill health bandage123','fluidcache fill mending vial123','fluidcache fill unknown vial123','fluidcache fill health vial0','fluidcache fill health vial01','fluidcache fill health vial-1','fluidcache fill health vial1.0','fluidcache fill health vial1\nquit','put wood in pipe123','put yarrow in pipe0','put yarrow in pipe01','put yarrow in pipe1;quit','light pipes\nquit','firstaid on','north','buy 1','fluidcache consume vial1'})do
 check(action(cmd)==false,'action capability escaped: '..cmd)
end
c.containers_refill_enabled=false;check(action('light pipes')==false,'permission ignored');c.containers_refill_enabled=true
online=false;check(query('viallist')==false and action('light pipes')==false,'offline adapter sent');online=true
sends={};check(combat_v2_supplies('check'),'public check failed')
check(calls.audit==1 and #sends==5,'public check did not audit both caches and containers')
local function tick()
 local id=c.supplies_owner.timer;local fn=assert(timers[id]).fn;timers[id]=nil;fn()
end
S.text(c,'You fill your pipe with a yarrow root.');S.prompt(c)
check(calls.text==1 and calls.prompt==1 and calls.last_line=='You fill your pipe with a yarrow root.','text/prompt not forwarded')
for i=1,40 do S.text(c,'You fill your pipe with a yarrow root.')end
t=104;tick();check(calls.audit==1,'hint ignored minimum 5 second separation')
t=105;tick();check(calls.audit==2,'known own acknowledgement did not refresh')
check(calls.action_sender==c.containers_action_sender,'service action capability missing')
-- Unknown own usage messages only forward: never fabricate counts or issue queries.
for i=1,40 do S.text(c,'You take a drink of an unverified fluid.')end
t=110;tick();check(calls.audit==2,'unknown consumption guessed')
c.containers_refill_enabled=false;local services=calls.service;t=115;tick();check(calls.service==services,'service ignored permission');c.containers_refill_enabled=true
-- No responses: cache timeouts expire, periodic monitoring still runs in OFF.
t=160;tick();check(#sends==10,'unexpected early periodic queries')
t=165;tick();check(calls.audit==3 and #sends==13,'OFF monitoring not refreshed at 60 seconds')
online=false;local sent=#sends;t=230;tick();check(#sends==sent,'disconnected tick sent');online=true
-- Seed a complete cache proof solely to isolate renderer contract behavior.
local d=c.supplies_data
for key in pairs(d.stocks)do d.stocks[key]=nil end
local elixirs={'infusion','prudence','purgative','soothing','health','mana','speed','vigor','levitation','harmony','arcane','immunity','mass','caloric','epidermal','mending','restoration'}
local pills={'acuity','amaurosis','anabiotic','antipsychotic','coagulation','decongestant','depressant','eucrasia','euphoriant','kawhepill','opiate','ototoxin','panacea','paste','pluck','somnium','steroid','stimulant','thanatonin','waterbreathing','reishi','willow','yarrow'}
for _,key in ipairs(elixirs)do d.stocks[key]={count=200,source='fixture',at=t}end
for _,key in ipairs(pills)do d.stocks['ic:'..key]={count=200,source='fixture',at=t}end
for _,s in pairs(d.sources)do s.pending=false;s.frame=nil;s.stale=false;s.complete=true;s.last_complete=t;s.status='complete'end
snapshot={issues={},stale=false,pending=false,containers={vial123={}}}
local s=S.render(c)
check(s.title=='OK' and s.level=='ok' and #s.entries==0 and s.note=='','healthy display not compact')
check(not label.text:find('unverified',1,true) and label.h==48,'healthy proof falsely unverified or tall')
snapshot.issues={'vial123 expiry 1 real day','pipe7 <low> & empty'}
s=S.render(c);check(s.level=='warning' and #s.entries==2,'carried issues lost or treated as cache keys')
check(label.text:find('&lt;low&gt; &amp;',1,true) and not label.text:find('<low>',1,true),'carried HTML not escaped')
check(S.render(c).entries[1]=='vial123 expiry 1 real day','duplicate expiry warning cleared on render')
snapshot.issues={};snapshot.stale=true;check(S.render(c).level=='warning','stale containers healthy')
snapshot.stale=false;snapshot.pending=true;check(S.render(c).level=='warning','pending containers healthy')
c.containers=nil;check(S.render(c).level=='warning','missing required backend healthy');c.containers=backend
c.containers_data={pending={phase='unknown committed'}};local barrier=c.containers_data.pending
S.detach(c);S.attach(c)
check(c.containers_data.pending==barrier and calls.invalidate>=2,'detach/reload discarded root barrier')
check(c.runner==runner and c.current.target==target and c.elemental_recovery==globe and c.mode=='OFF','integration changed combat identity')
print('PASS container integration '..n..' assertions: stub contract, actual bootstrap, narrow senders, lifecycle, OFF polling, debounce, compact escaped UI; no live transport')
