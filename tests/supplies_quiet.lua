-- Quiet supply policy: no live sender, all clock/timer/event data synthetic.
local root=assert(arg[1]);local S=dofile(root..'supplies.lua')
local t,ids,checks=100,0,0;local timers,events,commands={},{},{}
local function check(ok,why)checks=checks+1;assert(ok,why)end
function tempTimer(_,fn)ids=ids+1;timers[ids]=fn;return ids end
function killTimer(id)timers[id]=nil end
function registerAnonymousEventHandler(e,fn)ids=ids+1;events[ids]={e,fn};return ids end
function killAnonymousEventHandler(id)events[id]=nil end
function tempRegexTrigger()ids=ids+1;return ids end
function tempPromptTrigger()ids=ids+1;return ids end
function killTrigger()end
local backend={}
function backend.state()return{issues={},stale=false,pending=false}end
function backend.audit(c,sender,kind)
 for _,k in ipairs(kind and {kind}or{'vial','pipe','bandage'})do sender(({vial='viallist',pipe='pipelist',bandage='bandagelist'})[k])end
 return true
end
function backend.invalidate()error('hot preserve invalidated container evidence')end
function backend.text()end
function backend.prompt()end
function backend.service()end
local runner,position,barrier={waiting=true},{x=793,y=248},{fault='unresolved'}
local c={mode='BASH',runner=runner,supplies_clock=function()return t end,supplies_connected=function()return true end,containers=backend,containers_data={barrier=barrier},supplies_position=position}
local function sender(cmd)commands[#commands+1]=cmd end
S.bind_containers(c,sender)
-- Ordinary attachment owns invalidation; initial standalone fixture has no backend yet.
c.containers=nil;S.attach(c);c.containers=backend
local d=c.supplies_data
local fluids={'infusion','prudence','purgative','soothing','health','mana','speed','vigor','levitation','harmony','arcane','immunity','mass','caloric','epidermal','mending','restoration'}
local herbs={'acuity','amaurosis','anabiotic','antipsychotic','coagulation','decongestant','depressant','eucrasia','euphoriant','kawhepill','opiate','ototoxin','panacea','paste','pluck','somnium','steroid','stimulant','thanatonin','waterbreathing','reishi','willow','yarrow'}
for _,k in ipairs(fluids)do S.stock(c,k,500,'native fixture')end
for _,k in ipairs(herbs)do S.stock(c,'ic:'..k,500,'native fixture')end
for _,s in pairs(d.sources)do s.stale=false;s.complete=true;s.last_complete=t;s.status='complete'end
d.requested=true;c.supplies_sender=sender
local function tick()local id=c.supplies_owner.timer;local fn=assert(timers[id]);timers[id]=nil;fn()end
for i=1,720 do t=t+5;tick()end
check(#commands==0,'one hour idle caused repeated lists')
check(not S.state(c).stale and S.state(c).tracked,'90-second age broke event-tracked baseline')
check(S.state(c).stocks.health.at==100,'render pretended old stock was freshly verified')
check(S.rift(c,{name='anabiotic',amount='199'}),'fresh rift rejected')
check(S.state(c).stocks['ic:anabiotic'].count==199,'rift amount was not absolute')
check(S.rift(c,{name='anabiotic',amount='0'})and S.state(c).stocks['ic:anabiotic'].count==0,'zero lost')
check(not S.rift(c,{name='anabiotic',amount='-1'}),'invalid rift accepted')
S.text(c,'You pay 10 gold sovereigns to add 5 sips of an elixir of health to your fluidcache.')
t=t+5;tick();check(#commands==1 and commands[1]=='fluidcache','FC purchase spammed IC/containers')
for i=1,30 do t=t+5;tick()end
check(#commands==1,'unknown cache response retried automatically')
-- Isolate an explicit targeted stock request from the backend.
c.containers_data.stock_needed='ic';tick()
check(#commands==2 and commands[2]=='ic' and c.containers_data.stock_needed==nil,'stock request not targeted/one-shot')
for i=1,30 do t=t+5;tick()end
check(#commands==2,'targeted stock read retried on timer')
local old=c.supplies_owner;local data=c.supplies_data;local version=data.stocks.health.version
S.attach(c,true)
check(not old.alive and c.supplies_owner~=old,'old owner still active')
check(c.supplies_data==data and data.stocks.health.version==version,'hot attach destroyed stock baseline')
check(c.containers_data.barrier==barrier and c.runner==runner and c.supplies_position==position and c.mode=='BASH','hot attach altered barriers/combat/position')
check(not S.audit(c,nil,true,'quit'),'invalid source accepted')
check(#commands==2,'invalid source dispatched')

-- Disabling refill actions must not disable passive exhaustion readbacks.
local C=dofile(root..'containers.lua');local q={}
local c2={mode='OFF',supplies_clock=function()return t end,supplies_connected=function()return true end,containers_refill_enabled=false}
S.attach(c2);c2.containers=C;S.bind_containers(c2,function(cmd)q[#q+1]=cmd end)
c2.supplies_data.requested=true;c2.supplies_sender=function(cmd)q[#q+1]=cmd end
check(C.audit(c2,c2.containers_query_sender,'vial'),'disabled-refill baseline rejected')
C.text(c2,'Vial Elixir Sips Decay');C.text(c2,'-------------------------')
for i,n in ipairs({'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'})do
 local name=n=='arcane'and'an elixir of the arcane'or n=='purgative'and'a purgative concoction'or'an elixir of '..n
 C.text(c2,'vial'..i..'  '..name..'  '..(n=='vigor'and 1 or 50)..'  A')
end
C.text(c2,'-------------------------');C.prompt(c2)
S.text(c2,'You take a drink of an elixir of vigor from an academy vial.')
for i=1,3 do t=t+5;local id=c2.supplies_owner.timer;local fn=assert(timers[id]);timers[id]=nil;fn()end
local vials=0;for _,cmd in ipairs(q)do if cmd=='viallist'then vials=vials+1 end;check(not cmd:find('fill',1,true)and not cmd:find('put ',1,true),'disabled refill dispatched action')end
check(vials==2,'disabled refill suppressed targeted exhaustion readback')
print('PASS refill-disabled monitoring regression: baseline plus one targeted vial readback, zero refill actions')

print('PASS quiet supplies '..checks..' assertions: no one-hour polling, native absolute/zero stock, original timestamps, targeted reads and preserved hot ownership')
