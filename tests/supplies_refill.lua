local S=dofile(assert(arg[1])..'supplies.lua');local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local t=100;local ids=0;local events,timers={},{};local commands={}
function registerAnonymousEventHandler(e,f)ids=ids+1;events[ids]={e,f};return ids end
function killAnonymousEventHandler(id)events[id]=nil end
function tempTimer(delay,f)ids=ids+1;timers[ids]={delay=delay,fn=f};return ids end
function killTimer(id)timers[id]=nil end
local c={current={mode='SHADOW'},supplies_clock=function()return t end,supplies_connected=function()return true end}
c.supplies_sender=function(command)commands[#commands+1]=command end
S.attach(c)
check(S.rift(c,{name='anabiotic',amount='503'}),'valid absolute event rejected')
check(S.state(c).stocks['ic:anabiotic'].count==503,'event treated as delta')
S.rift(c,{name='anabiotic',amount='502'});check(S.state(c).stocks['ic:anabiotic'].count==502,'withdrawal not absolute')
S.rift(c,{name='anabiotic',amount='503'});check(S.state(c).stocks['ic:anabiotic'].count==503,'incall not absolute')
check(not S.rift(c,{name='wood',amount='0'})and not S.state(c).stocks['ic:wood'],'commodity leaked')
for _,n in ipairs({'-1','1e3','1.5',' 3'})do check(not S.rift(c,{name='anabiotic',amount=n}),'malformed amount accepted')end
S.text(c,'You pay 1050 gold sovereigns to add 1500 sips of an elixir of infusion to your fluidcache.')
S.text(c,'You pay 35 gold sovereigns to add 50 sips of a soothing poultice to your fluidcache.')
check(#commands==0,'receipt sent synchronously')
t=106;local tick=c.supplies_owner.timer;local callback=timers[tick].fn;timers[tick]=nil;callback()
check(#commands==2 and commands[1]=='fluidcache'and commands[2]=='ic','SHADOW receipt refresh failed')
check(not S.state(c).stocks.infusion,'purchase delta falsely assigned total')
check(c.current.mode=='SHADOW','mode changed');S.detach(c);check(next(events)==nil,'event owner leaked')
print('PASS refill adapters '..checks..' assertions: absolute INCALL/withdrawal, strict cure filter, debounced FC purchase refresh, SHADOW preserved')
